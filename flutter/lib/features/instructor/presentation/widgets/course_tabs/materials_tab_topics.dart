part of 'materials_tab.dart';

class _TopicsSidebarWidget extends StatelessWidget {
  final List<TopicItem> topics; final bool loading;
  final void Function(TopicItem) onTopicTap;
  final VoidCallback onAddManual, onGenerateAI;
  const _TopicsSidebarWidget({required this.topics, required this.loading,
      required this.onTopicTap, required this.onAddManual, required this.onGenerateAI});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _K.div))),
        child: Row(children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(7)),
            alignment: Alignment.center,
            child: const Icon(Icons.tag_rounded, size: 13, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          const Text('Topics', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
          if (!loading && topics.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
              child: Text('${topics.length}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ],
          const Spacer(),
          if (loading) const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.5)),
        ]),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _K.div))),
        child: SizedBox(
          width: double.infinity,
          child: _AddTopicBtnW(
            icon: Icons.edit_rounded,
            label: 'Add Topic',
            onTap: onAddManual,
            color: AppColors.primary,
            bg: _K.blueSoft,
          ),
        ),
      ),
      Expanded(
        child: loading
            ? const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 8),
                  Text('Loading topics…', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ]),
              )
            : topics.isEmpty
                ? _TopicsEmptyW(onAddManual: onAddManual)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: topics.length,
                    itemBuilder: (_, i) => _TopicItemW(topic: topics[i], index: i, onTap: () => onTopicTap(topics[i])),
                  ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Unified "Add Topic" button
// ─────────────────────────────────────────────────────────────────────────────
class _AddTopicUnifiedBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTopicUnifiedBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A137FEC),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: Colors.white),
              SizedBox(width: 5),
              Text(
                'Add Topic',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;
  const _GhostActionButton({required this.icon, required this.label, required this.fg, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
          ]),
        ),
      ),
    );
  }
}


enum _TopicCreateMode { manual, ai }

class _TopicDialogResult {
  final String title;
  final _TopicCreateMode mode;
  final List<int> learningOutcomeIds;

  const _TopicDialogResult.manual(this.title, {this.learningOutcomeIds = const []})
      : mode = _TopicCreateMode.manual;
  const _TopicDialogResult.ai()
      : mode = _TopicCreateMode.ai,
        title = '',
        learningOutcomeIds = const [];
}

class _AddTopicDialogV2 extends StatefulWidget {
  final List<LearningOutcome> outcomes;
  const _AddTopicDialogV2({super.key, this.outcomes = const []});

  @override
  State<_AddTopicDialogV2> createState() => _AddTopicDialogV2State();
}

class _AddTopicDialogV2State extends State<_AddTopicDialogV2>
    {
  final TextEditingController _titleCtrl = TextEditingController();
  bool _submitted = false;
  final Set<int> _selectedOutcomeIds = {};

  String? get _titleError {
    if (!_submitted) return null;
    if (_titleCtrl.text.trim().isEmpty) return 'Topic name is required';
    return null;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _submitted = true);
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(context, _TopicDialogResult.manual(title, learningOutcomeIds: _selectedOutcomeIds.toList()));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 42,
                  spreadRadius: 2,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogHeader(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: _manualBody(),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _K.div)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: _K.div),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Create Topic'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _K.div))),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.tag_rounded, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add Topic', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
            SizedBox(height: 2),
            Text('Create a clear topic and attach it to the right learning outcomes.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ]),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, size: 18),
          splashRadius: 20,
        ),
      ]),
    );
  }

  Widget _manualBody() {
    final outcomes = widget.outcomes;
    return Column(
      key: const ValueKey('manual'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Topic name', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        TextField(
          controller: _titleCtrl,
          autofocus: true,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'e.g. Introduction to Robotics',
            errorText: _titleError,
            prefixIcon: const Icon(Icons.tag_rounded, size: 16, color: AppColors.primary),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _K.div)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _K.div)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.4)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        if (outcomes.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(children: [
            const Text('Link to Learning Outcomes',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            const SizedBox(width: 6),
            Text('(optional)',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted.withOpacity(0.7))),
          ]),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _K.div),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: outcomes.length,
                itemBuilder: (_, i) {
                  final lo = outcomes[i];
                  final selected = _selectedOutcomeIds.contains(lo.id);
                  Color dotColor;
                  switch (lo.difficulty) {
                    case OutcomeDifficulty.intermediate: dotColor = const Color(0xFFD97706); break;
                    case OutcomeDifficulty.advanced: dotColor = const Color(0xFFDC2626); break;
                    default: dotColor = const Color(0xFF16A34A);
                  }
                  return InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedOutcomeIds.remove(lo.id);
                      } else {
                        _selectedOutcomeIds.add(lo.id);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary.withOpacity(0.06) : Colors.transparent,
                        border: i < outcomes.length - 1
                            ? const Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))
                            : null,
                      ),
                      child: Row(children: [
                        Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: selected ? AppColors.primary : const Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                          ),
                          child: selected
                              ? const Icon(Icons.check, size: 11, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.badgeBlueBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(lo.code,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.badgeBlueFg)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(lo.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: selected ? AppColors.textTitle : AppColors.textMuted,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            ))),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_selectedOutcomeIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${_selectedOutcomeIds.length} outcome${_selectedOutcomeIds.length == 1 ? '' : 's'} linked',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _K.blueSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _K.blueMid),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Use clear topic names so question generation and analytics stay well organized.',
              style: TextStyle(fontSize: 13, height: 1.5,
                  color: AppColors.primary, fontWeight: FontWeight.w500),
            )),
          ]),
        ),
      ],
    );
  }

}



bool _isDangerActionColor(Color color) => color.red >= 180 && color.green <= 120;

class _PreferencesDialogShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final Widget? leading;

  const _PreferencesDialogShell({
    required this.title,
    required this.child,
    this.subtitle,
    this.maxWidth = 620,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 20),
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textTitle,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool multiline;
  final bool autofocus;

  const _DialogTextField({
    required this.controller,
    required this.hintText,
    this.multiline = false,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: multiline ? 104 : 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: multiline ? 14 : 0,
      ),
      alignment: multiline ? Alignment.topLeft : Alignment.centerLeft,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        minLines: multiline ? 4 : 1,
        maxLines: multiline ? 5 : 1,
        style: AppText.input,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppText.hint,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _DialogActions extends StatelessWidget {
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;
  final AppButtonVariant confirmVariant;

  const _DialogActions({
    this.cancelLabel = 'Cancel',
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.confirmVariant = AppButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: cancelLabel,
            onTap: onCancel,
            variant: AppButtonVariant.soft,
            fullWidth: true,
            height: 40,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppButton(
            label: confirmLabel,
            onTap: onConfirm,
            variant: confirmVariant,
            fullWidth: true,
            height: 40,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ShareModuleDialog — lets the instructor choose the target course
// ─────────────────────────────────────────────────────────────────────────────
final _shareTargetCoursesProvider = FutureProvider.family<List<MyCourseItem>, int>((ref, currentCourseId) async {
  final res = await ref.read(coursesRepositoryProvider).myCourses(
    enrichMissingModuleCounts: false,
  );
  final items = [...res.items]
    ..removeWhere((course) => course.id == currentCourseId)
    ..sort((a, b) => a.safeTitle.toLowerCase().compareTo(b.safeTitle.toLowerCase()));
  return items;
});

class _ShareModuleDialog extends ConsumerStatefulWidget {
  final ModuleItem module;
  final int currentCourseId;
  const _ShareModuleDialog({required this.module, required this.currentCourseId, super.key});

  @override
  ConsumerState<_ShareModuleDialog> createState() => _ShareModuleDialogState();
}

class _ShareModuleDialogState extends ConsumerState<_ShareModuleDialog> {
  MyCourseItem? _selectedCourse;

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(_shareTargetCoursesProvider(widget.currentCourseId));
    return _PreferencesDialogShell(
      title: 'Share with Another Course',
      subtitle: 'Choose which course should receive a copied module',
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.copy_all_rounded, size: 18, color: Color(0xFF7C3AED)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.folder_rounded, size: 18, color: Color(0xFF137FEC)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.module.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
                  if (widget.module.description != null && widget.module.description!.isNotEmpty)
                    Text(widget.module.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          coursesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Text('Could not load your courses: $error', style: const TextStyle(fontSize: 13, color: Color(0xFF9F1239))),
            ),
            data: (courses) {
              if (courses.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text('No other instructor courses are available for sharing yet.', style: TextStyle(fontSize: 13, color: Color(0xFF92400E))),
                );
              }

              _selectedCourse ??= courses.first;
              final currentValue = courses.contains(_selectedCourse) ? _selectedCourse! : courses.first;
              return AppModernDropdown<MyCourseItem>(
                label: 'Target course',
                value: currentValue,
                items: [
                  for (final course in courses)
                    DropdownMenuItem<MyCourseItem>(
                      value: course,
                      child: Text(course.safeTitle, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => _selectedCourse = value),
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Expanded(child: Text(
                'This creates an independent copy in the selected course using the current backend copy endpoint.',
                style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF92400E)),
              )),
            ]),
          ),
          const SizedBox(height: 20),
          _DialogActions(
            onCancel: () => Navigator.pop(context),
            onConfirm: _selectedCourse == null ? null : () => Navigator.pop(context, _selectedCourse),
            confirmLabel: 'Copy Module',
          ),
        ],
      ),
    );
  }
}

class _DescriptionDialog extends StatelessWidget {
  final TextEditingController ctrl;
  const _DescriptionDialog({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return _PreferencesDialogShell(
      title: 'Edit Description',
      subtitle: 'Update the module description shown in preferences and sharing flows.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DialogTextField(
            controller: ctrl,
            hintText: 'Write a short helpful description',
            multiline: true,
          ),
          const SizedBox(height: 16),
          _DialogActions(
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
            confirmLabel: 'Save',
          ),
        ],
      ),
    );
  }
}

class _ChangeModulePositionDialog extends StatefulWidget {
  final ModuleItem module;
  final List<ModuleItem> modules;
  const _ChangeModulePositionDialog({required this.module, required this.modules});

  @override
  State<_ChangeModulePositionDialog> createState() => _ChangeModulePositionDialogState();
}

class _ChangeModulePositionDialogState extends State<_ChangeModulePositionDialog> {
  late int _selectedPosition = widget.module.orderIndex + 1;

  @override
  Widget build(BuildContext context) {
    return _PreferencesDialogShell(
      title: 'Change Position',
      subtitle: 'Move "${widget.module.title}" to a new order inside this course.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppModernDropdown<int>(
            label: 'Position',
            value: _selectedPosition,
            items: [
              for (var i = 0; i < widget.modules.length; i++)
                DropdownMenuItem<int>(
                  value: i + 1,
                  child: Text('#${i + 1}'),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedPosition = value);
            },
          ),
          const SizedBox(height: 16),
          _DialogActions(
            onCancel: () => Navigator.pop(context),
            onConfirm: () => Navigator.pop(context, _selectedPosition),
            confirmLabel: 'Save',
          ),
        ],
      ),
    );
  }
}

class _ManualTabContent extends StatelessWidget {
  final TextEditingController ctrl;
  final String? error;
  const _ManualTabContent({required this.ctrl, this.error, super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink(); // unused, kept for compat
}

class _AITabContent extends StatelessWidget {
  const _AITabContent({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink(); // unused, kept for compat
}


class _AddTopicBtnW extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  final Color color, bg;
  const _AddTopicBtnW({required this.icon, required this.label, required this.onTap,
      required this.color, required this.bg});
  @override
  Widget build(BuildContext context) => InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), onTap: onTap,
      borderRadius: BorderRadius.circular(7), child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 13, color: color), const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ])));
}

class _TopicsEmptyW extends StatelessWidget {
  final VoidCallback onAddManual;
  const _TopicsEmptyW({required this.onAddManual});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.tag_rounded, size: 22, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          const Text('No topics yet',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
          const SizedBox(height: 6),
          const Text(
            'Use the "Add Topic" button above to add the first topic for this material.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.6),
          ),
        ],
      ),
    ),
  );
}

class _TopicItemW extends StatelessWidget {
  final TopicItem topic; final int index; final VoidCallback onTap;
  const _TopicItemW({required this.topic, required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final readiness = _topicReadinessMeta(topic.readiness);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8ECF2)),
            boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)]),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text('${index + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(topic.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
              const SizedBox(height: 7),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: readiness.bg, borderRadius: BorderRadius.circular(999)),
                  child: Text(readiness.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: readiness.fg)),
                ),
                if (topic.estimatedDurationMinutes != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(999)),
                    child: Text('~${topic.estimatedDurationMinutes} min', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  ),
                if (topic.learningOutcomeIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(999)),
                    child: Text('${topic.learningOutcomeIds.length} LO${topic.learningOutcomeIds.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
              ]),
            ])),
            const SizedBox(width: 8),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textHint),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOPIC DRILL-DOWN PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _TopicPanelWidget extends StatelessWidget {
  final ModuleItem module;
  final MaterialItem material;
  final TopicItem topic;
  final List<TopicItem> allMaterialTopics;
  final List<LearningOutcome> outcomes;
  final bool canPop;
  final VoidCallback onBack, onGenerate, onAddManualQuestion, onEditTopic, onAddSubtopic;
  final ValueChanged<TopicItem> onOpenSubtopic;

  const _TopicPanelWidget({
    required this.module,
    required this.material,
    required this.topic,
    required this.allMaterialTopics,
    required this.outcomes,
    required this.canPop,
    required this.onBack,
    required this.onGenerate,
    required this.onAddManualQuestion,
    required this.onEditTopic,
    required this.onAddSubtopic,
    required this.onOpenSubtopic,
  });

  @override
  Widget build(BuildContext context) {
    final mappedOutcomes = outcomes
        .where((o) => topic.linkedOutcomeIds.contains(o.id.toString()) || topic.linkedOutcomeId == o.id.toString())
        .toList();

    final readinessMeta = _topicReadinessMeta(topic.readiness);
    final difficultyMeta = _topicDifficultyMeta(topic.difficulty);

    final isSubtopic = topic.parentTopicId != null;
    final parentTopic = isSubtopic
        ? allMaterialTopics.cast<TopicItem?>().firstWhere(
            (t) => t?.id == topic.parentTopicId,
            orElse: () => null,
          )
        : null;
    final subtopics = allMaterialTopics
        .where((t) => t.parentTopicId == topic.id)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));


    final actionCards = [
      _TopicActionData(
        icon: isSubtopic ? Icons.topic_outlined : Icons.auto_awesome_rounded,
        title: isSubtopic ? 'Build questions from subtopic' : 'Generate questions',
        subtitle: isSubtopic
            ? 'Use this subtopic as a focused anchor for question authoring.'
            : 'Open scoped AI generation with this topic as the anchor.',
        accent: AppColors.primary,
        softColor: AppColors.primarySoft,
        onTap: onGenerate,
      ),
      _TopicActionData(
        icon: Icons.edit_note_rounded,
        title: isSubtopic ? 'Draft subtopic question' : 'Draft manual question',
        subtitle: isSubtopic
            ? 'Create a question tied to this subtopic only.'
            : 'Create a hand-authored question tied directly to this topic.',
        accent: _K.blue,
        softColor: _K.blueSoft,
        onTap: onAddManualQuestion,
      ),
      _TopicActionData(
        icon: Icons.tune_rounded,
        title: isSubtopic ? 'Refine subtopic setup' : 'Refine topic setup',
        subtitle: 'Update title, mappings, notes, and delivery status.',
        accent: _K.green,
        softColor: _K.greenSoft,
        onTap: onEditTopic,
      ),
    ];

    final timeline = [
      _TimelineEntry(
        icon: Icons.add_task_rounded,
        title: isSubtopic ? 'Subtopic created' : 'Topic created',
        subtitle: isSubtopic ? 'Structured under its parent topic and ready for refinement.' : 'Structured under this material and ready for instructor refinement.',
      ),
      _TimelineEntry(
        icon: Icons.flag_outlined,
        title: mappedOutcomes.isEmpty ? 'Outcome mapping pending' : 'Outcome alignment in place',
        subtitle: mappedOutcomes.isEmpty
            ? 'Use Manage to connect this topic to one or more course outcomes.'
            : '${mappedOutcomes.length} mapped outcome(s) are already linked to this topic.',
      ),
      _TimelineEntry(
        icon: topic.readiness == TopicReadiness.ready ? Icons.rocket_launch_rounded : Icons.rule_folder_outlined,
        title: topic.readiness == TopicReadiness.ready ? 'Delivery-ready topic' : 'Preparation still in progress',
        subtitle: topic.readiness == TopicReadiness.ready
            ? 'This topic can move straight into assessment and delivery workflows.'
            : 'Keep refining content, notes, and alignment before live delivery.',
      ),
    ];

    return Container(
      color: _K.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _K.div)),
            ),
            child: Row(
              children: [
                if (canPop)
                  InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _K.bg,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _K.div),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back_ios_new_rounded, size: 11, color: AppColors.textMuted),
                          const SizedBox(width: 5),
                          Text(
                            material.displayTitle,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (canPop) const SizedBox(width: 10),
                const Icon(Icons.tag_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    topic.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTitle,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onEditTopic,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Manage'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopicHeroCard(
                    module: module,
                    material: material,
                    topic: topic,
                    parentTopicTitle: parentTopic?.title,
                    isSubtopic: isSubtopic,
                    mappedOutcomesCount: mappedOutcomes.length,
                    readinessMeta: readinessMeta,
                    difficultyMeta: difficultyMeta,
                    onManage: onEditTopic,
                  ),
                  const SizedBox(height: 18),
                  _TopicInsightsGrid(
                    topic: topic,
                    parentTopicTitle: parentTopic?.title,
                    isSubtopic: isSubtopic,
                    mappedOutcomesCount: mappedOutcomes.length,
                    readinessMeta: readinessMeta,
                    difficultyMeta: difficultyMeta,
                  ),
                  const SizedBox(height: 18),
                  _TopicSmartActionsCard(actions: actionCards),
                  const SizedBox(height: 18),
                  if (topic.description?.isNotEmpty ?? false) ...[
                    _CardWidget(
                      header: const _HdrWidget(
                        icon: Icons.description_outlined,
                        iconColor: AppColors.primary,
                        title: 'Topic Brief',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Text(
                          topic.description!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _CardWidget(
                    header: const _HdrWidget(
                      icon: Icons.flag_outlined,
                      iconColor: AppColors.primary,
                      title: 'Learning Outcome Alignment',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: mappedOutcomes.isEmpty
                          ? const Text(
                              'This topic is not mapped yet. Use Manage to align it to one or more course outcomes.',
                              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: mappedOutcomes
                                  .map(
                                    (lo) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _K.blueSoft,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: _K.blueMid),
                                      ),
                                      child: Text(
                                        '${lo.code} • ${lo.description}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CardWidget(
                    header: const _HdrWidget(
                      icon: Icons.sticky_note_2_outlined,
                      iconColor: AppColors.primary,
                      title: 'Instructor Notes',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Text(
                        (topic.instructorNotes?.trim().isNotEmpty ?? false)
                            ? topic.instructorNotes!.trim()
                            : 'No notes yet. Use Manage to add delivery notes, examples, or assessment guidance.',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!isSubtopic) ...[
                    _TopicSubtopicsCard(
                      topic: topic,
                      subtopics: subtopics,
                      onAddSubtopic: onAddSubtopic,
                      onOpenSubtopic: onOpenSubtopic,
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    _CardWidget(
                      header: const _HdrWidget(
                        icon: Icons.account_tree_outlined,
                        iconColor: AppColors.primary,
                        title: 'Parent topic',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Text(
                          parentTopic?.title ?? 'Parent topic',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textTitle),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _TopicTimelineCard(entries: timeline),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _TopicSubtopicsCard extends StatelessWidget {
  final TopicItem topic;
  final List<TopicItem> subtopics;
  final VoidCallback onAddSubtopic;
  final ValueChanged<TopicItem> onOpenSubtopic;

  const _TopicSubtopicsCard({
    required this.topic,
    required this.subtopics,
    required this.onAddSubtopic,
    required this.onOpenSubtopic,
  });

  @override
  Widget build(BuildContext context) {
    return _CardWidget(
      header: _HdrWidget(
        icon: Icons.account_tree_outlined,
        iconColor: AppColors.primary,
        title: 'Subtopics',
        trailing: ElevatedButton.icon(
          onPressed: onAddSubtopic,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Subtopic'),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: subtopics.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No subtopics yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTitle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Break "${topic.title}" into smaller teaching units so questions and notes stay organized.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: onAddSubtopic,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Create first subtopic'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  for (final subtopic in subtopics) ...[
                    InkWell(
                      hoverColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onOpenSubtopic(subtopic),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF3FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.subdirectory_arrow_right_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subtopic.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textTitle,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${subtopic.difficulty.label} • ${subtopic.readiness.label}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      ),
    );
  }
}

class _TopicHeroCard extends StatelessWidget {
  final ModuleItem module;
  final MaterialItem material;
  final TopicItem topic;
  final int mappedOutcomesCount;
  final bool isSubtopic;
  final String? parentTopicTitle;
  final _TopicMeta readinessMeta;
  final _TopicMeta difficultyMeta;
  final VoidCallback onManage;

  const _TopicHeroCard({
    required this.module,
    required this.material,
    required this.topic,
    required this.mappedOutcomesCount,
    required this.isSubtopic,
    this.parentTopicTitle,
    required this.readinessMeta,
    required this.difficultyMeta,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final created = '${topic.createdAt.day}/${topic.createdAt.month}/${topic.createdAt.year}';
    final statusChips = [
      _TopicStatusChip(
        icon: isSubtopic ? Icons.subdirectory_arrow_right_rounded : Icons.sell_outlined,
        label: isSubtopic ? 'Subtopic' : 'Topic',
        fg: AppColors.primary,
        bg: AppColors.primarySoft,
      ),
      if (topic.isRequired)
        const _TopicStatusChip(
          icon: Icons.check_circle_outline_rounded,
          label: 'Required',
          fg: _K.blue,
          bg: _K.blueSoft,
        ),
      _TopicStatusChip(icon: readinessMeta.icon, label: readinessMeta.label, fg: readinessMeta.fg, bg: readinessMeta.bg),
      _TopicStatusChip(icon: difficultyMeta.icon, label: difficultyMeta.label, fg: difficultyMeta.fg, bg: difficultyMeta.bg),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A1D4ED8),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: statusChips),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                  ),
                  child: Icon(
                    isSubtopic ? Icons.subdirectory_arrow_right_rounded : Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _TopicBreadcrumb(icon: Icons.folder_outlined, text: module.title),
                          _TopicBreadcrumb(icon: Icons.article_outlined, text: material.displayTitle),
                          if (isSubtopic && parentTopicTitle != null)
                            _TopicBreadcrumb(icon: Icons.account_tree_outlined, text: parentTopicTitle!),
                          _TopicBreadcrumb(icon: Icons.calendar_today_outlined, text: 'Created $created'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: onManage,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF111827),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _HeroStat(
                    label: 'Mapped outcomes',
                    value: mappedOutcomesCount == 0 ? 'Unmapped' : '$mappedOutcomesCount linked',
                    helper: mappedOutcomesCount == 0 ? 'Needs alignment' : 'Aligned with course goals',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeroStat(
                    label: 'Question workflow',
                    value: topic.readiness == TopicReadiness.ready ? 'Generation-ready' : 'Preparation mode',
                    helper: topic.readiness == TopicReadiness.ready ? 'Safe to build assessment coverage' : 'Refine content first',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeroStat(
                    label: isSubtopic ? 'Hierarchy' : 'Topic type',
                    value: isSubtopic ? 'Nested under topic' : (topic.source == TopicSource.ai ? 'AI-assisted' : 'Instructor-led'),
                    helper: isSubtopic ? 'Final content level inside this material' : (topic.source == TopicSource.ai ? 'Generated from material context' : 'Created manually'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicInsightsGrid extends StatelessWidget {
  final TopicItem topic;
  final int mappedOutcomesCount;
  final bool isSubtopic;
  final String? parentTopicTitle;
  final _TopicMeta readinessMeta;
  final _TopicMeta difficultyMeta;

  const _TopicInsightsGrid({
    required this.topic,
    required this.mappedOutcomesCount,
    required this.isSubtopic,
    this.parentTopicTitle,
    required this.readinessMeta,
    required this.difficultyMeta,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _TopicInsightData(
        title: 'Delivery status',
        value: readinessMeta.label,
        caption: topic.readiness == TopicReadiness.ready
            ? 'Ready for live teaching'
            : topic.readiness == TopicReadiness.review
                ? 'Needs final QA pass'
                : 'Still being prepared',
        icon: readinessMeta.icon,
        accent: readinessMeta.fg,
        softColor: readinessMeta.bg,
      ),
      _TopicInsightData(
        title: 'Difficulty',
        value: difficultyMeta.label,
        caption: topic.difficulty == TopicDifficulty.beginner
            ? 'Accessible introduction'
            : topic.difficulty == TopicDifficulty.intermediate
                ? 'Balanced depth'
                : 'Advanced treatment',
        icon: difficultyMeta.icon,
        accent: difficultyMeta.fg,
        softColor: difficultyMeta.bg,
      ),
      _TopicInsightData(
        title: 'Outcome coverage',
        value: mappedOutcomesCount == 0 ? 'Pending' : '$mappedOutcomesCount linked',
        caption: mappedOutcomesCount == 0
            ? 'No outcome alignment yet'
            : 'Connected to measurable outcomes',
        icon: Icons.flag_outlined,
        accent: _K.blue,
        softColor: _K.blueSoft,
      ),
      _TopicInsightData(
        title: isSubtopic ? 'Parent topic' : 'Instructor notes',
        value: isSubtopic
            ? (parentTopicTitle ?? 'Parent topic')
            : ((topic.instructorNotes?.trim().isNotEmpty ?? false) ? 'Available' : 'Missing'),
        caption: isSubtopic
            ? 'This subtopic is the final hierarchy level and cannot contain children.'
            : ((topic.instructorNotes?.trim().isNotEmpty ?? false)
                ? 'Delivery guidance has been added'
                : 'Add notes for examples and pacing'),
        icon: isSubtopic ? Icons.account_tree_outlined : Icons.sticky_note_2_outlined,
        accent: AppColors.primary,
        softColor: AppColors.primarySoft,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100
            ? 4
            : constraints.maxWidth > 760
                ? 2
                : 1;
        final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 14) / crossAxisCount;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards
              .map((card) => SizedBox(
                    width: itemWidth,
                    child: _TopicInsightCard(data: card),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _TopicInsightData {
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color accent;
  final Color softColor;

  const _TopicInsightData({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.accent,
    required this.softColor,
  });
}

class _TopicActionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color softColor;
  final VoidCallback onTap;

  const _TopicActionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.softColor,
    required this.onTap,
  });
}

class _TimelineEntry {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TimelineEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _TopicMeta {
  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;

  const _TopicMeta({
    required this.label,
    required this.icon,
    required this.fg,
    required this.bg,
  });
}

class _TopicStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;

  const _TopicStatusChip({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicBreadcrumb extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TopicBreadcrumb({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white.withOpacity(0.78)),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.84),
          ),
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final String helper;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.78),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Colors.white.withOpacity(0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicInsightCard extends StatelessWidget {
  final _TopicInsightData data;

  const _TopicInsightCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EEF5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.softColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: data.accent, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            data.title,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            data.value,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.textTitle),
          ),
          const SizedBox(height: 6),
          Text(
            data.caption,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _TopicSmartActionsCard extends StatelessWidget {
  final List<_TopicActionData> actions;

  const _TopicSmartActionsCard({required this.actions});

  @override
  Widget build(BuildContext context) {
    return _CardWidget(
      header: const _HdrWidget(
        icon: Icons.flash_on_rounded,
        iconColor: AppColors.primary,
        title: 'Smart Actions',
      ),
      child: Column(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            _TopicActionTile(data: actions[i]),
            if (i != actions.length - 1) const Divider(height: 1, color: Color(0xFFEEF2F6)),
          ],
        ],
      ),
    );
  }
}

class _TopicActionTile extends StatelessWidget {
  final _TopicActionData data;

  const _TopicActionTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: data.softColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(data.icon, color: data.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
                    const SizedBox(height: 4),
                    Text(data.subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_outward_rounded, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicTimelineCard extends StatelessWidget {
  final List<_TimelineEntry> entries;

  const _TopicTimelineCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return _CardWidget(
      header: const _HdrWidget(
        icon: Icons.schedule_rounded,
        iconColor: AppColors.primary,
        title: 'Topic timeline',
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(entries[i].icon, size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entries[i].title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
                        const SizedBox(height: 4),
                        Text(entries[i].subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.45)),
                      ],
                    ),
                  ),
                ],
              ),
              if (i != entries.length - 1) const Padding(
                padding: EdgeInsets.only(left: 15, top: 8, bottom: 8),
                child: Divider(height: 1, color: Color(0xFFEEF2F6)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

_TopicMeta _topicReadinessMeta(TopicReadiness readiness) {
  switch (readiness) {
    case TopicReadiness.ready:
      return const _TopicMeta(
        label: 'Ready',
        icon: Icons.check_circle_rounded,
        fg: _K.green,
        bg: _K.greenSoft,
      );
    case TopicReadiness.review:
      return const _TopicMeta(
        label: 'Needs Review',
        icon: Icons.pending_actions_rounded,
        fg: _K.amber,
        bg: _K.amberSoft,
      );
    case TopicReadiness.draft:
      return const _TopicMeta(
        label: 'Draft',
        icon: Icons.edit_note_rounded,
        fg: AppColors.textMuted,
        bg: Color(0xFFF1F5F9),
      );
  }
}

_TopicMeta _topicDifficultyMeta(TopicDifficulty difficulty) {
  switch (difficulty) {
    case TopicDifficulty.beginner:
      return const _TopicMeta(
        label: 'Beginner',
        icon: Icons.wb_sunny_outlined,
        fg: _K.blue,
        bg: _K.blueSoft,
      );
    case TopicDifficulty.intermediate:
      return const _TopicMeta(
        label: 'Intermediate',
        icon: Icons.stacked_bar_chart_rounded,
        fg: _K.amber,
        bg: _K.amberSoft,
      );
    case TopicDifficulty.advanced:
      return const _TopicMeta(
        label: 'Advanced',
        icon: Icons.local_fire_department_outlined,
        fg: Color(0xFFDC2626),
        bg: Color(0xFFFEF2F2),
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DIALOGS
// ─────────────────────────────────────────────────────────────────────────────
