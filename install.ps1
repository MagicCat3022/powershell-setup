<#
.SYNOPSIS
    Wires this repo into the current machine's PowerShell, installing what it
    needs along the way.

.DESCRIPTION
    Idempotent — safe to re-run after `git pull`. It:

      1. Verifies the bootstrap requirements (PowerShell 7+, git). These cannot
         be auto-installed: you are already running PowerShell, and git is how
         you obtained this repo.
      2. Installs the remaining prerequisites if missing — starship, PSReadLine
         2.2+, and a Nerd Font — then points Windows Terminal at the font.
      3. Junctions <repo>\modules\posh-git into the user module path.
      4. Appends a dot-source stub to $PROFILE.

    Nothing here needs administrator rights. A directory junction is used rather
    than a symlink because symlinks on Windows require admin or Developer Mode
    while junctions require neither, and PowerShell resolves both identically
    for module loading. The font likewise installs per-user (HKCU + LOCALAPPDATA)
    rather than machine-wide.

.PARAMETER Force
    Replace an existing posh-git module directory. Without this, a real
    (non-junction) posh-git install is left alone and the script stops.

.PARAMETER SkipPrereqs
    Only link the module and wire $PROFILE. Prerequisites are still reported.

.PARAMETER NerdFont
    Nerd Fonts release asset to install, without the .zip. Note that winget
    carries only JetBrainsMono (DEVCOM.JetBrainsMonoNerdFont), so fonts come
    from the Nerd Fonts GitHub releases instead.

.PARAMETER NerdFontFamily
    The font family name the asset above registers, as Windows Terminal must
    spell it. Must match $NerdFont — change both together.
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipPrereqs,
    [string]$NerdFont       = 'DroidSansMono',
    [string]$NerdFontFamily = 'DroidSansM Nerd Font Mono'
)

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot

function Write-Step($msg)  { Write-Host "  $msg" }
function Write-Ok($msg)    { Write-Host "  [ok]    $msg" -ForegroundColor Green }
function Write-Add($msg)   { Write-Host "  [added] $msg" -ForegroundColor Cyan }
function Write-Warn2($msg) { Write-Host "  [warn]  $msg" -ForegroundColor Yellow }

Write-Host "`npowershell-setup -> $repoRoot`n"

# ── 1. bootstrap requirements (cannot be auto-installed) ────────────────────
Write-Step 'Checking bootstrap requirements...'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "PowerShell 7+ required; this is $($PSVersionTable.PSVersion). Run install.ps1 from pwsh, not Windows PowerShell. Install with: winget install Microsoft.PowerShell"
}
Write-Ok "PowerShell $($PSVersionTable.PSVersion)"

if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Ok "git $((git --version) -replace 'git version ')"
} else {
    throw 'git not found on PATH. Install with: winget install Git.Git'
}

# ── 2. prerequisites ────────────────────────────────────────────────────────

function Test-FontFamilyInstalled([string]$family) {
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    try {
        $fc = New-Object System.Drawing.Text.InstalledFontCollection
        return ($fc.Families.Name -contains $family)
    } catch {
        return $false
    }
}

function Install-NerdFontPerUser([string]$assetName) {
    # Per-user install: copy into LOCALAPPDATA\Microsoft\Windows\Fonts and
    # register under HKCU. Windows has honoured this since 10/1809, and it
    # avoids needing administrator rights.
    $url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$assetName.zip"
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "nerdfont-$assetName-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null

    try {
        $zip = Join-Path $tmp "$assetName.zip"
        Write-Step "    downloading $assetName..."
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $tmp -Force

        $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        New-Item -ItemType Directory -Force -Path $fontDir | Out-Null

        $regKey = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
        if (-not (Test-Path $regKey)) { New-Item -Path $regKey -Force | Out-Null }

        Add-Type -AssemblyName System.Drawing

        $count = 0
        foreach ($file in Get-ChildItem -Path $tmp -Include '*.ttf', '*.otf' -Recurse) {
            $dest = Join-Path $fontDir $file.Name
            Copy-Item $file.FullName $dest -Force

            # Read the family name out of the file rather than guessing from
            # the filename — the registry entry has to match what Windows and
            # Windows Terminal will call the font.
            $pfc = New-Object System.Drawing.Text.PrivateFontCollection
            try {
                $pfc.AddFontFile($dest)
                $family = $pfc.Families[0].Name
            } finally {
                $pfc.Dispose()
            }

            $suffix = if ($file.Extension -eq '.otf') { '(OpenType)' } else { '(TrueType)' }
            New-ItemProperty -Path $regKey -Name "$family $suffix" -Value $dest `
                             -PropertyType String -Force | Out-Null
            $count++
        }
        return $count
    }
    finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Set-TerminalDefaultFont([string]$family) {
    $settings = Join-Path $env:LOCALAPPDATA `
        'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'

    if (-not (Test-Path $settings)) { return 'absent' }

    $raw = Get-Content $settings -Raw
    try { $json = $raw | ConvertFrom-Json } catch { return 'unparseable' }

    if ($json.profiles.defaults.font.face -eq $family) { return 'already' }

    # settings.json is JSONC and hand-editable, so it is patched textually.
    # Round-tripping through ConvertTo-Json would strip every comment. Only the
    # unambiguous empty-defaults shape is rewritten; anything else is left for
    # the user, because a regex for "face" could match another profile's font.
    if ($raw -notmatch '"defaults"\s*:\s*\{\s*\}') { return 'manual' }

    Copy-Item $settings "$settings.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"

    $block = @"
"defaults":
        {
            "font":
            {
                "face": "$family"
            }
        }
"@
    $updated = $raw -replace '"defaults"\s*:\s*\{\s*\}', $block.Replace('$', '$$')
    Set-Content -Path $settings -Value $updated -NoNewline -Encoding utf8
    return 'set'
}

if ($SkipPrereqs) {
    Write-Step "`nPrerequisites (-SkipPrereqs, reporting only)..."
} else {
    Write-Step "`nPrerequisites..."
}

$hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)

# starship ------------------------------------------------------------------
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Write-Ok "starship $((starship --version | Select-Object -First 1) -replace 'starship ')"
}
elseif ($SkipPrereqs -or -not $hasWinget) {
    Write-Warn2 'starship missing — install with: winget install Starship.Starship'
    Write-Warn2 'The prompt will not render until it is installed.'
}
else {
    Write-Step '    installing starship...'
    winget install --id Starship.Starship --source winget --silent `
                   --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0) {
        Write-Add 'starship installed (PATH updates in a new terminal)'
    } else {
        Write-Warn2 "winget exited $LASTEXITCODE — install manually: winget install Starship.Starship"
    }
}

# PSReadLine ----------------------------------------------------------------
# The profile sets PredictionSource, which needs 2.2+. Older builds throw and
# the try/catch there would swallow it, leaving predictions silently dead.
$psrl = Get-Module PSReadLine -ListAvailable |
            Sort-Object Version -Descending | Select-Object -First 1

if ($psrl -and $psrl.Version -ge [version]'2.2.0') {
    Write-Ok "PSReadLine $($psrl.Version)"
}
elseif ($SkipPrereqs) {
    Write-Warn2 "PSReadLine $($psrl.Version) is below 2.2 — history predictions will not work."
}
else {
    Write-Step '    installing PSReadLine 2.2+...'
    Install-Module PSReadLine -Scope CurrentUser -Force -AllowClobber -MinimumVersion 2.2.0
    Write-Add 'PSReadLine installed'
}

# Nerd Font -----------------------------------------------------------------
if (Test-FontFamilyInstalled $NerdFontFamily) {
    Write-Ok "font '$NerdFontFamily'"
}
elseif ($SkipPrereqs) {
    Write-Warn2 "font '$NerdFontFamily' missing — prompt icons will render as tofu boxes."
}
else {
    $n = Install-NerdFontPerUser $NerdFont
    if ($n -gt 0) {
        Write-Add "font '$NerdFontFamily' installed per-user ($n files)"
    } else {
        Write-Warn2 "No font files found in the $NerdFont release asset."
    }
}

# Windows Terminal font -----------------------------------------------------
if (-not $SkipPrereqs) {
    switch (Set-TerminalDefaultFont $NerdFontFamily) {
        'set'     { Write-Add "Windows Terminal default font -> '$NerdFontFamily' (settings.json backed up)" }
        'already' { Write-Ok  "Windows Terminal font '$NerdFontFamily'" }
        'absent'  { Write-Step '    Windows Terminal not installed — skipping font setting.' }
        'unparseable' { Write-Warn2 'Could not parse Windows Terminal settings.json — set the font manually.' }
        'manual'  {
            Write-Warn2 "Windows Terminal already has profile defaults; set the font yourself:"
            Write-Warn2 "  Settings > Defaults > Appearance > Font face > $NerdFontFamily"
        }
    }
}

# ── 3. module junction ──────────────────────────────────────────────────────
Write-Step "`nLinking posh-git..."

$moduleSource = Join-Path $repoRoot 'modules\posh-git'
$moduleTarget = Join-Path (Split-Path $PROFILE -Parent) 'Modules\posh-git'

if (-not (Test-Path $moduleSource)) { throw "Missing $moduleSource — is the repo complete?" }

New-Item -ItemType Directory -Force -Path (Split-Path $moduleTarget -Parent) | Out-Null

if (Test-Path $moduleTarget) {
    $existing = Get-Item $moduleTarget -Force
    $isLink = $existing.LinkType -in @('Junction', 'SymbolicLink')

    if ($isLink -and ($existing.Target -contains $moduleSource)) {
        Write-Ok 'Junction already points here — nothing to do.'
    }
    elseif ($isLink -or $Force) {
        # A stale link, or -Force over a real install. Real directories get
        # moved aside rather than deleted so nothing is lost.
        if ($isLink) {
            # Remove the link itself; never recurse, which would delete the
            # link's contents (i.e. this repo).
            [IO.Directory]::Delete($moduleTarget)
            Write-Step '    removed stale link.'
        } else {
            $backup = "$moduleTarget.replaced-$(Get-Date -Format yyyyMMdd-HHmmss)"
            Move-Item $moduleTarget $backup
            Write-Warn2 "Existing module moved to $backup"
        }
        New-Item -ItemType Junction -Path $moduleTarget -Target $moduleSource | Out-Null
        Write-Ok "Junction created -> $moduleSource"
    }
    else {
        Write-Warn2 "A real posh-git install already exists at $moduleTarget"
        Write-Warn2 'Re-run with -Force to move it aside and link this repo instead.'
    }
}
else {
    New-Item -ItemType Junction -Path $moduleTarget -Target $moduleSource | Out-Null
    Write-Ok "Junction created -> $moduleSource"
}

# ── 4. profile stub ─────────────────────────────────────────────────────────
Write-Step "`nWiring `$PROFILE..."

$stubMarker = '# >>> powershell-setup >>>'
$stubEnd    = '# <<< powershell-setup <<<'
$stub = @"
$stubMarker
# Managed by powershell-setup/install.ps1 — edit the repo, not this block.
. '$(Join-Path $repoRoot 'profile\profile.ps1')'
$stubEnd
"@

New-Item -ItemType Directory -Force -Path (Split-Path $PROFILE -Parent) | Out-Null
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE | Out-Null }

$current = Get-Content $PROFILE -Raw
if ($null -eq $current) { $current = '' }

if ($current -match [regex]::Escape($stubMarker)) {
    # Replace the existing managed block, leaving machine-local lines intact.
    $pattern = [regex]::Escape($stubMarker) + '.*?' + [regex]::Escape($stubEnd)
    $updated = [regex]::Replace($current, $pattern, $stub.Replace('$', '$$'), 'Singleline')
    Set-Content -Path $PROFILE -Value $updated -NoNewline -Encoding utf8
    Write-Ok 'Updated existing powershell-setup block.'
}
else {
    Add-Content -Path $PROFILE -Value "`n$stub" -Encoding utf8
    Write-Ok "Appended block to $PROFILE"
}

Write-Host "`nDone. Open a new terminal.`n" -ForegroundColor Green
