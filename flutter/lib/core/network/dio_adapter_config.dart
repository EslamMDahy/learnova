import 'package:dio/dio.dart';

import 'dio_adapter_config_stub.dart'
    if (dart.library.html) 'dio_adapter_config_web.dart';

/// Applies platform-specific Dio adapter configuration.
void configureDioAdapter(Dio dio) => configureDioAdapterImpl(dio);
