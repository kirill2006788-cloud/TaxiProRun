param(
  [string]$VpsHost = "161.104.19.23",
  [string]$User = "root",
  [string]$RemoteAppDir = "/opt/koroli-dorog-api"
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$LocalApiSrc = Join-Path $root "backend\api\src"
$LocalAdmin = Join-Path $root "admin"
if (-not $env:DEPLOY_SSH_PASSWORD) { throw "Set DEPLOY_SSH_PASSWORD" }
$pyPath = Join-Path $PSScriptRoot "_deploy_vps_impl.py"
python $pyPath $VpsHost $User $RemoteAppDir $LocalApiSrc $LocalAdmin
exit $LASTEXITCODE
