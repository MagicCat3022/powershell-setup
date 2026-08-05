# Portable PowerShell setup — dot-sourced from $PROFILE by a small local stub
# that install.ps1 writes. Everything here is machine-independent; anything
# machine-specific (e.g. the PowerToys CommandNotFound block, which PowerToys
# manages and rewrites itself) stays in the local $PROFILE.

$setupRoot = Split-Path $PSScriptRoot -Parent

# ── starship ────────────────────────────────────────────────────────────────
# Point starship at the repo's config so the prompt travels with this setup
# instead of living in a machine-local ~/.config/starship.toml.
$env:STARSHIP_CONFIG = Join-Path $setupRoot 'starship\starship.toml'

# ── posh-git (patched — see modules/posh-git) ───────────────────────────────
# install.ps1 normally junctions this into the user module path:
#   Documents\PowerShell\Modules\posh-git -> <repo>\modules\posh-git
# If that junction is missing (install.ps1 not run, or the machine disallows
# it), fall back to putting the repo's module dir on PSModulePath directly so
# the setup still works. Test-Path is used rather than Get-Module -ListAvailable
# because the latter scans every PSModulePath entry and costs far more.
$junction = Join-Path (Split-Path $PROFILE -Parent) 'Modules\posh-git'
if (-not (Test-Path $junction)) {
    $repoModules = Join-Path $setupRoot 'modules'
    if ($env:PSModulePath -notlike "*$repoModules*") {
        $env:PSModulePath = $repoModules + [IO.Path]::PathSeparator + $env:PSModulePath
    }
}

# Imported eagerly: ~230ms at startup in exchange for every Tab being instant,
# including the first of a session. MUST stay above the starship line —
# posh-git installs its own prompt function on import, and whichever loads
# last wins.
Import-Module posh-git

# ── PSReadLine ──────────────────────────────────────────────────────────────
# Inline greyed-out suggestions from history; accept with RightArrow.
# F2 toggles between InlineView and ListView at runtime.
# try/catch because predictions require a real terminal — without this, any
# redirected or piped pwsh session prints an error on startup.
try {
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin -ErrorAction Stop
    Set-PSReadLineOption -PredictionViewStyle InlineView -ErrorAction Stop
} catch {}

# Tab shows completions as a navigable grid instead of cycling one at a time.
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# ── prompt (must be last) ───────────────────────────────────────────────────
Invoke-Expression (&starship init powershell)
