import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../services/cloud.dart';
import '../ui.dart';
import 'lists.dart';

/// «مما استشهد به العلماء»: verses scholars quoted, with book and page.
class ShawahidScreen extends StatelessWidget {
  const ShawahidScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مما استشهد به العلماء')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        Text('أبيات استشهد بها العلماء في كتبهم، مع اسم الكتاب والجزء والصفحة. اضغط على الصفحة لتفتح الكتاب في «تراث».',
            style: TextStyle(fontSize: 15, color: C.muted(context), height: 1.6)),
        const SizedBox(height: 12),
        for (final s in Library.shawahidScholars)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              onTap: () => push(context, _ScholarShawahid(scholar: s)),
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Avatar(s.replaceFirst('ابن ', '').substring(0, 1)),
                const SizedBox(width: 12),
                Expanded(child: Text(s, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink(context)))),
                Text(Ar.num(_shown().where((x) => x.scholar == s).length), style: TextStyle(color: C.muted(context))),
                Icon(Icons.chevron_left_rounded, color: C.muted(context)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _ScholarShawahid extends StatelessWidget {
  final String scholar;
  const _ScholarShawahid({required this.scholar});
  @override
  Widget build(BuildContext context) {
    final list = _shown().where((x) => x.scholar == scholar).toList();
    return Scaffold(
      appBar: AppBar(title: Text('مما استشهد به $scholar')),
      body: list.isEmpty
          ? const EmptyNote(Icons.menu_book_outlined, 'تُضاف شواهده قريباً بإذن الله.')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              for (final x in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SoftCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (x.draft) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('مسودة للمراجعة: لا يراها غير المطوّر', style: TextStyle(fontSize: 13, color: C.accent(context)))),
                      for (final l in x.lines) Padding(padding: const EdgeInsets.only(bottom: 6), child: VerseLines(l, size: 21)),
                      Divider(color: C.line(context)),
                      if (x.poet.isNotEmpty)
                        InkWell(
                          onTap: Library.poetByName.containsKey(x.poet) ? () => openPoet(context, x.poet) : null,
                          child: Text('القائل: ${x.poet}', style: TextStyle(fontWeight: FontWeight.w700, color: C.ink(context))),
                        ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () {
                          final q = Uri.encodeComponent(x.lines.first.join(' '));
                          final url = x.url.isNotEmpty ? x.url : 'https://app.turath.io/search?q=$q';
                          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        },
                        child: Text('«${x.book}»${x.vol.isEmpty ? '' : ' (${x.vol}/${x.page})'}${x.vol.isEmpty && x.page.isNotEmpty ? ' ص ${x.page}' : ''} — افتح في «تراث»',
                            style: TextStyle(color: C.accent(context), decoration: TextDecoration.underline)),
                      ),
                    ]),
                  ),
                ),
            ]),
    );
  }
}

/// Drafts wait for the developer's reading, so readers do not see them.
Iterable<Shahid> _shown() => Library.shawahid.where((x) => !x.draft || Cloud.i.isDev);
