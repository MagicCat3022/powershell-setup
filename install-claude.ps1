<#
.SYNOPSIS
    Installs the Claude Code setup stored in claude\ on this machine, or
    exports this machine's setup into claude\.

.DESCRIPTION
    Idempotent — safe to re-run after `git pull`. Install, the default:

      1. Copies CLAUDE.md, settings.json, the status line script, hooks,
         agents, and own skills from <repo>\claude into the Claude Code
         directory. Own skills go to the skillshare source folder when
         skillshare manages ~/.claude/skills.
      2. Copies the feedback memories into the Work folder's project memory and
         adds their lines to its MEMORY.md.
      3. Copies each repo's local Claude settings into <WorkDir>\<repo>\.claude,
         for the repos that exist.
      4. Adds the plugin marketplaces, installs the enabled plugins, installs
         the skills-CLI and skillshare skills, and adds the user MCP servers.
         Skillshare then links its skills into its targets.

    -Export runs steps 1 to 3 from the machine into the repo, and rewrites
    claude\external.json, the list step 4 installs from. It copies whatever
    the machine holds, company-specific rules and skills included, so run it
    only on a machine with the generic setup and review the diff.

    Install never deletes. A file it would overwrite with different content is
    copied first to <ClaudeDir>\backups\powershell-setup-<timestamp>\. Backups
    stay outside <ClaudeDir>\skills, because a directory there that holds a
    SKILL.md loads as a skill.

    Export mirrors the machine: a managed file that is gone from the machine is
    deleted from the repo, and git keeps its history.

    Home paths are stored as {{HOME}} (C:/Users/<name>) and {{HOME_JSON}}
    (C:\\Users\\<name>, as JSON escapes it), and the work folder as {{WORK}}
    (~/Work, or the -WorkDir path written from ~), so the stored files are the
    same on every machine.

.PARAMETER Export
    Copy from this machine into the repo.

.PARAMETER ClaudeDir
    The Claude Code directory. Point it at an empty folder, together with
    -SkipExternal, to test an install without touching the live setup.

.PARAMETER WorkDir
    The folder that holds the work repos. Its path decides which project
    memory the feedback memories belong to, and replaces {{WORK}} in the
    stored files. Defaults to ~\Work when it exists, else ~\Documents\Github.

.PARAMETER SkipSettings
    Leave settings.json alone, on the machine and in the repo. Step 4 then
    installs the plugins enabled in the machine's settings.json.

.PARAMETER SkipClaudeMd
    Leave CLAUDE.md alone, on the machine and in the repo, for a machine that
    keeps its own global rules.

.PARAMETER SkipExternal
    Skip step 4. Plugins, skills-CLI skills, skillshare skills, and MCP
    servers always install into the real user profile, whatever -ClaudeDir
    says. An explicit -ClaudeDir keeps own skills in <ClaudeDir>\skills.

.PARAMETER Skills
    Names of the skills to install or export, wildcards allowed. Defaults to
    every skill. Applies to own, skills-CLI, and skillshare skills. Export
    mirrors the selection: the repo keeps only the selected skills.

.PARAMETER ExcludeSkills
    Names of skills to leave out, wildcards allowed. Applied after -Skills.
#>
[CmdletBinding()]
param(
    [switch]$Export,
    [string]$ClaudeDir = (Join-Path $HOME '.claude'),
    [string]$WorkDir   = $(if (Test-Path -LiteralPath (Join-Path $HOME 'Work')) { Join-Path $HOME 'Work' }
                           else { Join-Path $HOME 'Documents\Github' }),
    [switch]$SkipSettings,
    [switch]$SkipClaudeMd,
    [switch]$SkipExternal,
    [string[]]$Skills = @('*'),
    [string[]]$ExcludeSkills = @()
)

$ErrorActionPreference = 'Stop'
$store     = Join-Path $PSScriptRoot 'claude'
$ClaudeDir = [IO.Path]::GetFullPath($ClaudeDir).TrimEnd('\')
$WorkDir   = [IO.Path]::GetFullPath($WorkDir).TrimEnd('\')

function Test-SkillSelected([string]$name) {
    @($Skills | Where-Object { $name -like $_ }).Count -and
        -not @($ExcludeSkills | Where-Object { $name -like $_ }).Count
}

# Skillshare keeps skills in its source folder and links them into its targets.
# The first `skills:` key with a value in config.yaml is sources.skills.
$ssConfig = Join-Path $env:APPDATA 'skillshare\config.yaml'
$ssSource = if (Test-Path -LiteralPath $ssConfig) {
    $hit = Select-String -LiteralPath $ssConfig -Pattern '^\s+skills:\s*(\S.*)$' | Select-Object -First 1
    if ($hit) { $hit.Matches[0].Groups[1].Value.Trim().Trim('"', "'") }
}
$useSkillshare = $ssSource -and (Test-Path -LiteralPath $ssSource) -and
                 -not $PSBoundParameters.ContainsKey('ClaudeDir')
$skillsDir = if ($useSkillshare) { [IO.Path]::GetFullPath($ssSource).TrimEnd('\', '/') } else { Join-Path $ClaudeDir 'skills' }
$ssMetaFile = if ($useSkillshare) { Join-Path $ssSource '.metadata.json' }
$ssEntries = if ($ssMetaFile -and (Test-Path -LiteralPath $ssMetaFile)) {
    (Get-Content -LiteralPath $ssMetaFile -Raw | ConvertFrom-Json -AsHashtable).entries
} else { @{} }

function Write-Step($msg)  { Write-Host "  $msg" }
function Write-Ok($msg)    { Write-Host "  [ok]    $msg" -ForegroundColor Green }
function Write-Add($msg)   { Write-Host "  [added] $msg" -ForegroundColor Cyan }
function Write-Warn2($msg) { Write-Host "  [warn]  $msg" -ForegroundColor Yellow }

$homeFwd    = $HOME.Replace('\', '/')
$homeJson   = $HOME.Replace('\', '\\')
# The work folder as CLAUDE.md writes it: ~/Work, or an absolute path outside ~.
$workText   = if ($WorkDir.StartsWith("$HOME\", 'OrdinalIgnoreCase')) {
    '~/' + [IO.Path]::GetRelativePath($HOME, $WorkDir).Replace('\', '/')
} else {
    $WorkDir.Replace('\', '/')
}
# Matches the work folder only as a whole path, so ~/Work never matches inside ~/Workshop.
$workPattern = [regex]::Escape($workText) + '(?![A-Za-z0-9_-])'
$textExt    = '.md', '.json', '.ps1', '.py', '.js', '.ts', '.txt', '.yml', '.yaml', '.toml', '.sh'
$utf8       = [Text.UTF8Encoding]::new($false)
$backupRoot = Join-Path $ClaudeDir "backups\powershell-setup-$(Get-Date -Format yyyyMMdd-HHmmss)"
$script:backedUp = 0

# The project memory folder is named after the Work path with every character
# outside [A-Za-z0-9] replaced by '-': C:\Users\me\Work -> C--Users-me-Work.
$memDir = Join-Path $ClaudeDir "projects\$($WorkDir -replace '[^A-Za-z0-9]', '-')\memory"

$direction = if ($Export) { "$ClaudeDir -> $store" } else { "$store -> $ClaudeDir" }
Write-Host "`ninstall-claude $direction`n"

if ($Export -and -not (Test-Path -LiteralPath (Join-Path $ClaudeDir 'settings.json'))) {
    # Export mirrors deletions, so a wrong -ClaudeDir would empty claude\.
    throw "$ClaudeDir has no settings.json — is it a Claude Code directory?"
}
if (-not $Export -and -not (Test-Path -LiteralPath $store)) {
    throw "Missing $store — run with -Export first, or check the repo is complete."
}

# ── helpers ─────────────────────────────────────────────────────────────────

function Convert-Content([byte[]]$bytes) {
    # Swaps home and work paths for tokens on export and back on install. A file
    # with nothing to swap is returned byte for byte, so encoding is never touched.
    $bom    = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $offset = if ($bom) { 3 } else { 0 }
    $text   = $utf8.GetString($bytes, $offset, $bytes.Length - $offset)
    $new    = if ($Export) {
        ($text -creplace $workPattern, '{{WORK}}').Replace($homeJson, '{{HOME_JSON}}').Replace($homeFwd, '{{HOME}}')
    } else {
        $text.Replace('{{WORK}}', $workText).Replace('{{HOME_JSON}}', $homeJson).Replace('{{HOME}}', $homeFwd)
    }
    if ($new -ceq $text) { return ,$bytes }
    $out = $utf8.GetBytes($new)
    if ($bom) { $out = [byte[]](@(0xEF, 0xBB, 0xBF) + $out) }
    return ,$out
}

function Read-StoreText([string]$path) {
    $utf8.GetString((Convert-Content ([IO.File]::ReadAllBytes($path))))
}

function Backup-File([string]$path) {
    $full = [IO.Path]::GetFullPath($path)
    $rel  = if ($full.StartsWith("$ClaudeDir\", 'OrdinalIgnoreCase')) {
        [IO.Path]::GetRelativePath($ClaudeDir, $full)
    } elseif ($useSkillshare -and $full.StartsWith("$skillsDir\", 'OrdinalIgnoreCase')) {
        Join-Path 'skillshare-skills' ([IO.Path]::GetRelativePath($skillsDir, $full))
    } else {
        Join-Path 'work' ([IO.Path]::GetRelativePath($WorkDir, $full))
    }
    $dest = Join-Path $backupRoot $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
    Copy-Item -LiteralPath $path -Destination $dest -Force
    $script:backedUp++
}

function Write-Managed([string]$dst, [byte[]]$bytes) {
    if (Test-Path -LiteralPath $dst) {
        $old = [IO.File]::ReadAllBytes($dst)
        if ([Linq.Enumerable]::SequenceEqual($old, $bytes)) { return 'same' }
        if (-not $Export) { Backup-File $dst }
        $state = 'updated'
    } else {
        $state = 'added'
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
    [IO.File]::WriteAllBytes($dst, $bytes)
    return $state
}

function Copy-Managed([string]$src, [string]$dst) {
    $bytes = [IO.File]::ReadAllBytes($src)
    if ($textExt -contains [IO.Path]::GetExtension($src).ToLower()) {
        $bytes = Convert-Content $bytes
    }
    return Write-Managed $dst $bytes
}

function Get-ManagedFiles([string]$dir) {
    if (-not (Test-Path -LiteralPath $dir)) { return @() }
    Get-ChildItem -LiteralPath $dir -Recurse -File -Force |
        Where-Object {
            $_.FullName -notmatch '\\(__pycache__|node_modules)\\' -and $_.Extension -ne '.pyc' -and
            $_.Name -ne '.skillshare-manifest.json'
        }
}

function Write-Result([string]$label, [hashtable]$n) {
    $changes = @()
    foreach ($k in 'added', 'updated', 'removed') {
        if ($n[$k]) { $changes += "$($n[$k]) $k" }
    }
    if ($changes) { Write-Add "$label ($($changes -join ', '))" } else { Write-Ok $label }
}

function Sync-Tree([string]$src, [string]$dst, [string]$label) {
    $n = @{ added = 0; updated = 0; same = 0; removed = 0 }
    foreach ($f in Get-ManagedFiles $src) {
        $rel = [IO.Path]::GetRelativePath($src, $f.FullName)
        $n[(Copy-Managed $f.FullName (Join-Path $dst $rel))]++
    }
    if ($Export) {
        foreach ($f in Get-ManagedFiles $dst) {
            $rel = [IO.Path]::GetRelativePath($dst, $f.FullName)
            if (-not (Test-Path -LiteralPath (Join-Path $src $rel))) {
                Remove-Item -LiteralPath $f.FullName
                $n.removed++
            }
        }
        Remove-EmptyDirs $dst
    }
    Write-Result $label $n
}

function Remove-EmptyDirs([string]$dir) {
    if (-not (Test-Path -LiteralPath $dir)) { return }
    Get-ChildItem -LiteralPath $dir -Recurse -Directory -Force |
        Sort-Object { $_.FullName.Length } -Descending |
        Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force) } |
        Remove-Item
}

# Syncs each named folder. On export, a folder in the repo that is not named is deleted.
function Sync-Folders([string]$machineRoot, [string]$storeRoot, [string[]]$names, [string]$label) {
    foreach ($name in $names) {
        $m = Join-Path $machineRoot $name
        $s = Join-Path $storeRoot $name
        if ($Export) { Sync-Tree $m $s "$label $name" } else { Sync-Tree $s $m "$label $name" }
    }
    if ($Export -and (Test-Path -LiteralPath $storeRoot)) {
        foreach ($d in Get-ChildItem -LiteralPath $storeRoot -Directory) {
            if ($names -notcontains $d.Name) {
                Remove-Item -LiteralPath $d.FullName -Recurse
                Write-Add "$label $($d.Name) (removed)"
            }
        }
    }
}

# ── 1. core files, hooks, agents, skills ────────────────────────────────────
Write-Step 'Core files...'

$coreFiles = 'CLAUDE.md', 'settings.json', 'statusline-command.ps1' | Where-Object {
    -not ($SkipSettings -and $_ -eq 'settings.json') -and -not ($SkipClaudeMd -and $_ -eq 'CLAUDE.md')
}
foreach ($name in $coreFiles) {
    $m = Join-Path $ClaudeDir $name
    $s = Join-Path $store $name
    $src, $dst = if ($Export) { $m, $s } else { $s, $m }
    if (-not (Test-Path -LiteralPath $src)) { Write-Warn2 "$src missing — skipped."; continue }
    $state = Copy-Managed $src $dst
    if ($state -eq 'same') { Write-Ok $name } else { Write-Add "$name ($state)" }
}

foreach ($name in 'hooks', 'agents') {
    $m = Join-Path $ClaudeDir $name
    $s = Join-Path $store $name
    if ($Export) { Sync-Tree $m $s $name } else { Sync-Tree $s $m $name }
}

Write-Step "`nSkills..."

# Own skills are the real folders in the skills folder. Skills installed from
# a remote source, by the skills CLI or skillshare, reinstall through
# external.json; synced\ follows the claude.ai account.
$lockFile = Join-Path $HOME '.agents\.skill-lock.json'
$cliSkills = if (Test-Path -LiteralPath $lockFile) {
    @((Get-Content -LiteralPath $lockFile -Raw | ConvertFrom-Json -AsHashtable).skills.Keys)
} else { @() }
$remoteSkills = @($cliSkills) + @($ssEntries.Keys)
$skillNames = if ($Export) {
    Get-ChildItem -LiteralPath $skillsDir -Directory -Force |
        Where-Object {
            -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -and
            $_.Name -ne 'synced' -and -not $_.Name.StartsWith('.') -and
            $remoteSkills -notcontains $_.Name
        } |
        ForEach-Object Name
} else {
    Get-ChildItem -LiteralPath (Join-Path $store 'skills') -Directory | ForEach-Object Name
}
$skillNames = @($skillNames | Where-Object { Test-SkillSelected $_ })
Sync-Folders $skillsDir (Join-Path $store 'skills') $skillNames 'skill'

# ── 2. feedback memories ────────────────────────────────────────────────────
Write-Step "`nFeedback memories ($memDir)..."

$storeMem   = Join-Path $store 'memory'
$machineIdx = Join-Path $memDir 'MEMORY.md'
$storeIdx   = Join-Path $storeMem 'MEMORY.md'

if ($Export) {
    $feedback = @(Get-ChildItem -LiteralPath $memDir -Filter '*.md' -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -ne 'MEMORY.md' -and
            (Get-Content -LiteralPath $_.FullName -Raw) -match '(?m)^\s*type:\s*feedback\s*$'
        })
    $n = @{ added = 0; updated = 0; same = 0; removed = 0 }
    foreach ($f in $feedback) { $n[(Copy-Managed $f.FullName (Join-Path $storeMem $f.Name))]++ }
    foreach ($f in Get-ManagedFiles $storeMem) {
        if ($f.Name -ne 'MEMORY.md' -and $feedback.Name -notcontains $f.Name) {
            Remove-Item -LiteralPath $f.FullName
            $n.removed++
        }
    }
    # The index keeps only the lines that point at an exported memory.
    $lines = if (Test-Path -LiteralPath $machineIdx) {
        Get-Content -LiteralPath $machineIdx | Where-Object {
            $line = $_
            $feedback | Where-Object { $line.Contains("($($_.Name))") }
        }
    }
    $n[(Write-Managed $storeIdx (Convert-Content $utf8.GetBytes((@($lines) -join "`n") + "`n")))]++
    Write-Result "$($feedback.Count) feedback memories" $n
}
else {
    $n = @{ added = 0; updated = 0; same = 0; removed = 0 }
    foreach ($f in Get-ManagedFiles $storeMem) {
        if ($f.Name -ne 'MEMORY.md') { $n[(Copy-Managed $f.FullName (Join-Path $memDir $f.Name))]++ }
    }
    # Merge by file name: an index line is added only when no line on this
    # machine points at the same memory file. Existing lines stay untouched.
    $current = if (Test-Path -LiteralPath $machineIdx) { Get-Content -LiteralPath $machineIdx -Raw } else { '' }
    if ($null -eq $current) { $current = '' }
    $storeLines = if (Test-Path -LiteralPath $storeIdx) { (Read-StoreText $storeIdx) -split "`r?`n" }
    $missing = @($storeLines | Where-Object {
        $_ -match '\(([^)]+\.md)\)' -and -not $current.Contains("($($Matches[1]))")
    })
    if ($missing) {
        if (Test-Path -LiteralPath $machineIdx) { Backup-File $machineIdx }
        New-Item -ItemType Directory -Force -Path $memDir | Out-Null
        $sep = if ($current -and -not $current.EndsWith("`n")) { "`n" } else { '' }
        [IO.File]::WriteAllText($machineIdx, $current + $sep + ($missing -join "`n") + "`n", $utf8)
        $n.updated++
    }
    Write-Result 'feedback memories' $n
}

# ── 3. repo-local settings ──────────────────────────────────────────────────
Write-Step "`nRepo-local settings ($WorkDir)..."

$storeRepo = Join-Path $store 'repo-settings'

if ($Export) {
    # A settings.local.json that holds only {} carries nothing worth porting.
    $repos = @(Get-ChildItem -LiteralPath $WorkDir -Directory -ErrorAction SilentlyContinue | Where-Object {
        $f = Join-Path $_.FullName '.claude\settings.local.json'
        (Test-Path -LiteralPath $f) -and (Get-Content -LiteralPath $f -Raw).Trim() -ne '{}'
    } | ForEach-Object Name)
    foreach ($repo in $repos) {
        $state = Copy-Managed (Join-Path $WorkDir "$repo\.claude\settings.local.json") `
                              (Join-Path $storeRepo "$repo\settings.local.json")
        if ($state -eq 'same') { Write-Ok $repo } else { Write-Add "$repo ($state)" }
    }
    foreach ($d in Get-ChildItem -LiteralPath $storeRepo -Directory -ErrorAction SilentlyContinue) {
        if ($repos -notcontains $d.Name) {
            Remove-Item -LiteralPath $d.FullName -Recurse
            Write-Add "$($d.Name) (removed)"
        }
    }
}
else {
    foreach ($d in Get-ChildItem -LiteralPath $storeRepo -Directory -ErrorAction SilentlyContinue) {
        $repoDir = Join-Path $WorkDir $d.Name
        if (-not (Test-Path -LiteralPath $repoDir)) {
            Write-Step "    $($d.Name) is not cloned in $WorkDir — skipped."
            continue
        }
        $state = Copy-Managed (Join-Path $d.FullName 'settings.local.json') `
                              (Join-Path $repoDir '.claude\settings.local.json')
        if ($state -eq 'same') { Write-Ok $d.Name } else { Write-Add "$($d.Name) ($state)" }
    }
}

# ── 4. plugins, skills-CLI and skillshare skills, MCP servers ───────────────
$externalFile = Join-Path $store 'external.json'

if ($Export) {
    Write-Step "`nExternal list..."
    $skillsCli = @()
    if (Test-Path -LiteralPath $lockFile) {
        $lock = Get-Content -LiteralPath $lockFile -Raw | ConvertFrom-Json -AsHashtable
        foreach ($k in $lock.skills.Keys | Where-Object { Test-SkillSelected $_ } | Sort-Object) {
            $skillsCli += [ordered]@{ name = $k; source = $lock.skills[$k].source }
        }
    }
    $configFile = Join-Path (Split-Path $ClaudeDir -Parent) '.claude.json'
    $mcp = [ordered]@{}
    if (Test-Path -LiteralPath $configFile) {
        $servers = (Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json -AsHashtable).mcpServers
        if ($servers) { foreach ($k in $servers.Keys | Sort-Object) { $mcp[$k] = $servers[$k] } }
    }
    $skillshare = @($ssEntries.Keys | Where-Object { Test-SkillSelected $_ } | Sort-Object | ForEach-Object {
        [ordered]@{ name = $_; source = $ssEntries[$_].source }
    })
    $json  = ([ordered]@{ skillsCli = $skillsCli; skillshare = $skillshare; mcpServers = $mcp } |
              ConvertTo-Json -Depth 10) -replace "`r`n", "`n"
    $state = Write-Managed $externalFile (Convert-Content $utf8.GetBytes($json + "`n"))
    $summary = "external.json: $($skillsCli.Count) skills-CLI skills, $($skillshare.Count) skillshare skills, $($mcp.Count) MCP servers"
    if ($state -eq 'same') { Write-Ok $summary } else { Write-Add "$summary ($state)" }
}
elseif ($SkipExternal) {
    Write-Step "`nPlugins, skills-CLI and skillshare skills, MCP servers (-SkipExternal, skipped)."
}
elseif (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host ''
    Write-Warn2 'claude not on PATH — plugins, skills-CLI and skillshare skills, and MCP servers skipped.'
    Write-Warn2 'Install Claude Code, then re-run this script.'
}
else {
    Write-Step "`nPlugins..."
    $settings = Get-Content -LiteralPath (Join-Path $ClaudeDir 'settings.json') -Raw | ConvertFrom-Json -AsHashtable

    $knownMarkets = @(claude plugin marketplace list --json | ConvertFrom-Json | ForEach-Object name)
    foreach ($k in @($settings.extraKnownMarketplaces.Keys)) {
        $src = $settings.extraKnownMarketplaces[$k].source
        if ($knownMarkets -contains $k) { Write-Ok "marketplace $k" }
        elseif ($src.source -ne 'github') { Write-Warn2 "marketplace $k has source '$($src.source)' — add it by hand." }
        else {
            claude plugin marketplace add $src.repo
            if ($LASTEXITCODE -eq 0) { Write-Add "marketplace $k" } else { Write-Warn2 "marketplace $k failed (exit $LASTEXITCODE)" }
        }
    }

    $installed = @(claude plugin list --json | ConvertFrom-Json | ForEach-Object id)
    foreach ($k in @($settings.enabledPlugins.Keys | Sort-Object)) {
        if (-not $settings.enabledPlugins[$k] -or $k -like '*@builtin') { continue }
        if ($installed -contains $k) { Write-Ok $k; continue }
        claude plugin install $k
        if ($LASTEXITCODE -eq 0) { Write-Add $k } else { Write-Warn2 "$k failed (exit $LASTEXITCODE)" }
    }

    $external = Read-StoreText $externalFile | ConvertFrom-Json -AsHashtable

    Write-Step "`nSkills-CLI skills..."
    $hasNpx = [bool](Get-Command npx -ErrorAction SilentlyContinue)
    foreach ($s in @($external.skillsCli | Where-Object { $_ -and (Test-SkillSelected $_.name) })) {
        if (Test-Path -LiteralPath (Join-Path $HOME ".claude\skills\$($s.name)")) { Write-Ok $s.name; continue }
        if (-not $hasNpx) { Write-Warn2 "$($s.name) missing — npx not on PATH. Install Node.js, then re-run."; continue }
        # -a claude-code: without it the CLI links the skill into every agent it knows.
        npx skills add $s.source --skill $s.name -g -a claude-code -y
        if ($LASTEXITCODE -eq 0) { Write-Add $s.name } else { Write-Warn2 "$($s.name) failed (exit $LASTEXITCODE)" }
    }

    Write-Step "`nSkillshare skills..."
    $hasSkillshare = [bool](Get-Command skillshare -ErrorAction SilentlyContinue)
    foreach ($s in @($external.skillshare | Where-Object { $_ -and (Test-SkillSelected $_.name) })) {
        $present = (Test-Path -LiteralPath (Join-Path $HOME ".claude\skills\$($s.name)")) -or
                   ($ssSource -and (Test-Path -LiteralPath (Join-Path $ssSource $s.name)))
        if ($present) { Write-Ok $s.name; continue }
        if (-not $hasSkillshare) { Write-Warn2 "$($s.name) missing — skillshare not on PATH. Install skillshare, then re-run."; continue }
        # --name: the default name is the source folder, which can differ from the recorded name.
        skillshare install $s.source --name $s.name -y
        if ($LASTEXITCODE -eq 0) { Write-Add $s.name } else { Write-Warn2 "$($s.name) failed (exit $LASTEXITCODE)" }
    }

    Write-Step "`nMCP servers..."
    # Key order differs between the manifest and ~/.claude.json, so both sides
    # are compared with keys sorted at every level.
    function ConvertTo-SortedJson($value) {
        $sort = {
            param($v)
            if ($v -is [Collections.IDictionary]) {
                $o = [ordered]@{}
                foreach ($k in $v.Keys | Sort-Object) { $o[$k] = & $sort $v[$k] }
                $o
            } elseif ($v -is [Collections.IList]) {
                , @($v | ForEach-Object { & $sort $_ })
            } else { $v }
        }
        (& $sort $value) | ConvertTo-Json -Depth 10 -Compress
    }
    $userConfig = Join-Path $HOME '.claude.json'
    $userServers = if (Test-Path -LiteralPath $userConfig) {
        (Get-Content -LiteralPath $userConfig -Raw | ConvertFrom-Json -AsHashtable).mcpServers
    }
    if (-not $userServers) { $userServers = @{} }
    foreach ($name in @($external.mcpServers.Keys)) {
        $want = $external.mcpServers[$name] | ConvertTo-Json -Depth 10 -Compress
        if ($userServers.Contains($name)) {
            if ((ConvertTo-SortedJson $userServers[$name]) -eq (ConvertTo-SortedJson $external.mcpServers[$name])) {
                Write-Ok $name; continue
            }
            # The old user definition is kept beside the file backups.
            $old = Join-Path $backupRoot "mcp\$name.json"
            New-Item -ItemType Directory -Force -Path (Split-Path $old -Parent) | Out-Null
            [IO.File]::WriteAllText($old, ($userServers[$name] | ConvertTo-Json -Depth 10), $utf8)
            $script:backedUp++
            claude mcp remove -s user $name *> $null
            claude mcp add-json -s user $name $want
            if ($LASTEXITCODE -eq 0) { Write-Add "$name (updated)" } else { Write-Warn2 "$name update failed (exit $LASTEXITCODE)" }
            continue
        }
        claude mcp get $name *> $null
        if ($LASTEXITCODE -eq 0) { Write-Ok "$name (defined outside user scope)"; continue }
        claude mcp add-json -s user $name $want
        if ($LASTEXITCODE -eq 0) { Write-Add $name } else { Write-Warn2 "$name failed (exit $LASTEXITCODE)" }
    }
}

# Links the skills in the skillshare source, own and installed, into its targets.
if (-not $Export -and $ssSource -and (Get-Command skillshare -ErrorAction SilentlyContinue) -and
    ($useSkillshare -or -not $SkipExternal)) {
    Write-Step "`nSkillshare sync..."
    skillshare sync
    if ($LASTEXITCODE -ne 0) { Write-Warn2 "skillshare sync failed (exit $LASTEXITCODE)" }
}

if (-not $Export -and -not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host ''
    Write-Warn2 'python not on PATH — the git push guard hook in settings.json will not run.'
}

if ($script:backedUp) {
    Write-Host ''
    Write-Warn2 "$($script:backedUp) changed files backed up to $backupRoot"
}
$next = if ($Export) { 'Review the diff in claude\ before committing.' } else { 'Restart Claude Code to load the changes.' }
Write-Host "`nDone. $next`n" -ForegroundColor Green
