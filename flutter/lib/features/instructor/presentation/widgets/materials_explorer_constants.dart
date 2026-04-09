import 'package:flutter/material.dart';

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
//  Enums
// ─────────────────────────────────────────────────────────────────────────────
enum _NK { module, material, topic }
enum _MK { video, pdf, doc, ppt }

// ─────────────────────────────────────────────────────────────────────────────
//  Data model   Module → [Material → [Topic]]
// ─────────────────────────────────────────────────────────────────────────────
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
