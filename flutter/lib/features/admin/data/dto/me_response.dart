class MeResponse {
  final int id;
  final String email;
  final String fullName;
  final String systemRole; // normalized lower-case

  MeResponse({
    required this.id,
    required this.email,
    required this.fullName,
    required this.systemRole,
  });

  bool get isOwner => systemRole == 'owner';

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    return MeResponse(
      id: _toInt(json['id']) ?? 0,
      email: (json['email'] ?? '').toString().trim(),
      fullName: (json['full_name'] ?? json['fullName'] ?? '').toString().trim(),
      systemRole: (json['system_role'] ?? json['systemRole'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }
}
