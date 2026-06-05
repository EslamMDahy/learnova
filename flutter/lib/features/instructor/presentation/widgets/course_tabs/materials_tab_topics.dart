part of 'materials_tab.dart';

class _TopicsSidebarWidget extends StatelessWidget {
  final List<TopicItem> topics; final bool loading;
  final void Function(TopicItem) onTopicTap;
  final VoidCallback onAddManual, onGenerateAI;
  const _TopicsSidebarWidget({required this.topics, required this.loading,
      required this.onTopicTap, required this.onAddManual, required this.onGenerateAI,});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
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
          Text('Topics', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
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
        ],),
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
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(strokeWidth: 2),
                  const SizedBox(height: 8),
                  Text('Loading topics…', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ],),
              )
            : topics.isEmpty
                ? _TopicsEmptyW(onAddManual: onAddManual)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: topics.length,
                    itemBuilder: (_, i) => _TopicItemW(topic: topics[i], index: i, onTap: () => onTopicTap(topics[i])),
                  ),
      ),
    ],);
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
    Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              const BoxShadow(
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
    Theme.of(context);
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
          ],),
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
  final bool isSubtopic;
  const _AddTopicDialogV2({super.key, this.outcomes = const [], this.isSubtopic = false});

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
    if (_titleCtrl.text.trim().isEmpty) return widget.isSubtopic ? 'Subtopic name is required' : 'Topic name is required';
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
    Navigator.pop(context, _TopicDialogResult.manual(title, learningOutcomeIds: widget.isSubtopic ? _selectedOutcomeIds.toList() : const []));
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
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
                              borderRadius: BorderRadius.circular(12),),
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
                        label: Text(widget.isSubtopic ? 'Create Subtopic' : 'Create Topic'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),),
                        ),
                      ),
                    ),
                  ],),
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
          border: Border(bottom: BorderSide(color: _K.div)),),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.tag_rounded, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.isSubtopic ? 'Add Subtopic' : 'Add Topic', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textTitle,),),
            const SizedBox(height: 2),
            Text(widget.isSubtopic
                ? 'Create a final learning unit and map it to learning outcomes.'
                : 'Create a parent topic. Outcome mapping belongs to subtopics.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),),
          ],),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, size: 18),
          splashRadius: 20,
        ),
      ],),
    );
  }

  Widget _manualBody() {
    final outcomes = widget.isSubtopic ? widget.outcomes : const <LearningOutcome>[];
    return Column(
      key: const ValueKey('manual'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.isSubtopic ? 'Subtopic name' : 'Topic name', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted,),),
        const SizedBox(height: 8),
        TextField(
          controller: _titleCtrl,
          autofocus: true,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: widget.isSubtopic ? 'e.g. Variables and data types' : 'e.g. Introduction to Robotics',
            errorText: _titleError,
            prefixIcon: const Icon(Icons.tag_rounded, size: 16, color: AppColors.primary),
            filled: true,
            fillColor: AppColors.surfaceBg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _K.div),),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _K.div),),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.4),),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        if (outcomes.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(children: [
            Text('Link to Learning Outcomes',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted),),
            const SizedBox(width: 6),
            Text('(optional)',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted.withOpacity(0.7)),),
          ],),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: AppColors.surfaceBg,
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
                    case OutcomeDifficulty.intermediate: dotColor = AppColors.warningText; break;
                    case OutcomeDifficulty.advanced: dotColor = AppColors.dangerText; break;
                    default: dotColor = AppColors.successText;
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
                            ? Border(bottom: BorderSide(color: AppColors.divider))
                            : null,
                      ),
                      child: Row(children: [
                        Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: selected ? AppColors.primary : AppColors.borderSoft,
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
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.badgeBlueFg),),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(lo.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: selected ? AppColors.textTitle : AppColors.textMuted,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            ),),),
                      ],),
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
                  style: const TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w600),),
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
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(
              widget.isSubtopic
                  ? 'Subtopics are final-level items. Map learning outcomes here, not on the parent topic.'
                  : 'This creates a parent topic only. Add subtopics underneath it to map learning outcomes cleanly.',
              style: const TextStyle(fontSize: 13, height: 1.5,
                  color: AppColors.primary, fontWeight: FontWeight.w500,),
            ),),
          ],),
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
    Theme.of(context);
    return Dialog(
      backgroundColor: AppColors.cardBg,
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textTitle,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            subtitle!,
                            style: TextStyle(
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
                    child: Padding(
                      padding: const EdgeInsets.all(6),
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
    Theme.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: multiline ? 104 : 48),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
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
    Theme.of(context);
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
    Theme.of(context);
    final coursesAsync = ref.watch(_shareTargetCoursesProvider(widget.currentCourseId));
    return _PreferencesDialogShell(
      title: 'Share with Another Course',
      subtitle: 'Choose which course should receive a copied module',
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.infoBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.copy_all_rounded, size: 18, color: AppColors.purpleText),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.folder_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.module.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
                  if (widget.module.description != null && widget.module.description!.isNotEmpty)
                    Text(widget.module.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ],),
              ),
            ],),
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
                color: AppColors.dangerBg,
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
                    color: AppColors.warningSoftBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warningBorder),
                  ),
                  child: Text('No other instructor courses are available for sharing yet.', style: TextStyle(fontSize: 13, color: AppColors.warningText)),
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
              color: AppColors.warningSoftBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warningBorder),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 15, color: AppColors.warningText),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'This creates an independent copy in the selected course using the current backend copy endpoint.',
                style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.warningText),
              ),),
            ],),
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
    Theme.of(context);
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
    Theme.of(context);
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
      required this.color, required this.bg,});
  @override
  Widget build(BuildContext context) => InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), onTap: onTap,
      borderRadius: BorderRadius.circular(7), child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 13, color: color), const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],),),);
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
          Text('No topics yet',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textTitle),),
          const SizedBox(height: 6),
          Text(
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
    Theme.of(context);
    final readiness = _topicReadinessMeta(topic.readiness);
    return Material(
      color: AppColors.cardBg,
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
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: [BoxShadow(color: AppColors.shadowSoft, blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.badgeIndigoBg, AppColors.purpleBg]),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text('${index + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(topic.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
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
                    decoration: BoxDecoration(color: AppColors.surfaceBg, borderRadius: BorderRadius.circular(999)),
                    child: Text('~${topic.estimatedDurationMinutes} min', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  ),
                if (topic.learningOutcomeIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(999)),
                    child: Text('${topic.learningOutcomeIds.length} LO${topic.learningOutcomeIds.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
              ],),
            ],),),
            const SizedBox(width: 8),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: AppColors.surfaceBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textHint),
            ),
          ],),
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
  final VoidCallback onBack;
  final VoidCallback onRenameTopic;
  final VoidCallback onEditTopicSummary;
  final VoidCallback onEditTopicStatus;
  final VoidCallback onMapTopicOutcomes;
  final VoidCallback onDeleteTopic;
  final VoidCallback onAddSubtopic;
  final ValueChanged<TopicItem> onOpenSubtopic;

  const _TopicPanelWidget({
    required this.module,
    required this.material,
    required this.topic,
    required this.allMaterialTopics,
    required this.outcomes,
    required this.canPop,
    required this.onBack,
    required this.onRenameTopic,
    required this.onEditTopicSummary,
    required this.onEditTopicStatus,
    required this.onMapTopicOutcomes,
    required this.onDeleteTopic,
    required this.onAddSubtopic,
    required this.onOpenSubtopic,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
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
    final mappedOutcomes = outcomes
        .where((o) => topic.learningOutcomeIds.contains(o.id) || topic.linkedOutcomeIds.contains(o.id.toString()) || topic.linkedOutcomeId == o.id.toString())
        .toList();
    final inheritedOutcomeIds = <int>{};
    for (final subtopic in subtopics) {
      inheritedOutcomeIds.addAll(subtopic.learningOutcomeIds);
      for (final raw in subtopic.linkedOutcomeIds) {
        final parsed = int.tryParse(raw);
        if (parsed != null) inheritedOutcomeIds.add(parsed);
      }
      final legacy = int.tryParse(subtopic.linkedOutcomeId ?? '');
      if (legacy != null) inheritedOutcomeIds.add(legacy);
    }
    final inheritedOutcomes = outcomes.where((o) => inheritedOutcomeIds.contains(o.id)).toList();

    final child = isSubtopic
        ? _SubtopicWorkspacePage(
            module: module,
            material: material,
            topic: topic,
            parentTopic: parentTopic,
            mappedOutcomes: mappedOutcomes,
            totalOutcomes: outcomes.length,
            canPop: canPop,
            onBack: onBack,
            onRename: onRenameTopic,
            onEditSummary: onEditTopicSummary,
            onEditStatus: onEditTopicStatus,
            onMapOutcomes: onMapTopicOutcomes,
            onDelete: onDeleteTopic,
          )
        : _TopicWorkspacePage(
            module: module,
            material: material,
            topic: topic,
            subtopics: subtopics,
            inheritedOutcomes: inheritedOutcomes,
            totalOutcomes: outcomes.length,
            canPop: canPop,
            onBack: onBack,
            onRename: onRenameTopic,
            onEditSummary: onEditTopicSummary,
            onEditStatus: onEditTopicStatus,
            onAddSubtopic: onAddSubtopic,
            onDelete: onDeleteTopic,
            onOpenSubtopic: onOpenSubtopic,
          );

    return Container(
      color: AppColors.pageBg,
      child: child,
    );
  }
}

class _TopicWorkspacePage extends StatelessWidget {
  final ModuleItem module;
  final MaterialItem material;
  final TopicItem topic;
  final List<TopicItem> subtopics;
  final List<LearningOutcome> inheritedOutcomes;
  final int totalOutcomes;
  final bool canPop;
  final VoidCallback onBack;
  final VoidCallback onRename;
  final VoidCallback onEditSummary;
  final VoidCallback onEditStatus;
  final VoidCallback onAddSubtopic;
  final VoidCallback onDelete;
  final ValueChanged<TopicItem> onOpenSubtopic;

  const _TopicWorkspacePage({
    required this.module,
    required this.material,
    required this.topic,
    required this.subtopics,
    required this.inheritedOutcomes,
    required this.totalOutcomes,
    required this.canPop,
    required this.onBack,
    required this.onRename,
    required this.onEditSummary,
    required this.onEditStatus,
    required this.onAddSubtopic,
    required this.onDelete,
    required this.onOpenSubtopic,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final readySubtopics = subtopics.where((s) => s.readiness == TopicReadiness.ready || s.isReviewed).length;
    final mappedSubtopics = subtopics.where((s) => s.learningOutcomeIds.isNotEmpty || s.linkedOutcomeIds.isNotEmpty || s.linkedOutcomeId != null).length;
    final readiness = _topicPageScore(topic: topic, subtopics: subtopics);
    final description = (topic.description?.trim().isNotEmpty ?? false)
        ? topic.description!.trim()
        : 'No summary yet. Add one concise paragraph that explains the scope of this topic before breaking it into subtopics.';

    return Column(
      children: [
        _LearningItemTopBar(
          canPop: canPop,
          onBack: onBack,
          label: 'Topic',
          materialTitle: material.displayTitle,
          title: topic.title,
          actionLabel: 'Rename',
          onAction: onRename,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 42),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1340),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopicHeroV2(
                      topic: topic,
                      module: module,
                      material: material,
                      readiness: readiness,
                      subtopicCount: subtopics.length,
                      outcomeCount: inheritedOutcomes.length,
                      onRename: onRename,
                      onAddSubtopic: onAddSubtopic,
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 1100;
                        final main = Column(
                          children: [
                            _TopicScopeCardV2(
                              description: description,
                              isEmpty: !(topic.description?.trim().isNotEmpty ?? false),
                              onEditSummary: onEditSummary,
                            ),
                            const SizedBox(height: 16),
                            _TopicArchitectureCardV2(
                              module: module,
                              material: material,
                              topic: topic,
                              subtopicCount: subtopics.length,
                              inheritedOutcomeCount: inheritedOutcomes.length,
                              totalOutcomes: totalOutcomes,
                            ),
                            const SizedBox(height: 16),
                            _TopicSubtopicStudioV2(
                              subtopics: subtopics,
                              onOpenSubtopic: onOpenSubtopic,
                              onAddSubtopic: onAddSubtopic,
                            ),
                          ],
                        );
                        final aside = _TopicOpsPanelV2(
                          readiness: readiness,
                          readySubtopics: readySubtopics,
                          mappedSubtopics: mappedSubtopics,
                          subtopicCount: subtopics.length,
                          inheritedOutcomeCount: inheritedOutcomes.length,
                          onRename: onRename,
                          onEditSummary: onEditSummary,
                          onEditStatus: onEditStatus,
                          onAddSubtopic: onAddSubtopic,
                          onDelete: onDelete,
                        );
                        if (!wide) {
                          return Column(
                            children: [
                              aside,
                              const SizedBox(height: 16),
                              main,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: main),
                            const SizedBox(width: 18),
                            SizedBox(width: 360, child: aside),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubtopicWorkspacePage extends StatelessWidget {
  final ModuleItem module;
  final MaterialItem material;
  final TopicItem topic;
  final TopicItem? parentTopic;
  final List<LearningOutcome> mappedOutcomes;
  final int totalOutcomes;
  final bool canPop;
  final VoidCallback onBack;
  final VoidCallback onRename;
  final VoidCallback onEditSummary;
  final VoidCallback onEditStatus;
  final VoidCallback onMapOutcomes;
  final VoidCallback onDelete;

  const _SubtopicWorkspacePage({
    required this.module,
    required this.material,
    required this.topic,
    required this.parentTopic,
    required this.mappedOutcomes,
    required this.totalOutcomes,
    required this.canPop,
    required this.onBack,
    required this.onRename,
    required this.onEditSummary,
    required this.onEditStatus,
    required this.onMapOutcomes,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final score = _subtopicScore(topic: topic, mappedOutcomeCount: mappedOutcomes.length);
    final description = (topic.description?.trim().isNotEmpty ?? false)
        ? topic.description!.trim()
        : 'No subtopic explanation yet. Add the exact concept, skill, or paragraph range that this subtopic should cover.';
    return Column(
      children: [
        _LearningItemTopBar(
          canPop: canPop,
          onBack: onBack,
          label: 'Subtopic',
          materialTitle: material.displayTitle,
          title: topic.title,
          actionLabel: 'Rename',
          onAction: onRename,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 42),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1260),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SubtopicHeroV2(
                      topic: topic,
                      parentTopicTitle: parentTopic?.title ?? 'Parent topic',
                      mappedOutcomeCount: mappedOutcomes.length,
                      score: score,
                      onRename: onRename,
                      onMapOutcomes: onMapOutcomes,
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 1040;
                        final main = Column(
                          children: [
                            _SubtopicBriefCardV2(
                              description: description,
                              isEmpty: !(topic.description?.trim().isNotEmpty ?? false),
                              onEditSummary: onEditSummary,
                            ),
                            const SizedBox(height: 16),
                            _SubtopicOutcomeCardV2(
                              mappedOutcomes: mappedOutcomes,
                              totalOutcomes: totalOutcomes,
                              onMapOutcomes: onMapOutcomes,
                            ),
                            const SizedBox(height: 16),
                            _SubtopicContextCardV2(
                              module: module,
                              material: material,
                              parentTopic: parentTopic,
                              subtopic: topic,
                            ),
                          ],
                        );
                        final aside = _SubtopicOpsPanelV2(
                          score: score,
                          mappedOutcomeCount: mappedOutcomes.length,
                          onRename: onRename,
                          onEditSummary: onEditSummary,
                          onEditStatus: onEditStatus,
                          onMapOutcomes: onMapOutcomes,
                          onDelete: onDelete,
                        );
                        if (!wide) {
                          return Column(
                            children: [
                              aside,
                              const SizedBox(height: 16),
                              main,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: main),
                            const SizedBox(width: 18),
                            SizedBox(width: 340, child: aside),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

int _topicPageScore({required TopicItem topic, required List<TopicItem> subtopics}) {
  var score = 28;
  if (topic.description?.trim().isNotEmpty ?? false) score += 18;
  if (subtopics.isNotEmpty) score += 24;
  if (subtopics.any((s) => s.learningOutcomeIds.isNotEmpty || s.linkedOutcomeIds.isNotEmpty || s.linkedOutcomeId != null)) score += 18;
  if (subtopics.any((s) => s.readiness == TopicReadiness.ready || s.isReviewed)) score += 12;
  return score.clamp(0, 100).toInt();
}

int _subtopicScore({required TopicItem topic, required int mappedOutcomeCount}) {
  var score = 22;
  if (topic.description?.trim().isNotEmpty ?? false) score += 24;
  if (mappedOutcomeCount > 0) score += 34;
  if (topic.readiness == TopicReadiness.ready || topic.isReviewed) {
    score += 20;
  } else if (topic.readiness == TopicReadiness.review) {
    score += 10;
  }
  return score.clamp(0, 100).toInt();
}

class _LearningItemTopBar extends StatelessWidget {
  final bool canPop;
  final VoidCallback onBack;
  final String label;
  final String materialTitle;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _LearningItemTopBar({
    required this.canPop,
    required this.onBack,
    required this.label,
    required this.materialTitle,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (canPop) ...[
            _SmallSurfaceButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
            const SizedBox(width: 10),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.surfaceBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  materialTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textGray),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textTitle),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _TopicHeroV2 extends StatelessWidget {
  final TopicItem topic;
  final ModuleItem module;
  final MaterialItem material;
  final int readiness;
  final int subtopicCount;
  final int outcomeCount;
  final VoidCallback onRename;
  final VoidCallback onAddSubtopic;

  const _TopicHeroV2({
    required this.topic,
    required this.module,
    required this.material,
    required this.readiness,
    required this.subtopicCount,
    required this.outcomeCount,
    required this.onRename,
    required this.onAddSubtopic,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return _GradientShellV2(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const _WhitePillV2(icon: Icons.auto_stories_outlined, label: 'Parent topic'),
                  _WhitePillV2(icon: Icons.folder_open_outlined, label: module.title),
                  _WhitePillV2(icon: Icons.picture_as_pdf_outlined, label: material.displayTitle),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                topic.title,
                style: TextStyle(fontSize: compact ? 26 : 34, height: 1.08, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.8),
              ),
              const SizedBox(height: 10),
              Text(
                'A topic is the container. It owns subtopics; subtopics carry learning-outcome mapping.',
                style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.78)),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeroActionV2.primary(icon: Icons.account_tree_outlined, label: 'Add subtopic', onTap: onAddSubtopic),
                  _HeroActionV2.secondary(icon: Icons.drive_file_rename_outline_rounded, label: 'Rename topic', onTap: onRename),
                ],
              ),
            ],
          );
          final scoreCard = _HeroScoreCardV2(
            label: 'Topic readiness',
            score: readiness,
            firstLabel: 'Subtopics',
            firstValue: '$subtopicCount',
            secondLabel: 'Inherited outcomes',
            secondValue: '$outcomeCount',
          );
          if (compact) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [titleBlock, const SizedBox(height: 18), scoreCard]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: titleBlock), const SizedBox(width: 28), SizedBox(width: 360, child: scoreCard)]);
        },
      ),
    );
  }
}

class _SubtopicHeroV2 extends StatelessWidget {
  final TopicItem topic;
  final String parentTopicTitle;
  final int mappedOutcomeCount;
  final int score;
  final VoidCallback onRename;
  final VoidCallback onMapOutcomes;

  const _SubtopicHeroV2({
    required this.topic,
    required this.parentTopicTitle,
    required this.mappedOutcomeCount,
    required this.score,
    required this.onRename,
    required this.onMapOutcomes,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return _GradientShellV2(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const _WhitePillV2(icon: Icons.subdirectory_arrow_right_rounded, label: 'Subtopic'),
                  _WhitePillV2(icon: Icons.auto_stories_outlined, label: parentTopicTitle),
                  _WhitePillV2(icon: topic.isAiGenerated ? Icons.auto_awesome_rounded : Icons.edit_note_rounded, label: topic.isAiGenerated ? 'AI sourced' : 'Manual'),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                topic.title,
                style: TextStyle(fontSize: compact ? 26 : 34, height: 1.08, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.8),
              ),
              const SizedBox(height: 10),
              Text(
                'A subtopic is the final learning unit. Map outcomes here and keep the parent topic clean.',
                style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.78)),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeroActionV2.primary(icon: Icons.flag_outlined, label: 'Map outcomes', onTap: onMapOutcomes),
                  _HeroActionV2.secondary(icon: Icons.drive_file_rename_outline_rounded, label: 'Rename subtopic', onTap: onRename),
                ],
              ),
            ],
          );
          final scoreCard = _HeroScoreCardV2(
            label: 'Subtopic readiness',
            score: score,
            firstLabel: 'Mapped outcomes',
            firstValue: '$mappedOutcomeCount',
            secondLabel: 'Level',
            secondValue: 'Final',
          );
          if (compact) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [titleBlock, const SizedBox(height: 18), scoreCard]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: titleBlock), const SizedBox(width: 28), SizedBox(width: 360, child: scoreCard)]);
        },
      ),
    );
  }
}

class _GradientShellV2 extends StatelessWidget {
  final Widget child;
  const _GradientShellV2({required this.child});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F7BEE), Color(0xFF2446D8), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -90,
            top: -90,
            child: Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.10))),
          ),
          Positioned(
            right: 210,
            bottom: -110,
            child: Container(width: 260, height: 260, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06))),
          ),
          Padding(padding: const EdgeInsets.all(26), child: child),
        ],
      ),
    );
  }
}

class _HeroScoreCardV2 extends StatelessWidget {
  final String label;
  final int score;
  final String firstLabel;
  final String firstValue;
  final String secondLabel;
  final String secondValue;

  const _HeroScoreCardV2({required this.label, required this.score, required this.firstLabel, required this.firstValue, required this.secondLabel, required this.secondValue});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white))), Text('$score%', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white))]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: score / 100, minHeight: 8, backgroundColor: Colors.white.withOpacity(0.18), color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: _GlassMetricV2(label: firstLabel, value: firstValue)), const SizedBox(width: 10), Expanded(child: _GlassMetricV2(label: secondLabel, value: secondValue))]),
        ],
      ),
    );
  }
}

class _TopicScopeCardV2 extends StatelessWidget {
  final String description;
  final bool isEmpty;
  final VoidCallback onEditSummary;
  const _TopicScopeCardV2({required this.description, required this.isEmpty, required this.onEditSummary});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return _StudioPanelV2(
      icon: Icons.subject_rounded,
      title: 'Topic scope',
      subtitle: 'One short definition of what this parent topic covers.',
      trailing: _InlineTextActionV2(icon: Icons.edit_outlined, label: 'Edit summary', onTap: onEditSummary),
      child: Text(
        description,
        style: TextStyle(fontSize: 15, height: 1.65, fontWeight: isEmpty ? FontWeight.w600 : FontWeight.w700, color: isEmpty ? AppColors.textMuted : AppColors.textGray),
      ),
    );
  }
}

class _TopicArchitectureCardV2 extends StatelessWidget {
  final ModuleItem module;
  final MaterialItem material;
  final TopicItem topic;
  final int subtopicCount;
  final int inheritedOutcomeCount;
  final int totalOutcomes;

  const _TopicArchitectureCardV2({required this.module, required this.material, required this.topic, required this.subtopicCount, required this.inheritedOutcomeCount, required this.totalOutcomes});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return _StudioPanelV2(
      icon: Icons.hub_outlined,
      title: 'Content architecture',
      subtitle: 'The only valid depth is Module → Material → Topic → Subtopics.',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 720;
              final nodes = [
                _FlowNodeV2(icon: Icons.folder_outlined, label: 'Module', value: module.title),
                _FlowNodeV2(icon: Icons.picture_as_pdf_outlined, label: 'Material', value: material.displayTitle),
                _FlowNodeV2(icon: Icons.auto_stories_outlined, label: 'Topic', value: topic.title, active: true),
                _FlowNodeV2(icon: Icons.subdirectory_arrow_right_rounded, label: 'Subtopics', value: '$subtopicCount items'),
              ];
              if (stack) return Column(children: [for (var i = 0; i < nodes.length; i++) ...[nodes[i], if (i != nodes.length - 1) const SizedBox(height: 10)]]);
              return Row(children: [for (var i = 0; i < nodes.length; i++) ...[Expanded(child: nodes[i]), if (i != nodes.length - 1) Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textHint))]]);
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.badgeBlueBorder)),
            child: Row(
              children: [
                const _MiniIconV2(icon: Icons.flag_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(child: Text('Parent topics do not own outcome mapping. This topic inherits coverage from mapped subtopics.', style: TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w800, color: AppColors.badgeBlueFg))),
                Text('$inheritedOutcomeCount/$totalOutcomes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicSubtopicStudioV2 extends StatelessWidget {
  final List<TopicItem> subtopics;
  final ValueChanged<TopicItem> onOpenSubtopic;
  final VoidCallback onAddSubtopic;

  const _TopicSubtopicStudioV2({required this.subtopics, required this.onOpenSubtopic, required this.onAddSubtopic});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return _StudioPanelV2(
      icon: Icons.account_tree_outlined,
      title: 'Subtopic studio',
      subtitle: 'Break the topic into final learning units. Outcome mapping lives there.',
      trailing: _InlineTextActionV2(icon: Icons.add_rounded, label: 'Add subtopic', onTap: onAddSubtopic),
      child: subtopics.isEmpty
          ? _EmptySubtopicCanvasV2(onAddSubtopic: onAddSubtopic)
          : Column(
              children: [
                for (var i = 0; i < subtopics.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == subtopics.length - 1 ? 0 : 10),
                    child: _SubtopicPreviewTileV2(
                      index: i + 1,
                      subtopic: subtopics[i],
                      onTap: () => onOpenSubtopic(subtopics[i]),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _TopicOpsPanelV2 extends StatelessWidget {
  final int readiness;
  final int readySubtopics;
  final int mappedSubtopics;
  final int subtopicCount;
  final int inheritedOutcomeCount;
  final VoidCallback onRename;
  final VoidCallback onEditSummary;
  final VoidCallback onEditStatus;
  final VoidCallback onAddSubtopic;
  final VoidCallback onDelete;

  const _TopicOpsPanelV2({
    required this.readiness,
    required this.readySubtopics,
    required this.mappedSubtopics,
    required this.subtopicCount,
    required this.inheritedOutcomeCount,
    required this.onRename,
    required this.onEditSummary,
    required this.onEditStatus,
    required this.onAddSubtopic,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      children: [
        _StudioPanelV2(
          icon: Icons.bolt_outlined,
          title: 'Topic actions',
          subtitle: 'Every button opens its own focused popup.',
          compact: true,
          child: Column(
            children: [
              _ActionTileV2(icon: Icons.drive_file_rename_outline_rounded, title: 'Rename topic', subtitle: 'Change title only.', onTap: onRename, primary: true),
              _ActionTileV2(icon: Icons.subject_rounded, title: 'Edit summary', subtitle: 'Scope and instructor notes.', onTap: onEditSummary),
              _ActionTileV2(icon: Icons.speed_rounded, title: 'Delivery state', subtitle: 'Difficulty and readiness.', onTap: onEditStatus),
              _ActionTileV2(icon: Icons.account_tree_outlined, title: 'Add subtopic', subtitle: 'Create final learning units.', onTap: onAddSubtopic),
              _ActionTileV2(icon: Icons.delete_outline_rounded, title: 'Delete topic', subtitle: 'Remove this topic branch.', onTap: onDelete, danger: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _StudioPanelV2(
          icon: Icons.analytics_outlined,
          title: 'Topic signal',
          subtitle: 'Health of this parent node.',
          compact: true,
          child: Column(
            children: [
              _SignalRowV2(label: 'Readiness', value: '$readiness%'),
              _SignalRowV2(label: 'Subtopics ready', value: '$readySubtopics/$subtopicCount'),
              _SignalRowV2(label: 'Mapped subtopics', value: '$mappedSubtopics/$subtopicCount'),
              _SignalRowV2(label: 'Inherited outcomes', value: '$inheritedOutcomeCount'),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubtopicBriefCardV2 extends StatelessWidget {
  final String description;
  final bool isEmpty;
  final VoidCallback onEditSummary;
  const _SubtopicBriefCardV2({required this.description, required this.isEmpty, required this.onEditSummary});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return _StudioPanelV2(
      icon: Icons.notes_rounded,
      title: 'Subtopic brief',
      subtitle: 'The final teaching unit students are assessed against.',
      trailing: _InlineTextActionV2(icon: Icons.edit_outlined, label: 'Edit summary', onTap: onEditSummary),
      child: Text(description, style: TextStyle(fontSize: 15, height: 1.65, fontWeight: isEmpty ? FontWeight.w600 : FontWeight.w700, color: isEmpty ? AppColors.textMuted : AppColors.textGray)),
    );
  }
}

class _SubtopicOutcomeCardV2 extends StatelessWidget {
  final List<LearningOutcome> mappedOutcomes;
  final int totalOutcomes;
  final VoidCallback onMapOutcomes;
  const _SubtopicOutcomeCardV2({required this.mappedOutcomes, required this.totalOutcomes, required this.onMapOutcomes});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return _StudioPanelV2(
      icon: Icons.flag_outlined,
      title: 'Learning-outcome mapping',
      subtitle: 'This is the correct place for LO coverage.',
      trailing: _InlineTextActionV2(icon: Icons.edit_road_outlined, label: 'Map outcomes', onTap: onMapOutcomes),
      child: mappedOutcomes.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.surfaceBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  _MiniIconV2(icon: Icons.flag_circle_outlined, color: AppColors.warningText, bg: AppColors.warningSoftBg),
                  const SizedBox(width: 12),
                  Expanded(child: Text('No outcomes mapped yet. Link this subtopic to the exact course outcomes it teaches.', style: TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w800, color: AppColors.textGray))),
                ],
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < mappedOutcomes.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == mappedOutcomes.length - 1 ? 0 : 10),
                    child: _OutcomeTileV2(outcome: mappedOutcomes[i]),
                  ),
                const SizedBox(height: 12),
                _SignalRowV2(label: 'Course outcome coverage', value: '${mappedOutcomes.length}/$totalOutcomes'),
              ],
            ),
    );
  }
}

class _SubtopicContextCardV2 extends StatelessWidget {
  final ModuleItem module;
  final MaterialItem material;
  final TopicItem? parentTopic;
  final TopicItem subtopic;
  const _SubtopicContextCardV2({required this.module, required this.material, required this.parentTopic, required this.subtopic});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return _StudioPanelV2(
      icon: Icons.route_outlined,
      title: 'Placement',
      subtitle: 'A subtopic cannot contain another level.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 760;
          final nodes = [
            _FlowNodeV2(icon: Icons.folder_outlined, label: 'Module', value: module.title),
            _FlowNodeV2(icon: Icons.picture_as_pdf_outlined, label: 'Material', value: material.displayTitle),
            _FlowNodeV2(icon: Icons.auto_stories_outlined, label: 'Topic', value: parentTopic?.title ?? 'Parent topic'),
            _FlowNodeV2(icon: Icons.subdirectory_arrow_right_rounded, label: 'Subtopic', value: subtopic.title, active: true),
          ];
          if (stack) return Column(children: [for (var i = 0; i < nodes.length; i++) ...[nodes[i], if (i != nodes.length - 1) const SizedBox(height: 10)]]);
          return Row(children: [for (var i = 0; i < nodes.length; i++) ...[Expanded(child: nodes[i]), if (i != nodes.length - 1) Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textHint))]]);
        },
      ),
    );
  }
}

class _SubtopicOpsPanelV2 extends StatelessWidget {
  final int score;
  final int mappedOutcomeCount;
  final VoidCallback onRename;
  final VoidCallback onEditSummary;
  final VoidCallback onEditStatus;
  final VoidCallback onMapOutcomes;
  final VoidCallback onDelete;

  const _SubtopicOpsPanelV2({required this.score, required this.mappedOutcomeCount, required this.onRename, required this.onEditSummary, required this.onEditStatus, required this.onMapOutcomes, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      children: [
        _StudioPanelV2(
          icon: Icons.tune_rounded,
          title: 'Subtopic actions',
          subtitle: 'Separate tools for this final-level item.',
          compact: true,
          child: Column(
            children: [
              _ActionTileV2(icon: Icons.drive_file_rename_outline_rounded, title: 'Rename subtopic', subtitle: 'Change title only.', onTap: onRename, primary: true),
              _ActionTileV2(icon: Icons.subject_rounded, title: 'Edit summary', subtitle: 'Explain exact scope.', onTap: onEditSummary),
              _ActionTileV2(icon: Icons.flag_outlined, title: 'Map outcomes', subtitle: 'Attach course LOs here.', onTap: onMapOutcomes),
              _ActionTileV2(icon: Icons.speed_rounded, title: 'Delivery state', subtitle: 'Difficulty and readiness.', onTap: onEditStatus),
              _ActionTileV2(icon: Icons.delete_outline_rounded, title: 'Delete subtopic', subtitle: 'Remove this leaf item.', onTap: onDelete, danger: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _StudioPanelV2(
          icon: Icons.insights_outlined,
          title: 'Subtopic signal',
          subtitle: 'Readiness for assessment use.',
          compact: true,
          child: Column(
            children: [
              _SignalRowV2(label: 'Readiness', value: '$score%'),
              _SignalRowV2(label: 'Mapped outcomes', value: '$mappedOutcomeCount'),
              const _SignalRowV2(label: 'Depth', value: 'Final level'),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudioPanelV2 extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  final bool compact;

  const _StudioPanelV2({required this.icon, required this.title, required this.subtitle, required this.child, this.trailing, this.compact = false});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 16 : 20, compact ? 16 : 18, compact ? 16 : 20, compact ? 12 : 16),
            child: Row(
              children: [
                _MiniIconV2(icon: icon, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: compact ? 16 : 18, fontWeight: FontWeight.w900, color: AppColors.textTitle, letterSpacing: -0.2)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.divider),
          Padding(padding: EdgeInsets.all(compact ? 14 : 18), child: child),
        ],
      ),
    );
  }
}

class _ActionTileV2 extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;

  const _ActionTileV2({required this.icon, required this.title, required this.subtitle, required this.onTap, this.primary = false, this.danger = false});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final bg = primary
        ? AppColors.primary
        : danger
            ? AppColors.dangerBg
            : AppColors.surfaceBg;
    final fg = primary
        ? Colors.white
        : danger
            ? AppColors.dangerText
            : AppColors.textTitle;
    final sub = primary ? Colors.white.withOpacity(0.78) : AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: primary ? Colors.white.withOpacity(0.14) : AppColors.cardBg.withOpacity(0.75), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, size: 18, color: fg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: fg)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: TextStyle(fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w600, color: sub)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, size: 17, color: primary ? Colors.white : (danger ? AppColors.dangerText : AppColors.textHint)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubtopicPreviewTileV2 extends StatelessWidget {
  final int index;
  final TopicItem subtopic;
  final VoidCallback onTap;
  const _SubtopicPreviewTileV2({required this.index, required this.subtopic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final mappedCount = subtopic.learningOutcomeIds.isNotEmpty ? subtopic.learningOutcomeIds.length : subtopic.linkedOutcomeIds.length;
    final hasSummary = subtopic.description?.trim().isNotEmpty ?? false;
    return Material(
      color: AppColors.surfaceBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(15)),
                alignment: Alignment.center,
                child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subtopic.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: AppColors.textTitle)),
                    const SizedBox(height: 4),
                    Text(hasSummary ? subtopic.description!.trim() : 'No summary yet', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _TinyBadgeV2(label: '$mappedCount LO'),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySubtopicCanvasV2 extends StatelessWidget {
  final VoidCallback onAddSubtopic;
  const _EmptySubtopicCanvasV2({required this.onAddSubtopic});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surfaceBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          const _MiniIconV2(icon: Icons.account_tree_outlined, color: AppColors.primary),
          const SizedBox(height: 12),
          Text('No subtopics yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textTitle)),
          const SizedBox(height: 6),
          Text('Create subtopics before mapping learning outcomes. This keeps the topic as a clean parent container.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          _HeroActionV2.primary(icon: Icons.add_rounded, label: 'Create first subtopic', onTap: onAddSubtopic),
        ],
      ),
    );
  }
}

class _OutcomeTileV2 extends StatelessWidget {
  final LearningOutcome outcome;
  const _OutcomeTileV2({required this.outcome});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          const _MiniIconV2(icon: Icons.flag_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text('${outcome.code} • ${outcome.title}', style: TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w800, color: AppColors.textTitle))),
        ],
      ),
    );
  }
}

class _FlowNodeV2 extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool active;
  const _FlowNodeV2({required this.icon, required this.label, required this.value, this.active = false});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: active ? AppColors.primarySoft : AppColors.surfaceBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: active ? AppColors.badgeBlueBorder : AppColors.border)),
      child: Row(
        children: [
          _MiniIconV2(icon: icon, color: active ? AppColors.primary : AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppColors.textTitle)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhitePillV2 extends StatelessWidget {
  final IconData icon;
  final String label;
  const _WhitePillV2({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withOpacity(0.18))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _HeroActionV2 extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _HeroActionV2._({required this.icon, required this.label, required this.onTap, required this.filled});
  const _HeroActionV2.primary({required IconData icon, required String label, required VoidCallback onTap}) : this._(icon: icon, label: label, onTap: onTap, filled: true);
  const _HeroActionV2.secondary({required IconData icon, required String label, required VoidCallback onTap}) : this._(icon: icon, label: label, onTap: onTap, filled: false);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.white : Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: filled ? AppColors.primary : Colors.white),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: filled ? AppColors.primary : Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassMetricV2 extends StatelessWidget {
  final String label;
  final String value;
  const _GlassMetricV2({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.12))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.70))), const SizedBox(height: 5), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))]),
    );
  }
}

class _MiniIconV2 extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? bg;
  const _MiniIconV2({required this.icon, required this.color, this.bg});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg ?? AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _SmallSurfaceButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallSurfaceButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Material(
      color: AppColors.surfaceBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 16, color: AppColors.textGray)),
      ),
    );
  }
}

class _InlineTextActionV2 extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _InlineTextActionV2({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return TextButton.icon(onPressed: onTap, icon: Icon(icon, size: 15), label: Text(label), style: TextButton.styleFrom(foregroundColor: AppColors.primary));
  }
}

class _SignalRowV2 extends StatelessWidget {
  final String label;
  final String value;
  const _SignalRowV2({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(color: AppColors.surfaceBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textMuted))), Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textTitle))]),
    );
  }
}

class _TinyBadgeV2 extends StatelessWidget {
  final String label;
  const _TinyBadgeV2({required this.label});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary)),
    );
  }
}

int _topicCoverageScore({
  required TopicItem topic,
  required List<LearningOutcome> mappedOutcomes,
  required List<TopicItem> subtopics,
  required bool isSubtopic,
}) {
  var score = 20;
  if (topic.description?.trim().isNotEmpty ?? false) score += 18;
  if (topic.instructorNotes?.trim().isNotEmpty ?? false) score += 18;
  if (mappedOutcomes.isNotEmpty) score += 22;
  if (topic.readiness == TopicReadiness.ready) {
    score += 18;
  } else if (topic.readiness == TopicReadiness.review) {
    score += 10;
  }
  if (!isSubtopic && subtopics.isNotEmpty) score += 4;
  return score.clamp(0, 100).toInt();
}

class _TopicStudioTopBar extends StatelessWidget {
  final String materialTitle;
  final String topicTitle;
  final bool canPop;
  final VoidCallback onBack;
  final VoidCallback onEditTopic;

  const _TopicStudioTopBar({
    required this.materialTitle,
    required this.topicTitle,
    required this.canPop,
    required this.onBack,
    required this.onEditTopic,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(bottom: BorderSide(color: AppColors.borderGray)),
      ),
      child: Row(
        children: [
          if (canPop) ...[
            _TopicIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Back to PDF',
              onTap: onBack,
            ),
            const SizedBox(width: 10),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.headerBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Text(
                    materialTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              topicTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textTitle),
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: onEditTopic,
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Rename'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicStudioHero extends StatelessWidget {
  final ModuleItem module;
  final MaterialItem material;
  final TopicItem topic;
  final _TopicMeta readinessMeta;
  final _TopicMeta difficultyMeta;
  final bool isSubtopic;
  final String? parentTopicTitle;
  final int mappedOutcomesCount;
  final int subtopicCount;
  final int coverageScore;
  final VoidCallback onRenameTopic;
  final VoidCallback onEditTopicSummary;
  final VoidCallback onAddSubtopic;

  const _TopicStudioHero({
    required this.module,
    required this.material,
    required this.topic,
    required this.readinessMeta,
    required this.difficultyMeta,
    required this.isSubtopic,
    this.parentTopicTitle,
    required this.mappedOutcomesCount,
    required this.subtopicCount,
    required this.coverageScore,
    required this.onRenameTopic,
    required this.onEditTopicSummary,
    required this.onAddSubtopic,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final created = '${topic.createdAt.day}/${topic.createdAt.month}/${topic.createdAt.year}';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.isDark
              ? [const Color(0xFF08111F), const Color(0xFF0B2C73), AppColors.primary]
              : [AppColors.primary, AppColors.infoText, AppColors.purpleText],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          const BoxShadow(color: Color(0x24137FEC), blurRadius: 34, offset: Offset(0, 18)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -80,
            top: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.09),
              ),
            ),
          ),
          Positioned(
            right: 160,
            bottom: -90,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.purpleText.withOpacity(0.24),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 900;
                final left = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: [
                        _TopicGlassChip(
                          icon: isSubtopic ? Icons.subdirectory_arrow_right_rounded : Icons.auto_stories_rounded,
                          label: isSubtopic ? 'Subtopic page' : 'Topic page',
                        ),
                        _TopicGlassChip(icon: readinessMeta.icon, label: readinessMeta.label),
                        _TopicGlassChip(icon: difficultyMeta.icon, label: difficultyMeta.label),
                        _TopicGlassChip(
                          icon: topic.source == TopicSource.ai ? Icons.auto_awesome_rounded : Icons.edit_note_rounded,
                          label: topic.source == TopicSource.ai ? 'AI-assisted' : 'Manual',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      topic.title,
                      style: const TextStyle(
                        fontSize: 30,
                        height: 1.13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 9,
                      children: [
                        _TopicHeroPathItem(icon: Icons.folder_open_outlined, label: module.title),
                        _TopicHeroPathItem(icon: Icons.picture_as_pdf_outlined, label: material.displayTitle),
                        if (isSubtopic && parentTopicTitle != null)
                          _TopicHeroPathItem(icon: Icons.account_tree_outlined, label: parentTopicTitle!),
                        _TopicHeroPathItem(icon: Icons.calendar_today_outlined, label: 'Created $created'),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _TopicHeroButton.primary(
                          icon: Icons.edit_rounded,
                          label: isSubtopic ? 'Rename subtopic' : 'Rename topic',
                          onTap: onRenameTopic,
                        ),
                        _TopicHeroButton.secondary(
                          icon: Icons.notes_rounded,
                          label: 'Edit summary',
                          onTap: onEditTopicSummary,
                        ),
                        if (!isSubtopic)
                          _TopicHeroButton.secondary(
                            icon: Icons.account_tree_outlined,
                            label: 'Add subtopic',
                            onTap: onAddSubtopic,
                          ),
                      ],
                    ),
                  ],
                );

                final metrics = _TopicHeroMetrics(
                  coverageScore: coverageScore,
                  mappedOutcomesCount: mappedOutcomesCount,
                  subtopicCount: subtopicCount,
                  isSubtopic: isSubtopic,
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      left,
                      const SizedBox(height: 18),
                      metrics,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 26),
                    SizedBox(width: 350, child: metrics),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicHeroMetrics extends StatelessWidget {
  final int coverageScore;
  final int mappedOutcomesCount;
  final int subtopicCount;
  final bool isSubtopic;

  const _TopicHeroMetrics({
    required this.coverageScore,
    required this.mappedOutcomesCount,
    required this.subtopicCount,
    required this.isSubtopic,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBg.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Readiness score',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              Text(
                '$coverageScore%',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TopicProgressTrack(value: coverageScore / 100, bright: true),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _TopicGlassMetric(label: 'Outcomes', value: mappedOutcomesCount == 0 ? '0' : '$mappedOutcomesCount')),
              const SizedBox(width: 10),
              Expanded(child: _TopicGlassMetric(label: isSubtopic ? 'Level' : 'Subtopics', value: isSubtopic ? 'Leaf' : '$subtopicCount')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopicBriefBoard extends StatelessWidget {
  final TopicItem topic;
  final _TopicMeta readinessMeta;
  final _TopicMeta difficultyMeta;
  final int mappedOutcomesCount;
  final int subtopicCount;
  final bool isSubtopic;
  final String? parentTopicTitle;

  const _TopicBriefBoard({
    required this.topic,
    required this.readinessMeta,
    required this.difficultyMeta,
    required this.mappedOutcomesCount,
    required this.subtopicCount,
    required this.isSubtopic,
    this.parentTopicTitle,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final summary = (topic.description?.trim().isNotEmpty ?? false)
        ? topic.description!.trim()
        : 'No topic brief yet. Add a concise teaching scope so the instructor, instructors and reviewers know what this topic should cover.';
    return _TopicStudioCard(
      title: 'Teaching blueprint',
      subtitle: 'A clean snapshot of how this topic should be delivered and assessed.',
      icon: Icons.dashboard_customize_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary,
            style: TextStyle(
              fontSize: 14,
              height: 1.65,
              color: (topic.description?.trim().isNotEmpty ?? false) ? AppColors.textGray : AppColors.textMuted,
              fontWeight: (topic.description?.trim().isNotEmpty ?? false) ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 720;
              final tiles = [
                _TopicSummaryTile(
                  label: 'Delivery state',
                  value: readinessMeta.label,
                  helper: topic.readiness == TopicReadiness.ready
                      ? 'Ready for live delivery'
                      : topic.readiness == TopicReadiness.review
                          ? 'Needs final review pass'
                          : 'Still in preparation',
                  icon: readinessMeta.icon,
                  accent: readinessMeta.fg,
                  soft: readinessMeta.bg,
                ),
                _TopicSummaryTile(
                  label: 'Difficulty',
                  value: difficultyMeta.label,
                  helper: topic.difficulty == TopicDifficulty.beginner
                      ? 'Suitable for first exposure'
                      : topic.difficulty == TopicDifficulty.intermediate
                          ? 'Requires guided practice'
                          : 'Needs deeper scaffolding',
                  icon: difficultyMeta.icon,
                  accent: difficultyMeta.fg,
                  soft: difficultyMeta.bg,
                ),
                _TopicSummaryTile(
                  label: isSubtopic ? 'Parent topic' : 'Structure',
                  value: isSubtopic ? (parentTopicTitle ?? 'Parent topic') : '$subtopicCount subtopic${subtopicCount == 1 ? '' : 's'}',
                  helper: isSubtopic ? 'Nested teaching unit' : 'Breakdown inside this PDF',
                  icon: isSubtopic ? Icons.account_tree_outlined : Icons.schema_outlined,
                  accent: AppColors.primary,
                  soft: AppColors.primarySoft,
                ),
                _TopicSummaryTile(
                  label: 'Outcome map',
                  value: mappedOutcomesCount == 0 ? 'Unmapped' : '$mappedOutcomesCount linked',
                  helper: mappedOutcomesCount == 0 ? 'Needs alignment' : 'Connected to course goals',
                  icon: Icons.flag_outlined,
                  accent: _K.blue,
                  soft: _K.blueSoft,
                ),
              ];

              if (!wide) {
                return Column(
                  children: tiles
                      .map((tile) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: tile,
                          ),)
                      .toList(),
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: tiles
                    .map(
                      (tile) => SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: tile,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TopicStructureBoard extends StatelessWidget {
  final ModuleItem module;
  final MaterialItem material;
  final TopicItem topic;
  final List<TopicItem> subtopics;
  final bool isSubtopic;
  final String? parentTopicTitle;

  const _TopicStructureBoard({
    required this.module,
    required this.material,
    required this.topic,
    required this.subtopics,
    required this.isSubtopic,
    this.parentTopicTitle,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return _TopicStudioCard(
      title: isSubtopic ? 'Subtopic position' : 'Topic structure',
      subtitle: isSubtopic
          ? 'This item is the final level under a topic.'
          : 'This topic belongs to one material and can contain only subtopics.',
      icon: Icons.account_tree_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopicPathStrip(
            items: [
              _TopicPathNode(icon: Icons.folder_rounded, label: 'Module', value: module.title),
              _TopicPathNode(icon: Icons.picture_as_pdf_rounded, label: 'Material', value: material.displayTitle),
              if (isSubtopic)
                _TopicPathNode(icon: Icons.auto_stories_rounded, label: 'Parent topic', value: parentTopicTitle ?? 'Parent topic'),
              _TopicPathNode(
                icon: isSubtopic ? Icons.subdirectory_arrow_right_rounded : Icons.auto_stories_rounded,
                label: isSubtopic ? 'Subtopic' : 'Topic',
                value: topic.title,
              ),
            ],
          ),
          if (!isSubtopic) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  _TopicSoftIcon(icon: Icons.schema_outlined, color: AppColors.primary, bg: AppColors.primarySoft),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subtopics.isEmpty ? 'Ready for subtopics' : '${subtopics.length} subtopic${subtopics.length == 1 ? '' : 's'} attached',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: AppColors.textTitle),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtopics.isEmpty
                              ? 'Add subtopics when this topic needs smaller final learning points.'
                              : 'Learning-outcome coverage should be controlled from the subtopic level.',
                          style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopicFocusBoard extends StatelessWidget {
  final TopicItem topic;
  final _TopicMeta readinessMeta;
  final _TopicMeta difficultyMeta;
  final List<LearningOutcome> mappedOutcomes;
  final List<TopicItem> subtopics;
  final bool isSubtopic;
  final VoidCallback onEditSummary;
  final VoidCallback onMapOutcomes;

  const _TopicFocusBoard({
    required this.topic,
    required this.readinessMeta,
    required this.difficultyMeta,
    required this.mappedOutcomes,
    required this.subtopics,
    required this.isSubtopic,
    required this.onEditSummary,
    required this.onMapOutcomes,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final summary = topic.description?.trim();
    final notes = topic.instructorNotes?.trim();
    final hasSummary = summary != null && summary.isNotEmpty;
    final hasNotes = notes != null && notes.isNotEmpty;
    final hasChildren = subtopics.isNotEmpty;

    return _TopicStudioCard(
      title: isSubtopic ? 'Learning point' : 'Topic brief',
      subtitle: isSubtopic
          ? 'Subtopic details are handled separately from the parent topic page.'
          : 'One compact place for scope, state, and outcome-routing logic.',
      icon: Icons.view_quilt_outlined,
      action: TextButton.icon(
        onPressed: onEditSummary,
        icon: const Icon(Icons.edit_rounded, size: 16),
        label: const Text('Edit summary'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final tiles = [
                _TopicSummaryTile(
                  label: 'Delivery state',
                  value: readinessMeta.label,
                  helper: topic.readiness == TopicReadiness.ready
                      ? 'Ready for delivery'
                      : topic.readiness == TopicReadiness.review
                          ? 'Needs review'
                          : 'Still drafting',
                  icon: readinessMeta.icon,
                  accent: readinessMeta.fg,
                  soft: readinessMeta.bg,
                ),
                _TopicSummaryTile(
                  label: 'Difficulty',
                  value: difficultyMeta.label,
                  helper: topic.difficulty == TopicDifficulty.beginner
                      ? 'First exposure'
                      : topic.difficulty == TopicDifficulty.intermediate
                          ? 'Guided practice'
                          : 'Advanced depth',
                  icon: difficultyMeta.icon,
                  accent: difficultyMeta.fg,
                  soft: difficultyMeta.bg,
                ),
                _TopicSummaryTile(
                  label: isSubtopic ? 'Mapped outcomes' : 'Outcome rule',
                  value: isSubtopic
                      ? '${mappedOutcomes.length}'
                      : (hasChildren ? 'From subtopics' : '${mappedOutcomes.length} direct'),
                  helper: isSubtopic
                      ? 'Final-level mapping'
                      : (hasChildren ? 'Parent topic does not need direct LO links' : 'Can be mapped directly until subtopics exist'),
                  icon: Icons.flag_outlined,
                  accent: AppColors.primary,
                  soft: AppColors.primarySoft,
                ),
                _TopicSummaryTile(
                  label: isSubtopic ? 'Level' : 'Subtopics',
                  value: isSubtopic ? 'Leaf' : '${subtopics.length}',
                  helper: isSubtopic ? 'No children below this level' : 'Only one nested level is allowed',
                  icon: Icons.schema_outlined,
                  accent: AppColors.successText,
                  soft: AppColors.successBg,
                ),
              ];
              if (!wide) {
                return Column(
                  children: [
                    for (final tile in tiles) ...[
                      tile,
                      if (tile != tiles.last) const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final tile in tiles)
                    SizedBox(width: (constraints.maxWidth - 12) / 2, child: tile),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scope', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                Text(
                  hasSummary ? summary : 'No summary yet. Add a short scope so this topic is easy to teach and review.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: hasSummary ? AppColors.textGray : AppColors.textMuted,
                    fontWeight: hasSummary ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Text('Instructor notes', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                Text(
                  hasNotes ? notes : 'No notes yet.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.55,
                    color: hasNotes ? AppColors.textGray : AppColors.textMuted,
                    fontWeight: hasNotes ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!isSubtopic) ...[
            const SizedBox(height: 14),
            Material(
              color: hasChildren ? AppColors.warningSoftBg : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: onMapOutcomes,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: hasChildren ? AppColors.warningBorder : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(hasChildren ? Icons.info_outline_rounded : Icons.flag_outlined, size: 18, color: hasChildren ? AppColors.warningText : AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hasChildren
                              ? 'This topic has subtopics. Map learning outcomes on the subtopics instead of the parent.'
                              : 'No subtopics yet. This topic can be mapped directly to learning outcomes.',
                          style: TextStyle(fontSize: 12.5, height: 1.45, color: hasChildren ? AppColors.warningText : AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopicPathNode {
  final IconData icon;
  final String label;
  final String value;
  const _TopicPathNode({required this.icon, required this.label, required this.value});
}

class _TopicPathStrip extends StatelessWidget {
  final List<_TopicPathNode> items;
  const _TopicPathStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        if (compact) {
          return Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _TopicPathCard(node: items[i], active: i == items.length - 1),
                if (i != items.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Expanded(child: _TopicPathCard(node: items[i], active: i == items.length - 1)),
              if (i != items.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _TopicPathCard extends StatelessWidget {
  final _TopicPathNode node;
  final bool active;
  const _TopicPathCard({required this.node, required this.active});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? AppColors.primarySoft : AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? AppColors.primary.withOpacity(0.25) : AppColors.border),
      ),
      child: Row(
        children: [
          _TopicSoftIcon(icon: node.icon, color: active ? AppColors.primary : AppColors.textMuted, bg: active ? AppColors.cardBg : AppColors.headerBg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(node.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Text(node.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.textTitle)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicLevelDiagram extends StatelessWidget {
  final bool isSubtopic;
  const _TopicLevelDiagram({required this.isSubtopic});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final levels = [
      ('Module', Icons.folder_rounded, false),
      ('Material', Icons.picture_as_pdf_rounded, false),
      ('Topic', Icons.auto_stories_rounded, !isSubtopic),
      ('Subtopic', Icons.subdirectory_arrow_right_rounded, isSubtopic),
    ];
    return Column(
      children: [
        for (var i = 0; i < levels.length; i++) ...[
          _TopicLevelRow(label: levels[i].$1, icon: levels[i].$2, active: levels[i].$3),
          if (i != levels.length - 1)
            Container(width: 2, height: 16, color: AppColors.border),
        ],
      ],
    );
  }
}

class _TopicLevelRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  const _TopicLevelRow({required this.label, required this.icon, required this.active});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active ? AppColors.primarySoft : AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? AppColors.primary.withOpacity(0.25) : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: active ? AppColors.primary : AppColors.textMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: active ? AppColors.primary : AppColors.textMuted)),
          ),
          if (active)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
              child: const Text('current', style: TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w900)),
            ),
        ],
      ),
    );
  }
}

class _TopicOutcomeBoard extends StatelessWidget {
  final List<LearningOutcome> outcomes;
  final VoidCallback onEditTopic;

  const _TopicOutcomeBoard({required this.outcomes, required this.onEditTopic});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return _TopicStudioCard(
      title: 'Outcome alignment',
      subtitle: outcomes.isEmpty
          ? 'This topic is not linked to learning outcomes yet.'
          : 'These outcomes are used as the assessment target for this topic.',
      icon: Icons.flag_outlined,
      action: TextButton.icon(
        onPressed: onEditTopic,
        icon: const Icon(Icons.add_link_rounded, size: 16),
        label: Text(outcomes.isEmpty ? 'Map outcomes' : 'Update map'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      child: outcomes.isEmpty
          ? const _TopicEmptyPanel(
              icon: Icons.flag_outlined,
              title: 'No mapped outcomes',
              message: 'Open the edit popup and connect this topic to the outcomes it supports before generating graded questions.',
            )
          : Column(
              children: [
                for (var i = 0; i < outcomes.length; i++) ...[
                  _OutcomeTilePro(outcome: outcomes[i], index: i),
                  if (i != outcomes.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _TopicNotesBoard extends StatelessWidget {
  final TopicItem topic;
  final VoidCallback onEditTopic;

  const _TopicNotesBoard({required this.topic, required this.onEditTopic});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final notes = topic.instructorNotes?.trim();
    final hasNotes = notes != null && notes.isNotEmpty;
    return _TopicStudioCard(
      title: 'Instructor guidance',
      subtitle: 'Keep delivery cues, examples, warnings, and pacing notes close to the topic.',
      icon: Icons.sticky_note_2_outlined,
      action: TextButton.icon(
        onPressed: onEditTopic,
        icon: Icon(hasNotes ? Icons.edit_rounded : Icons.add_rounded, size: 16),
        label: Text(hasNotes ? 'Edit notes' : 'Add notes'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasNotes ? AppColors.surfaceBg : AppColors.warningSoftBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: hasNotes ? AppColors.border : AppColors.warningBorder),
        ),
        child: Text(
          hasNotes
              ? notes
              : 'No instructor notes yet. Add examples, common mistakes, pacing hints, or how this topic should be explained in class.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.65,
            color: hasNotes ? AppColors.textGray : AppColors.warningText,
            fontWeight: hasNotes ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TopicSubtopicBoard extends StatelessWidget {
  final TopicItem topic;
  final List<TopicItem> subtopics;
  final VoidCallback onAddSubtopic;
  final ValueChanged<TopicItem> onOpenSubtopic;

  const _TopicSubtopicBoard({
    required this.topic,
    required this.subtopics,
    required this.onAddSubtopic,
    required this.onOpenSubtopic,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return _TopicStudioCard(
      title: 'Subtopic map',
      subtitle: 'Break a broad topic into smaller teachable anchors.',
      icon: Icons.account_tree_outlined,
      action: FilledButton.icon(
        onPressed: onAddSubtopic,
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Add subtopic'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      child: subtopics.isEmpty
          ? _TopicEmptyPanel(
              icon: Icons.account_tree_outlined,
              title: 'No subtopics yet',
              message: 'Create smaller teaching units under "${topic.title}" when the section becomes too broad for one assessment anchor.',
            )
          : Column(
              children: [
                for (var i = 0; i < subtopics.length; i++) ...[
                  _SubtopicTilePro(
                    subtopic: subtopics[i],
                    index: i,
                    onTap: () => onOpenSubtopic(subtopics[i]),
                  ),
                  if (i != subtopics.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _TopicParentBoard extends StatelessWidget {
  final String? parentTopicTitle;

  const _TopicParentBoard({this.parentTopicTitle});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return _TopicStudioCard(
      title: 'Hierarchy',
      subtitle: 'This item is a final-level subtopic.',
      icon: Icons.account_tree_outlined,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _TopicSoftIcon(icon: Icons.subdirectory_arrow_right_rounded, color: AppColors.primary, bg: AppColors.primarySoft),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Parent topic', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    parentTopicTitle ?? 'Parent topic',
                    style: TextStyle(fontSize: 15, color: AppColors.textTitle, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicCommandRail extends StatelessWidget {
  final TopicItem topic;
  final bool isSubtopic;
  final int coverageScore;
  final int mappedOutcomesCount;
  final int totalOutcomesCount;
  final int subtopicCount;
  final VoidCallback onRenameTopic;
  final VoidCallback onEditTopicSummary;
  final VoidCallback onEditTopicStatus;
  final VoidCallback onMapTopicOutcomes;
  final VoidCallback onDeleteTopic;
  final VoidCallback onAddSubtopic;

  const _TopicCommandRail({
    required this.topic,
    required this.isSubtopic,
    required this.coverageScore,
    required this.mappedOutcomesCount,
    required this.totalOutcomesCount,
    required this.subtopicCount,
    required this.onRenameTopic,
    required this.onEditTopicSummary,
    required this.onEditTopicStatus,
    required this.onMapTopicOutcomes,
    required this.onDeleteTopic,
    required this.onAddSubtopic,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final outcomeTotal = totalOutcomesCount == 0 ? mappedOutcomesCount : totalOutcomesCount;
    final outcomeProgress = outcomeTotal == 0
        ? 0.0
        : (mappedOutcomesCount / outcomeTotal).clamp(0.0, 1.0).toDouble();

    return Column(
      children: [
        _TopicStudioCard(
          title: isSubtopic ? 'Subtopic actions' : 'Topic actions',
          subtitle: isSubtopic
              ? 'This is a final-level learning point. It does not contain children.'
              : 'Each action opens a focused popup for one job only.',
          icon: Icons.tune_rounded,
          child: Column(
            children: [
              _TopicCommandButton(
                icon: Icons.drive_file_rename_outline_rounded,
                title: isSubtopic ? 'Rename subtopic' : 'Rename topic',
                subtitle: 'Change the title only.',
                primary: true,
                onTap: onRenameTopic,
              ),
              const SizedBox(height: 10),
              _TopicCommandButton(
                icon: Icons.notes_rounded,
                title: 'Edit summary',
                subtitle: 'Update scope and instructor notes.',
                onTap: onEditTopicSummary,
              ),
              const SizedBox(height: 10),
              _TopicCommandButton(
                icon: Icons.speed_rounded,
                title: 'Set delivery state',
                subtitle: 'Difficulty and readiness only.',
                onTap: onEditTopicStatus,
              ),
              const SizedBox(height: 10),
              _TopicCommandButton(
                icon: Icons.flag_outlined,
                title: 'Outcome mapping',
                subtitle: subtopicCount > 0 && !isSubtopic
                    ? 'Handled through subtopics.'
                    : 'Connect this item to course outcomes.',
                onTap: onMapTopicOutcomes,
              ),
              if (!isSubtopic) ...[
                const SizedBox(height: 10),
                _TopicCommandButton(
                  icon: Icons.account_tree_outlined,
                  title: 'Add subtopic',
                  subtitle: 'Create a final-level child item.',
                  onTap: onAddSubtopic,
                ),
              ],
              const SizedBox(height: 10),
              _TopicCommandButton(
                icon: Icons.delete_outline_rounded,
                title: isSubtopic ? 'Delete subtopic' : 'Delete topic',
                subtitle: 'Remove it from this material.',
                danger: true,
                onTap: onDeleteTopic,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _TopicStudioCard(
          title: 'Readiness signal',
          subtitle: 'A compact check for structure, notes, and outcome coverage.',
          icon: Icons.monitor_heart_outlined,
          child: Column(
            children: [
              _TopicHealthRow(label: 'Preparation', value: coverageScore / 100, trailing: '$coverageScore%'),
              const SizedBox(height: 14),
              _TopicHealthRow(
                label: 'Outcome alignment',
                value: outcomeProgress,
                trailing: '$mappedOutcomesCount/$outcomeTotal',
              ),
              const SizedBox(height: 14),
              _TopicHealthRow(
                label: isSubtopic ? 'Hierarchy' : 'Subtopics',
                value: isSubtopic ? 1.0 : (subtopicCount > 0 ? 1.0 : 0.0),
                trailing: isSubtopic ? 'Leaf' : '$subtopicCount',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _TopicStudioCard(
          title: 'Content level',
          subtitle: isSubtopic
              ? 'Subtopics are the last level in the structure.'
              : 'Topics sit between the material file and subtopics.',
          icon: Icons.schema_outlined,
          child: _TopicLevelDiagram(isSubtopic: isSubtopic),
        ),
      ],
    );
  }
}

class _TopicStudioCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? action;

  const _TopicStudioCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: [BoxShadow(color: AppColors.shadowThin, blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopicSoftIcon(icon: icon, color: AppColors.primary, bg: AppColors.primarySoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textTitle)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 12),
                action!,
              ],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _TopicSummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color accent;
  final Color soft;

  const _TopicSummaryTile({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.accent,
    required this.soft,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _TopicSoftIcon(icon: icon, color: accent, bg: soft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                const SizedBox(height: 5),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textTitle)),
                const SizedBox(height: 3),
                Text(helper, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicCommandButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final bool danger;
  final VoidCallback onTap;

  const _TopicCommandButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final bg = primary ? AppColors.primary : AppColors.surfaceBg;
    final accent = danger ? AppColors.dangerText : AppColors.primary;
    final fg = primary ? Colors.white : (danger ? AppColors.dangerText : AppColors.textTitle);
    final sub = primary ? Colors.white.withOpacity(0.72) : AppColors.textMuted;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: primary ? AppColors.primary : (danger ? AppColors.dangerBorder : AppColors.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary ? Colors.white.withOpacity(0.14) : (danger ? AppColors.dangerBg : AppColors.primarySoft),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20, color: primary ? Colors.white : accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: fg)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, height: 1.35, color: sub, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 18, color: primary ? Colors.white : AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutcomeTilePro extends StatelessWidget {
  final LearningOutcome outcome;
  final int index;

  const _OutcomeTilePro({required this.outcome, required this.index});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final code = outcome.code.trim().isEmpty ? 'LO${index + 1}' : outcome.code;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _K.blueSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(code, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(outcome.title, style: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
                if (outcome.description?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 5),
                  Text(outcome.description!.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtopicTilePro extends StatelessWidget {
  final TopicItem subtopic;
  final int index;
  final VoidCallback onTap;

  const _SubtopicTilePro({required this.subtopic, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final readiness = _topicReadinessMeta(subtopic.readiness);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text('${index + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subtopic.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
                    const SizedBox(height: 5),
                    Text('${subtopic.difficulty.label} • ${readiness.label}', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicHealthRow extends StatelessWidget {
  final String label;
  final double value;
  final String trailing;

  const _TopicHealthRow({required this.label, required this.value, required this.trailing});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textGray))),
            Text(trailing, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.textTitle)),
          ],
        ),
        const SizedBox(height: 8),
        _TopicProgressTrack(value: value),
      ],
    );
  }
}

class _TopicTimelineStep extends StatelessWidget {
  final int index;
  final String title;
  final bool done;
  final bool last;

  const _TopicTimelineStep({required this.index, required this.title, required this.done, this.last = false});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: done ? _K.green : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: done
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : Text('$index', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary)),
            ),
            if (!last)
              Container(
                width: 2,
                height: 26,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: done ? AppColors.textTitle : AppColors.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopicEmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _TopicEmptyPanel({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopicSoftIcon(icon: icon, color: AppColors.primary, bg: AppColors.primarySoft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: AppColors.textTitle)),
                const SizedBox(height: 5),
                Text(message, style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicProgressTrack extends StatelessWidget {
  final double value;
  final bool bright;

  const _TopicProgressTrack({required this.value, this.bright = false});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final v = value.clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 8,
        color: bright ? Colors.white.withOpacity(0.16) : AppColors.border,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: bright
                    ? [Colors.white, AppColors.infoBorder]
                    : [AppColors.primary, AppColors.purpleText],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicGlassChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TopicGlassChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.cardBg.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }
}

class _TopicHeroPathItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TopicHeroPathItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white.withOpacity(0.78)),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.80)),
          ),
        ),
      ],
    );
  }
}

class _TopicHeroButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _TopicHeroButton.primary({required this.icon, required this.label, required this.onTap}) : primary = true;
  const _TopicHeroButton.secondary({required this.icon, required this.label, required this.onTap}) : primary = false;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Material(
      color: primary ? Colors.white : Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primary ? Colors.white : Colors.white.withOpacity(0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: primary ? AppColors.textTitle : Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: primary ? AppColors.textTitle : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicGlassMetric extends StatelessWidget {
  final String label;
  final String value;

  const _TopicGlassMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBg.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.72))),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }
}

class _TopicIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopicIconButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 15, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

class _TopicSoftIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;

  const _TopicSoftIcon({required this.icon, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, size: 20, color: color),
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
    Theme.of(context);
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
                  color: AppColors.surfaceBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No subtopics yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTitle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Break "${topic.title}" into smaller teaching units so notes and outcome coverage stay organized.',
                      style: TextStyle(
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
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderGray),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.infoBg,
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
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textTitle,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${subtopic.difficulty.label} • ${subtopic.readiness.label}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
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
    Theme.of(context);
    final created = '${topic.createdAt.day}/${topic.createdAt.month}/${topic.createdAt.year}';
    final statusChips = [
      _TopicStatusChip(
        icon: isSubtopic ? Icons.subdirectory_arrow_right_rounded : Icons.sell_outlined,
        label: isSubtopic ? 'Subtopic' : 'Topic',
        fg: AppColors.primary,
        bg: AppColors.primarySoft,
      ),
      if (topic.isRequired)
        _TopicStatusChip(
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
        gradient: LinearGradient(
          colors: AppColors.isDark
              ? [const Color(0xFF0F172A), AppColors.infoText, AppColors.purpleText]
              : [AppColors.primary, AppColors.infoText, AppColors.purpleText],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          const BoxShadow(
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
                    border: Border.all(color: AppColors.cardBg.withOpacity(0.14)),
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
                    backgroundColor: AppColors.cardBg,
                    foregroundColor: AppColors.textTitle,
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
    Theme.of(context);
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
                  ),)
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
    Theme.of(context);
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
    Theme.of(context);
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
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBg.withOpacity(0.10)),
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
    Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
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
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            data.value,
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.textTitle),
          ),
          const SizedBox(height: 6),
          Text(
            data.caption,
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
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
    Theme.of(context);
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
            if (i != actions.length - 1) Divider(height: 1, color: AppColors.borderSoft),
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
    Theme.of(context);
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
                    Text(data.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
                    const SizedBox(height: 4),
                    Text(data.subtitle, style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.arrow_outward_rounded, size: 18, color: AppColors.textMuted),
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
    Theme.of(context);
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
                        Text(entries[i].title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
                        const SizedBox(height: 4),
                        Text(entries[i].subtitle, style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.45)),
                      ],
                    ),
                  ),
                ],
              ),
              if (i != entries.length - 1) Padding(
                padding: const EdgeInsets.only(left: 15, top: 8, bottom: 8),
                child: Divider(height: 1, color: AppColors.borderSoft),
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
      return _TopicMeta(
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
      return _TopicMeta(
        label: 'Draft',
        icon: Icons.edit_note_rounded,
        fg: AppColors.textMuted,
        bg: AppColors.headerBg,
      );
  }
}

_TopicMeta _topicDifficultyMeta(TopicDifficulty difficulty) {
  switch (difficulty) {
    case TopicDifficulty.beginner:
      return _TopicMeta(
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
      return _TopicMeta(
        label: 'Advanced',
        icon: Icons.local_fire_department_outlined,
        fg: AppColors.dangerText,
        bg: AppColors.dangerBg,
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DIALOGS
// ─────────────────────────────────────────────────────────────────────────────
