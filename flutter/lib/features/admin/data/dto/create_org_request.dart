class CreateOrganizationRequest {
  final String name;
  final String description;
  final String? logoUrl;

  CreateOrganizationRequest({
    required String name,
    required String description,
    String? logoUrl,
  })  : name = name.trim(),
        description = description.trim(),
        logoUrl = logoUrl?.trim();

  
  void validate() {
    if (name.isEmpty) {
      throw ArgumentError('Organization name is required.');
    }
    if (description.isEmpty) {
      throw ArgumentError('Organization description is required.');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      if (logoUrl != null && logoUrl!.isNotEmpty) 'logo_url': logoUrl,
    };
  }
}
