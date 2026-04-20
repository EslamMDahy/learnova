import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_error_bus.dart';
import '../../../../core/network/error_mapper.dart';
import '../../data/materials_models.dart';
import '../../data/modules_materials_providers.dart';
import '../../data/modules_models.dart';
import '../../data/question_models.dart';
import '../../data/topics_models.dart';
import 'course_details_state.dart';

part 'course_details_modules_mixin.dart';
part 'course_details_materials_mixin.dart';
part 'course_details_topics_mixin.dart';
part 'course_details_questions_mixin.dart';

final courseDetailsControllerProvider = StateNotifierProvider
    .family<CourseDetailsController, CourseDetailsState, int>(
  (ref, courseId) => CourseDetailsController(ref, courseId),
);

class CourseDetailsController extends StateNotifier<CourseDetailsState>
    with
        _CourseDetailsModulesMixin,
        _CourseDetailsMaterialsMixin,
        _CourseDetailsTopicsMixin,
        _CourseDetailsQuestionsMixin {
  CourseDetailsController(this._ref, this._courseId)
      : super(const CourseDetailsState());

  final Ref _ref;
  final int _courseId;
  CancelToken? _cancel;

  Ref get ref => _ref;
  int get courseId => _courseId;
  CancelToken? get cancelToken => _cancel;
  set cancelToken(CancelToken? value) => _cancel = value;

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }
}
