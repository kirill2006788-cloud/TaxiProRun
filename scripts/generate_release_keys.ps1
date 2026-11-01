param(
  [string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = 'Stop'
$keytool = (Get-Command keytool -ErrorAction Stop).Source

function New-Secret([int]$bytes = 32) {
  $buffer = New-Object byte[] $bytes
  $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
  try {
    $rng.GetBytes($buffer)
  } finally {
    $rng.Dispose()
  }
  return -join ($buffer | ForEach-Object { $_.ToString('x2') })
}

function New-ReleaseKey(
  [string]$AndroidDir,
  [string]$Alias,
  [string]$DistinguishedName
) {
  $keystoreName = "release-key-prod-20260719.jks"
  $keystorePath = Join-Path $AndroidDir $keystoreName
  $propertiesPath = Join-Path $AndroidDir 'key.properties'
  $storePassword = New-Secret
  $keyPassword = $storePassword

  if (-not (Test-Path -LiteralPath $keystorePath)) {
    & $keytool `
      -genkeypair `
      -v `
      -keystore $keystorePath `
      -storetype PKCS12 `
      -keyalg RSA `
      -keysize 4096 `
      -validity 10000 `
      -alias $Alias `
      -storepass $storePassword `
      -keypass $keyPassword `
      -dname $DistinguishedName | Out-Null
  }

  @(
    "storePassword=$storePassword"
    "keyPassword=$keyPassword"
    "keyAlias=$Alias"
    "storeFile=../$keystoreName"
  ) | Set-Content -LiteralPath $propertiesPath -Encoding ASCII
}

New-ReleaseKey `
  -AndroidDir (Join-Path $Root 'android') `
  -Alias 'koroli-passenger-release' `
  -DistinguishedName 'CN=Koroli Dorog Passenger, OU=Mobile, O=Koroli Dorog, L=Moscow, ST=Moscow, C=RU'

New-ReleaseKey `
  -AndroidDir (Join-Path $Root 'driver_app\android') `
  -Alias 'koroli-driver-release' `
  -DistinguishedName 'CN=Koroli Dorog Driver, OU=Mobile, O=Koroli Dorog, L=Moscow, ST=Moscow, C=RU'

Write-Host 'Release keystores are ready.'
