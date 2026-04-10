import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../data/learning_outcomes_models.dart';

class _AddTopicColors {
  static const purple = Color(0xFF7C3AED);
  static const purpleBorder = Color(0xFFDDD6FE);
  static const blueSoft = Color(0xFFEFF6FF);
  static const blueMid = Color(0xFFDBEAFE);
  static const divider = Color(0xFFEEEEEE);
}

enum TopicCreateMode { manual, ai }

class TopicDialogResult {
  final String title;
  final TopicCreateMode mode;
  final List<int> learningOutcomeIds;

  const TopicDialogResult.manual(this.title, {this.learningOutcomeIds = const []})
      : mode = TopicCreateMode.manual;

  const TopicDialogResult.ai()
      : mode = TopicCreateMode.ai,
        title = '',
        learningOutcomeIds = const [];
}

class AddTopicUnifiedButton extends StatelessWidget {
  final VoidCallback onTap;
  const AddTopicUnifiedButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: Dialog(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF137FEC), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22137FEC),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 14, color: Colors.white),
                SizedBox(width: 5),
                Text(
                  'Add Topic',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddTopicDialogV2 extends StatefulWidget {
  final List<LearningOutcome> outcomes;
  const AddTopicDialogV2({super.key, this.outcomes = const []});

  @override
  State<AddTopicDialogV2> createState() => _AddTopicDialogV2State();
}

class _AddTopicDialogV2State extends State<AddTopicDialogV2>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _titleCtrl = TextEditingController();
  bool _submitted = false;
  final Set<int> _selectedOutcomeIds = {};

  bool get _isManual => _tabController.index == 0;

  String? get _titleError {
    if (!_submitted) return null;
    if (_titleCtrl.text.trim().isEmpty) return 'Topic name is required';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isManual) {
      setState(() => _submitted = true);
      final title = _titleCtrl.text.trim();
      if (title.isEmpty) return;
      Navigator.pop(
        context,
        TopicDialogResult.manual(title, learningOutcomeIds: _selectedOutcomeIds.toList()),
      );
      return;
    }
    Navigator.pop(context, const TopicDialogResult.ai());
  }

 @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: _dialogTabs(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _isManual ? _manualBody(key: const ValueKey('manual_field')) : _aiBody(key: const ValueKey('ai_field')),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: _AddTopicColors.divider)),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            FocusScope.of(context).unfocus(); 
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),),
                            side: const BorderSide(color: _AddTopicColors.divider),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            FocusScope.of(context).unfocus(); // تحرير الفوكس قبل التنفيذ
                            _submit();
                          },
                          icon: Icon(
                            _isManual ? Icons.add_rounded : Icons.auto_awesome_rounded,
                            size: 16,
                          ),
                          label: Text(_isManual ? 'Create Topic' : 'Generate with AI'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            backgroundColor: _isManual ? AppColors.primary : _AddTopicColors.purple,
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
      ),
    );
  }

  Widget _dialogHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _AddTopicColors.divider)),),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF137FEC), Color(0xFF8B5CF6)],),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.tag_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add Topic', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textTitle,),),
            SizedBox(height: 2),
            Text('Create a topic manually or let AI extract one for you.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),),
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

  Widget _dialogTabs() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Color(0x12000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        labelPadding: EdgeInsets.zero,
        tabs: [
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.edit_rounded, size: 14,
                color: _isManual ? AppColors.primary : AppColors.textHint,),
            const SizedBox(width: 6),
            Text('Manual', style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700,
                color: _isManual ? AppColors.primary : AppColors.textMuted,),),
          ],),),
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.auto_awesome_rounded, size: 14,
                color: !_isManual ? _AddTopicColors.purple : AppColors.textHint,),
            const SizedBox(width: 6),
            Text('AI Generate', style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700,
                color: !_isManual ? _AddTopicColors.purple : AppColors.textMuted,),),
          ],),),
        ],
      ),
    );
  }

  Widget _manualBody({Key? key}) {
    final outcomes = widget.outcomes;
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Topic name', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted,),),
        const SizedBox(height: 8),
        TextField(
          controller: _titleCtrl,
          autofocus: true,
          onTapOutside: (event) => FocusScope.of(context).requestFocus(FocusNode()),
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'e.g. Introduction to Robotics',
            errorText: _titleError,
            prefixIcon: const Icon(Icons.tag_rounded, size: 16, color: _AddTopicColors.purple),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _AddTopicColors.divider),),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _AddTopicColors.divider),),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.4),),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        if (outcomes.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(children: [
            const Text('Link to Learning Outcomes',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),),
            const SizedBox(width: 6),
            Text('(optional)',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted.withOpacity(0.7)),),
          ],),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _AddTopicColors.divider),
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
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.badgeBlueFg),),
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
            color: _AddTopicColors.blueSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _AddTopicColors.blueMid),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Use clear topic names so question generation and analytics stay well organized.',
              style: TextStyle(fontSize: 12, height: 1.5,
                  color: AppColors.primary, fontWeight: FontWeight.w500,),
            ),),
          ],),
        ),
      ],
    );
  }

  Widget _aiBody({required ValueKey<String> key}) {
    return Column(
      key: const ValueKey('ai'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFF5F3FF), Color(0xFFEEF2FF)],),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _AddTopicColors.purpleBorder),
          ),
          child: Column(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16),),
              child: const Icon(Icons.auto_awesome_rounded, color: _AddTopicColors.purple, size: 24),
            ),
            const SizedBox(height: 12),
            const Text('Generate Topics with AI', style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: _AddTopicColors.purple,),),
            const SizedBox(height: 6),
            const Text(
              'AI will analyze the selected material and extract suggested topics automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.textMuted),
            ),
          ],),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _AddTopicColors.divider),
          ),
          child: const Row(children: [
            Icon(Icons.bolt_rounded, size: 15, color: _AddTopicColors.purple),
            SizedBox(width: 8),
            Expanded(child: Text(
              'You can review and refine the generated topics later.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),),
          ],),
        ),
      ],
    );
  }
}
