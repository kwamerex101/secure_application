## 5.0.0

### Breaking
* **Enum rename** — `SecureApplicationAuthenticationStatus` values are now lowerCamelCase. Replace `SUCCESS` → `success`, `FAILED` → `failed`, `LOGOUT` → `logout`, `NONE` → `none`.
* **`onNeedUnlock` signature** — type tightened from `Future<Status?>? Function(...)?` to `Future<Status?> Function(...)?`. Return `Future.value(null)` instead of `null` if you have nothing to report.
* **Minimum SDK** — Dart `>=3.3.0`, Flutter `>=3.10.0`.
* **`rxdart` removed** as a dependency. The package now ships its own `ValueStream<T>` (built on `Stream.multi`) and exposes the same `Stream<T>` surface, so most callers do not need code changes — but any direct `BehaviorSubject` typing must be replaced with `Stream<T>`.

### Added
* **`SecureGate.fullScreen`** — when `true`, the gate is rendered into the root `Overlay` so it covers status / app / navigation bars regardless of where `SecureGate` is mounted in the tree. Pair with **`immersiveWhenLocked: true`** to hide system chrome via `SystemUiMode.immersiveSticky` while locked (restored to `edgeToEdge` on unlock).
* **Federated platform interface** — new `SecureApplicationPlatform` abstract class (in `lib/src/`) with a `MethodChannelSecureApplication` default. Federated platform packages can now replace `SecureApplicationPlatform.instance` to provide their own implementation. The pre-existing `SecureApplicationNative` static surface is kept as a thin compatibility shim.
* **State restoration** — the `secured` flag is persisted via `shared_preferences` on every `secure()`/`open()` and reapplied on launch, so `FLAG_SECURE` / `WDA_MONITOR` is engaged immediately after a process kill. Disable with `SecureApplication(restoreSecuredOnLaunch: false)`.
* **`SecureMode`** convenience enum (`open`, `secured`, `locked`, `paused`) with `controller.mode` getter for `switch`-friendly state introspection.
* **Web migrated to `package:web` + `dart:js_interop`** — replaces deprecated `dart:html`. Listeners use `addEventListener`/`removeEventListener` with proper handle tracking for clean teardown.

### Migration

```dart
// Before
SecureApplicationAuthenticationStatus.SUCCESS

// After
SecureApplicationAuthenticationStatus.success
```

```dart
// Before
Future<SecureApplicationAuthenticationStatus?>? Function(...)? onNeedUnlock;

// After — return Future.value(null) instead of null
Future<SecureApplicationAuthenticationStatus?> Function(...)? onNeedUnlock;
```

```dart
// New: switch on derived mode
switch (controller.mode) {
  case SecureMode.open:        // ...
  case SecureMode.secured:     // ...
  case SecureMode.locked:      // ...
  case SecureMode.paused:      // ...
}
```

```dart
// Federated test override
class FakeSecureApplication extends SecureApplicationPlatform {
  // override secure/open/lock/unlock/setOpacity/registerForEvents
}
SecureApplicationPlatform.instance = FakeSecureApplication();
```

## 4.2.0

### Security
* **iOS**: rewrite overlay path. Removed 500 ms `RunLoop.run(until:)` block during `applicationWillResignActive`. Replaced `UIApplication.shared.windows` with multi-scene/multi-screen enumeration (`connectedScenes.windows`) — overlays now cover Split View, Stage Manager, CarPlay, and external displays. Removed misused `ignoreSnapshotOnNextApplicationLaunch()` and zombie `backgroundTask`. Eliminated force-unwrap of `opacity` argument.
* **Android**: implement lifecycle wiring — ON_PAUSE/ON_RESUME invoke `lock`/`unlock` back to Dart when secured. Removed fragile `lateinit instance` pattern.
* **Windows**: implement `secure`/`open` via `SetWindowDisplayAffinity(WDA_MONITOR)` for screen-capture protection on Windows 10+. Marshal hook callbacks to the platform thread via `PostMessage` (was unsafe direct `MethodChannel::InvokeMethod` from hook thread). Plug `HWINEVENTHOOK` leak in destructor. Emit `unlock` on window restore (`SC_RESTORE` / `EVENT_SYSTEM_FOREGROUND`). Surface `WDA_FAILED` error on unsupported builds instead of silent success.
* **Web**: add visual blur overlay on `visibilitychange → hidden` and on `window blur`. Inject `@media print` style that hides DOM during printing; listen for `beforeprint`/`afterprint`. Bring parity with iOS/Android UX.
* **Dart**: tightened `onNeedUnlock` signature from `Future<Status?>? Function(...)?` to `Future<Status?> Function(...)?`. Lock now also fires on `AppLifecycleState.inactive` and `hidden` (defense-in-depth for iOS Control Center pull-down and Flutter 3.13+ states).

### Reliability
* Moved `Future.delayed(...).then(unlock)` out of `build()` and into a cancellable `Timer` in `didChangeAppLifecycleState` — eliminates duplicate-fire on rebuild and leaks-after-unmount.
* `Method`-channel error handling: Android/Web/Windows now return `NotImplemented` for unknown methods.

### Tooling
* Added GitHub Actions CI workflow: format check, analyze, and test on every PR.
* **Tests**: replaced empty scaffolding with 15 unit/widget tests (controller state machine, channel bridge, gate rendering).

### SDK
* Raise minimum Dart SDK to `>=3.0.0`, Flutter to `>=3.3.0`.

## 4.1.0

* Remove registrar This makes the plugin flutter 3.29.0 ready (thanks @Bassiuz )
* Set Java SDK version to avoir issue with latest android studio
* fix sample application

## 4.0.0

* Migrate to flutter 3.0
* Upgrade rxdart (thanks @ariefwijaya )
* Upgrade android dependencies
* [BUGFIX] Null check fix (thanks @WeiCongcong )


## 3.8.0

* [BUGFIX] No signature of method: build_…android() applicable for argument types: (build_…_run_closure2) ( #24 ) thanks @ghostman2013
* [BUGFIX] Fix null safety

## 3.7.3

* [BUGFIX] nativeRemoveDelay is null and that makes the app crash ( #16 )

## 3.7.2

* [BUGFIX] Fix a null safety issue (thanks @abhinandval and @lubritto )

## 3.7.1

* [WINDOWS] No also lock when user go to windows lock screen/switch user

## 3.7.0

* Windows support (minimize window will lock)

## 3.6.0

* Null safety
* Web support

## 3.5.2

* Small improvements to IOS Code

## 3.5.1

* Documentation tips
  
## 3.5.0

* Upgrade to RxDart 0.24.0
  
## 3.4.1

* Opacity is now propagated to IOS protection on task switcher
  
## 3.3.2

* Fix not implemented exception on Android when you exit the app

## 3.3.1

* Fix if you wanted to start the application locked. issue: https://github.com/neckaros/secure_application/issues/1

## 3.3.0

* New behavior stream for lock/unlock event so you can react to them in your application

## 3.2.0

* iOS works on iPad when you rotate after closing

## 3.1.2

* iOS fix

## 3.1.1

* require swift 4.2+

## 3.0.7

* allow to configure nativeRemoveDelay in secure_gate to let longer  app time to start especially on iOS

## 3.0.6

* iOS new bringSubview(toFront:) instead of deprecated metho
* pause during needunlock to prevent ios unlock loop when using faceid

## 3.0.3

* new authenticated information
* autenticationEvents is now a BehaviorSubject stream

## 3.0.0

* Rename package

## 1.0.0

* Working on iOS and Android

## 0.0.1

* Initial release
