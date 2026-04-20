enum OrganizationMemberStatus {
  pending,
  accepted,
  suspended,
  declined,
}

OrganizationMemberStatus parseOrganizationMemberStatus(String raw) {
  final value = raw.trim().toLowerCase();
  switch (value) {
    case 'pending':
    case 'pinding':
      return OrganizationMemberStatus.pending;
    case 'accepted':
      return OrganizationMemberStatus.accepted;
    case 'suspended':
      return OrganizationMemberStatus.suspended;
    case 'declined':
    case 'declinate':
    case 'rejected':
      return OrganizationMemberStatus.declined;
    default:
      throw ArgumentError('Invalid organization member status: $raw');
  }
}

String normalizeOrganizationMemberStatus(String raw) {
  switch (parseOrganizationMemberStatus(raw)) {
    case OrganizationMemberStatus.pending:
      return 'pending';
    case OrganizationMemberStatus.accepted:
      return 'accepted';
    case OrganizationMemberStatus.suspended:
      return 'suspended';
    case OrganizationMemberStatus.declined:
      return 'declined';
  }
}

String toOrganizationMemberApiStatus(OrganizationMemberStatus status) {
  switch (status) {
    case OrganizationMemberStatus.pending:
      return 'pending';
    case OrganizationMemberStatus.accepted:
      return 'accepted';
    case OrganizationMemberStatus.suspended:
      return 'suspended';
    case OrganizationMemberStatus.declined:
      return 'declinate';
  }
}
