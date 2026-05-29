/// J7 (Plan v2): AmbientRetrieval zeigt nie mehr als eine Karte.
///
/// Connection priorisiert, sonst top-1 Resurface, sonst nichts.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:second_brain/models/note_model.dart';
import 'package:second_brain/providers/glass_settings_provider.dart';
import 'package:second_brain/widgets/ambient_retrieval.dart';

Note _note(String id) {
  final t = DateTime(2026, 1, 1);
  return Note(
    id: id,
    title: 'Note $id',
    content: 'body',
    created: t,
    modified: t,
    status: NoteStatus.inbox,
    para: ParaCategory.inbox,
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => GlassSettingsProvider(),
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

const _kicker = 'TAUCHT WIEDER AUF';
const _connKicker = 'DEIN GEHIRN SIEHT EINEN ZUSAMMENHANG';

void main() {
  testWidgets('zwei Resurface-Notizen rendern nur eine Karte',
      (tester) async {
    await _pump(
      tester,
      AmbientRetrieval(resurfacedNotes: [_note('a'), _note('b')]),
    );
    expect(find.text(_kicker), findsOneWidget); // nicht zwei
  });

  testWidgets('Connection plus Resurface zeigt nur die Connection',
      (tester) async {
    await _pump(
      tester,
      AmbientRetrieval(
        connection: const {
          'note_a_title': 'A',
          'note_b_title': 'B',
          'explanation': 'weil',
        },
        resurfacedNotes: [_note('a')],
      ),
    );
    expect(find.text(_connKicker), findsOneWidget);
    expect(find.text(_kicker), findsNothing); // Resurface unterdrueckt
  });

  testWidgets('nichts vorhanden rendert keine Karte', (tester) async {
    await _pump(tester, const AmbientRetrieval());
    expect(find.text(_kicker), findsNothing);
    expect(find.text(_connKicker), findsNothing);
  });

  testWidgets('fallbackResurfaced greift wenn Server-Liste leer ist',
      (tester) async {
    await _pump(
      tester,
      AmbientRetrieval(fallbackResurfaced: _note('fb')),
    );
    expect(find.text(_kicker), findsOneWidget);
  });
}
