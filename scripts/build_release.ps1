# Release build for Koroli Dorog (passenger + driver)
# Usage:
#   .\scripts\build_release.ps1
#   .\scripts\build_release.ps1 -PassengerOnly
#   .\scripts\build_release.ps1 -DriverOnly
#   .\scripts\build_release.ps1 -Apk
#
# Cyrillic / non-ASCII workspace path (Windows Flutter / NDK):
#   If builds fail with path encoding errors under e.g. E:\project\Приложения\...,
#   map an ASCII drive letter first, then run from that root:
#     subst R: "E:\project\Приложения\TaxiPro"
#     R:
#     .\scripts\build_release.ps1
#   Remove mapping when done: subst R: /d
#   Do NOT delete contents of release\ — copy new APK/AAB into release\<version>\.

param(
  [switch]$PassengerOnly,
  [switch]$DriverOnly,
  [switch]$Apk
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

# Warn when path contains non-ASCII (common Flutter/Android toolchain issue).
if ($root -match '[^\x00-\x7F]') {
  Write-Warning @"
Workspace path contains non-ASCII characters:
  $root
If Gradle/NDK fails, use an ASCII subst drive, e.g.:
  subst R: `"$root`"
  R:
  .\scripts\build_release.ps1
"@
}

$envFile = Join-Path $root 'keys.local.env'
$flutter = if (Get-Command flutter -ErrorAction SilentlyContinue) {
  (Get-Command flutter).Source
} elseif (Test-Path 'E:\Dev\flutter-sdk2\bin\flutter.bat') {
  'E:\Dev\flutter-sdk2\bin\flutter.bat'
} else {
  $null
}

if (-not $flutter) {
  Write-Error 'Flutter SDK was not found'
}

if (-not (Test-Path $envFile)) {
  Write-Error "Missing $envFile; copy keys.local.env.example to keys.local.env"
}

$defines = @{}
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  if ($line -eq '' -or $line.StartsWith('#')) { return }
  $i = $line.IndexOf('=')
  if ($i -lt 1) { return }
  $k = $line.Substring(0, $i).Trim()
  $v = $line.Substring($i + 1).Trim()
  if ($v -ne '') { $defines[$k] = $v }
}

function Set-FirebaseFlag([string]$appDir, [string]$relJsonPath) {
  $json = Join-Path $appDir $relJsonPath
  if (Test-Path $json) {
    $defines['FIREBASE_ENABLED'] = 'true'
    Write-Host "FCM: found $relJsonPath; FIREBASE_ENABLED=true"
  }
}

if (-not $DriverOnly) {
  Set-FirebaseFlag -appDir $root -relJsonPath 'android/app/google-services.json'
}
if (-not $PassengerOnly) {
  Set-FirebaseFlag -appDir (Join-Path $root 'driver_app') -relJsonPath 'android/app/google-services.json'
}

# Production guard: never leave USE_MOCK_API unset for release scripts.
if (-not $defines.ContainsKey('USE_MOCK_API')) {
  $defines['USE_MOCK_API'] = 'false'
  Write-Host 'USE_MOCK_API not in keys.local.env — defaulting to false for release'
}

$dartDefines = @()
foreach ($k in ($defines.Keys | Sort-Object)) {
  $dartDefines += "--dart-define=$k=$($defines[$k])"
}

$buildCmd = if ($Apk) { 'build apk --release' } else { 'build appbundle --release' }

function Build-App([string]$dir, [string]$label) {
  Write-Host "`n=== $label ===" -ForegroundColor Cyan
  Push-Location $dir
  try {
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }
    Write-Host "flutter $buildCmd with $($dartDefines.Count) dart-defines"
    & $flutter @($buildCmd.Split(' ') + $dartDefines)
    if ($LASTEXITCODE -ne 0) { throw "flutter build failed" }
  } finally {
    Pop-Location
  }
}

$buildPassenger = -not $DriverOnly
$buildDriver = -not $PassengerOnly

if ($buildPassenger) { Build-App -dir $root -label 'Passenger' }
if ($buildDriver) { Build-App -dir (Join-Path $root 'driver_app') -label 'Driver' }

Write-Host "`nDone." -ForegroundColor Green
Write-Host "Copy artifacts into release\<version>\ (keep older APKs). See docs/RELEASE_ONE_COMMAND.md"
