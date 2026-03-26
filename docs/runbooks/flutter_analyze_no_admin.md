# Flutter Analyze Without Admin Rights

This runbook documents the safest way to execute `flutter analyze` on this machine when the standard `flutter` command goes through `puro` and may attempt elevated operations.

## Problem

In this environment:

- `flutter` resolves to `C:\Users\vasta\.puro\envs\stable\flutter\bin\flutter.bat`
- that wrapper delegates to `puro`
- `puro` may try to sync cache or create links
- on a non-admin terminal this can fail before analysis even starts

The failure is environmental, not related to the app code.

## Recommended workaround

Run Flutter tools through the bundled Dart SDK and invoke `flutter_tools.dart` directly.

From `apps/mobile_app`:

```powershell
$env:FLUTTER_ROOT='C:\Users\vasta\.puro\envs\stable\flutter'
& 'C:\Users\vasta\.puro\envs\stable\flutter\bin\cache\dart-sdk\bin\dart.exe' run `
  --packages='C:\Users\vasta\.puro\envs\stable\flutter\packages\flutter_tools\.dart_tool\package_config.json' `
  'C:\Users\vasta\.puro\envs\stable\flutter\packages\flutter_tools\bin\flutter_tools.dart' `
  analyze
```

## Analyze specific files

When the repo has unrelated work in progress, prefer targeted analysis:

```powershell
$env:FLUTTER_ROOT='C:\Users\vasta\.puro\envs\stable\flutter'
& 'C:\Users\vasta\.puro\envs\stable\flutter\bin\cache\dart-sdk\bin\dart.exe' run `
  --packages='C:\Users\vasta\.puro\envs\stable\flutter\packages\flutter_tools\.dart_tool\package_config.json' `
  'C:\Users\vasta\.puro\envs\stable\flutter\packages\flutter_tools\bin\flutter_tools.dart' `
  analyze `
  lib/app/theme/app_theme.dart `
  lib/features/auth/presentation/widgets/auth_widgets.dart `
  lib/features/onboarding/presentation/widgets/onboarding_scaffold.dart `
  lib/features/onboarding/presentation/pages/onboarding_welcome_page.dart `
  test/chat/chat_feature_test.dart
```

## When to use targeted analysis

Prefer file-scoped analysis when:

- the worktree contains user changes outside your current task
- the package has known unrelated errors
- you want to validate only the files touched by a UX or refactor patch

Prefer full-package analysis when:

- the worktree is stable
- imports and generated files are aligned
- you are doing broader cleanup

## Notes

- This workaround stays in user-space and does not require administrator rights.
- It is compatible with the repository rule to avoid admin-dependent steps.
- If full-package analysis still reports many errors, verify whether they come from pre-existing local changes before treating them as regressions from the current task.
