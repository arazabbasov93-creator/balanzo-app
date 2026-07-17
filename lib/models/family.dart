class Family {
  final String id;
  final String name;
  final String createdBy;
  final DateTime? createdAt;

  const Family({
    required this.id,
    required this.name,
    required this.createdBy,
    this.createdAt,
  });

  factory Family.fromJson(Map<String, dynamic> json) => Family(
        id: json['id'] as String,
        name: json['name'] as String,
        createdBy: json['created_by'] as String,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
}

class FamilyMember {
  final String id;
  final String familyId;
  final String userId;
  final String role; // 'admin' | 'co_admin' | 'member'
  final String? relationship;
  final double? spendLimit;
  final double? pendingSpendLimit;
  final String? spendLimitProposedBy;
  final int? spendLimitEffectiveMonth;
  final int? spendLimitEffectiveYear;
  final String? phone;
  final String? email;
  final String? fullName;
  final String? avatarUrl;

  const FamilyMember({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.role,
    this.relationship,
    this.spendLimit,
    this.pendingSpendLimit,
    this.spendLimitProposedBy,
    this.spendLimitEffectiveMonth,
    this.spendLimitEffectiveYear,
    this.phone,
    this.email,
    this.fullName,
    this.avatarUrl,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    return FamilyMember(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'member',
      relationship: json['relationship'] as String?,
      spendLimit: (json['spend_limit'] as num?)?.toDouble(),
      pendingSpendLimit: (json['pending_spend_limit'] as num?)?.toDouble(),
      spendLimitProposedBy: json['spend_limit_proposed_by'] as String?,
      spendLimitEffectiveMonth: (json['spend_limit_effective_month'] as num?)?.toInt(),
      spendLimitEffectiveYear: (json['spend_limit_effective_year'] as num?)?.toInt(),
      phone: user?['phone'] as String?,
      email: user?['email'] as String?,
      fullName: user?['full_name'] as String?,
      avatarUrl: user?['avatar_url'] as String?,
    );
  }

  bool get isAdminRole => role == 'admin' || role == 'co_admin';

  /// Locked when the limit was set in a prior calendar month.
  bool isSpendLimitLocked(DateTime now) {
    if (spendLimitEffectiveMonth == null || spendLimitEffectiveYear == null) {
      return false;
    }
    if (spendLimitEffectiveYear! > now.year) return false;
    if (spendLimitEffectiveYear! < now.year) return true;
    return spendLimitEffectiveMonth! < now.month;
  }

  String get displayName =>
      fullName ?? phone ?? email ?? userId.substring(0, 8);
}
