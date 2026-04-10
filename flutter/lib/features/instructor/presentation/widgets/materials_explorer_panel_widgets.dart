import 'package:flutter/material.dart';
import 'materials_explorer_constants.dart';
import 'materials_explorer_micro_widgets.dart';

// =============================================================================
//  RIGHT PANEL COMPONENTS
// =============================================================================

// ── Upload zone ────────────────────────────────────────────────────────────
class UploadZone extends StatefulWidget {
  final VoidCallback onTap;
  const UploadZone({super.key, required this.onTap});
  @override State<UploadZone> createState() => _UploadZoneState();
}

class _UploadZoneState extends State<UploadZone> {
  bool _h = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: _h ? const Color(0xFFE4F2FE) : K.white,
          border: Border.all(
            color: _h ? K.blue : K.border,
            width: _h ? 1.5 : 1,),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 54, height: 54,
            decoration: BoxDecoration(
              color: _h ? K.blue : K.blueSoft,
              borderRadius: BorderRadius.circular(16),),
            child: Icon(Icons.cloud_upload_rounded, size: 26,
              color: _h ? Colors.white : K.blue,),
          ),
          const SizedBox(height: 14),
          Text('Upload materials to this module',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700,
              color: _h ? K.blue : K.text,),),
          const SizedBox(height: 5),
          const Text('PDF, DOCX, PPTX, MP4  ·  Max 500 MB',
            style: TextStyle(fontSize: 12.5, color: K.muted),),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              color: K.blue,
              borderRadius: BorderRadius.circular(9),),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.upload_rounded, size: 15, color: Colors.white),
              SizedBox(width: 7),
              Text('Browse Files',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                  color: Colors.white,),),
            ],),
          ),
        ],),
      ),
    ),
  );
}

// ── Material list card (inside module panel) ────────────────────────────────────
class MaterialListCard extends StatefulWidget {
  final Node mat;
  final VoidCallback onTap, onRename, onDelete;
  const MaterialListCard({
    super.key,
    required this.mat,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });
  @override State<MaterialListCard> createState() => _MaterialListCardState();
}

class _MaterialListCardState extends State<MaterialListCard> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.mat;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: _h ? const Color(0xFFF0F5FF) : K.white,
            border: Border.all(color: _h ? K.blueBorder : K.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            MatIcon(mk: m.mk, size: 42),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                  color: K.text,),
                maxLines: 1, overflow: TextOverflow.ellipsis,),
              const SizedBox(height: 3),
              Text(_mkLabel(m.mk),
                style: const TextStyle(fontSize: 12, color: K.muted),),
            ],),),
            if (m.children.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: K.purpleSoft, borderRadius: BorderRadius.circular(999),),
                child: Text(
                  '${m.children.length} topic${m.children.length == 1 ? "" : "s"}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: K.purple,),),
              ),
            ],
            IcBtn(icon: Icons.edit_outlined,  tip: 'Rename', onTap: widget.onRename),
            IcBtn(icon: Icons.delete_outline, tip: 'Delete', onTap: widget.onDelete, col: K.red),
            const Icon(Icons.chevron_right_rounded, size: 16, color: K.hint),
          ],),
        ),
      ),
    );
  }

  static String _mkLabel(MK? k) {
    switch (k) {
      case MK.video: return 'Video lecture';
      case MK.doc:   return 'Word document';
      case MK.ppt:   return 'Presentation';
      default:        return 'PDF document';
    }
  }
}

// ── Material detail header ───────────────────────────────────────────────────
class MatHeader extends StatelessWidget {
  final Node mat;
  final VoidCallback onRename, onDelete;
  const MatHeader({super.key, required this.mat, required this.onRename, required this.onDelete});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      MatBadge(mat.mk),
      if (mat.qualityScore > 0 && mat.qualityScore < 60) ...[
        const SizedBox(width: 8),
        const Pill('⚠ REVIEW NEEDED', K.badgeRevBg, K.badgeRevFg),
      ],
    ],),
    const SizedBox(height: 12),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MatIcon(mk: mat.mk, size: 48),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(mat.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: K.text),),
        const SizedBox(height: 4),
        Text(_mkLabel(mat.mk),
          style: const TextStyle(fontSize: 12.5, color: K.muted, fontWeight: FontWeight.w600),),
      ],),),
      IcBtn(icon: Icons.edit_outlined,  tip: 'Rename', onTap: onRename),
      IcBtn(icon: Icons.delete_outline, tip: 'Delete', onTap: onDelete, col: K.red),
    ],),
  ],);

  static String _mkLabel(MK? k) {
    switch (k) {
      case MK.video: return 'Video lecture';
      case MK.doc:   return 'Word document';
      case MK.ppt:   return 'Presentation';
      default:        return 'PDF document';
    }
  }
}

// ── Topics section ────────────────────────────────────────────────────────────────
class TopicsSection extends StatelessWidget {
  final Node mat;
  final List<Node> topics;
  final bool generating;
  final VoidCallback onAddManual, onGenerateAI;
  final ValueChanged<Node> onRenameTopic, onDeleteTopic;

  const TopicsSection({
    super.key,
    required this.mat, required this.topics, required this.generating,
    required this.onAddManual, required this.onGenerateAI,
    required this.onRenameTopic, required this.onDeleteTopic,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: K.white,
      border: Border.all(color: K.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: K.purpleSoft, borderRadius: BorderRadius.circular(8),),
            child: const Icon(Icons.label_rounded, size: 16, color: K.purple),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Topics',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: K.text),),
            Text('Organise this material into topics',
              style: TextStyle(fontSize: 11.5, color: K.muted),),
          ],),),
          BtnAI(generating: generating, onTap: onGenerateAI),
          const SizedBox(width: 8),
          BtnOutline(label: 'Add', icon: Icons.add_rounded, onTap: onAddManual, small: true),
        ],),
      ),
      const Divider(height: 1, color: K.border),
      if (topics.isEmpty && !generating)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
          child: Column(children: [
            const Icon(Icons.label_off_outlined, size: 30, color: K.hint),
            const SizedBox(height: 10),
            const Text('No topics yet',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: K.text),),
            const SizedBox(height: 4),
            const Text(
              'Add topics manually or let AI generate them from the material content.',
              style: TextStyle(fontSize: 12, color: K.muted, height: 1.5),
              textAlign: TextAlign.center,),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              BtnAI(generating: generating, onTap: onGenerateAI, labeled: true),
              const SizedBox(width: 10),
              BtnOutline(label: 'Add manually', icon: Icons.add_rounded,
                onTap: onAddManual, small: true,),
            ],),
          ],),
        )
      else if (generating)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: AIGeneratingRow(),
        )
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            ...topics.map((t) => TopicChip(
              topic: t,
              onRename: () => onRenameTopic(t),
              onDelete: () => onDeleteTopic(t),
            ),),
          ],),
        ),
    ],),
  );
}

class TopicChip extends StatefulWidget {
  final Node topic;
  final VoidCallback onRename, onDelete;
  const TopicChip({super.key, required this.topic, required this.onRename, required this.onDelete});
  @override State<TopicChip> createState() => _TopicChipState();
}

class _TopicChipState extends State<TopicChip> {
  bool _h = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit:  (_) => setState(() => _h = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        color: _h ? K.purpleSoft : const Color(0xFFFAFAFF),
        border: Border.all(color: _h ? K.purple : K.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.label_rounded, size: 12, color: K.purple),
        const SizedBox(width: 5),
        Text(widget.topic.title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: K.text),),
        const SizedBox(width: 6),
        GestureDetector(onTap: widget.onRename,
          child: const Icon(Icons.edit_outlined, size: 11, color: K.muted),),
        const SizedBox(width: 3),
        GestureDetector(onTap: widget.onDelete,
          child: const Icon(Icons.close_rounded, size: 11, color: K.muted),),
      ],),
    ),
  );
}

class AIGeneratingRow extends StatelessWidget {
  const AIGeneratingRow({super.key});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 30, height: 30,
      decoration: BoxDecoration(color: K.blueSoft, borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.auto_awesome_rounded, size: 14, color: K.blue),
    ),
    const SizedBox(width: 12),
    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('AI is analysing the content and generating topics…',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: K.text),),
      SizedBox(height: 6),
      LinearProgressIndicator(minHeight: 3, color: K.blue, backgroundColor: K.blueSoft),
    ],),),
  ],);
}

// ── Transcript card ───────────────────────────────────────────────────────────────
class TranscriptCard extends StatelessWidget {
  final Node mat;
  const TranscriptCard({super.key, required this.mat});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
    decoration: BoxDecoration(
      color: K.white,
      border: Border.all(color: K.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: K.blueSoft, borderRadius: BorderRadius.circular(7)),
          child: const Icon(Icons.article_outlined, size: 14, color: K.blue),),
        const SizedBox(width: 10),
        const Expanded(child: Text('Transcript & Content',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: K.text),),),
        const TxBtn(label: 'B', bold: true),
        const SizedBox(width: 3),
        const TxBtn(label: 'I', italic: true),
        const SizedBox(width: 3),
        const TxBtn(label: 'S̶'),
        const SizedBox(width: 3),
        const TxBtn(label: '↗'),
      ],),
      const Divider(height: 20, color: K.border),
      Text(
        mat.transcript.isNotEmpty
          ? mat.transcript
          : 'Transcript will appear here once the material has been processed.',
        style: const TextStyle(fontSize: 13, height: 1.75, color: Color(0xFF1E293B)),),
      const SizedBox(height: 12),
      const Row(children: [
        Icon(Icons.auto_fix_high_rounded, size: 12, color: K.blue),
        SizedBox(width: 6),
        Text('Suggestion: Simplify sentence structure?',
          style: TextStyle(fontSize: 11.5, color: K.blue, fontWeight: FontWeight.w600),),
      ],),
    ],),
  );
}

// ── AI sidebar ─────────────────────────────────────────────────────────────────────
class AISidebar extends StatelessWidget {
  final Node mat;
  final VoidCallback onRegen;
  const AISidebar({super.key, required this.mat, required this.onRegen});

  @override
  Widget build(BuildContext context) {
    final score = mat.qualityScore.clamp(0, 100);
    final val   = score / 100.0;
    final col   = val >= 0.8 ? K.green : val >= 0.5 ? K.yellow : K.red;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: K.blueSoft, borderRadius: BorderRadius.circular(7)),
          child: const Icon(Icons.auto_awesome_rounded, size: 13, color: K.blue),),
        const SizedBox(width: 9),
        const Text('AI Analysis',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: K.text),),
      ],),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Quality Score',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: K.muted),),
        Text('$score/100',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: col),),
      ],),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(value: val, minHeight: 6,
          backgroundColor: K.bg, color: col,),),
      const SizedBox(height: 16),
      const Text('Suggested Tags',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: K.muted),),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        ...mat.tags.map((t) => TagChip(t)),
        const TagChip('+', dashed: true),
      ],),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: onRegen,
        icon: const Icon(Icons.refresh_rounded, size: 13),
        label: const Text('Regenerate',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),),
        style: OutlinedButton.styleFrom(
          foregroundColor: K.muted,
          side: const BorderSide(color: K.border),
          padding: const EdgeInsets.symmetric(vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),),
      ),),
    ],);
  }
}
