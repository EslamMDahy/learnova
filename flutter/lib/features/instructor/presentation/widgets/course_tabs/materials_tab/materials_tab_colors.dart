import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Color palette — shared across the materials tab widgets
// ─────────────────────────────────────────────────────────────────────────────
class MaterialsTabColors {
  MaterialsTabColors._();

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

// Internal alias used within this feature — keeps private API consistent
typedef _K = MaterialsTabColors;
