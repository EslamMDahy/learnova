class OrganizationOut {
  final int id;
  final String name;
  final String description;
  final String? logoUrl;
  final int ownerId;
  final int subscriptionPlanId;
  final String inviteCode;
  final String subscriptionStatus;

  OrganizationOut({
    required this.id,
    required this.name,
    required this.description,
    required this.logoUrl,
    required this.ownerId,
    required this.subscriptionPlanId,
    required this.inviteCode,
    required this.subscriptionStatus,
  });

  factory OrganizationOut.fromJson(Map<String, dynamic> json) {
    return OrganizationOut(
      id: _toInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      logoUrl: _toNullableString(json['logo_url']),
      ownerId: _toInt(json['owner_id']) ?? 0,
      subscriptionPlanId: _toInt(json['subscription_plan_id']) ?? 0,
      inviteCode: (json['invite_code'] ?? '').toString().trim(),
      subscriptionStatus:
          (json['subscription_status'] ?? '').toString().trim().toLowerCase(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        if (logoUrl != null && logoUrl!.isNotEmpty) 'logo_url': logoUrl,
        'owner_id': ownerId,
        'subscription_plan_id': subscriptionPlanId,
        'invite_code': inviteCode,
        'subscription_status': subscriptionStatus,
      };

  // ---------------- helpers ----------------

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static String? _toNullableString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
