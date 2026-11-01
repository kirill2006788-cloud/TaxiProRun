# Скрипт первоначальной настройки проекта «КОРОЛИ ДОРОГ»
# Запуск: .\setup.ps1

$ErrorActionPreference = "Stop"

$Flutter = if (Get-Command flutter -ErrorAction SilentlyContinue) {
    (Get-Command flutter).Source
} elseif (Test-Path "E:\Dev\flutter-sdk2\bin\flutter.bat") {
    "E:\Dev\flutter-sdk2\bin\flutter.bat"
} else {
    $null
}

if (-not $Flutter) {
    Write-Error "Flutter SDK не найден. Добавьте flutter в PATH или установите SDK."
}

Write-Host ">> flutter create (platform folders)..." -ForegroundColor Cyan
& $Flutter create . --org com.korolidorog --project-name koroli_dorog

Write-Host ">> flutter pub get..." -ForegroundColor Cyan
& $Flutter pub get

Write-Host ">> flutter analyze..." -ForegroundColor Cyan
& $Flutter analyze

Write-Host ">> Готово! Запуск: flutter run" -ForegroundColor Green
