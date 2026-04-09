import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'upload_materials_dialog.dart';
import 'package:learnova/features/instructor/presentation/widgets/create_exam_content.dart';
import 'package:learnova/features/instructor/data/courses_models.dart';
import 'package:learnova/features/instructor/presentation/controllers/course_details_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Design tokens
// ─────────────────────────────────────────────────────────────────────────────
class _K {
  static const bg         = Color(0xFFF5F7FA);
  static const white      = Colors.white;
  static const border     = Color(0xFFE8EAED);
  static const text       = Color(0xFF0F1923);
  static const sub        = Color(0xFF475569);
  static const muted      = Color(0xFF7B8EA0);
  static const hint       = Color(0xFFADB8C4);
  // primary blue
  static const blue       = Color(0xFF137FEC);
  static const blueHov    = Color(0xFF0E6DD0);
  static const blueSoft   = Color(0xFFEBF5FF);
  static const blueBorder = Color(0xFFBFDBFE);
  // semantic
  static const green      = Color(0xFF12B76A);
  static const orange     = Color(0xFFF97316);
  static const orangeSoft = Color(0xFFFFF4ED);
  static const purple     = Color(0xFF7C3AED);
  static const purpleSoft = Color(0xFFF5F3FF);
  static const red        = Color(0xFFEF4444);
  static const redSoft    = Color(0xFFFEF2F2);
  static const yellow     = Color(0xFFEAB308);
  // badge
  static const badgePdfBg  = Color(0xFFFEF2F2);
  static const badgePdfFg  = Color(0xFFDC2626);
  static const badgeVidBg  = Color(0xFFEBF5FF);
  static const badgeVidFg  = Color(0xFF1D4ED8);
  static const badgeDocBg  = Color(0xFFEFF6FF);
  static const badgeDocFg  = Color(0xFF1E40AF);
  static const badgePptBg  = Color(0xFFFFF7ED);
  static const badgePptFg  = Color(0xFFC2410C);
  static const badgeRevBg  = Color(0xFFFEF3C7);
  static const badgeRevFg  = Color(0xFFD97706);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Data model   Module → [Material → [Topic]]
// ─────────────────────────────────────────────────────────────────────────────
enum _NK { module, material, topic }
enum _MK { video, pdf, doc, ppt }       // material kind

class _Node {
  final String id;
  _NK   nk;
  String title;
  bool   isExpanded;
  List<_Node> children;
  // material-only fields
  _MK?  mk;
  int   qualityScore;
  List<String> tags;
  String transcript;
  // backend
  int? backendId;
  int? moduleId;

  _Node.module({
    required this.id, required this.title,
    this.isExpanded = true, List<_Node>? children, this.backendId,
  }) : nk = _NK.module, children = children ?? [],
       mk = null, qualityScore = 0, tags = const [], transcript = '';

  _Node.material({
    required this.id, required this.title, required _MK kind,
    this.isExpanded = false, List<_Node>? children,
    this.qualityScore = 0, this.tags = const [],
    this.transcript = '', this.backendId, this.moduleId,
  }) : nk = _NK.material, children = children ?? [], mk = kind;

  _Node.topic({
    required this.id, required this.title, this.backendId, this.moduleId,
  }) : nk = _NK.topic, children = [], isExpanded = false,
       mk = null, qualityScore = 0, tags = const [], transcript = '';
}

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
    void rm(List<_Node> l) { l.removeWhere((n) => n.id == t.id); for (final n in l) {
      rm(n.children);
    } }
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

  void _showUpload() => showDialog(context: context, builder: (_) => const UploadMaterialsDialog());

  void _openExam() {
    _examStep = 1;
    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: '',
      pageBuilder: (_, __, ___) => Material(color: Colors.white, child: SafeArea(
        child: StatefulBuilder(builder: (ctx, ss) => CreateExamContent(
          currentStep: _examStep,
          onBack: () { if (_examStep > 1) { ss(() => _examStep--); } else { Navigator.pop(ctx); } },
          onNext: () { if (_examStep < 3) { ss(() => _examStep++); } else { Navigator.pop(ctx); } },
        )),
      )),
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
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _K.border))),
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
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _K.blue))
            : _roots.isEmpty
              ? _emptyTreeState()
              : ListView(
                  controller: _treeScroll,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: _roots.map((mod) => _ModuleTreeItem(
                    module:      mod,
                    selectedId:  _selected?.id,
                    onModule:    (n) => setState(() { n.isExpanded = !n.isExpanded; _selected = n; }),
                    onMaterial:  (n) => setState(() { n.isExpanded = !n.isExpanded; _selected = n; }),
                    onTopic:     (n) => setState(() => _selected = n),
                    onRename:    _rename,
                    onDelete:    _delete,
                  )).toList(),
                ),
        ),
        // Footer button
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: _K.border))),
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
        decoration: BoxDecoration(color: _K.blueSoft, borderRadius: BorderRadius.circular(14)),
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
    if (sel == null)              return _panelEmpty();
    if (sel.nk == _NK.module)     return _panelModule(sel);
    if (sel.nk == _NK.material)   return _panelMaterial(sel);
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.07),
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
        // Header
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
            _IcBtn(icon: Icons.delete_outline, tip: 'Delete', onTap: () => _delete(mod), col: _K.red),
          ]),
        ),
        // Body
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Upload zone
            _UploadZone(onTap: _showUpload),
            // Materials list
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
      // Main scroll area
      Expanded(child: Container(
        color: const Color(0xFFF8FAFC),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 20, 80),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _MatHeader(mat: mat, onRename: () => _rename(mat), onDelete: () => _delete(mat)),
            const SizedBox(height: 22),
            // ── Topics section ─────────────────────────────────────
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
            // ── Transcript ─────────────────────────────────────────
            _TranscriptCard(mat: mat),
          ]),
        ),
      )),
      // AI sidebar
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

  // ── TOPIC panel (leaf — just shows info) ─────────────────────────────────
  Widget _panelTopic(_Node t) => Container(
    color: _K.bg,
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 54, height: 54,
        decoration: BoxDecoration(color: _K.purpleSoft, borderRadius: BorderRadius.circular(16)),
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
        Text(txt, style: const TextStyle(fontSize: 12, color: _K.muted, fontWeight: FontWeight.w600)),
        const Spacer(),
        _BtnGenerate(label: 'Generate Question', icon: Icons.auto_awesome_rounded,
          onTap: _openExam),
      ]),
    );
  }

  // ── dialog helpers ────────────────────────────────────────────────────────
  Future<String?> _dlgInput(String t, String h, String init, String act) =>
    showDialog<String>(context: context, barrierDismissible: false,
      builder: (_) => _DlgInput(title: t, hint: h, init: init, action: act));

  Future<bool> _dlgConfirm(String body, String act, {bool danger = false}) async {
    final r = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (_) => _DlgConfirm(body: body, action: act, danger: danger));
    return r ?? false;
  }
}

// =============================================================================
//  TREE NODES
// =============================================================================

// One complete module row + its children
class _ModuleTreeItem extends StatelessWidget {
  final _Node module;
  final String? selectedId;
  final ValueChanged<_Node> onModule, onMaterial, onTopic, onRename, onDelete;

  const _ModuleTreeItem({
    required this.module, required this.selectedId,
    required this.onModule, required this.onMaterial, required this.onTopic,
    required this.onRename, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sel = selectedId == module.id;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Module row
      _SidebarRow(
        indent: 0, isSelected: sel,
        leading: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            module.isExpanded
              ? Icons.keyboard_arrow_down_rounded
              : Icons.keyboard_arrow_right_rounded,
            size: 14, color: _K.muted,
          ),
          const SizedBox(width: 5),
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E0),
              borderRadius: BorderRadius.circular(5)),
            child: const Icon(Icons.folder_rounded, size: 12, color: Color(0xFFF97316)),
          ),
        ]),
        title: module.title,
        titleStyle: TextStyle(
          fontSize: 12.5, fontWeight: FontWeight.w700,
          color: sel ? _K.blue : _K.text),
        trailing: _CtxMenu(items: [
          _MItem(icon: Icons.upload_rounded, label: 'Upload material',
            color: _K.blue, onTap: () => onModule(module)),
          const _MDivider(),
          _MItem(icon: Icons.edit_outlined, label: 'Rename',
            onTap: () => onRename(module)),
          _MItem(icon: Icons.delete_outline, label: 'Delete',
            color: _K.red, onTap: () => onDelete(module)),
        ]),
        onTap: () => onModule(module),
      ),
      // Materials
      if (module.isExpanded)
        ...module.children.map((mat) => _MaterialTreeItem(
          mat: mat, selectedId: selectedId,
          onMaterial: onMaterial, onTopic: onTopic,
          onRename: onRename, onDelete: onDelete,
        )),
    ]);
  }
}

class _MaterialTreeItem extends StatelessWidget {
  final _Node mat;
  final String? selectedId;
  final ValueChanged<_Node> onMaterial, onTopic, onRename, onDelete;

  const _MaterialTreeItem({
    required this.mat, required this.selectedId,
    required this.onMaterial, required this.onTopic,
    required this.onRename, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sel   = selectedId == mat.id;
    final icon  = _mkIcon(mat.mk);
    final col   = _mkColor(mat.mk);
    final bg    = _mkBg(mat.mk);
    final topics = mat.children.where((c) => c.nk == _NK.topic).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SidebarRow(
        indent: 1, isSelected: sel,
        leading: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            topics.isNotEmpty
              ? (mat.isExpanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_right_rounded)
              : Icons.remove_rounded,
            size: 13, color: _K.hint,
          ),
          const SizedBox(width: 5),
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
            child: Icon(icon, size: 11, color: col),
          ),
        ]),
        title: mat.title,
        titleStyle: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: sel ? _K.blue : const Color(0xFF2D3748)),
        trailing: _CtxMenu(items: [
          _MItem(icon: Icons.label_outline_rounded, label: 'Add topic manually',
            color: _K.purple, onTap: () => onMaterial(mat)),
          _MItem(icon: Icons.auto_awesome_rounded, label: 'Generate topics with AI',
            color: _K.blue, onTap: () => onMaterial(mat)),
          const _MDivider(),
          _MItem(icon: Icons.edit_outlined, label: 'Rename', onTap: () => onRename(mat)),
          _MItem(icon: Icons.delete_outline, label: 'Delete',
            color: _K.red, onTap: () => onDelete(mat)),
        ]),
        onTap: () => onMaterial(mat),
      ),
      // Topics
      if (mat.isExpanded)
        ...topics.map((t) {
          final tsel = selectedId == t.id;
          return _SidebarRow(
            indent: 2, isSelected: tsel,
            leading: Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: _K.purpleSoft, borderRadius: BorderRadius.circular(4)),
              child: const Icon(Icons.label_rounded, size: 10, color: _K.purple),
            ),
            title: t.title,
            titleStyle: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w500,
              color: tsel ? _K.purple : _K.muted),
            onTap: () => onTopic(t),
          );
        }),
    ]);
  }

  static IconData _mkIcon(_MK? k) {
    switch (k) {
      case _MK.video: return Icons.play_circle_rounded;
      case _MK.doc:   return Icons.description_rounded;
      case _MK.ppt:   return Icons.slideshow_rounded;
      default:        return Icons.picture_as_pdf_rounded;
    }
  }
  static Color _mkColor(_MK? k) {
    switch (k) {
      case _MK.video: return _K.blue;
      case _MK.doc:   return const Color(0xFF1E40AF);
      case _MK.ppt:   return _K.orange;
      default:        return _K.red;
    }
  }
  static Color _mkBg(_MK? k) {
    switch (k) {
      case _MK.video: return _K.blueSoft;
      case _MK.doc:   return _K.badgeDocBg;
      case _MK.ppt:   return _K.orangeSoft;
      default:        return _K.redSoft;
    }
  }
}

// Base sidebar row — animated hover + selected
class _SidebarRow extends StatefulWidget {
  final int indent;
  final bool isSelected;
  final Widget leading;
  final String title;
  final TextStyle titleStyle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SidebarRow({
    required this.indent, required this.isSelected, required this.leading,
    required this.title, required this.titleStyle, required this.onTap,
    this.trailing,
  });
  @override State<_SidebarRow> createState() => _SidebarRowState();
}
class _SidebarRowState extends State<_SidebarRow> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final lp = 14.0 + widget.indent * 18.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          margin: widget.isSelected
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 1)
            : const EdgeInsets.symmetric(vertical: 1),
          padding: EdgeInsets.fromLTRB(
            widget.isSelected ? lp - 4 : lp, 7, 8, 7),
          decoration: BoxDecoration(
            color: widget.isSelected
              ? _K.blueSoft
              : (_h ? const Color(0xFFF4F6F8) : Colors.transparent),
            borderRadius: widget.isSelected
              ? BorderRadius.circular(8) : null,
          ),
          child: Row(children: [
            widget.leading,
            const SizedBox(width: 7),
            Expanded(child: Text(widget.title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: widget.titleStyle)),
            if (widget.trailing != null) widget.trailing!,
          ]),
        ),
      ),
    );
  }
}

// =============================================================================
//  RIGHT PANEL COMPONENTS
// =============================================================================

// ── Upload zone ───────────────────────────────────────────────────────────────
class _UploadZone extends StatefulWidget {
  final VoidCallback onTap;
  const _UploadZone({required this.onTap});
  @override State<_UploadZone> createState() => _UploadZoneState();
}
class _UploadZoneState extends State<_UploadZone> {
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
          color: _h ? const Color(0xFFE4F2FE) : _K.white,
          border: Border.all(
            color: _h ? _K.blue : _K.border,
            width: _h ? 1.5 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 54, height: 54,
            decoration: BoxDecoration(
              color: _h ? _K.blue : _K.blueSoft,
              borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.cloud_upload_rounded, size: 26,
              color: _h ? Colors.white : _K.blue),
          ),
          const SizedBox(height: 14),
          Text('Upload materials to this module',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700,
              color: _h ? _K.blue : _K.text)),
          const SizedBox(height: 5),
          const Text('PDF, DOCX, PPTX, MP4  ·  Max 500 MB',
            style: TextStyle(fontSize: 12.5, color: _K.muted)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              color: _K.blue,
              borderRadius: BorderRadius.circular(9)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.upload_rounded, size: 15, color: Colors.white),
              SizedBox(width: 7),
              Text('Browse Files',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                  color: Colors.white)),
            ]),
          ),
        ]),
      ),
    ),
  );
}

// ── Material list card (inside module panel) ──────────────────────────────────
class _MaterialListCard extends StatefulWidget {
  final _Node mat;
  final VoidCallback onTap, onRename, onDelete;
  const _MaterialListCard({required this.mat, required this.onTap,
    required this.onRename, required this.onDelete});
  @override State<_MaterialListCard> createState() => _MaterialListCardState();
}
class _MaterialListCardState extends State<_MaterialListCard> {
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
            color: _h ? const Color(0xFFF0F5FF) : _K.white,
            border: Border.all(color: _h ? _K.blueBorder : _K.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            _MatIcon(mk: m.mk, size: 42),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                  color: _K.text),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(_mkLabel(m.mk),
                style: const TextStyle(fontSize: 12, color: _K.muted)),
            ])),
            if (m.children.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _K.purpleSoft, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  '${m.children.length} topic${m.children.length == 1 ? "" : "s"}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: _K.purple)),
              ),
            ],
            _IcBtn(icon: Icons.edit_outlined,  tip: 'Rename',
              onTap: widget.onRename),
            _IcBtn(icon: Icons.delete_outline, tip: 'Delete',
              onTap: widget.onDelete, col: _K.red),
            const Icon(Icons.chevron_right_rounded, size: 16, color: _K.hint),
          ]),
        ),
      ),
    );
  }
  static String _mkLabel(_MK? k) {
    switch (k) {
      case _MK.video: return 'Video lecture';
      case _MK.doc:   return 'Word document';
      case _MK.ppt:   return 'Presentation';
      default:        return 'PDF document';
    }
  }
}

// ── Material detail header ────────────────────────────────────────────────────
class _MatHeader extends StatelessWidget {
  final _Node mat;
  final VoidCallback onRename, onDelete;
  const _MatHeader({required this.mat, required this.onRename, required this.onDelete});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Badge row
    Row(children: [
      _MatBadge(mat.mk),
      if (mat.qualityScore > 0 && mat.qualityScore < 60) ...[
        const SizedBox(width: 8),
        const _Pill('⚠ REVIEW NEEDED', _K.badgeRevBg, _K.badgeRevFg),
      ],
    ]),
    const SizedBox(height: 12),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _MatIcon(mk: mat.mk, size: 48),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(mat.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _K.text)),
        const SizedBox(height: 4),
        Text(_mkLabel(mat.mk),
          style: const TextStyle(fontSize: 12.5, color: _K.muted, fontWeight: FontWeight.w600)),
      ])),
      _IcBtn(icon: Icons.edit_outlined,  tip: 'Rename', onTap: onRename),
      _IcBtn(icon: Icons.delete_outline, tip: 'Delete', onTap: onDelete, col: _K.red),
    ]),
  ]);

  static String _mkLabel(_MK? k) {
    switch (k) {
      case _MK.video: return 'Video lecture';
      case _MK.doc:   return 'Word document';
      case _MK.ppt:   return 'Presentation';
      default:        return 'PDF document';
    }
  }
}

// ── Topics section ────────────────────────────────────────────────────────────
class _TopicsSection extends StatelessWidget {
  final _Node mat;
  final List<_Node> topics;
  final bool generating;
  final VoidCallback onAddManual, onGenerateAI;
  final ValueChanged<_Node> onRenameTopic, onDeleteTopic;

  const _TopicsSection({
    required this.mat, required this.topics, required this.generating,
    required this.onAddManual, required this.onGenerateAI,
    required this.onRenameTopic, required this.onDeleteTopic,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _K.white,
      border: Border.all(color: _K.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header bar
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _K.purpleSoft, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.label_rounded, size: 16, color: _K.purple),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Topics',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _K.text)),
            Text('Organise this material into topics',
              style: TextStyle(fontSize: 11.5, color: _K.muted)),
          ])),
          // AI button
          _BtnAI(generating: generating, onTap: onGenerateAI),
          const SizedBox(width: 8),
          // Manual
          _BtnOutline(label: 'Add', icon: Icons.add_rounded, onTap: onAddManual, small: true),
        ]),
      ),
      const Divider(height: 1, color: _K.border),

      // Body
      if (topics.isEmpty && !generating)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
          child: Column(children: [
            const Icon(Icons.label_off_outlined, size: 30, color: _K.hint),
            const SizedBox(height: 10),
            const Text('No topics yet',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _K.text)),
            const SizedBox(height: 4),
            const Text(
              'Add topics manually or let AI generate them from the material content.',
              style: TextStyle(fontSize: 12, color: _K.muted, height: 1.5),
              textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _BtnAI(generating: generating, onTap: onGenerateAI, labeled: true),
              const SizedBox(width: 10),
              _BtnOutline(label: 'Add manually', icon: Icons.add_rounded,
                onTap: onAddManual, small: true),
            ]),
          ]),
        )
      else if (generating)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: _AIGeneratingRow(),
        )
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            ...topics.map((t) => _TopicChip(
              topic: t,
              onRename: () => onRenameTopic(t),
              onDelete: () => onDeleteTopic(t),
            )),
          ]),
        ),
    ]),
  );
}

class _TopicChip extends StatefulWidget {
  final _Node topic;
  final VoidCallback onRename, onDelete;
  const _TopicChip({required this.topic, required this.onRename, required this.onDelete});
  @override State<_TopicChip> createState() => _TopicChipState();
}
class _TopicChipState extends State<_TopicChip> {
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
        color: _h ? _K.purpleSoft : const Color(0xFFFAFAFF),
        border: Border.all(color: _h ? _K.purple : _K.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.label_rounded, size: 12, color: _K.purple),
        const SizedBox(width: 5),
        Text(widget.topic.title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _K.text)),
        const SizedBox(width: 6),
        GestureDetector(onTap: widget.onRename,
          child: const Icon(Icons.edit_outlined, size: 11, color: _K.muted)),
        const SizedBox(width: 3),
        GestureDetector(onTap: widget.onDelete,
          child: const Icon(Icons.close_rounded, size: 11, color: _K.muted)),
      ]),
    ),
  );
}

class _AIGeneratingRow extends StatelessWidget {
  const _AIGeneratingRow();
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 30, height: 30,
      decoration: BoxDecoration(color: _K.blueSoft, borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.auto_awesome_rounded, size: 14, color: _K.blue),
    ),
    const SizedBox(width: 12),
    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('AI is analysing the content and generating topics…',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _K.text)),
      SizedBox(height: 6),
      LinearProgressIndicator(minHeight: 3, color: _K.blue, backgroundColor: _K.blueSoft),
    ])),
  ]);
}

// ── Transcript card ────────────────────────────────────────────────────────────
class _TranscriptCard extends StatelessWidget {
  final _Node mat;
  const _TranscriptCard({required this.mat});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
    decoration: BoxDecoration(
      color: _K.white,
      border: Border.all(color: _K.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: _K.blueSoft, borderRadius: BorderRadius.circular(7)),
          child: const Icon(Icons.article_outlined, size: 14, color: _K.blue)),
        const SizedBox(width: 10),
        const Expanded(child: Text('Transcript & Content',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _K.text))),
        const _TxBtn(label: 'B', bold: true),
        const SizedBox(width: 3),
        const _TxBtn(label: 'I', italic: true),
        const SizedBox(width: 3),
        const _TxBtn(label: 'S̶'),
        const SizedBox(width: 3),
        const _TxBtn(label: '↗'),
      ]),
      const Divider(height: 20, color: _K.border),
      Text(
        mat.transcript.isNotEmpty
          ? mat.transcript
          : 'Transcript will appear here once the material has been processed.',
        style: const TextStyle(fontSize: 13, height: 1.75, color: Color(0xFF1E293B))),
      const SizedBox(height: 12),
      const Row(children: [
        Icon(Icons.auto_fix_high_rounded, size: 12, color: _K.blue),
        SizedBox(width: 6),
        Text('Suggestion: Simplify sentence structure?',
          style: TextStyle(fontSize: 11.5, color: _K.blue, fontWeight: FontWeight.w600)),
      ]),
    ]),
  );
}

// ── AI sidebar ────────────────────────────────────────────────────────────────
class _AISidebar extends StatelessWidget {
  final _Node mat;
  final VoidCallback onRegen;
  const _AISidebar({required this.mat, required this.onRegen});

  @override
  Widget build(BuildContext context) {
    final score = mat.qualityScore.clamp(0, 100);
    final val   = score / 100.0;
    final col   = val >= 0.8 ? _K.green : val >= 0.5 ? _K.yellow : _K.red;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: _K.blueSoft, borderRadius: BorderRadius.circular(7)),
          child: const Icon(Icons.auto_awesome_rounded, size: 13, color: _K.blue)),
        const SizedBox(width: 9),
        const Text('AI Analysis',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _K.text)),
      ]),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Quality Score',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _K.muted)),
        Text('$score/100',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: col)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(value: val, minHeight: 6,
          backgroundColor: _K.bg, color: col)),
      const SizedBox(height: 16),
      const Text('Suggested Tags',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _K.muted)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        ...mat.tags.map((t) => _Tag(t)),
        const _Tag('+', dashed: true),
      ]),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: onRegen,
        icon: const Icon(Icons.refresh_rounded, size: 13),
        label: const Text('Regenerate',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _K.muted,
          side: const BorderSide(color: _K.border),
          padding: const EdgeInsets.symmetric(vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      )),
    ]);
  }
}

// =============================================================================
//  SHARED MICRO-WIDGETS
// =============================================================================

// Material icon — correct icon + color per type
class _MatIcon extends StatelessWidget {
  final _MK? mk;
  final bool isModule;
  final double size;
  const _MatIcon({this.mk, this.isModule = false, required this.size});

  @override
  Widget build(BuildContext context) {
    IconData ic; Color col, bg;
    if (isModule) {
      ic = Icons.folder_rounded; col = _K.blue; bg = _K.blueSoft;
    } else {
      switch (mk) {
        case _MK.video:
          ic = Icons.play_circle_rounded; col = _K.blue; bg = _K.blueSoft; break;
        case _MK.doc:
          ic = Icons.description_rounded;
          col = const Color(0xFF1E40AF); bg = _K.badgeDocBg; break;
        case _MK.ppt:
          ic = Icons.slideshow_rounded; col = _K.orange; bg = _K.orangeSoft; break;
        default:
          ic = Icons.picture_as_pdf_rounded; col = _K.red; bg = _K.redSoft; break;
      }
    }
    final r = size * 0.27;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(r + 2)),
      alignment: Alignment.center,
      child: Icon(ic, size: size * 0.44, color: col),
    );
  }
}

// Material badge pill
class _MatBadge extends StatelessWidget {
  final _MK? mk;
  const _MatBadge(this.mk);
  @override
  Widget build(BuildContext context) {
    String label; Color bg, fg;
    switch (mk) {
      case _MK.video:
        label = 'VIDEO'; bg = _K.badgeVidBg; fg = _K.badgeVidFg; break;
      case _MK.doc:
        label = 'DOCUMENT'; bg = _K.badgeDocBg; fg = _K.badgeDocFg; break;
      case _MK.ppt:
        label = 'PRESENTATION'; bg = _K.badgePptBg; fg = _K.badgePptFg; break;
      default:
        label = 'PDF'; bg = _K.badgePdfBg; fg = _K.badgePdfFg; break;
    }
    return _Pill(label, bg, fg);
  }
}

class _Pill extends StatelessWidget {
  final String label; final Color bg, fg;
  const _Pill(this.label, this.bg, this.fg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(label,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800,
        color: fg, letterSpacing: 0.4)),
  );
}

// Blue primary button
class _BtnPrimary extends StatefulWidget {
  final String label; final IconData icon; final VoidCallback onTap; final bool full;
  const _BtnPrimary({required this.label, required this.icon,
    required this.onTap, this.full = false});
  @override State<_BtnPrimary> createState() => _BtnPrimaryState();
}
class _BtnPrimaryState extends State<_BtnPrimary> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit:  (_) => setState(() => _h = false),
    child: GestureDetector(onTap: widget.onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      width: widget.full ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _h ? _K.blueHov : _K.blue,
        borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: widget.full ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: widget.full ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(widget.icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(widget.label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
              color: Colors.white)),
        ]),
    )),
  );
}

// Outline button
class _BtnOutline extends StatefulWidget {
  final String label; final IconData icon; final VoidCallback onTap; final bool small;
  const _BtnOutline({required this.label, required this.icon,
    required this.onTap, this.small = false});
  @override State<_BtnOutline> createState() => _BtnOutlineState();
}
class _BtnOutlineState extends State<_BtnOutline> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit:  (_) => setState(() => _h = false),
    child: GestureDetector(onTap: widget.onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      padding: EdgeInsets.symmetric(
        horizontal: widget.small ? 10 : 14,
        vertical:   widget.small ? 6  : 9),
      decoration: BoxDecoration(
        color: _h ? const Color(0xFFF1F5F9) : _K.white,
        border: Border.all(color: _K.border),
        borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(widget.icon, size: 13, color: _K.text),
        const SizedBox(width: 5),
        Text(widget.label,
          style: TextStyle(fontSize: widget.small ? 12 : 12.5,
            fontWeight: FontWeight.w600, color: _K.text)),
      ]),
    )),
  );
}

// Danger outline button
class _BtnDanger extends StatefulWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  const _BtnDanger({required this.label, required this.icon, required this.onTap});
  @override State<_BtnDanger> createState() => _BtnDangerState();
}
class _BtnDangerState extends State<_BtnDanger> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit:  (_) => setState(() => _h = false),
    child: GestureDetector(onTap: widget.onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _h ? _K.redSoft : _K.white,
        border: Border.all(color: _h ? _K.red : _K.border),
        borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(widget.icon, size: 13, color: _K.red),
        const SizedBox(width: 5),
        Text(widget.label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _K.red)),
      ]),
    )),
  );
}

// Generate Question button
class _BtnGenerate extends StatefulWidget {
  final String label; final IconData icon; final VoidCallback? onTap;
  const _BtnGenerate({required this.label, required this.icon, this.onTap});
  @override State<_BtnGenerate> createState() => _BtnGenerateState();
}
class _BtnGenerateState extends State<_BtnGenerate> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit:  (_) => setState(() => _h = false),
    child: GestureDetector(onTap: widget.onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: _h ? _K.blueHov : _K.blue,
        borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(widget.icon, size: 14, color: Colors.white),
        const SizedBox(width: 7),
        Text(widget.label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
      ]),
    )),
  );
}

// AI generate button
class _BtnAI extends StatefulWidget {
  final bool generating;
  final VoidCallback onTap;
  final bool labeled;
  const _BtnAI({required this.generating, required this.onTap, this.labeled = false});
  @override State<_BtnAI> createState() => _BtnAIState();
}
class _BtnAIState extends State<_BtnAI> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit:  (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.generating ? null : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        padding: EdgeInsets.symmetric(
          horizontal: widget.labeled ? 12 : 8,
          vertical:   widget.labeled ? 7  : 5),
        decoration: BoxDecoration(
          color: _h && !widget.generating
            ? const Color(0xFFD2E9FD)
            : _K.blueSoft,
          border: Border.all(
            color: _h && !widget.generating ? _K.blue : _K.blueBorder),
          borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          widget.generating
            ? const SizedBox(width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: _K.blue))
            : const Icon(Icons.auto_awesome_rounded, size: 13, color: _K.blue),
          if (widget.labeled) ...[
            const SizedBox(width: 6),
            const Text('Generate with AI',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _K.blue)),
          ],
        ]),
      ),
    ),
  );
}

// Icon button (edit / delete / etc)
class _IcBtn extends StatelessWidget {
  final IconData icon; final String tip; final VoidCallback onTap; final Color col;
  const _IcBtn({required this.icon, required this.tip, required this.onTap,
    this.col = _K.muted});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tip,
    child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
      onTap: onTap, borderRadius: BorderRadius.circular(6),
      child: Padding(padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 17, color: col)),
    ),
  );
}

// Toolbar icon button
class _TbBtn extends StatefulWidget {
  final IconData icon; final String tip; final VoidCallback onTap;
  const _TbBtn({required this.icon, required this.tip, required this.onTap});
  @override State<_TbBtn> createState() => _TbBtnState();
}
class _TbBtnState extends State<_TbBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.tip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(onTap: widget.onTap, child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: _h ? _K.bg : Colors.transparent,
          borderRadius: BorderRadius.circular(6)),
        child: Icon(widget.icon, size: 14, color: _K.hint),
      )),
    ),
  );
}

// Transcript toolbar button
class _TxBtn extends StatefulWidget {
  final String label; final bool bold; final bool italic;
  const _TxBtn({required this.label, this.bold = false, this.italic = false});
  @override State<_TxBtn> createState() => _TxBtnState();
}
class _TxBtnState extends State<_TxBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _h = true),
    onExit:  (_) => setState(() => _h = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      width: 26, height: 26,
      decoration: BoxDecoration(
        color: _h ? _K.bg : Colors.transparent,
        borderRadius: BorderRadius.circular(5)),
      child: Center(child: Text(widget.label, style: TextStyle(
        fontSize: 12,
        fontWeight: widget.bold ? FontWeight.w900 : FontWeight.w500,
        fontStyle: widget.italic ? FontStyle.italic : FontStyle.normal,
        color: _K.muted))),
    ),
  );
}

// Count badge
class _CountBadge extends StatelessWidget {
  final String label;
  const _CountBadge(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: _K.blueSoft, borderRadius: BorderRadius.circular(999)),
    child: Text(label, style: const TextStyle(fontSize: 11,
      fontWeight: FontWeight.w700, color: _K.blue)),
  );
}

// Tag chip
class _Tag extends StatelessWidget {
  final String label; final bool dashed;
  const _Tag(this.label, {this.dashed = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: dashed ? Colors.transparent : const Color(0xFFF1F5F9),
      border: Border.all(color: _K.border),
      borderRadius: BorderRadius.circular(999)),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
      color: dashed ? _K.hint : _K.sub)),
  );
}

// ── Context menu ──────────────────────────────────────────────────────────────
class _MItem {
  final IconData icon; final String label; final Color? color; final VoidCallback onTap;
  const _MItem({required this.icon, required this.label, this.color, required this.onTap});
}
class _MDivider { const _MDivider(); }

class _CtxMenu extends StatelessWidget {
  final List<dynamic> items;
  const _CtxMenu({required this.items});
  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    tooltip: '',
    icon: const Icon(Icons.more_horiz_rounded, size: 14, color: _K.hint),
    padding: EdgeInsets.zero, iconSize: 14,
    onSelected: (i) => (items[i] as _MItem).onTap(),
    itemBuilder: (_) {
      final out = <PopupMenuEntry<int>>[];
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        if (item is _MDivider) {
          out.add(const PopupMenuDivider());
        } else if (item is _MItem) {
          out.add(PopupMenuItem<int>(value: i, child: Row(children: [
            Icon(item.icon, size: 14, color: item.color ?? _K.text),
            const SizedBox(width: 9),
            Text(item.label,
              style: TextStyle(fontSize: 13, color: item.color ?? _K.text)),
          ])));
        }
      }
      return out;
    },
  );
}

// =============================================================================
//  DIALOGS
// =============================================================================
class _DlgInput extends StatefulWidget {
  final String title, hint, init, action;
  const _DlgInput({required this.title, required this.hint,
    required this.init, required this.action});
  @override State<_DlgInput> createState() => _DlgInputState();
}
class _DlgInputState extends State<_DlgInput> {
  late final TextEditingController _c;
  bool _err = false;
  @override void initState() { super.initState(); _c = TextEditingController(text: widget.init); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  void _submit() {
    final t = _c.text.trim();
    if (t.isEmpty) { setState(() => _err = true); return; }
    Navigator.of(context).pop(t);
  }
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Container(width: 400, padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 34, height: 34,
              decoration: BoxDecoration(color: _K.blueSoft,
                borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.edit_rounded, size: 17, color: _K.blue)),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _K.text))),
            GestureDetector(onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.close_rounded, size: 17, color: _K.muted)),
          ]),
          const SizedBox(height: 18),
          TextField(
            controller: _c, autofocus: true,
            onSubmitted: (_) => _submit(),
            onChanged: (_) { if (_err) setState(() => _err = false); },
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _K.text),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: _K.hint, fontWeight: FontWeight.w400),
              filled: true, fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _err ? _K.red : _K.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _err ? _K.red : _K.blue, width: 1.5)),
              errorText: _err ? 'Name cannot be empty' : null),
          ),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _K.border), foregroundColor: _K.muted,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _K.blue, foregroundColor: Colors.white, elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text(widget.action,
                style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
        ]),
    ),
  );
}

class _DlgConfirm extends StatelessWidget {
  final String body, action; final bool danger;
  const _DlgConfirm({required this.body, required this.action, required this.danger});
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Container(width: 380, padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 34, height: 34,
              decoration: BoxDecoration(
                color: danger ? _K.redSoft : _K.blueSoft,
                borderRadius: BorderRadius.circular(9)),
              child: Icon(
                danger ? Icons.delete_outline_rounded : Icons.help_outline_rounded,
                size: 17, color: danger ? _K.red : _K.blue)),
            const SizedBox(width: 12),
            Expanded(child: Text(body,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _K.text))),
          ]),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _K.border), foregroundColor: _K.muted,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: danger ? _K.red : _K.blue,
                foregroundColor: Colors.white, elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text(action,
                style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
        ]),
    ),
  );
}
