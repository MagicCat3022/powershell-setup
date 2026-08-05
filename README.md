# powershell-setup

Portable PowerShell 7 environment: starship prompt, patched posh-git completion,
and PSReadLine history predictions. Clone, run `install.ps1`, open a new
terminal.

## Install on a new machine

```powershell
git clone <this-repo> $HOME\Documents\Github\powershell-setup
& $HOME\Documents\Github\powershell-setup\install.ps1
```

`install.ps1` is idempotent — re-run it after every `git pull`. It checks
prerequisites, junctions `modules\posh-git` into the user module path, and
appends a dot-source stub to `$PROFILE`.

Prerequisites: PowerShell 7+, git, and
[starship](https://starship.rs) (`winget install Starship.Starship`).
A Nerd Font is required for the prompt's icons — this setup was built against
`DroidSansM Nerd Font Mono`, set as the Windows Terminal default font.

## Layout

```
install.ps1              wires the repo into the current machine
profile/profile.ps1      the portable profile, dot-sourced from $PROFILE
starship/starship.toml   prompt config (loaded via $env:STARSHIP_CONFIG)
modules/posh-git/1.1.0/  posh-git 1.1.0 with local patches
```

Machine-specific settings deliberately stay **out** of this repo and remain in
the local `$PROFILE` — notably the PowerToys CommandNotFound block, which
PowerToys manages and rewrites itself.

## The posh-git patches

Upstream posh-git 1.1.0 is vendored here with three local changes, each marked
by a `LOCAL EDIT` comment block in the source. The first commit is pristine
upstream and the second is the patch, so the diff is always recoverable:

```powershell
git log --oneline -- modules/posh-git
git diff <pristine-commit> <patch-commit> -- modules/posh-git
```

### 1. No `git --version` subprocess at import

`CheckRequirements.ps1` ran `git --version` on every module import (~35ms) only
to populate `$script:GitVersion` and `$script:GitCygwin`. Both are pinned now.
Set `$Env:POSHGIT_NO_PIN` to restore upstream runtime detection.

> If you install this on a machine with a materially older Git, update
> `$script:PinnedGitVersion` in `CheckRequirements.ps1`. The only consumer that
> cares is a `>= 2.16.2` check gating the `update-git-for-windows` completion.

### 2. Branch completion is ~4x faster

`git checkout <TAB>` fans out to `gitBranches` + `gitRemoteUniqueBranches` +
`gitTags` — upstream, four `git` subprocesses per keypress at ~40ms each. One
`git for-each-ref` now fetches heads, remotes and tags together behind a
3-second cache.

Measured on a repo with 158 local + 158 remote branches and 2 tags:

| | upstream | patched |
|---|---|---|
| warm cache | 185ms | 48ms |
| cold cache | 185ms | 157ms |

(~32ms of that is the completion framework itself, so warm is near the floor.)

Tune with `$GitTabSettings.RefCacheSeconds`; `0` disables caching. The tradeoff:
a branch created or fetched **in another window** can take up to 3s to appear.
Branches created in the same shell are unaffected.

### 3. Subsequence branch matching

Upstream filtered with `-like "$filter*"` — prefix only. Now the filter's
characters need only appear in order, left to right, anywhere in the name:

```
q124   -> bq1124
falog  -> feature/auth-login, feature/auth-logout
login  -> feature/auth-login, fix/login-crash
```

Results are bucketed **prefix > substring > scattered**, alphabetical within
each tier, so typing a prefix behaves exactly as it always did — new matches
only ever appear below the old ones. Applied to tags and remote-unique branches
too, so one Tab never mixes match semantics.

## Updating posh-git

`Update-Module` does not apply here — the module is vendored, not installed.
To move to a new upstream release:

1. `Save-Module posh-git -Path <tmp> -RequiredVersion <new>`
2. Commit that pristine tree over `modules/posh-git/`.
3. Re-apply the patch: `git cherry-pick <patch-commit>`, or diff the old pair
   and port the `LOCAL EDIT` blocks by hand.

### Gotcha worth remembering

Functions returning `List[string]` must use the unary-comma idiom (`,$list`).
Without it PowerShell unrolls the List into `Object[]` — or a bare `String`
when it holds one element — and callers lose `.AddRange`. This silently
empties every completion rather than raising anything obvious.

## Keyboard

| Key | Action |
|---|---|
| `Tab` | completion grid (`MenuComplete`) |
| `→` | accept inline history suggestion |
| `Ctrl+→` | accept one word of it |
| `F2` | toggle inline ⟷ list prediction view |

## Credits

posh-git is MIT licensed, © Keith Dahlby and contributors —
<https://github.com/dahlbyk/posh-git>. It is vendored here, with patches, only
to keep the customizations portable.
