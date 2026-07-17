-- ============================================================
-- Balanzo schema + RLS additions
-- Run in Supabase SQL Editor after verifying columns via:
--   SELECT column_name, data_type FROM information_schema.columns
--   WHERE table_schema = 'public' AND table_name IN (...);
-- ============================================================

-- ── Receipts: fees, discounts, sequence number ───────────────

ALTER TABLE receipts
  ADD COLUMN IF NOT EXISTS service_charge NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discount_amount NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS sequence_number BIGINT;

CREATE UNIQUE INDEX IF NOT EXISTS receipts_user_sequence_idx
  ON receipts (user_id, sequence_number)
  WHERE sequence_number IS NOT NULL;

-- Per-user sequence counter (safe concurrent allocation)
CREATE TABLE IF NOT EXISTS receipt_sequence_counters (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  last_value BIGINT NOT NULL DEFAULT 0
);

ALTER TABLE receipt_sequence_counters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "receipt_sequence_counters_select_own" ON receipt_sequence_counters;
CREATE POLICY "receipt_sequence_counters_select_own"
  ON receipt_sequence_counters FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "receipt_sequence_counters_upsert_own" ON receipt_sequence_counters;
CREATE POLICY "receipt_sequence_counters_upsert_own"
  ON receipt_sequence_counters FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── Family members: relationship + spend limits ──────────────

ALTER TABLE family_members
  ADD COLUMN IF NOT EXISTS relationship TEXT,
  ADD COLUMN IF NOT EXISTS spend_limit NUMERIC,
  ADD COLUMN IF NOT EXISTS pending_spend_limit NUMERIC,
  ADD COLUMN IF NOT EXISTS spend_limit_proposed_by UUID,
  ADD COLUMN IF NOT EXISTS spend_limit_effective_month INTEGER,
  ADD COLUMN IF NOT EXISTS spend_limit_effective_year INTEGER;

-- ── Receipt reports (support tickets) ─────────────────────────

CREATE TABLE IF NOT EXISTS receipt_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receipt_id UUID REFERENCES receipts(id) ON DELETE SET NULL,
  sequence_number BIGINT,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'resolved')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE receipt_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "receipt_reports_select_own" ON receipt_reports;
CREATE POLICY "receipt_reports_select_own"
  ON receipt_reports FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "receipt_reports_insert_own" ON receipt_reports;
CREATE POLICY "receipt_reports_insert_own"
  ON receipt_reports FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ── Families: consolidated RLS (drop redundant policy names) ─

DO $$ DECLARE pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'families'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON families', pol.policyname);
  END LOOP;
END $$;

-- Members can read their family; creator (created_by) has full access.
CREATE POLICY "families_select"
  ON families FOR SELECT
  USING (
    auth.uid() = created_by
    OR id IN (SELECT family_id FROM family_members WHERE user_id = auth.uid())
  );

CREATE POLICY "families_insert"
  ON families FOR INSERT
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "families_update"
  ON families FOR UPDATE
  USING (
    auth.uid() = created_by
    OR id IN (
      SELECT family_id FROM family_members
      WHERE user_id = auth.uid() AND role IN ('admin', 'co_admin')
    )
  );

CREATE POLICY "families_delete"
  ON families FOR DELETE
  USING (auth.uid() = created_by);

-- ── Family members: allow co_admin updates ───────────────────

DROP POLICY IF EXISTS "family_members_update" ON family_members;
CREATE POLICY "family_members_update"
  ON family_members FOR UPDATE
  USING (
    user_id = auth.uid()
    OR auth.uid() IN (SELECT created_by FROM families WHERE id = family_id)
    OR auth.uid() IN (
      SELECT user_id FROM family_members
      WHERE family_id = family_members.family_id AND role IN ('admin', 'co_admin')
    )
  );

-- ── Family invites + accept RPC ───────────────────────────────

CREATE TABLE IF NOT EXISTS family_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  invited_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE family_invites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "family_invites_insert" ON family_invites;
CREATE POLICY "family_invites_insert" ON family_invites FOR INSERT
  WITH CHECK (
    auth.uid() = invited_by AND (
      auth.uid() IN (SELECT created_by FROM families WHERE id = family_id)
      OR auth.uid() IN (SELECT user_id FROM family_members WHERE family_id = family_invites.family_id AND role IN ('admin','co_admin'))
    )
  );

DROP POLICY IF EXISTS "family_invites_select_own" ON family_invites;
CREATE POLICY "family_invites_select_own" ON family_invites FOR SELECT
  USING (
    auth.uid() = invited_by
    OR auth.uid() IN (SELECT created_by FROM families WHERE id = family_id)
  );

DROP POLICY IF EXISTS "family_invites_delete" ON family_invites;
CREATE POLICY "family_invites_delete" ON family_invites FOR DELETE
  USING (
    auth.uid() = invited_by
    OR auth.uid() IN (SELECT created_by FROM families WHERE id = family_id)
    OR auth.uid() IN (SELECT user_id FROM family_members WHERE family_id = family_invites.family_id AND role IN ('admin','co_admin'))
  );

CREATE OR REPLACE FUNCTION accept_family_invite(invite_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_family_id UUID;
  v_expires TIMESTAMPTZ;
BEGIN
  SELECT family_id, expires_at INTO v_family_id, v_expires
  FROM family_invites WHERE id = invite_id;
  IF v_family_id IS NULL THEN
    RAISE EXCEPTION 'Invalid invite';
  END IF;
  IF v_expires < now() THEN
    RAISE EXCEPTION 'Invite expired';
  END IF;
  INSERT INTO family_members (family_id, user_id, role)
  VALUES (v_family_id, auth.uid(), 'member')
  ON CONFLICT (family_id, user_id) DO NOTHING;
  RETURN v_family_id;
END;
$$;

GRANT EXECUTE ON FUNCTION accept_family_invite(UUID) TO authenticated;

-- ── AI premium monthly usage (separate from free-tier weekly ai_usage) ──

CREATE TABLE IF NOT EXISTS ai_premium_usage (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  month_start DATE NOT NULL,
  message_count INT NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, month_start)
);

ALTER TABLE ai_premium_usage ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ai_premium_usage_select_own" ON ai_premium_usage;
CREATE POLICY "ai_premium_usage_select_own"
  ON ai_premium_usage FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "ai_premium_usage_insert_own" ON ai_premium_usage;
CREATE POLICY "ai_premium_usage_insert_own"
  ON ai_premium_usage FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "ai_premium_usage_update_own" ON ai_premium_usage;
CREATE POLICY "ai_premium_usage_update_own"
  ON ai_premium_usage FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "ai_premium_usage_upsert_own" ON ai_premium_usage;
CREATE POLICY "ai_premium_usage_upsert_own"
  ON ai_premium_usage FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
