import 'package:flutter/material.dart';

import '../../../../../../../core/theme/app_theme.dart';
import '../../../../../data/modules_models.dart';
import '../materials_context.dart';

/// Dialog for changing a module's position within a course.
/// Returns the selected 1-based position (int) or null if cancelled.
class MatChangePositionDialog extends StatefulWidget {
  final ModuleItem module;
  final List<ModuleItem> modules;

  const MatChangePositionDialog({
    super.key,
    required this.module,
    required this.modules,
  });

  @override
  State<MatChangePositionDialog> createState() =>
      _MatChangePositionDialogState();
}

class _MatChangePositionDialogState extends State<MatChangePositionDialog> {
  late int _selectedPosition;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.module.orderIndex + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Change Module Position',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '"${widget.module.title}" is currently at position #${widget.module.orderIndex + 1}.',
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedPosition,
                decoration: InputDecoration(
                  labelText: 'New position',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                ),
                items: List.generate(
                  widget.modules.length,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(
                      '#${i + 1}  —  ${widget.modules[i].title}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedPosition = v);
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: MatK.div),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(context, _selectedPosition),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Move'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
