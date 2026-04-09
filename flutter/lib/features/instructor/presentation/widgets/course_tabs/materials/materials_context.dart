// ignore_for_file: unused_element
import 'package:flutter/material.dart';

import '../../../../data/modules_models.dart';
import '../../../../data/materials_models.dart';
import '../../../../data/topics_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Color palette (shared across all materials sub-widgets)
// ─────────────────────────────────────────────────────────────────────────────
class MatK {
  MatK._();
  static const purple     = Color(0xFF7C3AED);
  static const purpleSoft = Color(0xFFF5F3FF);
  static const purpleBd   = Color(0xFFDDD6FE);
  static const amber      = Color(0xFFD97706);
  static const amberSoft  = Color(0xFFFFFBEB);
  static const green      = Color(0xFF16A34A);
  static const greenSoft  = Color(0xFFF0FDF4);
  static const redSoft    = Color(0xFFFFF1F2);
  static const blue       = Color(0xFF2563EB);
  static const blueSoft   = Color(0xFFEFF6FF);
  static const blueMid    = Color(0xFFDBEAFE);
  static const div        = Color(0xFFEEEEEE);
  static const bg         = Color(0xFFF6F7F9);
  static const sidebar    = Color(0xFFFAFAFA);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Context types
// ─────────────────────────────────────────────────────────────────────────────
enum MatCType { module, material, topic }

class MatCtx {
  final MatCType       type;
  final ModuleItem?    module;
  final MaterialItem?  material;
  final TopicItem?     topic;

  const MatCtx._({required this.type, this.module, this.material, this.topic});

  factory MatCtx.module(ModuleItem m) =>
      MatCtx._(type: MatCType.module, module: m);

  factory MatCtx.material(ModuleItem m, MaterialItem mat) =>
      MatCtx._(type: MatCType.material, module: m, material: mat);

  factory MatCtx.topic(ModuleItem m, MaterialItem mat, TopicItem t) =>
      MatCtx._(type: MatCType.topic, module: m, material: mat, topic: t);
}
