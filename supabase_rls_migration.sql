-- ============================================================
-- Balanzo RLS Migration
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- ── Schema additions ─────────────────────────────────────────

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS subscription_tier TEXT NOT NULL DEFAULT 'free'
  CHECK (subscription_tier IN ('free', 'ai_premium', 'family_plan'));

-- ── Enable RLS on all tables ─────────────────────────────────

ALTER TABLE users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipts         ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipt_items    ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories       ENABLE ROW LEVEL SECURITY;
ALTER TABLE families         ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_members   ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets          ENABLE ROW LEVEL SECURITY;

-- ── Drop existing policies (idempotent re-run) ───────────────

DO $$ DECLARE pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname, tablename FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('users','receipts','receipt_items','categories',
                        'families','family_members','budgets')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', pol.policyname, pol.tablename);
  END LOOP;
END $$;

-- ── USERS ─────────────────────────────────────────────────────
-- PK is `id` which equals auth.uid()

CREATE POLICY "users_select_own"
  ON users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "users_insert_own"
  ON users FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "users_update_own"
  ON users FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "users_delete_own"
  ON users FOR DELETE
  USING (auth.uid() = id);

-- ── RECEIPTS ──────────────────────────────────────────────────
-- user_id = owner; family members can read shared family receipts

CREATE POLICY "receipts_select_own"
  ON receipts FOR SELECT
  USING (
    auth.uid() = user_id
    OR (
      family_id IS NOT NULL
      AND family_id IN (
        SELECT family_id FROM family_members WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "receipts_insert_own"
  ON receipts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "receipts_update_own"
  ON receipts FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "receipts_delete_own"
  ON receipts FOR DELETE
  USING (auth.uid() = user_id);

-- ── RECEIPT_ITEMS ─────────────────────────────────────────────
-- Access through parent receipt ownership

CREATE POLICY "receipt_items_select_own"
  ON receipt_items FOR SELECT
  USING (
    receipt_id IN (
      SELECT id FROM receipts
      WHERE user_id = auth.uid()
         OR (family_id IS NOT NULL
             AND family_id IN (
               SELECT family_id FROM family_members WHERE user_id = auth.uid()
             ))
    )
  );

CREATE POLICY "receipt_items_insert_own"
  ON receipt_items FOR INSERT
  WITH CHECK (
    receipt_id IN (SELECT id FROM receipts WHERE user_id = auth.uid())
  );

CREATE POLICY "receipt_items_update_own"
  ON receipt_items FOR UPDATE
  USING (
    receipt_id IN (SELECT id FROM receipts WHERE user_id = auth.uid())
  );

CREATE POLICY "receipt_items_delete_own"
  ON receipt_items FOR DELETE
  USING (
    receipt_id IN (SELECT id FROM receipts WHERE user_id = auth.uid())
  );

-- ── CATEGORIES ────────────────────────────────────────────────
-- Default categories (is_default=true) visible to all authenticated users
-- Custom categories visible only to their creator

CREATE POLICY "categories_select"
  ON categories FOR SELECT
  USING (is_default = true OR user_id = auth.uid());

CREATE POLICY "categories_insert_own"
  ON categories FOR INSERT
  WITH CHECK (auth.uid() = user_id AND is_default = false);

CREATE POLICY "categories_update_own"
  ON categories FOR UPDATE
  USING (auth.uid() = user_id AND is_default = false);

CREATE POLICY "categories_delete_own"
  ON categories FOR DELETE
  USING (auth.uid() = user_id AND is_default = false);

-- ── FAMILIES ──────────────────────────────────────────────────
-- owner_user_id = creator of the family

CREATE POLICY "families_select_own"
  ON families FOR SELECT
  USING (auth.uid() = owner_user_id);

CREATE POLICY "families_insert_own"
  ON families FOR INSERT
  WITH CHECK (auth.uid() = owner_user_id);

CREATE POLICY "families_update_own"
  ON families FOR UPDATE
  USING (auth.uid() = owner_user_id);

CREATE POLICY "families_delete_own"
  ON families FOR DELETE
  USING (auth.uid() = owner_user_id);

-- ── FAMILY_MEMBERS ────────────────────────────────────────────

CREATE POLICY "family_members_select"
  ON family_members FOR SELECT
  USING (
    auth.uid() IN (SELECT owner_user_id FROM families WHERE id = family_id)
    OR auth.uid() = user_id
  );

CREATE POLICY "family_members_insert"
  ON family_members FOR INSERT
  WITH CHECK (
    auth.uid() IN (SELECT owner_user_id FROM families WHERE id = family_id)
  );

CREATE POLICY "family_members_delete_self_or_owner"
  ON family_members FOR DELETE
  USING (
    user_id = auth.uid()
    OR auth.uid() IN (SELECT owner_user_id FROM families WHERE id = family_id)
  );

-- ── BUDGETS ───────────────────────────────────────────────────
-- Personal budgets owned by user; family budgets shared with members (admins manage)

CREATE POLICY "budgets_select_own"
  ON budgets FOR SELECT
  USING (
    user_id = auth.uid()
    OR (
      family_id IS NOT NULL
      AND family_id IN (SELECT family_id FROM family_members WHERE user_id = auth.uid())
    )
  );

CREATE POLICY "budgets_insert_own"
  ON budgets FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    OR (
      family_id IS NOT NULL
      AND family_id IN (
        SELECT family_id FROM family_members
        WHERE user_id = auth.uid() AND role = 'admin'
      )
    )
  );

CREATE POLICY "budgets_update_own"
  ON budgets FOR UPDATE
  USING (
    user_id = auth.uid()
    OR family_id IN (
      SELECT family_id FROM family_members
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "budgets_delete_own"
  ON budgets FOR DELETE
  USING (
    user_id = auth.uid()
    OR family_id IN (
      SELECT family_id FROM family_members
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================
-- Done. Verify with:
--   SELECT tablename, policyname FROM pg_policies
--   WHERE schemaname = 'public' ORDER BY tablename, policyname;
-- ============================================================
