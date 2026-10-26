"""Prints the review threads and reviewer comments on a GitHub PR as markdown.

Usage: python fetch_threads.py [PR number, URL, or branch] [--all]

Runs from inside the repo. With no argument, uses the PR for the current branch. Unresolved
threads print in full, most urgent first. Resolved threads print as a one-line digest, for
spotting a finding the AI review bot raises again. --all prints resolved threads in full too.
"""

import json
import re
import subprocess
import sys

THREADS_QUERY = """
query($owner: String!, $name: String!, $number: Int!, $after: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 50, after: $after) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id isResolved isOutdated path line originalLine
          resolvedBy { login }
          comments(first: 50) {
            nodes { author { login } body createdAt url originalCommit { abbreviatedOid } }
          }
        }
      }
    }
  }
}
"""

PR_QUERY = """
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      title url author { login } headRefName baseRefName headRefOid
      reviews(last: 50) { nodes { author { login } state body submittedAt commit { abbreviatedOid } } }
      comments(last: 50) { nodes { author { login } body createdAt url } }
    }
  }
}
"""

SEVERITY_ORDER = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3}
HTML_COMMENT = re.compile(r"<!--.*?-->", re.S)
BODY_LIMIT = 4000


def gh(*args):
    result = subprocess.run(["gh", *args], capture_output=True, text=True, encoding="utf-8")
    if result.returncode != 0:
        sys.exit(f"gh {' '.join(args[:2])} failed: {result.stderr.strip()}")
    return result.stdout


def graphql(query, **variables):
    args = ["api", "graphql", "-f", f"query={query}"]
    for key, value in variables.items():
        if value is not None:
            args += ["-F" if isinstance(value, int) else "-f", f"{key}={value}"]
    return json.loads(gh(*args))["data"]["repository"]["pullRequest"]


def login(node):
    return (node.get("author") or {}).get("login") or "ghost"


def is_bot(name):
    return name.endswith("[bot]") or name in ("github-actions", "copilot-pull-request-reviewer")


def classify(comment):
    """Returns the reviewer kind and, for the AI review bot, its parsed fields."""
    body = comment["body"]
    name = login(comment)
    if "<!--ai-review-" in body:
        source = re.search(r"<!--ai-review-review-source:(\w+)-->", body)
        blocking = re.search(r"<!--ai-review-blocking:(\w+)-->", body)
        severity = re.search(r"\*\*Severity:\*\*\W*(Critical|High|Medium|Low)", body)
        return "AI review", {
            "source": source.group(1) if source else "?",
            "blocking": bool(blocking and blocking.group(1) == "true"),
            "severity": severity.group(1) if severity else None,
        }
    if "copilot" in name.lower():
        return "Copilot", {}
    if is_bot(name):
        return f"bot {name}", {}
    return f"human {name}", {}


def clean(body):
    body = HTML_COMMENT.sub("", body).strip()
    return body if len(body) <= BODY_LIMIT else body[:BODY_LIMIT] + "\n[truncated]"


def finding_line(body):
    match = re.search(r"\*\*What is wrong:\*\*\s*(.+)", body)
    text = match.group(1) if match else HTML_COMMENT.sub("", body).strip().splitlines()[0]
    return re.sub(r"\s+", " ", text)[:160]


def rank(thread):
    kind, fields = thread["kind"]
    answered = thread["answered"]
    if kind == "AI review":
        group = 0 if fields["blocking"] else 2
    elif kind.startswith("human"):
        group = 1
    else:
        group = 3
    return (answered, group, SEVERITY_ORDER.get(fields.get("severity"), 4), thread["path"] or "")


def main():
    args = [a for a in sys.argv[1:] if a != "--all"]
    show_all = "--all" in sys.argv
    sys.stdout.reconfigure(encoding="utf-8")

    view = json.loads(gh("pr", "view", *args[:1], "--json", "number,url"))
    owner, name = re.match(r"https://github\.com/([^/]+)/([^/]+)/pull/", view["url"]).groups()
    number = view["number"]

    pr = graphql(PR_QUERY, owner=owner, name=name, number=number)
    pr_author = login(pr)

    threads, after = [], None
    while True:
        page = graphql(THREADS_QUERY, owner=owner, name=name, number=number, after=after)["reviewThreads"]
        threads += page["nodes"]
        if not page["pageInfo"]["hasNextPage"]:
            break
        after = page["pageInfo"]["endCursor"]

    for thread in threads:
        comments = thread["comments"]["nodes"]
        thread["kind"] = classify(comments[0])
        thread["answered"] = len(comments) > 1 and login(comments[-1]) == pr_author

    print(f"# PR #{number}: {pr['title']}")
    print(f"{pr['url']}")
    print(f"`{pr['headRefName']}` into `{pr['baseRefName']}`, head {pr['headRefOid'][:8]}, author {pr_author}\n")

    open_threads = sorted((t for t in threads if not t["isResolved"]), key=rank)
    resolved = [t for t in threads if t["isResolved"]]
    print(f"## Unresolved threads: {len(open_threads)}\n")
    for index, thread in enumerate(open_threads, 1):
        print_thread(index, thread)

    print(f"## Resolved threads: {len(resolved)}\n")
    for thread in resolved:
        if show_all:
            print_thread("R", thread)
            continue
        comments = thread["comments"]["nodes"]
        reply = comments[-1]["body"].strip().splitlines()[0][:80] if len(comments) > 1 else "(no reply)"
        print(f"- `{thread['path']}:{thread['line'] or thread['originalLine']}` {thread['kind'][0]}: "
              f"{finding_line(comments[0]['body'])} | reply: {reply}")
    print()

    head = pr["headRefOid"][:7]
    general = [
        r for r in pr["reviews"]["nodes"]
        if r["body"].strip() and r["state"] != "DISMISSED" and not is_bot(login(r)) and login(r) != pr_author
    ] + [
        c for c in pr["comments"]["nodes"]
        if not is_bot(login(c)) and login(c) != pr_author
    ]
    print(f"## Review bodies and PR comments from people: {len(general)}\n")
    for item in general:
        state = item.get("state", "COMMENT")
        when = item.get("submittedAt") or item.get("createdAt")
        print(f"### {login(item)} {state} {when[:10]}\n{clean(item['body'])}\n")

    latest_bot = [r for r in pr["reviews"]["nodes"] if is_bot(login(r))]
    if latest_bot:
        last = latest_bot[-1]
        commit = (last.get("commit") or {}).get("abbreviatedOid") or "?"
        status = "on the head" if head.startswith(commit[:7]) else "on an older commit"
        print(f"Latest bot review: {login(last)} {last['state']} on {commit} ({status}).")


def print_thread(index, thread):
    comments = thread["comments"]["nodes"]
    kind, fields = thread["kind"]
    tags = [kind]
    if fields:
        tags.append(f"{fields['source']}, {fields['severity'] or 'no severity'}, "
                    f"{'blocking' if fields['blocking'] else 'non-blocking'}")
    if thread["isOutdated"]:
        tags.append("outdated")
    if thread["isResolved"]:
        tags.append(f"resolved by {(thread.get('resolvedBy') or {}).get('login') or '?'}")
    elif thread["answered"]:
        tags.append("answered by the PR author, still open")
    line = thread["line"] or thread["originalLine"]
    commit = (comments[0].get("originalCommit") or {}).get("abbreviatedOid") or "?"
    print(f"### {index}. `{thread['path']}:{line}` ({'; '.join(tags)})")
    print(f"thread `{thread['id']}`, commented on {commit}, {comments[0]['url']}\n")
    print(clean(comments[0]["body"]) + "\n")
    for reply in comments[1:]:
        print(f"> **{login(reply)}:** {clean(reply['body'])}\n")


if __name__ == "__main__":
    main()
