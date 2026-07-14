import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../providers/auth_provider.dart';

/// Schermata iniziale: login Spotify + avviso sui requisiti reali
/// dell'integrazione (Premium, app Spotify installata, BPM manuale).
/// Fa anche da "onboarding": l'istruttore vede questi avvisi prima di poter
/// usare l'app, non sono nascosti in un secondo momento.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoggingIn = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _isLoggingIn = true;
      _error = null;
    });
    final error = await ref.read(authControllerProvider.notifier).login();
    if (!mounted) return;
    setState(() {
      _isLoggingIn = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.pool, size: 72, color: Colors.teal),
              const SizedBox(height: 16),
              Text(
                'AquaGym Tracklist',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Pianifica e riproduci la colonna sonora delle tue lezioni,'
                ' con BPM tagliati su misura per riscaldamento, core e stretching.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prima di iniziare',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      _RequirementRow(
                        icon: Icons.workspace_premium,
                        text: 'Serve un account Spotify Premium: la riproduzione'
                            ' via app remota non funziona con account free.',
                      ),
                      _RequirementRow(
                        icon: Icons.phone_android,
                        text: 'L\'app Spotify ufficiale deve essere installata'
                            ' su questo dispositivo: è lei a riprodurre l\'audio.',
                      ),
                      _RequirementRow(
                        icon: Icons.speed,
                        text: 'Spotify non fornisce più il BPM dei brani via API:'
                            ' lo tagghi tu una volta sola per ogni brano, poi resta salvato.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (!AppConfig.isConfigured)
                Text(
                  'Configurazione mancante: avvia l\'app con --dart-define='
                  'SPOTIFY_CLIENT_ID=... (vedi README).',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton.icon(
                onPressed: (_isLoggingIn || !AppConfig.isConfigured) ? null : _login,
                icon: _isLoggingIn
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: Text(_isLoggingIn ? 'Connessione...' : 'Collega Spotify'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RequirementRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
