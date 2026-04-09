/// Typed request DTO for POST /auth/register.
///
/// Using a dedicated class instead of a raw [Map] means:
///   • Typos in field names are caught at compile time, not at runtime.
///   • The shape of the request body is documented in one place.
///   • [AuthApi.signup] has a clean, single-parameter signature.
class SignupRequest {
  final String fullName;
  final String email;
  final String password;
  final String systemRole;

  const SignupRequest({
    required this.fullName,
    required this.email,
    required this.password,
    required this.systemRole,
  });

  Map<String, dynamic> toJson() => {
        'full_name': fullName.trim(),
        'email': email.trim(),
        'password': password,
        'system_role': systemRole.trim(),
      };
}
