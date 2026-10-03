# Jalankan dari PowerShell: powershell -ExecutionPolicy Bypass -File scripts/bootstrap.ps1
$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $PSScriptRoot
Push-Location $projectDir
$backupDir = Join-Path ([System.IO.Path]::GetTempPath()) ('perona-' + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $backupDir | Out-Null
try {
    Copy-Item pubspec.yaml (Join-Path $backupDir 'pubspec.yaml')
    Copy-Item lib (Join-Path $backupDir 'lib') -Recurse
    Copy-Item test (Join-Path $backupDir 'test') -Recurse
    & flutter create --no-pub --platforms=android --org id.peronasepatu --project-name perona_pos .
    if ($LASTEXITCODE -ne 0) { throw 'flutter create gagal. Jalankan flutter doctor dan perbaiki instalasi Flutter.' }
    if (Test-Path test/widget_test.dart) { Remove-Item test/widget_test.dart }
} finally {
    if (Test-Path (Join-Path $backupDir 'pubspec.yaml')) {
        Copy-Item (Join-Path $backupDir 'pubspec.yaml') pubspec.yaml -Force
        Copy-Item (Join-Path $backupDir 'lib/*') lib -Recurse -Force
        Copy-Item (Join-Path $backupDir 'test/*') test -Recurse -Force
    }
    Pop-Location
}
$manifestPath = Join-Path $projectDir 'android/app/src/main/AndroidManifest.xml'
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath -Raw
    if ($manifest -notmatch 'android.permission.INTERNET') {
        $manifest = $manifest.Replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">', '<manifest xmlns:android="http://schemas.android.com/apk/res/android">' + "`n" + '    <uses-permission android:name="android.permission.INTERNET"/>')
    }
    $manifest = $manifest.Replace('android:label="perona_pos"', 'android:label="Perona Kasir"')
    Set-Content -Path $manifestPath -Value $manifest -Encoding utf8
}
Write-Host 'Kerangka Android siap. Isi config.json, kemudian jalankan flutter pub get, flutter analyze, dan flutter test.'
Write-Host 'Build release harus memakai signing key pribadi; baca README sebelum membagikan APK.'
