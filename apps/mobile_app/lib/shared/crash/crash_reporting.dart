import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether this build was made to be able to send crash reports:
/// `--dart-define=CRASH_REPORTING=true`. Off by default: a normal build, a test
/// run or a local run never starts the service, whatever the owner consented.
const bool kCrashReportingFlag = bool.fromEnvironment('CRASH_REPORTING');

/// The Sentry project address (EU organisation), given at build time with
/// `--dart-define=SENTRY_DSN=...` by the owner; never written in the repository.
const String kSentryDsn = String.fromEnvironment('SENTRY_DSN');

/// The part of Sentry the app starts and stops - a seam so the rules below are
/// tested without a network, and so another provider can replace Sentry.
abstract class CrashTransport {
  /// Starts the service. May throw.
  Future<void> start({required String dsn, required String environment, required String release});

  /// Stops it: nothing more is captured or sent.
  Future<void> stop();
}

/// Sentry (organisation in the EU region), started only after the owner's
/// consent, with the strictest options: see [scrubCrashEvent].
class SentryCrashTransport implements CrashTransport {
  @override
  Future<void> start({
    required String dsn,
    required String environment,
    required String release,
  }) {
    return SentryFlutter.init((options) {
      options
        ..dsn = dsn
        ..environment = environment
        ..release = release
        ..debug = false
        // No IP, e-mail, user id or cookies.
        ..sendDefaultPii = false
        // No screenshot (and no view hierarchy, off by default and left that way):
        // a screen can show the medical record.
        ..attachScreenshot = false
        ..attachThreads = false
        // Stability only, not measuring use (that is the "analytics" consent).
        ..enableAutoSessionTracking = false
        ..enableAutoPerformanceTracing = false
        ..enableUserInteractionTracing = false
        ..enableFramesTracking = false
        ..enableWatchdogTerminationTracking = false
        // What the owner touched, what the network answered: none of it leaves.
        ..enableUserInteractionBreadcrumbs = false
        ..enableAutoNativeBreadcrumbs = false
        ..captureFailedRequests = false
        ..maxBreadcrumbs = 30
        ..beforeBreadcrumb = ((breadcrumb, hint) => null)
        ..reportPackages = false
        ..sendClientReports = false
        // Native crashes (unhandled Java/Kotlin, NDK) and ANRs are sent by the
        // Android SDK with the exception's message, on the next launch and before
        // Dart runs: scrubCrashEvent could never filter them. So they are off -
        // privacy before diagnostics. (anrEnabled is ON by default in this
        // package, so it is switched off explicitly.)
        ..enableNativeCrashHandling = false
        ..anrEnabled = false
        ..beforeSend = scrubCrashEvent;
    });
  }

  @override
  Future<void> stop() => Sentry.close();
}

/// The context entries that describe the phone and the app, never what the
/// owner did or wrote. Everything else (notably Flutter's `flutter_error_details`,
/// which carries the failing widget's description) is dropped.
const _keptContexts = {'device', 'os', 'runtime', 'app', 'culture', 'gpu', 'browser'};

/// The last gate before an event leaves the phone: keeps the exception type and
/// the stack trace (our own code's file and function names, which is what finds
/// the bug) and the device/app description, and removes everything that could
/// carry what the owner typed or who they are: the exception text, any message,
/// the user, the request, breadcrumbs, extra data, tags and the other contexts.
SentryEvent? scrubCrashEvent(SentryEvent event, Hint hint) {
  event
    ..message = null
    ..user = null
    ..request = null
    ..breadcrumbs = null
    ..serverName = null
    ..culprit = null
    ..transaction = null;
  // ignore: deprecated_member_use
  event.extra = null;
  event.tags = null;
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    // The type stays ("FormatException"); the text ("... Thor ...") never does.
    exception.value = null;
  }
  event.contexts.removeWhere((key, _) => !_keptContexts.contains(key));

  // What describes the phone stays; what identifies it or its owner does not.
  // The device and app descriptions are REBUILT from an allowlist of fields
  // instead of cleaned: that also drops the ones the SDK adds without a typed
  // field (the installation `id`, the device name - often "<name>'s phone" -,
  // `device_unique_identifier`, the app's per-device hash, the names of the
  // screens that were open).
  final device = event.contexts.device;
  if (device != null) event.contexts.device = _describeDevice(device);
  final app = event.contexts.app;
  if (app != null) event.contexts.app = _describeApp(app);

  for (final exception in event.exceptions ?? const <SentryException>[]) {
    _scrubFrames(exception.stackTrace);
  }
  for (final thread in event.threads ?? const <SentryThread>[]) {
    _scrubFrames(thread.stacktrace);
  }
  return event;
}

/// The phone, as the report needs it (model, system family, memory, screen):
/// no name, no identifier, no boot time.
SentryDevice _describeDevice(SentryDevice device) => SentryDevice(
      family: device.family,
      model: device.model,
      modelId: device.modelId,
      arch: device.arch,
      manufacturer: device.manufacturer,
      brand: device.brand,
      simulator: device.simulator,
      memorySize: device.memorySize,
      freeMemory: device.freeMemory,
      usableMemory: device.usableMemory,
      lowMemory: device.lowMemory,
      storageSize: device.storageSize,
      freeStorage: device.freeStorage,
      processorCount: device.processorCount,
      cpuDescription: device.cpuDescription,
      processorFrequency: device.processorFrequency,
      screenWidthPixels: device.screenWidthPixels,
      screenHeightPixels: device.screenHeightPixels,
      screenDensity: device.screenDensity,
      screenDpi: device.screenDpi,
      orientation: device.orientation,
      deviceType: device.deviceType,
    );

/// The app, as the report needs it: which build it was. No per-device hash, no
/// screen names, no start time.
SentryApp _describeApp(SentryApp app) => SentryApp(
      name: app.name,
      version: app.version,
      identifier: app.identifier,
      build: app.build,
      buildType: app.buildType,
    );

void _scrubFrames(SentryStackTrace? stackTrace) {
  if (stackTrace == null) return;
  for (final frame in stackTrace.frames) {
    frame
      ..absPath = scrubStackPath(frame.absPath)
      ..fileName = scrubStackPath(frame.fileName);
  }
}

/// A stack frame's file without the build machine's folders (a Windows user
/// name in `C:\Users\<name>\...`): `package:` and `dart:` paths are kept as they
/// are; a file path is cut to what follows its last `/lib/`, else to the file
/// name.
@visibleForTesting
String? scrubStackPath(String? path) {
  if (path == null || path.isEmpty) return path;
  if (path.startsWith('package:') || path.startsWith('dart:')) return path;
  final normalized = path.replaceAll(r'\', '/');
  if (!normalized.contains('/')) return path;
  final lib = normalized.lastIndexOf('/lib/');
  if (lib != -1) return normalized.substring(lib + 1);
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}

/// The owner's "send error reports" decision as the phone remembers it, so the
/// service can start at boot without waiting for the network. The account's own
/// record is `account_consents.diagnostics`; this is its local copy.
class CrashConsentStore {
  const CrashConsentStore();

  static const _key = 'vet_app.diagnostics_consent';

  Future<bool> read() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> write(bool granted) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (granted) {
        await preferences.setBool(_key, true);
      } else {
        await preferences.remove(_key);
      }
    } catch (_) {}
  }
}

/// Error reports, doubly gated and off by default:
///
/// 1. the build must allow it ([kCrashReportingFlag] and a [kSentryDsn]);
/// 2. the owner must have consented ("Invia rapporti sugli errori" in
///    Impostazioni, the `diagnostics` account consent).
///
/// Until both hold nothing is started, collected or stored. Never on web. When
/// the owner withdraws consent, or signs out, the service is stopped.
/// What is sent is limited by [scrubCrashEvent]; no user identifier is ever set.
/// See docs/runbooks/crash_reporting.md and docs/security/10_crash_reporting.md.
class CrashReporting {
  CrashReporting({
    CrashTransport? transport,
    CrashConsentStore store = const CrashConsentStore(),
    bool? enabled,
    String? dsn,
    bool? isWeb,
    Future<({String environment, String release})> Function()? describeApp,
  })  : _transport = transport ?? SentryCrashTransport(),
        _store = store,
        _enabled = enabled ?? kCrashReportingFlag,
        _dsn = dsn ?? kSentryDsn,
        _isWeb = isWeb ?? kIsWeb,
        _describeApp = describeApp ?? _defaultDescribeApp;

  static final CrashReporting instance = CrashReporting();

  final CrashTransport _transport;
  final CrashConsentStore _store;
  final bool _enabled;
  final String _dsn;
  final bool _isWeb;
  final Future<({String environment, String release})> Function() _describeApp;
  bool _active = false;

  /// True while the service is running (build allows it AND consent given).
  bool get isActive => _active;

  /// Whether this build can send reports at all, whatever the consent.
  bool get isAvailable => !_isWeb && _enabled && _dsn.isNotEmpty;

  static Future<({String environment, String release})> _defaultDescribeApp() async {
    final info = await PackageInfo.fromPlatform();
    // The package name tells the three apps (prod / francesco / roberto) apart.
    return (environment: info.packageName, release: '${info.version}+${info.buildNumber}');
  }

  /// At boot: starts the service only if the build allows it and the owner has
  /// already consented. Never throws, never delays the app for long.
  Future<void> initialize() async {
    if (!isAvailable) return;
    if (!await _store.read()) return;
    await _start();
  }

  /// The owner's decision (the Impostazioni switch, or the account's stored
  /// decision loaded after sign-in): remembered, then the service is started or
  /// stopped to match.
  Future<void> applyConsent(bool granted) async {
    if (!isAvailable) return;
    await _store.write(granted);
    if (granted) {
      await _start();
    } else {
      await _stop();
    }
  }

  /// Sign-out: the service stops and the local copy of the decision goes (the
  /// next account decides for itself).
  Future<void> onSignedOut() async {
    await _stop();
    await _store.write(false);
  }

  Future<void> _start() async {
    if (_active) return;
    try {
      final app = await _describeApp();
      await _transport.start(dsn: _dsn, environment: app.environment, release: app.release);
      _active = true;
    } catch (error) {
      // A wrong address or no network at start: stay off, the app goes on.
      debugPrint('Crash reporting not started: ${error.runtimeType}');
    }
  }

  Future<void> _stop() async {
    if (!_active) return;
    _active = false;
    try {
      await _transport.stop();
    } catch (_) {}
  }
}
