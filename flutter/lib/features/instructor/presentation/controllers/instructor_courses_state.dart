import 'package:equatable/equatable.dart';
import '../../data/courses_models.dart';

class InstructorCoursesState extends Equatable {
  final bool loading;
  final String? error;
  final List<MyCourseItem> items;

  const InstructorCoursesState({
    this.loading = false,
    this.error,
    this.items = const [],
  });

  InstructorCoursesState copyWith({
    bool? loading,
    String? error,
    List<MyCourseItem>? items,
  }) {
    return InstructorCoursesState(
      loading: loading ?? this.loading,
      error: error,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [loading, error, items];
}
