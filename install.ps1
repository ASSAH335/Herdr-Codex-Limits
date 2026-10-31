param([switch]$NoActivate)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command herdr-app -ErrorAction SilentlyContinue)) { throw 'herdr-app was not found in PATH. Install Herdr Desktop first.' }
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) { throw 'codex was not found in PATH. Install Codex CLI first.' }
if (-not (Get-Command py.exe -ErrorAction SilentlyContinue) -and -not (Get-Command python.exe -ErrorAction SilentlyContinue)) { throw 'Python 3 was not found in PATH. Install Python 3 and reopen Herdr.' }
$appDir = if ($env:HERDR_APP_HOME) { $env:HERDR_APP_HOME } else { Join-Path $HOME '.config/herdr-app' }
$modSource = Join-Path $PSScriptRoot 'usage-tabs'
$layoutSource = Join-Path $PSScriptRoot 'usage-layout.json'
foreach ($file in @((Join-Path $modSource 'main.js'), (Join-Path $modSource 'mod.json'), (Join-Path $modSource 'usage.py'), $layoutSource)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing installer file: $file" }
}
$mods = Join-Path $appDir 'mods'
$layouts = Join-Path $appDir 'layouts'
New-Item -ItemType Directory -Force -Path $mods, $layouts | Out-Null
$mod = Join-Path $mods 'usage-tabs'
$layout = Join-Path $layouts 'usage-layout.json'
function Backup-Existing([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $backup = "$Path.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $i = 1
    $candidate = $backup
    while (Test-Path -LiteralPath $candidate) { $candidate = "$backup-$i"; $i++ }
    Move-Item -LiteralPath $Path -Destination $candidate
    Write-Host "Backup saved: $candidate"
}
Backup-Existing $mod
Backup-Existing $layout
Copy-Item -LiteralPath $modSource -Destination $mod -Recurse
Copy-Item -LiteralPath $layoutSource -Destination $layout
Write-Host 'Checking the mod...'
& herdr-app check $mod
if ($LASTEXITCODE -ne 0) { throw 'Mod check failed. Existing files are preserved in backups; the layout was not activated.' }
if (-not $NoActivate) {
    & herdr-app do layout.switch --name usage-layout
    if ($LASTEXITCODE -ne 0) { throw 'Files installed, but the layout could not be activated. Start Herdr and run: herdr-app do layout.switch --name usage-layout' }
    Write-Host 'Installed. Open a Codex tab to see your limits.'
} else { Write-Host 'Installed and checked; layout was not switched.' }
