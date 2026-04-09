import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import 'settings_api.dart';
import 'settings_repository.dart';

final settingsApiProvider = Provider<SettingsApi>(
  (ref) => SettingsApi(ref.read(apiClientProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.read(settingsApiProvider)),
);
