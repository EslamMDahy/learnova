import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import 'exam_correction_api.dart';

final examCorrectionApiProvider = Provider<ExamCorrectionApi>((ref) {
  return ExamCorrectionApi(ref.read(apiClientProvider));
});
