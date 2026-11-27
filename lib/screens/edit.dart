import 'package:flutter/material.dart';

import '../data.dart';
import '../ui.dart';

/// Developer: correct a piece — the poet's name and the wording or vowelling of each
/// hemistich. The correction goes to every reader; «أرجِع الأصل» takes it back.
class EditPieceScreen extends StatefulWidget {
  /// 'p:<selection number>' for a selection of the book, 's:<piece id>' for a shown piece.
  final String editKey;
  final String poet;
  final List<List<String>> lines;
  const EditPieceScreen({super.key, required this.editKey, required this.poet, required this.lines});

  EditPieceScreen.poem(Poem p, {super.key})
      : editKey = p.fromShahid ? 's:${p.shahidId}' : 'p:${p.id}',
        poet = p.poet,
        lines = p.lines;

  EditPieceScreen.piece(Shahid x, {super.key})
      : editKey = 's:${x.id}',
        poet = x.poet,
        lines = x.lines;

  @override
  State<EditPieceScreen> createState() => _EditPieceState();
}

class _EditPieceState extends State<EditPieceScreen> {
  late final _poet = TextEditingController(text: widget.poet);
  late final _lines = [
    for (final l in widget.lines) [for (final h in l) TextEditingController(text: h)]
  ];

  @override
  void dispose() {
    _poet.dispose();
    for (final l in _lines) {
      for (final c in l) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _save() {
    // An emptied hemistich keeps what it had: a verse never loses a half by mistake.
    final lines = [
      for (var i = 0; i < _lines.length; i++)
        [
          for (var j = 0; j < _lines[i].length; j++) _lines[i][j].text.trim().isEmpty ? widget.lines[i][j] : _lines[i][j].text.trim()
        ]
    ];
    final poet = _poet.text.trim();
    Store.i.setEdit(widget.editKey, poet: poet.isEmpty ? widget.poet : poet, lines: lines);
    toast(context, 'حُفظ التعديل ويصل إلى القرّاء');
    Navigator.pop(context);
  }

  void _reset() {
    Store.i.setEdit(widget.editKey);
    toast(context, 'أُرجع إلى الأصل');
    Navigator.pop(context);
  }

  InputDecoration _box(BuildContext context, String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: C.card(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: C.line(context))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: C.line(context))),
      );

  @override
  Widget build(BuildContext context) {
    final edited = Store.i.edits.containsKey(widget.editKey);
    return Scaffold(
      appBar: AppBar(title: const Text('تحرير')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        Text('للمطوّر: عدّل اسم الشاعر أو نصّ الأبيات وتشكيلها ثم احفظ.', style: TextStyle(fontSize: 14.5, color: C.muted(context))),
        const SizedBox(height: 14),
        TextField(controller: _poet, style: const TextStyle(fontSize: 18), decoration: _box(context, 'اسم الشاعر')),
        for (var i = 0; i < _lines.length; i++) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
            child: Text('البيت ${Ar.num(i + 1)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.accent(context))),
          ),
          for (var j = 0; j < _lines[i].length; j++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _lines[i][j],
                maxLines: null,
                style: const TextStyle(fontFamily: verseFont, fontSize: 22, height: 1.7),
                decoration: _box(context, _lines[i].length == 1 ? 'النص' : (j == 0 ? 'الصدر' : 'العجز')),
              ),
            ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: _save,
          icon: const Icon(Icons.check_rounded),
          label: const Text('حفظ', style: TextStyle(fontSize: 17)),
        ),
        if (edited) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _reset,
            icon: const Icon(Icons.undo_rounded),
            label: const Text('أرجِع الأصل', style: TextStyle(fontSize: 16)),
          ),
        ],
      ]),
    );
  }
}
