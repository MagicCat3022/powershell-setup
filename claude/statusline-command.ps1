param()
$input_text = $input | Out-String
$d = $input_text | ConvertFrom-Json

$cwd      = if ($d.cwd) { $d.cwd } else { $d.workspace.current_dir }
$model    = if ($d.model.display_name) { $d.model.display_name } else { $d.model.id }
$effort   = $d.effort.level
$ctxPct   = $d.context_window.remaining_percentage
$sessUsed = $d.rate_limits.five_hour.used_percentage
$cost     = $d.cost.total_cost_usd

$folder = Split-Path $cwd -Leaf

# Git info
$branch = & git -C $cwd rev-parse --abbrev-ref HEAD 2>$null
$ins = 0; $del = 0; $untracked = 0
if ($branch) {
    $diff = & git -C $cwd diff HEAD --shortstat 2>$null
    if ($diff -match '(\d+) insertion') { $ins = [int]$Matches[1] }
    if ($diff -match '(\d+) deletion')  { $del = [int]$Matches[1] }
    $untrackedFiles = & git -C $cwd ls-files --others --exclude-standard 2>$null
    if ($untrackedFiles) {
        $untrackedFiles = @($untrackedFiles)
        $untracked = $untrackedFiles.Count
        foreach ($f in $untrackedFiles) {
            $fullPath = Join-Path $cwd $f
            if (Test-Path $fullPath -PathType Leaf) {
                $ins += (Get-Content $fullPath -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
            }
        }
    }
}

# ANSI helpers
function Col($code, $text) { "$([char]27)[$($code)m$text$([char]27)[0m" }
$DIM = "$([char]27)[2m"
$RST = "$([char]27)[0m"

$parts = @()
$parts += Col 36 $folder
if ($branch) {
    $parts += Col 33 $branch
    $gitStr = "$(Col 32 "+$ins")/$(Col 31 "-$del")"
    if ($untracked -gt 0) { $gitStr += "/$(Col 33 "?$untracked")" }
    $parts += $gitStr
}
$modelStr = if ($effort) { "$model[$effort]" } else { $model }
$parts += Col 34 $modelStr
if ($null -ne $ctxPct) { $parts += Col 35 "ctx:$([int]$ctxPct)%" }
if ($null -ne $sessUsed) { $parts += Col 36 "sess:$([int](100 - $sessUsed))%" }
if ($null -ne $cost)   { $parts += "${DIM}`$$($cost.ToString('F4'))${RST}" }

$sep = "${DIM} | ${RST}"
Write-Host ($parts -join $sep) -NoNewline
Write-Host ""
