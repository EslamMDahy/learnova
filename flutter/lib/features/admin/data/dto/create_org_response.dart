import 'organization_out.dart';

class CreateOrganizationResponse {
  final OrganizationOut organization;

  CreateOrganizationResponse({required this.organization});

  factory CreateOrganizationResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['organization'];

    if (raw is! Map) {
      throw const FormatException('Invalid response: "organization" is missing or not an object.');
    }

    final orgJson = raw.cast<String, dynamic>();
    return CreateOrganizationResponse(
      organization: OrganizationOut.fromJson(orgJson),
    );
  }
}
