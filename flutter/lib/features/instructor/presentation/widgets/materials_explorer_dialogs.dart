import 'package:flutter/material.dart';
import 'materials_explorer_constants.dart';

// =============================================================================
//  DIALOGS
// =============================================================================

class DlgInput extends StatefulWidget {
  final String title, hint, init, action;
  const DlgInput({
    super.key,
    required this.title,
    required this.hint,
    required this.init,
    required this.action,
  });
  @override State<DlgInput> createState() => _DlgInputState();
}

class _DlgInputState extends State<DlgInput> {
  late final TextEditingController _c;
  bool _err = false;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.init);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  void _submit() {
    final t = _c.text.trim();
    if (t.isEmpty) { setState(() => _err = true); return; }
    Navigator.of(context).pop(t);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Container(
      width: 400,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: K.blueSoft, borderRadius: BorderRadius.circular(9),),
              child: const Icon(Icons.edit_rounded, size: 17, color: K.blue),),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: K.text),),),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.close_rounded, size: 17, color: K.muted),),
          ],),
          const SizedBox(height: 18),
          TextField(
            controller: _c,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            onChanged: (_) { if (_err) setState(() => _err = false); },
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: K.text),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: K.hint, fontWeight: FontWeight.w400),
              filled: true, fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _err ? K.red : K.border),),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _err ? K.red : K.blue, width: 1.5),),
              errorText: _err ? 'Name cannot be empty' : null,),
          ),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: K.muted,
                side: const BorderSide(color: K.border),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),),
              child: const Text('Cancel',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: K.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),),
              child: Text(widget.action,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),),
            ),
          ],),
        ],
      ),
    ),
  );
}

class DlgConfirm extends StatelessWidget {
  final String body, action;
  final bool danger;
  const DlgConfirm({
    super.key,
    required this.body,
    required this.action,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Container(
      width: 360,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: danger ? K.redSoft : K.blueSoft,
                borderRadius: BorderRadius.circular(9),),
              child: Icon(
                danger ? Icons.delete_outline_rounded : Icons.help_outline_rounded,
                size: 17,
                color: danger ? K.red : K.blue,),),
            const SizedBox(width: 12),
            Expanded(child: Text(body,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: K.text),),),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              child: const Icon(Icons.close_rounded, size: 17, color: K.muted),),
          ],),
          const SizedBox(height: 22),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: K.muted,
                side: const BorderSide(color: K.border),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),),
              child: const Text('Cancel',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: danger ? K.red : K.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),),
              child: Text(action,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),),
            ),
          ],),
        ],
      ),
    ),
  );
}
