# AquaGym Tracklist

App Flutter per istruttori di acquagym: collega Spotify, tagga manualmente il
BPM dei brani, costruisci lezioni divise in riscaldamento / core / stretching
con range BPM e durate personalizzate, e riproducile a bordo vasca.

## Limiti tecnici noti (leggere prima di iniziare)

- **Il BPM non è ottenibile automaticamente da Spotify.** L'endpoint
  `audio-features` è deprecato dal 27/11/2024 per le nuove app: il BPM va
  taggato manualmente in libreria (una volta sola per brano, resta salvato).
- **Serve un account Spotify Premium** per la riproduzione via SDK
  (App Remote / Web Playback). Con account Free il login funziona ma
  `play()` fallirà.
- **Serve l'app Spotify ufficiale installata** sul device di test: è lei a
  riprodurre l'audio, l'app AquaGym Tracklist si limita a comandarla.
  Su emulatore Android/simulatore iOS senza l'app Spotify installata la
  riproduzione non funziona: testare su device fisico.
- Non è possibile alterare velocità/tempo dei brani (audio protetto DRM):
  il BPM serve solo a **selezionare** i brani giusti per fase, non a
  "adattarli" al ritmo.

## 1. Scaffolding del progetto

Questo repository contiene `lib/`, `test/` e `pubspec.yaml` ma non le
cartelle native `android/` e `ios/` (vengono generate da Flutter stesso,
riscriverle a mano produrrebbe solo boilerplate meno affidabile di quello
ufficiale). Dalla root del progetto:

```bash
flutter create .
flutter pub get
```

Questo aggiunge `android/`, `ios/` (e opzionalmente `macos/`, `web/`, ecc.)
senza toccare `lib/` e `pubspec.yaml` già presenti.

## 2. Creare l'app su Spotify for Developers

1. Vai su https://developer.spotify.com/dashboard e crea una nuova app.
2. Redirect URI: aggiungi esattamente `aquagymtracklist://callback`
   (o lo scheme che scegli — deve coincidere con `SPOTIFY_REDIRECT_URI`
   passato all'avvio, vedi punto 6).
3. Abilita "Android" e "iOS" nelle impostazioni dell'app:
   - Android: inserisci il package name (es. `com.tuoazienda.aquagymtracklist`,
     deve combaciare con `applicationId` in `android/app/build.gradle`) e lo
     SHA-1 del keystore di debug (`cd android && ./gradlew signingReport`).
   - iOS: inserisci il Bundle ID (deve combaciare con quello in Xcode).
4. Copia il **Client ID**: serve al punto 6. Non serve il Client Secret
   (il flusso PKCE non lo usa, e non va mai distribuito in un'app mobile).

## 3. Configurazione Android

In `android/app/src/main/AndroidManifest.xml`, dentro `<application>`:

```xml
<!-- Necessario per l'App Remote SDK: rende visibile il pacchetto Spotify
     nonostante le restrizioni di package visibility di Android 11+ -->
<queries>
  <package android:name="com.spotify.music" />
</queries>

<activity
  android:name=".MainActivity"
  ...>
  <!-- Intent filter per intercettare il redirect OAuth (flutter_web_auth_2) -->
  <intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="aquagymtracklist" />
  </intent-filter>
</activity>
```

Il package `spotify_sdk` scarica la libreria Android App Remote via Maven
automaticamente: non serve aggiungere manualmente l'AAR.

## 4. Configurazione iOS

In `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>aquagymtracklist</string>
    </array>
  </dict>
</array>

<key>LSApplicationQueriesSchemes</key>
<array>
  <string>spotify</string>
</array>
```

A differenza di Android, l'iOS SDK di Spotify **non è distribuito su
CocoaPods trunk**: va scaricato come `.xcframework` dalla pagina
https://github.com/spotify/ios-sdk (sezione Releases) e trascinato in
Xcode su Runner > Frameworks, oppure referenziato via Podfile puntando al
repo git, secondo le istruzioni aggiornate nella documentazione ufficiale
(https://developer.spotify.com/documentation/ios). Verificare la
compatibilità con la versione del package `spotify_sdk` installata.

## 5. Configurazione macOS (opzionale, solo se testi come app desktop)

Le entitlements per rete in uscita (`com.apple.security.network.client`) e
Keychain (`keychain-access-groups`, richiesto da `flutter_secure_storage`
per salvare i token Spotify) sono già presenti in
`macos/Runner/DebugProfile.entitlements` e `Release.entitlements`.

Manca però la **firma del target Runner**, volutamente non versionata nel
`project.pbxproj` perché legata al tuo account Apple personale (chi fa
fork del progetto ha un Team diverso dal mio, quindi committare il mio
avrebbe rotto la build per chiunque altro). Il Team ID va in un file
locale, ignorato da git:

1. Trova il tuo **Team ID**: apri il **workspace**
   (`open macos/Runner.xcworkspace`) → progetto **Runner** → target
   **Runner** → tab **Signing & Capabilities** → spunta
   **"Automatically manage signing"** e scegli il tuo **Team** nel menu
   (basta un Apple ID personale gratuito, non serve un account developer a
   pagamento per lo sviluppo/test locale; se non hai account collegati:
   **Xcode → Settings → Accounts → "+"**).
2. Copia `macos/Runner/Configs/Local.xcconfig.example` in
   `macos/Runner/Configs/Local.xcconfig` (già in `.gitignore`) e incolla lì
   il tuo Team ID.
3. Se compare un errore "Failed to register bundle identifier", il
   `com.example.aquagym_tracklist` di default è già in uso da qualcun
   altro: cambialo in qualcosa di univoco (es. `com.tuonome.aquagymtracklist`)
   e, se avevi già configurato la piattaforma iOS su Spotify, aggiorna
   anche lì il Bundle ID.
4. `flutter clean` prima del primo run dopo aver configurato la firma.

## 6. Avvio dell'app

```bash
flutter run \
  --dart-define=SPOTIFY_CLIENT_ID=<il tuo client id> \
  --dart-define=SPOTIFY_REDIRECT_URI=aquagymtracklist://callback
```

Se `SPOTIFY_CLIENT_ID` non è impostato, l'app mostra un avviso nella
schermata di login e blocca il pulsante "Collega Spotify".

## 7. Test

```bash
flutter test
```

Copre l'algoritmo di generazione scaletta (`GenerateSetlistUseCase`) e il
parsing delle risposte della Spotify Web API (`Track.fromSpotifyJson`).

## Struttura del progetto

```
lib/
  core/            configurazione (dart-define), tema
  domain/          modelli puri (Track, LessonPlan, LessonPhase, PhaseType)
                   e l'algoritmo di generazione scaletta
  data/            Spotify (auth PKCE, Web API client, App Remote wrapper),
                   persistenza locale (Hive), repository
  presentation/    provider Riverpod, schermate, widget riutilizzabili
```

## Perché Hive e non drift/sqflite

I due aggregati principali (Track taggato, LessonPlan con fasi annidate)
sono document-like: non servono join SQL, solo lookup per id e liste
complete. Hive permette di salvare direttamente le `Map<String, dynamic>`
prodotte da `toDbMap()` senza generare `TypeAdapter` con `build_runner`,
quindi il progetto è buildabile subito dopo `flutter pub get` senza uno
step di code generation. Se in futuro servissero query relazionali (es.
statistiche cross-lezione) si può migrare a drift senza toccare il domain
layer, che non conosce Hive.

## TODO da decidere

- Logo/icona app (la palette in `core/theme/app_theme.dart` è già allineata
  al branding "Aquamore": teal su sfondo quasi nero, tema scuro unico).
- Se servono più istruttori sullo stesso device con librerie separate,
  serve un concetto di "profilo" non presente in questa prima versione.
- Eventuale limite anti-ripetizione tra lezioni consecutive (oggi
  l'anti-ripetizione vale solo all'interno della stessa lezione).
