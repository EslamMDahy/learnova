import '../../../../data/materials_models.dart';
import '../../../../data/modules_models.dart';
import '../../../../data/topics_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Selection context types for the materials tab
// ─────────────────────────────────────────────────────────────────────────────

/// Discriminates whether the current selection is a module, material, or topic.
enum MaterialTabContextType { module, material, topic }

// Internal alias kept private to this feature directory.
typedef _CType = MaterialTabContextType;

/// Holds the currently selected node in the materials sidebar.
/// At most one of [module], [material], [topic] is populated at a time,
/// depending on the [type].
class MaterialTabContext {
  final MaterialTabContextType type;
  final ModuleItem?             module;
  final MaterialItem?           material;
  final TopicItem?              topic;

  const MaterialTabContext._(
      {required this.type, this.module, this.material, this.topic});

  factory MaterialTabContext.module(ModuleItem m) =>
      MaterialTabContext._(type: MaterialTabContextType.module, module: m);

  factory MaterialTabContext.material(ModuleItem m, MaterialItem mat) =>
      MaterialTabContext._(
          type: MaterialTabContextType.material, module: m, material: mat);

  factory MaterialTabContext.topic(
          ModuleItem m, MaterialItem mat, TopicItem t) =>
      MaterialTabContext._(
          type: MaterialTabContextType.topic,
          module: m,
          material: mat,
          topic: t);
}

// Internal alias kept private to this feature directory.
typedef _Ctx = MaterialTabContext;
