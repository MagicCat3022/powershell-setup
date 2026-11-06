<#
.SYNOPSIS
    Installs the Oh My Pi (omp) setup stored in omp\ on this machine, or
    exports this machine's setup into omp\.

.DESCRIPTION
    Idempotent — safe to re-run after `git pull`. Install, the default:

      1. Installs omp with the official script when `omp` is missing.
      2. Copies config.yml, themes, and extensions from <repo>\omp into the
         omp agent directory.
      3. Writes each Claude Code agent in <repo>\claude\agents as an omp task
         agent in <AgentDir>\agents. omp skips ~/.claude/agents, whose
         frontmatter differs: `model: inherit` and `color` are dropped, `effort`
         becomes `thinking-level`, and tool names are lowercased.
      4. Downloads the local model the config's `tiny` role names.
      5. Sets Windows Terminal's default bell style to audible plus taskbar
         flash, so a finished or waiting omp turn in a background tab is seen.

    The skills, CLAUDE.md, Claude plugins, MCP servers, and the git push guard
    script come from ~/.claude, which config.yml opts into. Run
    install-claude.ps1 first.

    -Export runs step 2 from the machine into the repo.

    Install never deletes. A file it would overwrite with different content is
    copied first to <AgentDir>\backups\powershell-setup-<timestamp>\, outside
    extensions\, where omp would load a copied .ts file as an extension.

    Export mirrors the machine: a theme or extension that is gone from the
    machine is deleted from the repo, and git keeps its history.

.PARAMETER Export
    Copy from this machine into the repo.

.PARAMETER AgentDir
    The omp agent directory. Point it at an empty folder, together with
    -SkipExternal, to test an install without touching the live setup.

.PARAMETER SkipExternal
    Skip steps 1, 4, and 5: the omp install, the model download, and the
    Windows Terminal change.
#>
[CmdletBinding()]
param(
    [switch]$Export,
    [string]$AgentDir = (Join-Path $HOME '.omp\agent'),
    [switch]$SkipExternal
)

$ErrorActionPreference = 'Stop'
$store    = Join-Path $PSScriptRoot 'omp'
$AgentDir = [IO.Path]::GetFullPath($AgentDir).TrimEnd('\')

function Write-Step($msg)  { Write-Host "  $msg" }
function Write-Ok($msg)    { Write-Host "  [ok]    $msg" -ForegroundColor Green }
function Write-Add($msg)   { Write-Host "  [added] $msg" -ForegroundColor Cyan }
function Write-Warn2($msg) { Write-Host "  [warn]  $msg" -ForegroundColor Yellow }

$backupRoot = Join-Path $AgentDir "backups\powershell-setup-$(Get-Date -Format yyyyMMdd-HHmmss)"
$script:backedUp = 0

$direction = if ($Export) { "$AgentDir -> $store" } else { "$store -> $AgentDir" }
Write-Host "`ninstall-omp $direction`n"

if ($Export -and -not (Test-Path -LiteralPath (Join-Path $AgentDir 'config.yml'))) {
    # Export mirrors deletions, so a wrong -AgentDir would empty omp\.
    throw "$AgentDir has no config.yml — is it an omp agent directory?"
}
if (-not $Export -and -not (Test-Path -LiteralPath $store)) {
    throw "Missing $store — run with -Export first, or check the repo is complete."
}

# ── helpers ─────────────────────────────────────────────────────────────────

function Copy-Managed([string]$src, [string]$dst) {
    return Write-Managed $dst ([IO.File]::ReadAllBytes($src))
}

function Write-Managed([string]$dst, [byte[]]$bytes) {
    if (Test-Path -LiteralPath $dst) {
        if ([Linq.Enumerable]::SequenceEqual([IO.File]::ReadAllBytes($dst), $bytes)) { return 'same' }
        if (-not $Export) {
            $backup = Join-Path $backupRoot ([IO.Path]::GetRelativePath($AgentDir, $dst))
            New-Item -ItemType Directory -Force -Path (Split-Path $backup -Parent) | Out-Null
            Copy-Item -LiteralPath $dst -Destination $backup -Force
            $script:backedUp++
        }
        $state = 'updated'
    } else {
        $state = 'added'
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
    [IO.File]::WriteAllBytes($dst, $bytes)
    return $state
}

function Sync-Tree([string]$src, [string]$dst, [string]$label) {
    $n = [ordered]@{ added = 0; updated = 0; same = 0; removed = 0 }
    $files = @(Get-ChildItem -LiteralPath $src -Recurse -File -ErrorAction SilentlyContinue)
    foreach ($f in $files) {
        $n[(Copy-Managed $f.FullName (Join-Path $dst ([IO.Path]::GetRelativePath($src, $f.FullName))))]++
    }
    if ($Export) {
        $kept = $files | ForEach-Object { [IO.Path]::GetRelativePath($src, $_.FullName) }
        foreach ($f in Get-ChildItem -LiteralPath $dst -Recurse -File -ErrorAction SilentlyContinue) {
            if ($kept -notcontains [IO.Path]::GetRelativePath($dst, $f.FullName)) {
                Remove-Item -LiteralPath $f.FullName
                $n.removed++
            }
        }
    }
    $changes = @($n.Keys | Where-Object { $_ -ne 'same' -and $n[$_] } | ForEach-Object { "$($n[$_]) $_" })
    if ($changes) { Write-Add "$label ($($changes -join ', '))" } else { Write-Ok $label }
}

function Resolve-Omp {
    $cmd = Get-Command omp -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    # The install script adds this folder to the user PATH, which this session
    # does not see until it restarts.
    $exe = Join-Path $env:LOCALAPPDATA 'omp\omp.exe'
    if (Test-Path -LiteralPath $exe) { return $exe }
    return $null
}

# ── 1. omp ──────────────────────────────────────────────────────────────────
$omp = Resolve-Omp
if (-not $Export -and -not $SkipExternal) {
    Write-Step 'omp...'
    if ($omp) {
        Write-Ok "omp $((& $omp --version) -join ' ')"
    } else {
        Invoke-RestMethod https://omp.sh/install.ps1 | Invoke-Expression
        $omp = Resolve-Omp
        if ($omp) { Write-Add "omp $((& $omp --version) -join ' ')" }
        else { Write-Warn2 'omp install finished, but omp.exe was not found — open a new terminal and re-run.' }
    }
    Write-Host ''
}

# ── 2. config, themes, extensions ───────────────────────────────────────────
Write-Step 'Config, themes, extensions...'

$m = Join-Path $AgentDir 'config.yml'
$s = Join-Path $store 'config.yml'
$src, $dst = if ($Export) { $m, $s } else { $s, $m }
$state = Copy-Managed $src $dst
if ($state -eq 'same') { Write-Ok 'config.yml' } else { Write-Add "config.yml ($state)" }

foreach ($name in 'themes', 'extensions') {
    $m = Join-Path $AgentDir $name
    $s = Join-Path $store $name
    if ($Export) { Sync-Tree $m $s $name } else { Sync-Tree $s $m $name }
}

# ── 3. agents ───────────────────────────────────────────────────────────────
if (-not $Export) {
    $n = [ordered]@{ added = 0; updated = 0; same = 0 }
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'claude\agents') -Filter '*.md' -File -ErrorAction SilentlyContinue) {
        $text = [IO.File]::ReadAllText($f.FullName)
        $m = [regex]::Match($text, '\A---\r?\n(.*?)\r?\n---\r?\n', 'Singleline')
        if (-not $m.Success) { Write-Warn2 "agent $($f.Name) has no frontmatter — skipped."; continue }
        $front = foreach ($line in $m.Groups[1].Value -split '\r?\n') {
            if ($line -match '^(model:\s*inherit|color:)') { continue }
            if ($line -match '^effort:\s*(.+)$') { "thinking-level: $($Matches[1])"; continue }
            if ($line -match '^tools:\s*(.+)$') { "tools: $($Matches[1].ToLower())"; continue }
            $line
        }
        $out = "---`n$($front -join "`n")`n---`n" + $text.Substring($m.Length)
        $n[(Write-Managed (Join-Path $AgentDir "agents\$($f.Name)") ([Text.UTF8Encoding]::new($false).GetBytes($out)))]++
    }
    $changes = @($n.Keys | Where-Object { $_ -ne 'same' -and $n[$_] } | ForEach-Object { "$($n[$_]) $_" })
    if ($changes) { Write-Add "agents from claude\agents ($($changes -join ', '))" } else { Write-Ok 'agents from claude\agents' }
}

if (-not $Export -and -not $SkipExternal) {
    # ── 4. tiny local model ─────────────────────────────────────────────────
    Write-Step "`nLocal model..."
    $tiny = Select-String -LiteralPath (Join-Path $AgentDir 'config.yml') -Pattern '^\s+tiny:\s*local/(\S+)' |
        Select-Object -First 1
    if (-not $tiny) {
        Write-Ok 'no local model in modelRoles.tiny'
    } elseif (-not $omp) {
        Write-Warn2 'omp not found — local model skipped.'
    } else {
        $key = $tiny.Matches[0].Groups[1].Value
        & $omp tiny-models download $key
        if ($LASTEXITCODE -eq 0) { Write-Ok "local model $key" } else { Write-Warn2 "local model $key failed (exit $LASTEXITCODE)" }
    }

    # ── 5. Windows Terminal bell ────────────────────────────────────────────
    Write-Step "`nWindows Terminal bell..."
    $wt = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    if (-not (Test-Path -LiteralPath $wt)) {
        Write-Step '    Windows Terminal not installed — skipped.'
    } else {
        $raw = Get-Content -LiteralPath $wt -Raw
        if ($raw -match '"bellStyle"') {
            Write-Ok 'bellStyle already set'
        } elseif ($raw -notmatch '"defaults"\s*:\s*\{') {
            Write-Warn2 'No profiles.defaults in settings.json — add "bellStyle": ["audible", "taskbar"] by hand.'
        } else {
            # settings.json is JSONC, so it is patched textually: a round trip
            # through ConvertTo-Json would strip every comment.
            $bell = '"bellStyle": ["audible", "taskbar"]'
            $updated = if ($raw -match '"defaults"\s*:\s*\{\s*\}') {
                ([regex]'"defaults"\s*:\s*\{\s*\}').Replace($raw, "`"defaults`": { $bell }", 1)
            } else {
                ([regex]'"defaults"\s*:\s*\{').Replace($raw, "`"defaults`": { $bell,", 1)
            }
            try { $null = $updated | ConvertFrom-Json } catch {
                throw "Patching $wt would make it invalid JSON — add `"bellStyle`" by hand."
            }
            Copy-Item -LiteralPath $wt "$wt.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
            Set-Content -LiteralPath $wt -Value $updated -NoNewline -Encoding utf8
            Write-Add 'bellStyle audible + taskbar (settings.json backed up)'
        }
    }
}

if ($script:backedUp) {
    Write-Host ''
    Write-Warn2 "$($script:backedUp) changed files backed up to $backupRoot"
}
$next = if ($Export) { 'Review the diff in omp\ before committing.' } else { 'Restart omp to load the changes. Sign in with /login for each provider modelRoles uses.' }
Write-Host "`nDone. $next`n" -ForegroundColor Green
