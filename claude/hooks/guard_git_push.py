"""PreToolUse hook for Bash and PowerShell.

Asks for confirmation before a git push that rewrites or deletes a remote branch, or that
targets a protected branch. Any parse failure allows the command, so the hook never blocks
work on its own error.
"""

import json
import os
import re
import shlex
import subprocess
import sys

PROTECTED = {"dev", "main", "master"}
# Screenshot branches that PR descriptions link to by commit. Rewriting them is routine.
EXEMPT_PREFIXES = ("pr-assets/",)

SEPARATORS = re.compile(r"&&|\|\||;|\||\r?\n")
REDIRECT = re.compile(r"^\d*>|^<|^\d*>&\d$")
FORCE_FLAGS = ("--force", "--force-with-lease", "--force-if-includes")
VALUE_OPTIONS = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}
GIT_VALUE_OPTIONS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}


def tokens(segment):
    lexer = shlex.shlex(segment, posix=True)
    lexer.whitespace_split = True
    # Windows paths keep their backslashes.
    lexer.escape = ""
    try:
        return list(lexer)
    except ValueError:
        return segment.split()


def to_windows_path(path):
    path = os.path.expanduser(path)
    match = re.match(r"^/([a-zA-Z])(/.*)?$", path)
    if match:
        path = f"{match.group(1).upper()}:{match.group(2) or '/'}"
    return path


def resolve_dir(current, target):
    if target is None or "$" in target or current is None and not os.path.isabs(to_windows_path(target)):
        return None
    target = to_windows_path(target)
    return os.path.normpath(target if os.path.isabs(target) else os.path.join(current, target))


def current_branch(directory):
    if directory is None:
        return None
    try:
        result = subprocess.run(
            ["git", "-C", directory, "symbolic-ref", "--quiet", "--short", "HEAD"],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return result.stdout.strip() or None if result.returncode == 0 else None


def short_ref(ref):
    return ref[len("refs/heads/"):] if ref.startswith("refs/heads/") else ref


def exempt(branch):
    return branch is not None and branch.startswith(EXEMPT_PREFIXES)


def check_push(args, directory):
    """Returns the reasons to ask about one git push, given the arguments after `push`."""
    force = mirror = delete = tags_only = False
    positionals = []
    skip = False
    for arg in args:
        if skip:
            skip = False
            continue
        if REDIRECT.match(arg):
            continue
        if arg in VALUE_OPTIONS:
            skip = True
        elif arg.startswith(FORCE_FLAGS) or re.fullmatch(r"-[a-zA-Z]*f[a-zA-Z]*", arg):
            force = True
        elif arg in ("--delete", "-d"):
            delete = True
        elif arg in ("--mirror", "--all"):
            mirror = True
        elif arg == "--tags":
            tags_only = True
        elif not arg.startswith("-"):
            positionals.append(arg)

    refspecs = positionals[1:]
    branch = None
    targets = []
    for spec in refspecs:
        spec_force = spec.startswith("+")
        spec = spec.lstrip("+")
        src, _, dst = spec.partition(":")
        if not dst:
            dst = src
        if dst == "HEAD":
            branch = branch or current_branch(directory)
            dst = branch
        dst = short_ref(dst) if dst else dst
        targets.append((dst, spec_force, src == "" or delete))
    if not refspecs and not tags_only and not mirror:
        branch = current_branch(directory)
        targets.append((branch, False, False))

    reasons = []
    if mirror:
        reasons.append("pushes every branch (--mirror or --all)")
    for dst, spec_force, spec_delete in targets:
        name = dst or "the current branch"
        if exempt(dst):
            continue
        if spec_delete:
            reasons.append(f"deletes the remote branch {name}")
        elif force or spec_force:
            reasons.append(f"force-pushes {name}")
        if dst in PROTECTED and not spec_delete:
            reasons.append(f"pushes to the protected branch {name}")
    return reasons


def check_command(command, cwd):
    reasons = []
    directory = cwd
    for segment in SEPARATORS.split(command):
        words = tokens(segment.strip())
        while words and (re.match(r"^\w+=", words[0]) or words[0] in ("&", "command", "exec")):
            words = words[1:]
        if not words:
            continue
        head = words[0].lower()
        if head in ("cd", "set-location", "sl", "pushd", "push-location") and len(words) > 1:
            rest = [w for w in words[1:] if w.lower() not in ("-path", "-literalpath")]
            directory = resolve_dir(directory, rest[0] if rest else None)
            continue
        if head not in ("git", "git.exe"):
            continue
        index = 1
        git_dir = directory
        while index < len(words) and words[index].startswith("-"):
            option = words[index]
            if option in GIT_VALUE_OPTIONS and index + 1 < len(words):
                if option == "-C":
                    git_dir = resolve_dir(git_dir, words[index + 1])
                index += 2
            else:
                index += 1
        if index < len(words) and words[index] == "push":
            reasons.extend(check_push(words[index + 1:], git_dir))
    return list(dict.fromkeys(reasons))


def main():
    try:
        data = json.load(sys.stdin)
        command = (data.get("tool_input") or {}).get("command") or ""
        if "push" not in command:
            return
        reasons = check_command(command, data.get("cwd"))
    except Exception:
        return
    if reasons:
        reason = "git push " + "; ".join(reasons) + ". Confirm before it runs."
        print(
            json.dumps(
                {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": "ask",
                        "permissionDecisionReason": reason,
                    }
                }
            )
        )


if __name__ == "__main__":
    main()
