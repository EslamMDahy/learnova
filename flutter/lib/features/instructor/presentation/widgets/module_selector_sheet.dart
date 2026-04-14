import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/courses_models.dart';
import '../../data/courses_providers.dart';
import '../../data/modules_materials_providers.dart';
import '../../data/modules_models.dart';

// ─────────────────────────────────────────────────────────────────────────────────
//  Result model
// ─────────────────────────────────────────────────────────────────────────────────
class ModuleSelectorResult {
  final bool isNew;
  final ModuleItem? existing;
  /// The course the [existing] module lives in. Required when [isNew] is false
  /// so the caller knows which course to pass as [sourceCourseId] to the copy
  /// endpoint: POST /courses/{sourceCourseId}/modules/{moduleId}/copy
  final int? sourceCourseId;
  final String? newTitle;
  final String? newDescription;

  const ModuleSelectorResult.existing(this.existing, this.sourceCourseId)
      : isNew = false,
        newTitle = null,
        newDescription = null;

  const ModuleSelectorResult.newModule(this.newTitle, this.newDescription)
      : isNew = true,
        existing = null,
        sourceCourseId = null;
}

Future<ModuleSelectorResult?> showModuleSelectorSheet(
  BuildContext context,
  int currentCourseId, {
  List<ModuleItem> currentModules = const [],
}) {
  final size = MediaQuery.of(context).size;
  final width = size.width < 600 ? size.width * 0.96 : 860.0;
  final height = size.height < 820 ? size.height * 0.82 : 720.0;

  return showDialog<ModuleSelectorResult>(
    context: context,
    barrierColor: const Color(0xFF0B1A2B).withOpacity(0.55),
    builder: (_) => Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: height),
          child: _ModuleSelectorSheet(
            currentCourseId: currentCourseId,
            currentModules: currentModules,
          ),
        ),
      ),
    ),
  );
}

class _ReusableCourse {
  final MyCourseItem course;
  final List<ModuleItem> modules;

  const _ReusableCourse({required this.course, required this.modules});
}

final _reusableCoursesProvider =
    FutureProvider.autoDispose.family<List<_ReusableCourse>, int>((ref, currentCourseId) async {
  final coursesResponse = await ref.read(coursesRepositoryProvider).myCourses();
  final modulesApi = ref.read(modulesApiProvider);

  final reusable = <_ReusableCourse>[];
  for (final course in coursesResponse.items) {
    if (course.id == currentCourseId) continue;
    try {
      final modulesResponse = await modulesApi.listModules(courseId: course.id);
      if (modulesResponse.modules.isNotEmpty) {
        reusable.add(_ReusableCourse(course: course, modules: modulesResponse.modules));
      }
    } catch (_) {
      // ignore per-course failures to keep dialog resilient
    }
  }

  return reusable;
});

enum _SelectorStep { options, chooseCourse, chooseModule, create }

class _ModuleSelectorSheet extends ConsumerStatefulWidget {
  final int currentCourseId;
  final List<ModuleItem> currentModules;

  const _ModuleSelectorSheet({
    required this.currentCourseId,
    required this.currentModules,
  });

  @override
  ConsumerState<_ModuleSelectorSheet> createState() => _ModuleSelectorSheetState();
}

class _ModuleSelectorSheetState extends ConsumerState<_ModuleSelectorSheet> {
  _SelectorStep _step = _SelectorStep.options;
  _ReusableCourse? _selectedCourse;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _titleError;
  String? _descError;

  Set<String> get _currentTitles => widget.currentModules
      .map((e) => e.title.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reusableAsync = ref.watch(_reusableCoursesProvider(widget.currentCourseId));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          _Header(
            title: _headerTitle,
            subtitle: _headerSubtitle,
            onClose: () => Navigator.pop(context),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _buildStepContent(reusableAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(AsyncValue<List<_ReusableCourse>> reusableAsync) {
    if (_step == _SelectorStep.chooseCourse) return _buildChooseCourse(reusableAsync);
    if (_step == _SelectorStep.chooseModule) return _buildChooseModule();
    if (_step == _SelectorStep.create) return _buildCreateForm();
    return _buildOptions(reusableAsync);
  }

  String get _headerTitle {
    if (_step == _SelectorStep.chooseCourse) return 'Choose a course';
    if (_step == _SelectorStep.chooseModule) return 'Choose module to copy';
    if (_step == _SelectorStep.create) return 'Create module';
    return 'Add module';
  }

  String get _headerSubtitle {
    if (_step == _SelectorStep.chooseCourse) {
      return 'Pick another course, then choose one of its modules to copy into this course.';
    }
    if (_step == _SelectorStep.chooseModule) {
      return 'These are the modules currently available in ${_selectedCourse?.course.safeTitle ?? 'this course'}. Pick one to copy.';
    }
    if (_step == _SelectorStep.create) {
      return 'Build a clean section for this course in a way that matches the rest of the experience.';
    }
    return 'Start with a clean new module or reuse one from another course.';
  }

  Widget _buildOptions(AsyncValue<List<_ReusableCourse>> reusableAsync) {
    return reusableAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const _ErrorState(message: 'Failed to load reusable modules.'),
      data: (courses) {
        final readyCount = courses.fold<int>(0, (sum, c) {
          final ready = c.modules.where((m) => !_isBlocked(m)).length;
          return sum + ready;
        });
        final blockedCount = courses.fold<int>(0, (sum, c) {
          final blocked = c.modules.where(_isBlocked).length;
          return sum + blocked;
        });

        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.auto_awesome_rounded,
                    badge: 'Recommended',
                    // Both badges use the same blue palette to stay consistent
                    // with the site’s primary color. The old “From other courses”
                    // badge was purple which clashed with the rest of the UI.
                    badgeColor: const Color(0xFFE8F1FF),
                    badgeTextColor: const Color(0xFF1D6FE9),
                    iconBg: const Color(0xFFEFF6FF),
                    iconFg: const Color(0xFF137FEC),
                    title: 'Create a fresh module',
                    description:
                        'Best for a brand-new chapter, week, or topic group. Title and description are validated before creation.',
                    cta: 'Start creating',
                    onTap: () => setState(() => _step = _SelectorStep.create),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.content_copy_rounded,
                    badge: 'From other courses',
                    badgeColor: const Color(0xFFE8F1FF),
                    badgeTextColor: const Color(0xFF1D6FE9),
                    iconBg: const Color(0xFFEFF6FF),
                    iconFg: const Color(0xFF137FEC),
                    title: 'Reuse from another course',
                    description: readyCount > 0
                        ? '$readyCount validated modules can be copied from ${courses.length} ${courses.length == 1 ? 'other course' : 'other courses'}.'
                        : 'No reusable modules are currently available from your other courses.',
                    cta: courses.isEmpty ? 'No reusable modules' : 'Browse courses',
                    enabled: courses.isNotEmpty,
                    onTap: courses.isEmpty ? null : () => setState(() => _step = _SelectorStep.chooseCourse),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Reusable source courses',
              subtitle: courses.isEmpty
                  ? 'No courses currently have modules you can copy.'
                  : '${courses.length} ${courses.length == 1 ? 'course' : 'courses'} • $readyCount ${readyCount == 1 ? 'module' : 'modules'} ready to copy',
              actionLabel: courses.isEmpty ? null : 'Open browser',
              onAction: courses.isEmpty ? null : () => setState(() => _step = _SelectorStep.chooseCourse),
              child: courses.isEmpty
                  ? const _EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No reusable modules yet',
                      message: 'Create modules in another course first, then return here to copy them.',
                    )
                  : Column(
                      children: [
                        if (blockedCount > 0)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$blockedCount ${blockedCount == 1 ? 'module already exists' : 'modules already exist'} in this course and will stay disabled to avoid duplicate copies.',
                                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ...courses.map((course) {
                          final ready = course.modules.where((m) => !_isBlocked(m)).length;
                          final blocked = course.modules.length - ready;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CourseTile(
                              course: course.course,
                              readyCount: ready,
                              blockedCount: blocked,
                              onTap: () {
                                setState(() {
                                  _selectedCourse = course;
                                  _step = _SelectorStep.chooseModule;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChooseCourse(AsyncValue<List<_ReusableCourse>> reusableAsync) {
    return reusableAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const _ErrorState(message: 'Failed to load source courses.'),
      data: (courses) {
        if (courses.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BackLink(label: 'Back to module options', onTap: () => setState(() => _step = _SelectorStep.options)),
                const SizedBox(height: 18),
                const Expanded(
                  child: _EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No courses available to copy from',
                    message: 'Only courses that already contain modules appear here.',
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackLink(label: 'Back to module options', onTap: () => setState(() => _step = _SelectorStep.options)),
              const SizedBox(height: 18),
              Expanded(
                child: _SectionCard(
                  title: 'Courses you can copy from',
                  subtitle: 'Each course shows its real module count from the backend so you always know where reusable content exists.',
                  expandChild: true,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: courses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final entry = courses[i];
                      final ready = entry.modules.where((m) => !_isBlocked(m)).length;
                      final blocked = entry.modules.length - ready;
                      return _CourseTile(
                        course: entry.course,
                        readyCount: ready,
                        blockedCount: blocked,
                        onTap: () {
                          setState(() {
                            _selectedCourse = entry;
                            _step = _SelectorStep.chooseModule;
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChooseModule() {
    final entry = _selectedCourse;
    if (entry == null) {
      return const _ErrorState(message: 'No course selected.');
    }

    final readyModules = entry.modules.where((m) => !_isBlocked(m)).toList();
    final blockedModules = entry.modules.where(_isBlocked).toList();

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackLink(label: 'Back to course list', onTap: () => setState(() => _step = _SelectorStep.chooseCourse)),
          const SizedBox(height: 18),
          Expanded(
            child: _SectionCard(
              title: entry.course.safeTitle,
              subtitle: 'Code: ${entry.course.safeCourseCode} • ${readyModules.length} ready • ${blockedModules.length} blocked',
              trailing: _CountBubble(count: entry.modules.length),
              expandChild: true,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (readyModules.isEmpty)
                    const _EmptyState(
                      icon: Icons.content_copy_outlined,
                      title: 'No modules available to copy',
                      message: 'All modules in this course are already present in your current course.',
                    )
                  else ...[
                    const _StateLabel('Modules ready to copy'),
                    const SizedBox(height: 8),
                    ...readyModules.map((module) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ModuleTile(
                            module: module,
                            enabled: true,
                            // FIX: pass the source course id so the caller can
                            // build the correct copy endpoint URL.
                            onTap: () => Navigator.pop(
                              context,
                              ModuleSelectorResult.existing(
                                module,
                                entry.course.id,
                              ),
                            ),
                          ),
                        )),
                  ],
                  if (blockedModules.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const _StateLabel('Unavailable in this course'),
                    const SizedBox(height: 8),
                    ...blockedModules.map((module) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ModuleTile(
                            module: module,
                            enabled: false,
                            reason: _blockedReason(module),
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    final previewTitle = _titleCtrl.text.trim().isEmpty ? 'New module' : _titleCtrl.text.trim();
    final previewDescription = _descCtrl.text.trim().isEmpty
        ? 'This will appear cleanly in the materials sidebar.'
        : _descCtrl.text.trim();

    Widget quickChip(String label) {
      return ActionChip(
        label: Text(label),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: Colors.white,
        onPressed: () {
          _titleCtrl.text = label;
          _titleCtrl.selection = TextSelection.collapsed(offset: _titleCtrl.text.length);
          if (_titleError != null) setState(() => _titleError = null);
          setState(() {});
        },
      );
    }

    final detailsCard = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Module details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
          const SizedBox(height: 6),
          const Text('This section will appear in the course structure.', style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          const _FieldLabel('Module title', required: true),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_titleError != null) setState(() => _titleError = null);
              setState(() {});
            },
            decoration: _inputDecoration(
              hintText: 'e.g. Chapter 2',
              errorText: _titleError,
              helperText: 'Shown directly in the materials sidebar.',
              prefixIcon: const Icon(Icons.folder_open_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          const _FieldLabel('Description'),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            minLines: 2,
            onChanged: (_) {
              if (_descError != null) setState(() => _descError = null);
              setState(() {});
            },
            decoration: _inputDecoration(
              hintText: 'Optional note about this module.',
              errorText: _descError,
              helperText: 'Optional. Keep it short.',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 12, right: 8, bottom: 18),
                child: Icon(Icons.subject_rounded, size: 18),
              ),
            ),
          ),
        ],
      ),
    );

    final previewCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Live preview', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_open_rounded, color: Color(0xFF137FEC), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(previewTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
                  const SizedBox(height: 4),
                  Text(previewDescription, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.8, height: 1.4, color: AppColors.textMuted)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(999)),
                child: const Text('Module', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF137FEC))),
              ),
            ]),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackLink(label: 'Back to module options', onTap: () => setState(() => _step = _SelectorStep.options)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCEBFF)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Create a module', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
              const SizedBox(height: 6),
              const Text('Use a short, clear title. Description is optional and only appears as extra context.', style: TextStyle(fontSize: 12.8, height: 1.45, color: AppColors.textMuted)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                quickChip('Chapter 1'),
                quickChip('Week 2'),
                quickChip('Assessment Prep'),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                if (compact) {
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [detailsCard, const SizedBox(height: 14), previewCard],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: detailsCard),
                    const SizedBox(width: 14),
                    Expanded(flex: 5, child: previewCard),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = _SelectorStep.options),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textTitle,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _submitCreate,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF137FEC),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create module', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    String? helperText,
    String? errorText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      helperText: helperText,
      errorText: errorText,
      isDense: true,
      alignLabelWithHint: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: prefixIcon,
      prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF137FEC), width: 1.5),
      ),
    );
  }

  void _submitCreate() {
    final cleanedTitle = _normalizeSpaces(_titleCtrl.text);
    final cleanedDescription = _normalizeSpaces(_descCtrl.text);

    String? titleError;
    String? descError;

    if (cleanedTitle.isEmpty) {
      titleError = 'Module title is required.';
    } else if (cleanedTitle.length < 3) {
      titleError = 'Use at least 3 characters.';
    } else if (cleanedTitle.length > 64) {
      titleError = 'Keep the title under 64 characters.';
    } else if (_currentTitles.contains(cleanedTitle.toLowerCase())) {
      titleError = 'A module with this title already exists in this course.';
    }

    if (cleanedDescription.length > 240) {
      descError = 'Keep the description under 240 characters.';
    }

    if (titleError != null || descError != null) {
      setState(() {
        _titleError = titleError;
        _descError = descError;
      });
      return;
    }

    Navigator.pop(
      context,
      ModuleSelectorResult.newModule(
        cleanedTitle,
        cleanedDescription.isEmpty ? null : cleanedDescription,
      ),
    );
  }

  String _normalizeSpaces(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ');

  bool _isBlocked(ModuleItem module) {
    final normalizedTitle = module.title.trim().toLowerCase();
    if (_currentTitles.contains(normalizedTitle)) return true;
    if (module.sharedWithCourseIds.contains(widget.currentCourseId)) return true;
    return false;
  }

  String _blockedReason(ModuleItem module) {
    final normalizedTitle = module.title.trim().toLowerCase();
    if (_currentTitles.contains(normalizedTitle)) {
      return 'A module with the same title already exists in this course.';
    }
    if (module.sharedWithCourseIds.contains(widget.currentCourseId)) {
      return 'This module is already linked to the current course.';
    }
    return 'This module cannot be copied into the current course.';
  }
}


class _PreviewMiniPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PreviewMiniPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11.8, fontWeight: FontWeight.w600, color: Colors.white70)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onClose;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.widgets_outlined, color: Color(0xFF137FEC)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12.8, height: 1.45, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            onTap: onClose,
            borderRadius: BorderRadius.circular(99),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String badge;
  final Color badgeColor;
  final Color badgeTextColor;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String description;
  final String cta;
  final VoidCallback? onTap;
  final bool enabled;

  const _ActionCard({
    required this.icon,
    required this.badge,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.description,
    required this.cta,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: iconFg),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeTextColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
                const SizedBox(height: 10),
                Text(description, style: const TextStyle(fontSize: 12.8, height: 1.55, color: AppColors.textMuted)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(cta, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: enabled ? const Color(0xFF137FEC) : AppColors.textMuted)),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: enabled ? const Color(0xFF137FEC) : AppColors.textMuted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final bool expandChild;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.expandChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              if (actionLabel != null)
                TextButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(actionLabel!),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  final MyCourseItem course;
  final int readyCount;
  final int blockedCount;
  final VoidCallback onTap;

  const _CourseTile({
    required this.course,
    required this.readyCount,
    required this.blockedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Color(0xFF137FEC)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(course.safeTitle, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(course.safeCourseCode, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${course.courseType} • ${course.visibilityLevel}', style: const TextStyle(fontSize: 12.2, color: AppColors.textMuted)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniBadge(icon: Icons.copy_all_outlined, text: '$readyCount ready'),
                        _MiniBadge(icon: Icons.groups_2_outlined, text: '${course.enrollmentCount ?? 0} students'),
                        if (blockedCount > 0) _MiniBadge(icon: Icons.shield_outlined, text: '$blockedCount blocked'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final ModuleItem module;
  final bool enabled;
  final VoidCallback? onTap;
  final String? reason;

  const _ModuleTile({
    required this.module,
    required this.enabled,
    this.onTap,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: enabled ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.folder_copy_outlined, color: enabled ? const Color(0xFF137FEC) : AppColors.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(module.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: enabled ? AppColors.textTitle : AppColors.textMuted)),
                const SizedBox(height: 4),
                Text(
                  (module.description ?? '').trim().isEmpty ? 'No description yet' : module.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniBadge(icon: Icons.visibility_outlined, text: module.isPublished ? 'Published' : 'Draft'),
                    _MiniBadge(icon: Icons.swap_vert_rounded, text: 'Order #${module.orderIndex + 1}'),
                    if (!enabled && reason != null) _MiniBadge(icon: Icons.info_outline_rounded, text: reason!),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (enabled)
            FilledButton.icon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF137FEC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.copy_all_rounded, size: 16),
              label: const Text('Copy'),
            )
          else
            const Icon(Icons.block_rounded, color: AppColors.textMuted),
        ],
      ),
    );

    if (!enabled) return Opacity(opacity: 0.78, child: card);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), borderRadius: BorderRadius.circular(10), onTap: onTap, child: card),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1D6FE9)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
        ],
      ),
    );
  }
}

class _CountBubble extends StatelessWidget {
  final int count;
  const _CountBubble({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.border),
      ),
      child: Text('$count', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
    );
  }
}

class _StateLabel extends StatelessWidget {
  final String text;
  const _StateLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textMuted));
  }
}

class _BackLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BackLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
        if (required)
          const Text(' *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
      ),
    );
  }
}
