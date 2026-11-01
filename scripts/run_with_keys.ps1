# Запуск Flutter с ключами из keys.local.env
# Использование:
#   .\scripts\run_with_keys.ps1              # пассажир
#   .\scripts\run_with_keys.ps1 -Driver      # водитель
#   .\scripts\run_with_keys.ps1 -BuildApk

param(
  [switch]$Driver,
  [switch]$BuildApk,
  [string]$Device
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$envFile = Join-Path $root 'keys.local.env'

if (-not (Test-Path $envFile)) {
  Write-Error "Нет $envFile — скопируйте keys.local.env.example → keys.local.env и вставьте ключи."
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

$appDir = if ($Driver) { Join-Path $root 'driver_app' } else { $root }
$gsJson = Join-Path $appDir 'android/app/google-services.json'
if (Test-Path $gsJson) {
  $defines['FIREBASE_ENABLED'] = 'true'
}

$dartDefines = @()
foreach ($k in ($defines.Keys | Sort-Object)) {
  $dartDefines += "--dart-define=$k=$($defines[$k])"
}

# ASCII junction предпочтителен для Gradle
$junction = if ($Driver) { 'E:\project\TaxiProRun\driver_app' } else { 'E:\project\TaxiProRun' }
if (Test-Path $junction) { $appDir = $junction }

Push-Location $appDir
try {
  if ($BuildApk) {
    Write-Host "flutter build apk $($dartDefines -join ' ')"
    & flutter build apk @dartDefines
  } else {
    $args = @('run') + $dartDefines
    if ($Device) { $args += @('-d', $Device) }
    Write-Host "flutter $($args -join ' ')"
    & flutter @args
  }
} finally {
  Pop-Location
}
