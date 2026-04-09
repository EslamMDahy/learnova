import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'upload_materials_dialog.dart';
import 'package:learnova/features/instructor/presentation/widgets/create_exam_content.dart';
import 'package:learnova/features/instructor/data/courses_models.dart';
import 'package:learnova/features/instructor/presentation/controllers/course_details_controller.dart';
import 'materials_explorer_constants.dart';
import 'materials_explorer_tree_widgets.dart';
import 'materials_explorer_panel_widgets.dart';
import 'materials_explorer_micro_widgets.dart';
import 'materials_explorer_dialogs.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Page widget
// ─────────────────────────────────────────────────────────────────────────────
class MaterialsExplorerPage extends ConsumerStatefulWidget {
  final String courseSlug;
  final MyCourseItem course;
  const MaterialsExplorerPage({super.key, required this.courseSlug, required this.course});
  @override
  ConsumerState<MaterialsExplorerPage> createState() => _MaterialsExplorerPageState();
}

class _MaterialsExplorerPageState extends ConsumerState<MaterialsExplorerPage>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  final _searchCtrl  = TextEditingController();
  final _treeScroll  = ScrollController();
  int   _uid         = 0;
  List<_Node> _roots = [];
  _Node? _selected;
  bool _loadingTree      = true;
  bool _generatingTopics = false;
  DateTime _lastSaved    = DateTime.now().subtract(const Duration(minutes: 2));
  int _examStep = 1;

  // ── lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromBackend());
  }

  @override
  void dispose() { _searchCtrl.dispose(); _treeScroll.dispose(); super.dispose(); }

  // ── backend load ─────────────────────────────────────────────────────────
  Future<void> _loadFromBackend() async {
    if (!mounted) return;
    setState(() => _loadingTree = true);
    final cid  = widget.course.id;
    final ctrl = ref.read(courseDetailsControllerProvider(cid).notifier);
    var st = ref.read(courseDetailsControllerProvider(cid));
    if (st.modules.isEmpty && !st.modulesLoading) {
      await ctrl.loadModules();
    } else {
      while (ref.read(courseDetailsControllerProvider(cid)).modulesLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (!mounted) return;
      }
    }
    st = ref.read(courseDetailsControllerProvider(cid));
    if (!mounted) return;
    final roots = <_Node>[];
    for (final mod in st.modules) {
      await ctrl.loadMaterials(mod.id);
      final fresh = ref.read(courseDetailsControllerProvider(cid));
      final mats  = fresh.materials[mod.id] ?? [];
      final matNodes = mats.map((m) => _Node.material(
        id: 'mat_${m.id}', title: m.displayTitle,
        kind: m.type == 'video' ? _MK.video : _MK.pdf,
        backendId: m.id, moduleId: mod.id,
        transcript: m.description ?? '',
      )).toList();
      roots.add(_Node.module(
        id: 'mod_${mod.id}', title: mod.title,
        children: matNodes, backendId: mod.id,
      ));
    }
    if (!mounted) return;
    setState(() { _roots = roots; _loadingTree = false; _lastSaved = DateTime.now(); });
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  String _nid() => '${DateTime.now().microsecondsSinceEpoch}_${_uid++}';

  void _removeNode(_Node t) {
    void rm(List<_Node> l) {
      l.removeWhere((n) => n.id == t.id);
      for (final n in l) { rm(n.children); }
    }
    rm(_roots);
  }

  void _setAllExpanded(bool v) {
    void walk(List<_Node> ns) { for (final n in ns) { n.isExpanded = v; walk(n.children); } }
    setState(() => walk(_roots));
  }

  // ── CRUD ─────────────────────────────────────────────────────────────────
  Future<void> _createModule() async {
    final name = await _dlgInput('New Module', 'e.g. Chapter 1 — Introduction', '', 'Create');
    if (name == null || !mounted) return;
    final ctrl    = ref.read(courseDetailsControllerProvider(widget.course.id).notifier);
    final created = await ctrl.createModule(name);
    if (!mounted || created == null) return;
    setState(() {
      final n = _Node.module(id: 'mod_${created.id}', title: created.title, backendId: created.id);
      _roots.add(n);
      _selected = n;
      _lastSaved = DateTime.now();
    });
  }

  Future<void> _addTopicToMaterial(_Node mat, {String? prefill}) async {
    final name = await _dlgInput('New Topic', 'e.g. Binary Trees', prefill ?? '', 'Add Topic');
    if (name == null || !mounted) return;
    setState(() {
      mat.children.add(_Node.topic(id: _nid(), title: name));
      mat.isExpanded = true;
    });
  }

  Future<void> _generateTopicsWithAI(_Node mat) async {
    if (_generatingTopics) return;
    setState(() => _generatingTopics = true);
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) { setState(() => _generatingTopics = false); return; }
    final suggest = ['Core Concepts', 'Key Definitions', 'Practical Examples',
                     'Common Mistakes', 'Summary & Review'];
    setState(() {
      for (final t in suggest) {
        if (!mat.children.any((c) => c.title == t)) {
          mat.children.add(_Node.topic(id: _nid(), title: t));
        }
      }
      mat.isExpanded = true;
      _generatingTopics = false;
    });
  }

  Future<void> _rename(_Node n) async {
    final name = await _dlgInput('Rename', 'New name', n.title, 'Save');
    if (name == null) return;
    setState(() => n.title = name);
  }

  Future<void> _delete(_Node n) async {
    final ok = await _dlgConfirm('Delete "${n.title}"?', 'Delete', danger: true);
    if (!ok || !mounted) return;
    setState(() { _removeNode(n); if (_selected?.id == n.id) _selected = null; });
  }

  void _showUpload() => showDialog(
    context: context, builder: (_) => const UploadMaterialsDialog());

  void _openExam() {
    _examStep = 1;
    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: '',
      pageBuilder: (_, __, ___) => Material(
        color: Colors.white,
        child: SafeArea(
          child: StatefulBuilder(builder: (ctx, ss) => CreateExamContent(
            currentStep: _examStep,
            onBack: () {
              if (_examStep > 1) { ss(() => _examStep--); }
              else { Navigator.pop(ctx); }
            },
            onNext: () {
              if (_examStep < 3) { ss(() => _examStep++); }
              else { Navigator.pop(ctx); }
            },
          )),
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Expanded(child: Row(children: [
        _buildSidebar(),
        Container(width: 1, color: _K.border),
        Expanded(child: _buildRightPanel()),
      ])),
      _buildBottomBar(),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LEFT SIDEBAR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSidebar() => SizedBox(
    width: 284,
    child: Container(
      color: _K.white,
      child: Column(children: [
        // Toolbar
        Container(
          height: 46,
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _K.border))),
          child: Row(children: [
            const Text('HIERARCHY',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800,
                color: _K.hint, letterSpacing: 0.9)),
            const Spacer(),
            _TbBtn(icon: Icons.unfold_less_rounded, tip: 'Collapse all',
              onTap: () => _setAllExpanded(false)),
            _TbBtn(icon: Icons.unfold_more_rounded, tip: 'Expand all',
              onTap: () => _setAllExpanded(true)),
          ]),
        ),
        // Tree
        Expanded(
          child: _loadingTree
            ? const Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: _K.blue))
            : _roots.isEmpty
              ? _emptyTreeState()
              : ListView(
                  controller: _treeScroll,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: _roots.map((mod) => _ModuleTreeItem(
                    module:     mod,
                    selectedId: _selected?.id,
                    onModule:   (n) => setState(() { n.isExpanded = !n.isExpanded; _selected = n; }),
                    onMaterial: (n) => setState(() { n.isExpanded = !n.isExpanded; _selected = n; }),
                    onTopic:    (n) => setState(() => _selected = n),
                    onRename:   _rename,
                    onDelete:   _delete,
                  )).toList(),
                ),
        ),
        // Footer button
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _K.border))),
          child: _BtnPrimary(
            label: 'Create New Module',
            icon: Icons.add_rounded,
            onTap: _createModule,
            full: true,
          ),
        ),
      ]),
    ),
  );

  Widget _emptyTreeState() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: _K.blueSoft, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.folder_open_rounded, size: 26, color: _K.blue),
      ),
      const SizedBox(height: 14),
      const Text('No modules yet',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _K.text),
        textAlign: TextAlign.center),
      const SizedBox(height: 6),
      const Text('Create a module to start adding course materials.',
        style: TextStyle(fontSize: 12, color: _K.muted, height: 1.5),
        textAlign: TextAlign.center),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════
  //  RIGHT PANEL  — 3 states: nothing / module / material
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildRightPanel() {
    final sel = _selected;
    if (sel == null)            return _panelEmpty();
    if (sel.nk == _NK.module)   return _panelModule(sel);
    if (sel.nk == _NK.material) return _panelMaterial(sel);
    return _panelTopic(sel);
  }

  // ── nothing selected ────────────────────────────────────────────────────
  Widget _panelEmpty() => Container(
    color: _K.bg,
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: _K.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: const Icon(Icons.touch_app_outlined, size: 28, color: _K.blue),
      ),
      const SizedBox(height: 18),
      const Text('Select a module or material',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _K.text)),
      const SizedBox(height: 6),
      const Text('Use the hierarchy panel on the left to navigate.',
        style: TextStyle(fontSize: 13, color: _K.muted)),
      const SizedBox(height: 20),
      _BtnOutline(label: 'Upload Material', icon: Icons.upload_rounded, onTap: _showUpload),
    ])),
  );

  // ── MODULE panel ─────────────────────────────────────────────────────────
  Widget _panelModule(_Node mod) {
    final mats = mod.children.where((c) => c.nk == _NK.material).toList();
    return Container(
      color: _K.bg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 20, 16),
          decoration: const BoxDecoration(
            color: _K.white,
            border: Border(bottom: BorderSide(color: _K.border)),
          ),
          child: Row(children: [
            const _MatIcon(isModule: true, size: 44),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mod.title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _K.text),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text('Module  ·  ${mats.length} material${mats.length == 1 ? "" : "s"}',
                style: const TextStyle(fontSize: 12.5, color: _K.muted)),
            ])),
            _IcBtn(icon: Icons.edit_outlined,  tip: 'Rename', onTap: () => _rename(mod)),
            const SizedBox(width: 2),
            _IcBtn(icon: Icons.delete_outline, tip: 'Delete',
              onTap: () => _delete(mod), col: _K.red),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _UploadZone(onTap: _showUpload),
            if (mats.isNotEmpty) ...[
              const SizedBox(height: 28),
              Row(children: [
                const Text('MATERIALS IN THIS MODULE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: _K.muted, letterSpacing: 0.7)),
                const SizedBox(width: 8),
                _CountBadge('${mats.length}'),
              ]),
              const SizedBox(height: 12),
              ...mats.map((m) => _MaterialListCard(
                mat: m,
                onTap: () => setState(() { m.isExpanded = !m.isExpanded; _selected = m; }),
                onRename: () => _rename(m),
                onDelete: () => _delete(m),
              )),
            ],
          ]),
        )),
      ]),
    );
  }

  // ── MATERIAL panel ───────────────────────────────────────────────────────
  Widget _panelMaterial(_Node mat) {
    final topics = mat.children.where((c) => c.nk == _NK.topic).toList();
    return Row(children: [
      Expanded(child: Container(
        color: const Color(0xFFF8FAFC),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 20, 80),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _MatHeader(mat: mat, onRename: () => _rename(mat), onDelete: () => _delete(mat)),
            const SizedBox(height: 22),
            _TopicsSection(
              mat: mat,
              topics: topics,
              generating: _generatingTopics,
              onAddManual: () => _addTopicToMaterial(mat),
              onGenerateAI: () => _generateTopicsWithAI(mat),
              onRenameTopic: (t) => _rename(t),
              onDeleteTopic: (t) => _delete(t),
            ),
            const SizedBox(height: 20),
            _TranscriptCard(mat: mat),
          ]),
        ),
      )),
      Container(
        width: 228,
        decoration: const BoxDecoration(
          color: _K.white,
          border: Border(left: BorderSide(color: _K.border)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: _AISidebar(mat: mat, onRegen: () => setState(() {
            mat.qualityScore = 65 + DateTime.now().second % 35;
          })),
        ),
      ),
    ]);
  }

  // ── TOPIC panel (leaf) ───────────────────────────────────────────────────
  Widget _panelTopic(_Node t) => Container(
    color: _K.bg,
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 54, height: 54,
        decoration: BoxDecoration(
          color: _K.purpleSoft, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.label_rounded, size: 26, color: _K.purple),
      ),
      const SizedBox(height: 16),
      Text(t.title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _K.text),
        textAlign: TextAlign.center),
      const SizedBox(height: 6),
      const Text('Topic', style: TextStyle(fontSize: 13, color: _K.muted)),
      const SizedBox(height: 22),
      Row(mainAxisSize: MainAxisSize.min, children: [
        _BtnOutline(label: 'Rename', icon: Icons.edit_outlined, onTap: () => _rename(t)),
        const SizedBox(width: 10),
        _BtnDanger(label: 'Delete', icon: Icons.delete_outline, onTap: () => _delete(t)),
      ]),
    ])),
  );

  // ── bottom bar ────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    if (_selected == null) return const SizedBox.shrink();
    final diff = DateTime.now().difference(_lastSaved);
    final txt = diff.inSeconds < 60 ? 'Saved just now'
              : diff.inMinutes < 60 ? 'Saved ${diff.inMinutes}m ago'
              : 'Saved ${diff.inHours}h ago';
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: _K.white,
        border: Border(top: BorderSide(color: _K.border)),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_outline_rounded, size: 14, color: _K.green),
        const SizedBox(width: 6),
        Text(txt, style: const TextStyle(
          fontSize: 12, color: _K.muted, fontWeight: FontWeight.w600)),
        const Spacer(),
        _BtnGenerate(
          label: 'Generate Question',
          icon: Icons.auto_awesome_rounded,
          onTap: _openExam),
      ]),
    );
  }

  // ── dialog helpers ────────────────────────────────────────────────────────
  Future<String?> _dlgInput(String t, String h, String init, String act) =>
    showDialog<String>(
      context: context, barrierDismissible: false,
      builder: (_) => _DlgInput(title: t, hint: h, init: init, action: act));

  Future<bool> _dlgConfirm(String body, String act, {bool danger = false}) async {
    final r = await showDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (_) => _DlgConfirm(body: body, action: act, danger: danger));
    return r ?? false;
  }
}
