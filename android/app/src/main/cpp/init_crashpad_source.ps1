$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$CrashpadDir = Join-Path $ScriptDir "crashpad"
$MiniChromiumDir = Join-Path $CrashpadDir "third_party\mini_chromium\mini_chromium"

Write-Host "Downloading Crashpad sources to $CrashpadDir..."

# Clone Crashpad if not exists
if (-not (Test-Path $CrashpadDir)) {
    git clone https://chromium.googlesource.com/crashpad/crashpad.git $CrashpadDir
} else {
    Write-Host "Crashpad directory already exists."
}

# Clone Mini Chromium
$MiniChromiumParent = Join-Path $CrashpadDir "third_party\mini_chromium"
if (-not (Test-Path $MiniChromiumParent)) {
    New-Item -ItemType Directory -Force -Path $MiniChromiumParent | Out-Null
}

if (-not (Test-Path $MiniChromiumDir)) {
    Write-Host "Downloading Mini Chromium..."
    git clone https://chromium.googlesource.com/chromium/mini_chromium $MiniChromiumDir
} else {
    Write-Host "Mini Chromium directory already exists."
}

Write-Host "Done. Crashpad sources are ready."
