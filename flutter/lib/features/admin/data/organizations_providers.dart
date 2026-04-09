import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import 'organizations_api.dart';
import 'organizations_repository.dart';

final organizationsApiProvider = Provider<OrganizationsApi>((ref) {
  return OrganizationsApi(ref.read(apiClientProvider));
});

final organizationsRepositoryProvider = Provider<OrganizationsRepository>((ref) {
  return OrganizationsRepository(ref.read(organizationsApiProvider));
});
