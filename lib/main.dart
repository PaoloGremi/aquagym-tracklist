import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/local_db/local_database.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/core_providers.dart';
import 'presentation/screens/lesson_list_screen.dart';
import 'presentation/screens/library_screen.dart';
import 'presentation/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive richiede init asincrono (apertura box su disco) prima che
  // qualunque repository possa leggere/scrivere: lo facciamo qui, una
  // sola volta, e passiamo l'istanza già pronta ai provider tramite
  // override (vedi commento su localDatabaseProvider).
  final db = LocalDatabase();
  await db.init();

  runApp(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(db)],
      child: const AquaGymApp(),
    ),
  );
}

class AquaGymApp extends StatelessWidget {
  const AquaGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AquaGym Tracklist',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

/// Mostra il login finché l'utente non è collegato a Spotify, poi la
/// shell principale dell'app.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authControllerProvider);

    switch (status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.loggedOut:
        return const LoginScreen();
      case AuthStatus.loggedIn:
        return const HomeShell();
    }
  }
}

/// Shell con bottom navigation: Libreria (import + tagging BPM) e Lezioni
/// (builder, editor, avvio Live).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _screens = [LessonListScreen(), LibraryScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Lezioni'),
          NavigationDestination(icon: Icon(Icons.library_music), label: 'Brani'),
        ],
      ),
    );
  }
}
