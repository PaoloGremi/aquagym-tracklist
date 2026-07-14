import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/models/lesson_plan.dart';
import '../../domain/models/track.dart';

/// Persistenza locale basata su Hive.
///
/// Scelta di design (Hive vs drift/sqflite): i nostri due aggregati
/// (Track taggato, LessonPlan con fasi annidate) sono document-like, non
/// relazionali — non servono join SQL, solo lookup per id e liste complete.
/// Hive ci permette di salvare direttamente `Map<String, dynamic>` prodotte
/// da `toDbMap()` SENZA generare TypeAdapter con build_runner (li serviremmo
/// solo per storare oggetti Dart tipizzati direttamente): usando
/// `Box<Map>` e i metodi `toDbMap`/`fromDbMap` già presenti sui modelli,
/// evitiamo uno step di code generation e il progetto resta immediatamente
/// buildabile dopo `flutter pub get`. Se in futuro servissero query
/// relazionali complesse (es. statistiche cross-lezione) si può migrare a
/// drift senza toccare il domain layer, che non conosce Hive.
class LocalDatabase {
  static const tracksBoxName = 'tracks_box';
  static const lessonsBoxName = 'lessons_box';

  late final Box<Map> _tracksBox;
  late final Box<Map> _lessonsBox;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _tracksBox = await Hive.openBox<Map>(tracksBoxName);
    _lessonsBox = await Hive.openBox<Map>(lessonsBoxName);
    _initialized = true;
  }

  // ---- Tracks ----

  Future<void> upsertTrack(Track track) =>
      _tracksBox.put(track.spotifyId, track.toDbMap());

  Track? getTrack(String spotifyId) {
    final map = _tracksBox.get(spotifyId);
    return map != null ? Track.fromDbMap(map) : null;
  }

  List<Track> getAllTracks() =>
      _tracksBox.values.map((m) => Track.fromDbMap(m)).toList();

  Future<void> deleteTrack(String spotifyId) => _tracksBox.delete(spotifyId);

  // ---- Lessons ----

  Future<void> upsertLesson(LessonPlan plan) =>
      _lessonsBox.put(plan.id, plan.toDbMap());

  List<LessonPlan> getAllLessons() {
    return _lessonsBox.values
        .map((m) => LessonPlan.fromDbMap(m, getTrack))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  LessonPlan? getLesson(String id) {
    final map = _lessonsBox.get(id);
    return map != null ? LessonPlan.fromDbMap(map, getTrack) : null;
  }

  Future<void> deleteLesson(String id) => _lessonsBox.delete(id);
}
