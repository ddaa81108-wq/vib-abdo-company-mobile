param(
  [Parameter(Mandatory = $true)]
  [ValidateRange(1, 2100000000)]
  [int]$BuildNumber
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Push-Location -LiteralPath $projectRoot
$previousSigning = $env:ANDROID_REQUIRE_RELEASE_SIGNING
$previousGoogle = $env:ENABLE_GOOGLE_SERVICES
try {
  git diff --quiet
  if ($LASTEXITCODE) { throw 'Review tracked changes before building.' }
  git diff --cached --quiet
  if ($LASTEXITCODE) { throw 'Review staged changes before building.' }

  $flutterCommand = Get-Command flutter.bat -ErrorAction Stop
  if (-not (Test-Path -LiteralPath 'android\app\google-services.json')) {
    throw 'Production Firebase config is missing: android\app\google-services.json'
  }
  if ($env:ANDROID_KEY_PROPERTIES -and -not (Test-Path -LiteralPath $env:ANDROID_KEY_PROPERTIES)) {
    throw 'The configured signing properties file is missing.'
  }
  if (-not $env:ANDROID_KEY_PROPERTIES -and
      -not (Test-Path -LiteralPath 'android\key.properties') -and
      -not $env:ANDROID_KEYSTORE_PATH) {
    throw 'Set ANDROID_KEY_PROPERTIES to the existing original key.properties file. Do not copy it into Git.'
  }

  $sdkRoot = $env:ANDROID_HOME
  if (-not $sdkRoot) { $sdkRoot = $env:ANDROID_SDK_ROOT }
  if (-not $sdkRoot) { $sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
  $buildTools = Join-Path $sdkRoot 'build-tools\36.0.0'
  $signer = Join-Path $buildTools 'apksigner.bat'
  $aapt = Join-Path $buildTools 'aapt2.exe'
  if (-not (Test-Path -LiteralPath $signer) -or -not (Test-Path -LiteralPath $aapt)) {
    throw 'Android build-tools 36.0.0 are required. Set ANDROID_HOME to the existing SDK.'
  }
  $pythonCommand = Get-Command py.exe -ErrorAction SilentlyContinue
  $pythonArgs = @('-3')
  if (-not $pythonCommand) {
    $pythonCommand = Get-Command python.exe -ErrorAction SilentlyContinue |
      Where-Object { $_.Source -notlike '*\Microsoft\WindowsApps\*' } |
      Select-Object -First 1
    $pythonArgs = @()
  }
  if (-not $pythonCommand) { throw 'Python 3 is required for the release APK demo-data scan.' }
  & $pythonCommand.Source @pythonArgs --version
  if ($LASTEXITCODE) { throw 'Python 3 could not start.' }

  $env:ANDROID_REQUIRE_RELEASE_SIGNING = 'true'
  $env:ENABLE_GOOGLE_SERVICES = 'true'
  & $flutterCommand.Source pub get --enforce-lockfile
  if ($LASTEXITCODE) { throw 'Dependency resolution failed.' }
  & $flutterCommand.Source build apk --release "--build-number=$BuildNumber" `
    --dart-define=USE_FAKE_API=false `
    --dart-define=API_BASE=https://vip2100.com `
    --dart-define=EMPLOYEE_TOTALS_SOURCE=collections `
    --dart-define=COLLECTIONS_WHITE_GOLD=true
  if ($LASTEXITCODE) { throw 'APK build failed.' }

  $apk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
  $certificate = & $signer verify --print-certs $apk
  if ($LASTEXITCODE) { throw 'APK signature verification failed.' }
  $expected = '40b569e6ffe89126ed81027a1b157e4dc4891319ec8c5449ae60206e08bbb841'
  if (-not ($certificate -match "Signer #1 certificate SHA-256 digest: $expected")) {
    throw 'APK certificate differs from the original release certificate. Do not distribute.'
  }
  $badging = & $aapt dump badging $apk
  if ($LASTEXITCODE) { throw 'Could not verify APK package metadata.' }
  $packageLine = $badging | Where-Object { $_ -like 'package:*' } | Select-Object -First 1
  if (-not $packageLine -or -not $packageLine.Contains("name='com.vip2100.vib' versionCode='$BuildNumber'")) {
    throw 'Unexpected application id or version code. Do not distribute.'
  }
  & $pythonCommand.Source @pythonArgs tool/scan_release_apk.py $apk
  if ($LASTEXITCODE) { throw 'Release APK demo-data scan failed.' }

  $commit = (git rev-parse --short=12 HEAD).Trim()
  if ($LASTEXITCODE) { throw 'Could not determine source commit.' }
  $releaseDirectory = Join-Path $projectRoot 'build\releases'
  New-Item -ItemType Directory -Path $releaseDirectory -Force | Out-Null
  $output = Join-Path $releaseDirectory "vib-production-$commit-$BuildNumber.apk"
  Copy-Item -LiteralPath $apk -Destination $output
  $hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
  Set-Content -LiteralPath "$output.sha256" -Value "$hash  $([IO.Path]::GetFileName($output))" -Encoding Ascii
  Write-Output "Verified production APK: $output"
  Write-Output "Commit: $commit"
  Write-Output "Version code: $BuildNumber"
} finally {
  $env:ANDROID_REQUIRE_RELEASE_SIGNING = $previousSigning
  $env:ENABLE_GOOGLE_SERVICES = $previousGoogle
  Pop-Location
}
