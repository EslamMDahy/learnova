class UserProfile {
  final int id;
  final String fullName;
  final String email;

  final String? avatarUrl;
  final String? phoneNumber;
  final String? bio;

  final String? studentId;
  final String? universityEmail;
  final String languagePreference;

  final String systemRole;
  final bool isEmailVerified;
  final String accountStatus;

  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl,
    this.phoneNumber,
    this.bio,
    this.studentId,
    this.universityEmail,
    required this.languagePreference,
    required this.systemRole,
    required this.isEmailVerified,
    required this.accountStatus,
    this.createdAt,
    this.lastLoginAt,
  });

  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static String _toStr(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    final s = v.toString();
    return s;
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is String && v.trim().isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  static String _normalizeLang(dynamic v) {
    final raw = (v ?? '').toString().trim();
    if (raw.isEmpty) return 'en_US';

    // backend may return "en" / "ar"
    if (raw == 'en') return 'en_US';
    if (raw == 'ar') return 'ar_EG';

    return raw; // keep "en_US", "en_GB", "ar_EG", ...
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: _toInt(json['id']),
      fullName: _toStr(json['full_name'] ?? json['name']),
      email: _toStr(json['email']),
      avatarUrl: (json['avatar_url'] ?? json['avatarUrl'])?.toString(),
      phoneNumber: (json['phone_number'] ?? json['phone'] ?? json['phoneNumber'])
          ?.toString(),
      bio: json['bio']?.toString(),
      studentId: (json['student_id'] ?? json['studentId'])?.toString(),
      universityEmail:
          (json['university_email'] ?? json['universityEmail'])?.toString(),
      languagePreference: _normalizeLang(
        json['language_preference'] ?? json['languagePreference'],
      ),
      systemRole: _toStr(json['system_role'] ?? json['role'] ?? 'USER'),
      isEmailVerified: (json['is_email_verified'] ?? json['isEmailVerified'] ?? false) as bool,
      accountStatus: _toStr(json['account_status'] ?? json['accountStatus'] ?? 'active'),
      createdAt: _dt(json['created_at'] ?? json['createdAt']),
      lastLoginAt: _dt(json['last_login_at'] ?? json['lastLoginAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'avatar_url': avatarUrl,
    'phone': phoneNumber,          
    'phone_number': phoneNumber,   
    'bio': bio,
    'student_id': studentId,
    'university_email': universityEmail,
    'language_preference': languagePreference,
    'system_role': systemRole,
    'is_email_verified': isEmailVerified,
    'account_status': accountStatus,
    'created_at': createdAt?.toIso8601String(),
    'last_login_at': lastLoginAt?.toIso8601String(),
  };

}
