import 'package:flutter/material.dart';
import 'package:learnova/core/theme/app_theme.dart';
import 'package:learnova/core/ui/toast.dart';
import 'package:learnova/features/instructor/data/courses_models.dart';
import 'package:learnova/features/instructor/data/learning_outcomes_models.dart';
import 'package:learnova/shared/widgets/components/dropdowns.dart';
import 'learning_outcomes_section.dart';

class CreateCourseDialogResult {
  final CourseCreateRequest request;
  final bool needsInvites;
  final List<LearningOutcome> learningOutcomes;
  const CreateCourseDialogResult({
    required this.request,
    required this.needsInvites,
    required this.learningOutcomes,
  });
}

enum _PublishChoice    { published, draft }
enum _VisibilityChoice { publicCourse, privateCourse }

class CreateCourseDialog extends StatefulWidget {
  const CreateCourseDialog({super.key});
  @override
  State<CreateCourseDialog> createState() => _CreateCourseDialogState();
}

class _CreateCourseDialogState extends State<CreateCourseDialog> {
  final _titleCtrl = TextEditingController();
  final _codeCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();

  String _selectedTerm = 'Fall 2025';
  _PublishChoice    _publish    = _PublishChoice.draft;
  _VisibilityChoice _visibility = _VisibilityChoice.privateCourse;

  String? _titleError;
  String? _codeError;
  bool _titleTouched = false;
  bool _codeTouched  = false;

  List<LearningOutcome> _outcomes = [];

  static final _codeRx = RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-_\/ ]*$');

  static const _terms = [
    'Fall 2023', 'Spring 2024', 'Fall 2024',
    'Spring 2025', 'Fall 2025', 'Spring 2026',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_onTitleChanged);
    _codeCtrl.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onTitleChanged);
    _codeCtrl.removeListener(_onCodeChanged);
    _titleCtrl.dispose();
    _codeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    if (!_titleTouched) return;
    _validateTitle();
  }

  void _onCodeChanged() {
    if (!_codeTouched) return;
    _validateCode();
  }

  void _validateTitle() {
    final err = _titleCtrl.text.trim().isEmpty ? 'Course title is required.' : null;
    if (err == _titleError) return;
    if (mounted) setState(() => _titleError = err);
  }

  void _validateCode() {
    final c = _codeCtrl.text.trim();
    String? err;
    if (c.isNotEmpty) {
      if (c.length < 2 || c.length > 31) {
        err = 'Course code must be 2–31 characters.';
      // ignore: curly_braces_in_flow_control_structures
      } else if (!_codeRx.hasMatch(c))       err = 'Use letters/numbers and - _ / only.';
    }
    if (err == _codeError) return;
    if (mounted) setState(() => _codeError = err);
  }

  void _validateAll() {
    setState(() { _titleTouched = true; _codeTouched = true; });
    _validateTitle();
    _validateCode();
  }

  bool get _canSubmit =>
      _titleCtrl.text.trim().isNotEmpty && _titleError == null && _codeError == null;

  void _submit() {
    _validateAll();
    if (!_canSubmit) {
      AppToast.error(context, title: 'Validation Error',
          message: _titleError ?? _codeError ?? 'Fix highlighted fields.');
      return;
    }
    final isPublic = _visibility == _VisibilityChoice.publicCourse;
    final status   = _publish == _PublishChoice.published ? 'published' : 'draft';
    final request  = CourseCreateRequest(
      courseType: 'individual',
      organizationId: null,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      coverImageUrl: null,
      bannerImageUrl: null,
      isPublic: isPublic,
      visibilityLevel: isPublic ? 'public' : 'private',
      requiresEnrollmentApproval: !isPublic,
      learningOutcomes: _outcomes.map((o) => '${o.code}: ${o.description}').toList(),
      tags: const [],
      category: null,
      status: status,
      courseCode: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
      academicTerm: _selectedTerm,
      localStatus: status,
    );
    Navigator.of(context).pop(CreateCourseDialogResult(
      request: request,
      needsInvites: !isPublic,
      learningOutcomes: _outcomes,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = size.width < 800 ? size.width * 0.96 : 740.0;
    final maxH = size.height * 0.92;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      backgroundColor: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 40, offset: Offset(0, 16)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                    child: Column(
                      children: [
                        _buildCourseDetailsCard(),
                        const SizedBox(height: 16),
                        _buildBottomRow(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: Color(0xFFF0F2F4))),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              border: Border.all(color: const Color(0xFFDBEAFE)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add_box_outlined, size: 18, color: Color(0xFF137FEC)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create New Course',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                        color: Color(0xFF111418))),
                SizedBox(height: 1),
                Text('Fill in the details to set up a new learning module.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF617589))),
              ],
            ),
          ),
          _HoverIconBtn(
            icon: Icons.close_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ── Course Details card ───────────────────────────────────────────────────
  Widget _buildCourseDetailsCard() {
    return _SectionCard(
      icon: Icons.article_outlined,
      title: 'Course Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course Title
          _buildFieldLabel('Course Title', required: true),
          const SizedBox(height: 6),
          _TitledInputWithError(
            controller: _titleCtrl,
            hint: 'e.g. Introduction to Artificial Intelligence',
            prefixIcon: Icons.school_outlined,
            error: _titleError,
            onBlur: () {
              if (!_titleTouched) setState(() => _titleTouched = true);
              _validateTitle();
            },
          ),
          const SizedBox(height: 16),

          // Code + Term row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Course Code', optional: true),
                    const SizedBox(height: 6),
                    _TitledInputWithError(
                      controller: _codeCtrl,
                      hint: 'e.g. CS-101',
                      prefixIcon: Icons.tag_rounded,
                      error: _codeError,
                      onBlur: () {
                        if (!_codeTouched) setState(() => _codeTouched = true);
                        _validateCode();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Academic Term'),
                    const SizedBox(height: 6),
                    // Use the shared FigmaUmDropdown40 which is already pixel-perfect
                    FigmaUmDropdown40(
                      width: double.infinity,
                      value: _selectedTerm,
                      items: _terms,
                      onChanged: (v) => setState(() => _selectedTerm = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          _buildFieldLabel('Course Description'),
          const SizedBox(height: 6),
          _DescriptionField(controller: _descCtrl),
          const SizedBox(height: 10),

          // AI tip
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF137FEC)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Tip: A detailed description helps generate better quiz questions.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF137FEC),
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Learning Outcomes card ────────────────────────────────────────────────
  Widget _buildLearningOutcomesCard() {
    return _SectionCard(
      icon: Icons.flag_outlined,
      title: 'Learning Outcomes',
      badge: _outcomes.isEmpty ? null : '${_outcomes.length}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Define what students will achieve. Topics will be linked to these outcomes.',
            style: TextStyle(fontSize: 13, color: Color(0xFF617589), height: 1.5),
          ),
          const SizedBox(height: 14),
          LearningOutcomesSection(
            initialOutcomes: _outcomes,
            onChanged: (list) => setState(() => _outcomes = list),
          ),
        ],
      ),
    );
  }

  // ── Config + Cover row ────────────────────────────────────────────────────
  Widget _buildBottomRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _SectionCard(
            icon: Icons.tune_rounded,
            title: 'Configuration',
            child: _ConfigSection(
              publish: _publish,
              visibility: _visibility,
              onPublishChanged: (v) => setState(() => _publish = v),
              onVisibilityChanged: (v) => setState(() => _visibility = v),
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 210,
          child: _SectionCard(
            icon: Icons.image_outlined,
            title: 'Course Cover',
            child: _CoverUpload(),
          ),
        ),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Color(0xFFF0F2F4))),
      ),
      child: Row(
        children: [
          const Spacer(),
          _OutlineBtn(label: 'Cancel', onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 10),
          _PrimaryBtn(label: '+ Create Course', onTap: _canSubmit ? _submit : null),
        ],
      ),
    );
  }

  // ── Helper: field label ───────────────────────────────────────────────────
  Widget _buildFieldLabel(String label, {bool required = false, bool optional = false}) {
    return Row(
      children: [
        Text(label,
            style: AppText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
        if (required)
          const Text(' *',
              style: TextStyle(fontSize: 13, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
        if (optional) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('Optional',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF137FEC),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final String? badge;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: const Color(0xFF137FEC)),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: Color(0xFF111418))),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF137FEC),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(badge!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: const Color(0xFFF0F2F4)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Input with error display (uses AppLabeledTextField internals) ─────────────
class _TitledInputWithError extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final String? error;
  final VoidCallback? onBlur;

  const _TitledInputWithError({
    required this.controller,
    required this.hint,
    this.prefixIcon,
    this.error,
    this.onBlur,
  });

  @override
  State<_TitledInputWithError> createState() => _TitledInputWithErrorState();
}

class _TitledInputWithErrorState extends State<_TitledInputWithError> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!mounted) return;
      final hasFocus = _focus.hasFocus;
      setState(() => _focused = hasFocus);
      if (!hasFocus) widget.onBlur?.call();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasErr = (widget.error ?? '').isNotEmpty;
    final borderColor = hasErr
        ? const Color(0xFFEF4444)
        : _focused
            ? AppColors.primary
            : AppColors.borderSoft;
    final borderWidth = _focused && !hasErr ? 1.5 : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: hasErr ? const Color(0xFFFEF2F2) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Row(
            children: [
              if (widget.prefixIcon != null) ...[
                Icon(widget.prefixIcon, size: 16,
                    color: hasErr
                        ? const Color(0xFFEF4444)
                        : _focused
                            ? AppColors.primary
                            : AppColors.muted),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _focus,
                  style: AppText.input,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: AppText.hint,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasErr) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 12, color: Color(0xFFEF4444)),
              const SizedBox(width: 4),
              Text(widget.error!,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Description field (toolbar + textarea) ────────────────────────────────────
class _DescriptionField extends StatefulWidget {
  final TextEditingController controller;
  const _DescriptionField({required this.controller});
  @override
  State<_DescriptionField> createState() => _DescriptionFieldState();
}

class _DescriptionFieldState extends State<_DescriptionField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _focused ? AppColors.primary : AppColors.borderSoft,
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(
          children: [
            // Toolbar
            Container(
              height: 38,
              color: AppColors.surfaceBg,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: const Row(
                children: [
                  _TbBtn(icon: Icons.format_bold_rounded),
                  _TbBtn(icon: Icons.format_italic_rounded),
                  _TbBtn(icon: Icons.format_list_bulleted_rounded),
                  _TbBtn(icon: Icons.link_rounded),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFF0F2F4)),
            // Text area
            SizedBox(
              height: 110,
              child: TextFormField(
                controller: widget.controller,
                focusNode: _focus,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: AppText.input.copyWith(height: 1.55),
                decoration: InputDecoration(
                  hintText: 'Enter a detailed description of the course content, objectives, and prerequisites...',
                  hintStyle: AppText.hint.copyWith(height: 1.55),
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TbBtn extends StatefulWidget {
  final IconData icon;
  const _TbBtn({required this.icon});
  @override
  State<_TbBtn> createState() => _TbBtnState();
}

class _TbBtnState extends State<_TbBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: _h ? AppColors.border : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Center(child: Icon(widget.icon, size: 16, color: _h ? AppColors.text : AppColors.muted)),
    ),
  );
}

// ── Config section ────────────────────────────────────────────────────────────
class _ConfigSection extends StatelessWidget {
  final _PublishChoice publish;
  final _VisibilityChoice visibility;
  final ValueChanged<_PublishChoice> onPublishChanged;
  final ValueChanged<_VisibilityChoice> onVisibilityChanged;

  const _ConfigSection({
    required this.publish,
    required this.visibility,
    required this.onPublishChanged,
    required this.onVisibilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Visibility Status',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                color: Color(0xFF617589), letterSpacing: 0.2)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _OptionTile(
            title: 'Save as Draft',
            sub: 'Only visible to instructors',
            selected: publish == _PublishChoice.draft,
            onTap: () => onPublishChanged(_PublishChoice.draft),
          )),
          const SizedBox(width: 8),
          Expanded(child: _OptionTile(
            title: 'Publish Now',
            sub: 'Visible to enrolled students',
            selected: publish == _PublishChoice.published,
            onTap: () => onPublishChanged(_PublishChoice.published),
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _OptionTile(
            title: 'Set as Private',
            sub: 'For specific Student',
            selected: visibility == _VisibilityChoice.privateCourse,
            onTap: () => onVisibilityChanged(_VisibilityChoice.privateCourse),
          )),
          const SizedBox(width: 8),
          Expanded(child: _OptionTile(
            title: 'Set as Public',
            sub: 'For Public Student',
            selected: visibility == _VisibilityChoice.publicCourse,
            onTap: () => onVisibilityChanged(_VisibilityChoice.publicCourse),
          )),
        ]),
        if (visibility == _VisibilityChoice.privateCourse) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceBg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF137FEC)),
              SizedBox(width: 8),
              Expanded(child: Text('You can invite students after creating the course.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF111418)))),
            ]),
          ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatefulWidget {
  final String title, sub;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.title, required this.sub,
    required this.selected, required this.onTap,
  });

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    const blue  = Color(0xFF137FEC);
    const blueSoft = Color(0xFFEFF6FF);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: widget.selected ? blueSoft : _h ? AppColors.pageBg : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected ? blue : AppColors.border,
              width: widget.selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Text block (left)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: widget.selected ? blue : AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.sub,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF617589)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Radio dot (right) — matches Figma exactly
              Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.selected ? blue : AppColors.border,
                    width: 2,
                  ),
                  color: Colors.white,
                ),
                child: widget.selected
                    ? Center(
                        child: Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: blue, shape: BoxShape.circle),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cover upload ──────────────────────────────────────────────────────────────
class _CoverUpload extends StatefulWidget {
  @override
  State<_CoverUpload> createState() => _CoverUploadState();
}

class _CoverUploadState extends State<_CoverUpload> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: _h ? const Color(0xFFEFF6FF) : const Color(0xFFFAFBFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _h ? const Color(0xFF137FEC) : AppColors.border,
            width: _h ? 1.5 : 1,
          ),
        ),
  child: Column(
  mainAxisSize: MainAxisSize.min, 
  children: [
    Container(
      width: 46, height: 63,
      decoration: BoxDecoration(
        color: _h ? const Color(0xFFEFF6FF) : AppColors.headerBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.add_photo_alternate_outlined, size: 22,
          color: _h ? const Color(0xFF137FEC) : AppColors.muted),
    ),
    const SizedBox(height: 12),
    
    // 2. جعل النصوص تحت بعضها وفي المنتصف
    Text(
      'Upload a file',
      style: TextStyle(
        fontSize: 13, 
        fontWeight: FontWeight.w700,
        color: _h ? const Color(0xFF137FEC) : AppColors.muted,
        fontFamily: 'Inter'
      ),
    ),
    const SizedBox(height: 4), // مسافة بسيطة بين السطرين
    const Text(
      'or drag and drop',
      style: TextStyle(
        fontSize: 12, 
        color: Color(0xFF9CA3AF), 
        fontFamily: 'Inter'
      ),
    ),
    
    const SizedBox(height: 8),
    
    const Text(
      'PNG, JPG, GIF up to 10MB',
      textAlign: TextAlign.center, // تأكيد التوسط
      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
    ),
  ],
),
      ),
    );
  }
}

// ── Hover close button ────────────────────────────────────────────────────────
class _HoverIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HoverIconBtn({required this.icon, required this.onTap});
  @override
  State<_HoverIconBtn> createState() => _HoverIconBtnState();
}

class _HoverIconBtnState extends State<_HoverIconBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: _h ? AppColors.headerBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(widget.icon, size: 18, color: AppColors.muted),
      ),
    ),
  );
}

// ── Buttons ───────────────────────────────────────────────────────────────────
class _PrimaryBtn extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  const _PrimaryBtn({required this.label, this.onTap});
  @override
  State<_PrimaryBtn> createState() => _PrimaryBtnState();
}

class _PrimaryBtnState extends State<_PrimaryBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: !enabled
                ? AppColors.border
                : _h ? const Color(0xFF0E6FD4) : AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(widget.label,
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700,
                    color: enabled ? Colors.white : AppColors.muted)),
          ),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});
  @override
  State<_OutlineBtn> createState() => _OutlineBtnState();
}

class _OutlineBtnState extends State<_OutlineBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: _h ? AppColors.headerBg : Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(widget.label,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600,
                  color: AppColors.text)),
        ),
      ),
    ),
  );
}
