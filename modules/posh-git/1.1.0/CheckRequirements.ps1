$global:GitMissing = $false
$script:GitCygwin = $false
$script:GitVersion = $requiredVersion = [System.Version]'2.15'

# ---------------------------------------------------------------------------
# LOCAL PERF EDIT — not upstream posh-git.
#
# Upstream calls Test-GitVersion at import, which spawns `git --version` as a
# subprocess (~35ms measured) on every single module load. Its entire purpose
# is to populate $script:GitVersion and $script:GitCygwin.
#
# Those are read in exactly three places:
#   GitTabExpansion.ps1:63  GitVersion -ge 2.16.2 -> offer the
#                           'update-git-for-windows' completion
#   PoshGitTypes.ps1:226    GitCygwin  -> AnsiConsole default
#   PoshGitTypes.ps1:273    GitMissing -> EnablePromptStatus default
#
# Installed here: git 2.55.0.windows.3 — Git for Windows, so GitCygwin is
# $false and the 2.16.2 gate passes. Pinning the value below skips the
# subprocess while keeping all three consumers correct.
#
# If you ever change your Git installation, either update PinnedGitVersion or
# set $Env:POSHGIT_NO_PIN to fall back to upstream runtime detection.
#
# Update-Module overwrites this file. A pristine copy of the whole module is
# kept alongside it in ..\posh-git\1.1.0-pristine-backup\
# ---------------------------------------------------------------------------
$script:PinnedGitVersion = [System.Version]'2.55.0'

if (!(Get-Command git -TotalCount 1 -ErrorAction SilentlyContinue)) {
    Write-Warning "git command could not be found. Please create an alias or add it to your PATH."
    $global:GitMissing = $true
    return
}

function Test-GitVersion ($version = $([string](git --version 2> $null))) {
    if ($version -notmatch '(?<ver>\d+(?:\.\d+)+)(?<g4w>(?<rc>[-.]rc\d+)?\.windows|\.vfs)?') {
        Write-Warning "posh-git could not parse Git version ($version)"
        $script:GitVersion = $version
        return $false
    }

    # On Windows, check if Git is not "Git for Windows"
    if ((($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows) -and !$Matches['g4w']) {
        $script:GitCygwin = $true

        if (!$Env:POSHGIT_CYGWIN_WARNING) {
            Write-Warning 'You appear to have an unsupported Git distribution; setting $GitPromptSettings.AnsiConsole = $false. posh-git recommends Git for Windows.'
        }
    }

    $script:GitVersion = [System.Version]$Matches['ver']

    return $GitVersion -ge $requiredVersion
}

if ($Env:POSHGIT_NO_PIN) {
    # Upstream behaviour: detect at runtime, paying for the subprocess.
    if (!(Test-GitVersion)) {
        Write-Warning "posh-git requires Git $requiredVersion or better. You have $GitVersion."
    }
}
else {
    $script:GitVersion = $script:PinnedGitVersion
}
