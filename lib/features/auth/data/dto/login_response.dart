class LoginResponse {
  final String accessToken;
  final String? refreshToken; 
  final String? tokenType;

  /// User object
  final LoginUser? user;

  /// Organizations list (may be empty for non-owner)
  final List<LoginOrganization> organizations;

  String? get organizationId {
    for (final o in organizations) {
      if (o.id.trim().isNotEmpty) return o.id;
    }
    return null;
  }

  const LoginResponse({
    required this.accessToken,
    this.refreshToken,
    this.tokenType,
    this.user,
    this.organizations = const [],
  });

  LoginResponse copyWith({
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    LoginUser? user,
    List<LoginOrganization>? organizations,
  }) {
    return LoginResponse(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
      user: user ?? this.user,
      organizations: organizations ?? this.organizations,
    );
  }

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final root = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : (json['result'] is Map<String, dynamic>)
            ? json['result'] as Map<String, dynamic>
            : json;

    final token =
        (root['access_token'] ?? root['token'] ?? root['accessToken'])
            ?.toString();

    if (token == null || token.trim().isEmpty) {
      throw Exception('Missing access token in response');
    }

    final refresh =
        (root['refresh_token'] ?? root['refreshToken'])?.toString();

    final parsedTokenType =
        (root['token_type'] ?? root['tokenType'])?.toString();

    LoginUser? parsedUser;
    final userJson = root['user'];
    if (userJson is Map<String, dynamic>) {
      parsedUser = LoginUser.fromJson(userJson);
    }

    final orgsRaw =
        root['organizations'] ?? root['orgs'] ?? root['organization'];

    final parsedOrgs = <LoginOrganization>[];

    if (orgsRaw is List) {
      for (final item in orgsRaw) {
        if (item is Map<String, dynamic>) {
          parsedOrgs.add(LoginOrganization.fromJson(item));
        }
      }
    } else if (orgsRaw is Map<String, dynamic>) {
      parsedOrgs.add(LoginOrganization.fromJson(orgsRaw));
    }

    return LoginResponse(
      accessToken: token,
      refreshToken: (refresh != null && refresh.trim().isNotEmpty) ? refresh.trim() : null,
      tokenType: parsedTokenType,
      user: parsedUser,
      organizations: parsedOrgs,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoginResponse &&
        other.accessToken == accessToken &&
        other.refreshToken == refreshToken &&
        other.tokenType == tokenType &&
        other.user == user &&
        _listEquals(other.organizations, organizations);
  }

  @override
  int get hashCode => Object.hash(
        accessToken,
        refreshToken,
        tokenType,
        user,
        Object.hashAll(organizations),
      );
}

class LoginUser {
  final String id;

  /// backend: full_name
  final String? fullName;

  final String? email;
  final String? systemRole;

  final String? avatarUrl;
  final String? phoneNumber;
  final String? bio;

  final String? studentId;
  final String? universityEmail;

  /// backend: language_preference (new response uses "en")
  final String? languagePreference;

  final String? createdAt; // ISO string
  final String? lastLoginAt; // ISO string

  final String? subscriptionPlanName;

  const LoginUser({
    required this.id,
    this.fullName,
    this.email,
    this.systemRole,
    this.avatarUrl,
    this.phoneNumber,
    this.bio,
    this.studentId,
    this.universityEmail,
    this.languagePreference,
    this.createdAt,
    this.lastLoginAt,
    this.subscriptionPlanName,
  });

  LoginUser copyWith({
    String? id,
    String? fullName,
    String? email,
    String? systemRole,
    String? avatarUrl,
    String? phoneNumber,
    String? bio,
    String? studentId,
    String? universityEmail,
    String? languagePreference,
    String? createdAt,
    String? lastLoginAt,
    String? subscriptionPlanName,
  }) {
    return LoginUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      systemRole: systemRole ?? this.systemRole,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bio: bio ?? this.bio,
      studentId: studentId ?? this.studentId,
      universityEmail: universityEmail ?? this.universityEmail,
      languagePreference: languagePreference ?? this.languagePreference,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      subscriptionPlanName: subscriptionPlanName ?? this.subscriptionPlanName,
    );
  }

  factory LoginUser.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['_id'] ?? json['userId'])?.toString();

    if (id == null || id.trim().isEmpty) {
      throw Exception('Missing user id in login response user object');
    }

    return LoginUser(
      id: id,
      fullName: (json['full_name'] ?? json['name'])?.toString(),
      email: json['email']?.toString(),
      avatarUrl: (json['avatar_url'] ?? json['avatarUrl'])?.toString(),
      systemRole: (json['system_role'] ?? json['role'] ?? json['type'])
          ?.toString(),

      phoneNumber: (json['phone_number'] ?? json['phoneNumber'])?.toString(),
      bio: json['bio']?.toString(),
      studentId: (json['student_id'] ?? json['studentId'])?.toString(),
      universityEmail:
          (json['university_email'] ?? json['universityEmail'])?.toString(),
      languagePreference:
          (json['language_preference'] ?? json['languagePreference'])
              ?.toString(),

      createdAt: json['created_at']?.toString(),
      lastLoginAt: json['last_login_at']?.toString(),

      subscriptionPlanName:
          (json['subscription_plan_name'] ?? json['subscriptionPlanName'])
              ?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': _toIntOrString(id),
      'full_name': fullName,
      'email': email,
      'avatar_url': avatarUrl,
      'phone_number': phoneNumber,
      'bio': bio,
      'system_role': systemRole,
      'student_id': studentId,
      'university_email': universityEmail,
      'language_preference': languagePreference,
      'created_at': createdAt,
      'last_login_at': lastLoginAt,
      'subscription_plan_name': subscriptionPlanName,
    };
  }

  dynamic _toIntOrString(String v) {
    final n = int.tryParse(v);
    return n ?? v;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoginUser &&
        other.id == id &&
        other.fullName == fullName &&
        other.email == email &&
        other.systemRole == systemRole &&
        other.avatarUrl == avatarUrl &&
        other.phoneNumber == phoneNumber &&
        other.bio == bio &&
        other.studentId == studentId &&
        other.universityEmail == universityEmail &&
        other.languagePreference == languagePreference &&
        other.createdAt == createdAt &&
        other.lastLoginAt == lastLoginAt &&
        other.subscriptionPlanName == subscriptionPlanName;
  }

  @override
  int get hashCode => Object.hash(
        id,
        fullName,
        email,
        systemRole,
        avatarUrl,
        phoneNumber,
        bio,
        studentId,
        universityEmail,
        languagePreference,
        createdAt,
        lastLoginAt,
        subscriptionPlanName,
      );
}

class LoginOrganization {
  final String id;
  final String? name;

  final String? description;
  final String? logoUrl;
  final String? inviteCode;
  final String? subscriptionStatus;

  const LoginOrganization({
    required this.id,
    this.name,
    this.description,
    this.logoUrl,
    this.inviteCode,
    this.subscriptionStatus,
  });

  LoginOrganization copyWith({
    String? id,
    String? name,
    String? description,
    String? logoUrl,
    String? inviteCode,
    String? subscriptionStatus,
  }) {
    return LoginOrganization(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      inviteCode: inviteCode ?? this.inviteCode,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
    );
  }

  factory LoginOrganization.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ??
            json['_id'] ??
            json['organizationId'] ??
            json['orgId'])
        ?.toString();

    if (id == null || id.trim().isEmpty) {
      throw Exception('Missing organization id in login response org object');
    }

    return LoginOrganization(
      id: id,
      name: (json['name'] ?? json['title'])?.toString(),
      description: json['description']?.toString(),
      logoUrl: (json['logo_url'] ?? json['logoUrl'])?.toString(),
      inviteCode: (json['invite_code'] ?? json['inviteCode'])?.toString(),
      subscriptionStatus:
          (json['subscription_status'] ?? json['subscriptionStatus'])
              ?.toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoginOrganization &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.logoUrl == logoUrl &&
        other.inviteCode == inviteCode &&
        other.subscriptionStatus == subscriptionStatus;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, logoUrl, inviteCode, subscriptionStatus);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
