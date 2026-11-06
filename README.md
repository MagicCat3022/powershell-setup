# powershell-setup

Portable PowerShell 7 environment: starship prompt, patched posh-git completion,
and PSReadLine history predictions. Clone, run `install.ps1`, open a new
terminal.

## Install on a new machine

```powershell
git clone https://github.com/MagicCat3022/powershell-setup.git $HOME\Documents\Github\powershell-setup
& $HOME\Documents\Github\powershell-setup\install.ps1
```

This repo is public, so the clone needs no sign-in. A push authenticates through
the Git Credential Manager bundled with Git for Windows, with a browser sign-in
on first use — no SSH key or `ssh-agent` needed. The install path above is only a
convention; `install.ps1` resolves its own location, so the repo works from
anywhere you clone it.

`install.ps1` is idempotent — re-run it after every `git pull`.

## Prerequisites

Two are **bootstrap** requirements the script cannot install for you, for
circular reasons — you are already running PowerShell, and git is how you got
this repo:

| | install with |
|---|---|
| PowerShell 7+ | `winget install Microsoft.PowerShell` |
| git | `winget install Git.Git` |

Everything else `install.ps1` installs itself if missing, all per-user, with
**no administrator rights required**:

| | how | why |
|---|---|---|
| [starship](https://starship.rs) | `winget` | the prompt |
| PSReadLine 2.2+ | PSGallery | `PredictionSource` needs 2.2; older versions throw and predictions end up silently dead |
| `DroidSansM Nerd Font Mono` | Nerd Fonts GitHub release | the prompt's git/language icons render as tofu boxes without it |
| Windows Terminal font | patches `settings.json` | installing the font achieves nothing visible until something selects it |

Pass `-SkipPrereqs` to only link the module and wire `$PROFILE`; missing
prerequisites are still reported.

### Why the font doesn't come from winget

winget carries exactly one Nerd Font — JetBrainsMono
(`DEVCOM.JetBrainsMonoNerdFont`) — and not DroidSansMono. So the font is pulled
from the [Nerd Fonts releases](https://github.com/ryanoasis/nerd-fonts/releases)
and installed per-user: files into `%LOCALAPPDATA%\Microsoft\Windows\Fonts`,
registered under `HKCU`. The family name is read out of each font file rather
than guessed from its filename, because the registry entry has to match what
Windows and Windows Terminal call the font.

To use a different font, pass **both** parameters — they have to agree:

```powershell
.\install.ps1 -NerdFont JetBrainsMono -NerdFontFamily 'JetBrainsMono Nerd Font Mono'
```

### Windows Terminal font caveat

`settings.json` is JSONC and hand-editable, so it is patched textually —
round-tripping it through `ConvertTo-Json` would strip every comment. Only the
unambiguous empty-`"defaults": {}` shape is rewritten. If you already have
profile defaults, the script tells you to set the font yourself rather than
risk a regex matching some other profile's font. The file is backed up
alongside itself before any edit.

## Layout

```
install.ps1              wires the repo into the current machine
profile/profile.ps1      the portable profile, dot-sourced from $PROFILE
starship/starship.toml   prompt config (loaded via $env:STARSHIP_CONFIG)
modules/posh-git/1.1.0/  posh-git 1.1.0 with local patches
install-claude.ps1       installs or exports the Claude Code setup
claude/                  the Claude Code setup (see "Claude Code" below)
install-omp.ps1          installs or exports the Oh My Pi setup
omp/                     the Oh My Pi setup (see "Oh My Pi" below)
```

Machine-specific settings deliberately stay **out** of this repo and remain in
the local `$PROFILE` — notably the PowerToys CommandNotFound block, which
PowerToys manages and rewrites itself.

## The posh-git patches

Upstream posh-git 1.1.0 is vendored here with four local changes, each marked
by a `LOCAL EDIT` comment block in the source. The first commit is pristine
upstream and the second is the patch, so the diff is always recoverable:

```powershell
git log --oneline -- modules/posh-git
git diff 2ab92ed e591b69 -- modules/posh-git   # the patch, in isolation
```

| commit | contents |
|---|---|
| `2ab92ed` | posh-git 1.1.0 exactly as PSGallery ships it |
| `e591b69` | the three local patches, and nothing else |

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

### 4. File completion works under a non-posh-git prompt

`Expand-GitCommand` passed `$Global:GitStatus` to the completer, but that
variable is populated by **posh-git's own prompt function** — which starship
replaces. It was therefore always `$null`, and every file completion silently
degraded to raw filesystem paths:

| `git add fi<TAB>` | |
|---|---|
| upstream, under starship | `.\file1.txt … .\file5.txt` — every file, plus `.git\` |
| patched | `file1.txt, file2.txt, file3.txt` — only the modified ones |

`git checkout -- <TAB>` was worse: it offered branch names instead of paths.

The status is now computed on demand, but only for the commands that consume
it — `add`, `rm`, `mv`, `reset`, `restore`, `diff`, `difftool`, `merge`,
`mergetool`, and the `-- <path>` form. `Get-GitStatus` costs ~48ms, and a plain
`git checkout` deliberately does **not** pay it:

| | |
|---|---|
| `git checkout ma<TAB>` | 30ms — unchanged |
| `git add fi<TAB>` | 55ms — up from 29ms, and now correct |

Unlike the ref cache this result is **not** cached: working-tree state changes
far more often than refs do, and a stale file list would actively mislead.

> Only literal command names are matched, before posh-git expands aliases. If
> you alias e.g. `a = add`, `git a <TAB>` falls back to filesystem completion.
> Add the alias to `$script:gitNeedsStatusPattern` if that matters.

## Updating posh-git

`Update-Module` does not apply here — the module is vendored, not installed.
To move to a new upstream release:

1. `Save-Module posh-git -Path <tmp> -RequiredVersion <new>`
2. Commit that pristine tree over `modules/posh-git/`.
3. Re-apply the patch: `git cherry-pick e591b69`, or port the `LOCAL EDIT`
   blocks by hand if upstream has moved the surrounding code far enough that
   the cherry-pick conflicts.
4. Re-run `install.ps1` on each machine (it is idempotent), then confirm
   completion still works — `git checkout <TAB>` in a repo with branches.

### Gotcha worth remembering

Functions returning `List[string]` must use the unary-comma idiom (`,$list`).
Without it PowerShell unrolls the List into `Object[]` — or a bare `String`
when it holds one element — and callers lose `.AddRange`. This silently
empties every completion rather than raising anything obvious.

## Claude Code

`claude/` holds a generic Claude Code setup: the global rules (`CLAUDE.md`),
settings, the status line script, the git push guard hook, agents, skills, and
feedback memories. Nothing in it names a company, a repo, or a host.
`install-claude.ps1` copies it in either direction.

```powershell
.\install-claude.ps1           # repo -> this machine
.\install-claude.ps1 -Export   # this machine -> repo
```

| | |
|---|---|
| `CLAUDE.md`, `settings.json`, `statusline-command.ps1`, `hooks/`, `agents/` | `~/.claude` |
| `skills/<name>/` | own skills: the skillshare source folder when skillshare is set up, else `~/.claude/skills`. Export takes every real folder there except `synced`, dot-folders, and skills installed from a remote source. |
| `memory/` | the work folder's project memory. Export takes the `type: feedback` memories. Install adds index lines to `MEMORY.md` by file name. |
| `repo-settings/<repo>/` | `<work folder>/<repo>/.claude/settings.local.json`, for repos that are cloned. Export creates one for each repo with local settings. |
| `external.json` | skills-CLI skills, skillshare skills (by source), and user MCP servers. Install adds what is missing and replaces a user MCP server whose definition differs, keeping the old one in the backup folder under `mcp/`. |

- Install installs the plugins set to `true` in `enabledPlugins` in `settings.json`,
  and adds the marketplaces in `extraKnownMarketplaces`.
- Install never deletes. It copies each file it changes to
  `~/.claude/backups/powershell-setup-<timestamp>/` first.
- Export mirrors the machine. A skill, agent, or memory deleted locally is
  deleted from `claude/`.
- Home paths are stored as `{{HOME}}` (`C:/Users/<name>`) and `{{HOME_JSON}}`
  (`C:\\Users\\<name>`), and the work folder as `{{WORK}}`.
- The work folder is `~/Work` when it exists, else `~/Documents/Github`. Pass
  `-WorkDir` to choose another.
- `-SkipSettings` leaves `settings.json` alone on the machine and in the repo,
  for a machine that keeps its own settings. Install then installs the plugins
  that machine's `settings.json` enables.
- `-SkipClaudeMd` leaves `CLAUDE.md` alone on the machine and in the repo, for a
  machine that keeps its own global rules.
- When skillshare is set up, install runs `skillshare sync` last, which links
  the skills into every skillshare target.
- `-Skills` and `-ExcludeSkills` take skill names, wildcards allowed, and
  apply to own, skills-CLI, and skillshare skills. Install installs only the
  selected skills. Export keeps only the selected skills in `claude/`:
  `.\install-claude.ps1 -Export -ExcludeSkills deadlock-skins` drops that
  skill from the repo.
- Prerequisites: Claude Code (`claude`), Node.js (`npx`, for skills-CLI skills),
  skillshare (for skillshare skills), and Python (for the git push guard hook).
- To test an install without touching the live setup, run
  `.\install-claude.ps1 -ClaudeDir <empty folder> -WorkDir <empty folder> -SkipExternal`.

On a machine whose `~/.claude` holds company-specific rules or skills:

- Export copies them into `claude/`, company content included. Run export only
  on a machine with the generic setup, and review the diff before committing.
- Install replaces that machine's `CLAUDE.md` and `settings.json` with the
  generic ones, unless `-SkipClaudeMd` and `-SkipSettings` keep them. The
  originals go to the backup folder. Skills with other names stay.

Not included: credentials, `~/.claude.json` (session state), the skills synced
from claude.ai (they follow the account), and project and reference memories
(ticket state).

The semantic search section of `CLAUDE.md` uses a CocoIndex project at
`<work folder>/code-index`, which lives outside this repo. Machines without one
skip that section.

## Oh My Pi

`omp/` holds the [Oh My Pi](https://omp.sh) (`omp`) setup: `config.yml` (model
roles, settings, status line), the `claude-code` theme, and three extensions:
`statusline.ts` draws a colored line under the status bar with the shortened
path, the context used and where auto-compaction fires, and the remaining
Claude/Codex quota. omp keeps extension colors only on that line, so
`config.yml` sets `statusLine.showHookStatus: true` and leaves `status` out of
the segments. `git-push-guard.ts` asks before a risky `git push`, and
`approval-bell.ts` rings the terminal bell when a tool call waits for approval;
both ring the same bell omp uses when a turn ends. `install-omp.ps1` copies it in
either direction.

```powershell
.\install-claude.ps1        # first: omp reads the Claude Code setup
.\install-omp.ps1           # repo -> this machine
.\install-omp.ps1 -Export   # this machine -> repo
```

| | |
|---|---|
| `config.yml` | `~/.omp/agent/config.yml` |
| `themes/`, `extensions/` | `~/.omp/agent/themes`, `~/.omp/agent/extensions` |
| `claude/agents/*.md` | `~/.omp/agent/agents`, rewritten as omp task agents |

omp uses the Claude Code setup in `~/.claude` too. `config.yml` sets
`enabledProviders: [claude]` and `skills.enableClaudeUser: true`, so omp loads:

- `~/.claude/CLAUDE.md` as the global rules, while `~/.omp/agent/AGENTS.md` does
  not exist (that file would replace it);
- the skills in `~/.claude/skills`;
- the Claude Code plugins: their skills, agents, and commands (as
  `/<plugin>:<command>`);
- the user MCP servers in `~/.claude.json`. An OAuth server such as `atlassian`
  needs its own sign-in: `/mcp reauth <name>`. omp drops the `playwright`
  server, because its built-in browser covers it.

Two pieces need an omp form:

- **Agents.** omp skips `~/.claude/agents`, whose frontmatter differs. Install
  writes each agent in `claude/agents` to `~/.omp/agent/agents`: `model:
  inherit` and `color` are dropped, `effort` becomes `thinking-level`, and tool
  names are lowercased.
- **The git push guard.** omp cannot run Claude Code's command hooks.
  `git-push-guard.ts` sends each bash command that mentions `push` to
  `~/.claude/hooks/guard_git_push.py` and shows a confirm dialog when the
  script flags it. Without a UI, as in a subagent or `omp -p`, a flagged push
  is blocked.

Install also:

- installs omp with `irm https://omp.sh/install.ps1 | iex` when `omp` is missing;
- downloads the local model that `modelRoles.tiny` names (`local/<key>`);
- sets `"bellStyle": ["audible", "taskbar"]` in the Windows Terminal profile
  defaults, so a background tab chimes and flashes when omp finishes or asks.
  Run `install.ps1` first: its font step only patches empty profile defaults.

- Install never deletes. It copies each file it changes to
  `~/.omp/agent/backups/powershell-setup-<timestamp>/` first.
- Export mirrors the machine. A theme or extension deleted locally is deleted
  from `omp/`. Export leaves agents alone, since `claude/agents` holds them.
- To test an install without touching the live setup, run
  `.\install-omp.ps1 -AgentDir <empty folder> -SkipExternal`.

After install, sign in with `/login` for each provider `modelRoles` uses
(Anthropic and OpenAI Codex).

Not included: credentials (`agent.db`), sessions, and Mnemopi memories.

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
