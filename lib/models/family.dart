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
  final String role; // 'admin' | 'member'
  final String? phone;
  final String? email;
  final String? fullName;
  final String? avatarUrl;

  const FamilyMember({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.role,
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
      phone: user?['phone'] as String?,
      email: user?['email'] as String?,
      fullName: user?['full_name'] as String?,
      avatarUrl: user?['avatar_url'] as String?,
    );
  }

  String get displayName =>
      fullName ?? phone ?? email ?? userId.substring(0, 8);
}
