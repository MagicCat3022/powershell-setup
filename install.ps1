<#
.SYNOPSIS
    Wires this repo into the current machine's PowerShell.

.DESCRIPTION
    Idempotent — safe to re-run after `git pull`. It:

      1. Checks prerequisites (PowerShell 7+, git, starship).
      2. Junctions <repo>\modules\posh-git into the user module path.
      3. Appends a dot-source stub to $PROFILE.

    A directory junction is used rather than a symlink deliberately: symlinks
    on Windows need admin or Developer Mode, junctions need neither, and
    PowerShell resolves both identically for module loading.

.PARAMETER Force
    Replace an existing posh-git module directory. Without this, a real
    (non-junction) posh-git install is left alone and the script stops.
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot

function Write-Step($msg)  { Write-Host "  $msg" }
function Write-Ok($msg)    { Write-Host "  [ok]   $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "  [warn] $msg" -ForegroundColor Yellow }

Write-Host "`npowershell-setup -> $repoRoot`n"

# ── 1. prerequisites ────────────────────────────────────────────────────────
Write-Step 'Checking prerequisites...'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "PowerShell 7+ required; this is $($PSVersionTable.PSVersion). Run install.ps1 from pwsh, not Windows PowerShell."
}
Write-Ok "PowerShell $($PSVersionTable.PSVersion)"

if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Ok "git $((git --version) -replace 'git version ')"
} else {
    throw 'git not found on PATH.'
}

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Write-Ok "starship $((starship --version | Select-Object -First 1) -replace 'starship ')"
} else {
    Write-Warn2 'starship not found — install with: winget install Starship.Starship'
    Write-Warn2 'The prompt will not render until it is installed.'
}

# ── 2. module junction ──────────────────────────────────────────────────────
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
            Write-Step 'Removed stale link.'
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

# ── 3. profile stub ─────────────────────────────────────────────────────────
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
