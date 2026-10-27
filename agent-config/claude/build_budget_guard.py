#!/usr/bin/env python3
"""Build budget guard: stop a /build session past 2 hours or past two missed tries (Eddy, 2026-10-24).

PreToolUse hook (all tools; subagents carry `agent_id` and are skipped). It makes
`.claude/playbooks/build.md` §2 mechanical: "A step that misses its proof twice is
parked ... A record that runs past ... about two hours stops at its next landable
point and is split into small records."

Active only in a build session: the transcript holds a user message that starts
`/build` (or `$build`, or the slash-command wrapper `<command-name>/build`). Build
start = that first message's timestamp (the transcript file survives compaction).

Rules, each denying the tool call with a "park and split" reason:
  time   now - build start > 2 h
  compactions  the transcript holds 2 or more `compact_boundary` rows after the build
         start (retro 2026-10-27: every top /build compacted 4-8 times; split at the second)
  tries  in the build's plan.md (the last plan.md the transcript Edit/Write'd), one
         step (a top-level `- [ ]` / `- [x]` bullet plus its indented lines) holds two
         or more markers ("missed its proof", "failed, not ticked", "**failed") and is
         not marked parked (`parked`, `skip:`)

The hold ends with the build (BS-IOS-BUG-581 D1): once the record's `Status:` no
longer reads Ready To Build, Ready To Act or IN PROGRESS, or the checkout's HEAD is in
`origin/main` (or `main`) and was committed after the build began, nothing is held.

Calls still allowed so the agent can park:
  Read, Glob, Grep; Edit/Write/MultiEdit on `plan.md`, `AGENTS.md`, or files under
  `project/specs/` or `project/bugs/`; Bash parsed, not matched as text (D2): `&&`,
  `||`, `;`, `|` and newlines split it, git's globals (`-C dir`, `-c k=v`, `--no-pager`)
  and `-q` are skipped, and a line passes when every part does. A part may be read-only
  (D3): git log/status/diff/show/fetch/rev-parse/merge-base/ls-files/worktree list/branch
  listing; cd, cat, head, tail, grep, rg, ls, wc, echo, pwd, sed -n; cp, mkdir,
  python3 tools/features_index.py, herdr-goal-done; post-land cleanup: `git worktree
  remove` (no --force) of a worktree whose HEAD is in main, `git worktree prune`,
  `git branch -d`; and so the split can land, `git add` / `commit` (-m/-F, no -a) of
  records, plan.md and AGENTS.md only, `git push [origin main]`, and `python3
  tools/land.py` when the branch differs from main only in those files. Redirects pass
  only to /dev/null or between streams (`2>&1`); `$(` and backticks never pass.

Escape hatch: env BUILD_BUDGET_EXTEND=1, or a file `.working/<goal>/budget-extend`
(goal = the /build argument lowercased, e.g. FS-487 -> fs487) under the session cwd.
The guard makes `.working/<goal>/` when it first holds the build, so the file can
always be made (D5). Eddy's okay lives in that file; the agent never creates it.

Fail open: any error allows the call and prints to stderr.
"""
from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

LIMIT_SECONDS = 2 * 3600
COMPACTION_LIMIT = 2
MISS = ("missed its proof", "failed, not ticked", "**failed")
PARKED = ("parked", "skip:")
OKAY_TOOLS = {"Read", "Glob", "Grep"}
EDIT_TOOLS = {"Edit", "Write", "MultiEdit"}
#: Commands that only read, or that a parked build needs (D3); judged by argv[0].
READ_ONLY = {"cd", "cat", "head", "tail", "grep", "rg", "ls", "wc", "echo", "pwd", "true",
             "cp", "mkdir", "herdr-goal-done"}
#: git verbs that only read (D3).
GIT_READ = {"log", "status", "diff", "show", "fetch", "rev-parse", "merge-base", "ls-files",
            "rev-list", "shortlog", "blame", "describe"}
#: git globals whose value is the next word; `-C`'s names the checkout (D2).
GIT_VALUE_GLOBALS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}
SEPARATORS = {"&&", "||", ";", "|", "\n"}
ACTIVE = ("ready to build", "ready to act", "in progress")
BUILD_START = re.compile(r"^\s*(?:<command-message>build</command-message>\s*)?"
                         r"(?:<command-name>)?[/$]build\b")
STEP = re.compile(r"^- \[[ xX]\]")


def when(stamp: str) -> float:
    return datetime.fromisoformat(stamp.replace("Z", "+00:00")).timestamp()


def scan(transcript: str):
    """Return (build start epoch, goal ID as typed, last plan.md path, compactions since start)."""
    start = goal = plan = None
    compactions = 0
    with open(transcript, encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            if start is None and '"user"' in raw:
                try:
                    row = json.loads(raw)
                except ValueError:
                    continue
                content = (row.get("message") or {}).get("content")
                if row.get("type") == "user" and not row.get("isSidechain"):
                    text = content if isinstance(content, str) else " ".join(
                        b.get("text", "") for b in content or [] if isinstance(b, dict))
                    if BUILD_START.match(text):
                        start = when(row["timestamp"])
                        args = re.search(r"<command-args>\s*([^\s<]+)", text) or re.search(
                            r"[/$]build\s+(\S+)", text)
                        goal = args.group(1) if args else None
            elif start is not None and '"compact_boundary"' in raw:
                try:
                    row = json.loads(raw)
                except ValueError:
                    continue
                if (row.get("type") == "system" and row.get("subtype") == "compact_boundary"
                        and not row.get("isSidechain")):
                    compactions += 1
            elif '"tool_use"' in raw and "plan.md" in raw:
                try:
                    row = json.loads(raw)
                except ValueError:
                    continue
                for block in (row.get("message") or {}).get("content") or []:
                    if not isinstance(block, dict) or block.get("type") != "tool_use":
                        continue
                    path = (block.get("input") or {}).get("file_path", "")
                    if block.get("name") in EDIT_TOOLS and os.path.basename(path) == "plan.md":
                        plan = path
    return start, goal, plan, compactions


def missed_step(plan: str) -> str | None:
    """First step with two or more miss markers that is not parked, else None."""
    steps, current = [], []
    for line in Path(plan).read_text(errors="replace").splitlines():
        if STEP.match(line) and not line.startswith((" ", "\t")):
            current = [line]
            steps.append(current)
        elif current and (line.startswith((" ", "\t")) or not line.strip()):
            current.append(line)
        else:
            current = []
    for lines in steps:
        text = "\n".join(lines).lower()
        if sum(text.count(m) for m in MISS) >= 2 and not any(p in text for p in PARKED):
            return lines[0].strip()[:80]
    return None


def git(cwd: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(cwd), *args], capture_output=True, text=True,
                          timeout=3)


def landed(cwd: Path, rev: str = "HEAD") -> bool:
    """`rev` in this checkout is already in `origin/main` (D1); local `main` does not
    count, since a held build can move it."""
    return git(cwd, "merge-base", "--is-ancestor", rev, "origin/main").returncode == 0


def record_status(cwd: Path, goal_id: str) -> str | None:
    """The `Status:` line of the record named `goal_id`, lowercased, or None."""
    top = git(cwd, "rev-parse", "--show-toplevel").stdout.strip()
    root = Path(top) if top else cwd
    for folder in ("project/specs", "project/bugs"):
        for record in (root / folder).glob(f"{goal_id}*.md"):
            if record.stem != goal_id and not record.stem.startswith(goal_id + "-"):
                continue
            for line in record.read_text(errors="replace").splitlines():
                if (found := re.match(r"\s*-?\s*Status:\s*(.*)", line)):
                    return found.group(1).lower()
    return None


def hold_ended(cwd: Path, goal_id: str | None, start: float) -> bool:
    """The build is over (D1): its record left the active states, or this checkout's
    HEAD landed in main after the build began."""
    if goal_id and (status := record_status(cwd, goal_id)) is not None:
        if not any(word in status for word in ACTIVE):
            return True
    stamp = git(cwd, "log", "-1", "--format=%ct").stdout.strip()
    if not (stamp.isdigit() and int(stamp) > start and landed(cwd)):
        return False
    # Landed with nothing left over: a fast-forward at the start, or one chunk of
    # a chunked build landed, still leaves uncommitted work to hold.
    dirt = git(cwd, "status", "--porcelain", "--untracked-files=no")
    return dirt.returncode == 0 and not dirt.stdout.strip()


def record_path(path: str) -> bool:
    """A file a parked build may land: a record, a plan.md or an AGENTS.md."""
    return (bool(re.search(r"(^|/)project/(specs|bugs)/", path))
            or os.path.basename(path) in ("plan.md", "AGENTS.md"))


def tokens(command: str) -> list[str] | None:
    """Shell words with `&&`, `||`, `;`, `|`, newlines and redirects as their own words."""
    lexer = shlex.shlex(command, posix=True, punctuation_chars="();<>|&\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    try:
        return list(lexer)
    except ValueError:
        return None


def parts_of(command: str) -> list[list[str]] | None:
    """The line as one argv per command, redirects checked and dropped; None when a
    part cannot be judged (substitution, a subshell, a write redirect)."""
    if "`" in command or "$(" in command:
        return None
    words = tokens(command)
    if words is None:
        return None
    parts, current, index = [], [], 0
    while index < len(words):
        word = words[index]
        if word in SEPARATORS:
            parts.append(current)
            current = []
        elif word in (">", ">>", "<", ">&", "&>", "<&"):
            target = words[index + 1] if index + 1 < len(words) else ""
            stream = word in (">&", "<&") and target.isdigit()
            if not (stream or target == "/dev/null"):
                return None
            if current and current[-1].isdigit():
                current.pop()  # the `2` of `2>&1`
            index += 1
        elif word and set(word) <= set("();<>|&"):
            return None  # `>|`, `<>`, `<<`, a subshell, `&`: not judged, so refused
        else:
            current.append(word)
        index += 1
    parts.append(current)
    return [part for part in parts if part] or None


def git_verb(words: list[str], cwd: Path) -> tuple[list[str], Path]:
    """git's argv after its globals, and the checkout `-C` aimed it at (D2)."""
    while words and words[0].startswith("-"):
        head = words[0]
        runs = head == "-c" and len(words) > 1 and RUNS_COMMAND.search(words[1].split("=")[0])
        if runs or head in ("-p", "--paginate") or head.startswith("--exec-path"):
            raise ValueError("a git global that runs a command")
        if head == "-C" and len(words) > 1:
            cwd = (cwd / words[1]).resolve()
        words = words[2:] if head in GIT_VALUE_GLOBALS else words[1:]
    return words, cwd


#: Flags that make a read write a file or run a command (`--output`, `sed -i`,
#: `rg --pre`, `find -exec`).
WRITING_FLAGS = re.compile(r"^(--output\b|--pre\b|-i|--in-place\b|--ext-diff\b|-exec\b|-delete\b)")


#: `-c` keys whose value git runs as a command (a pager, an alias, a hook).
RUNS_COMMAND = re.compile(r"(?i)pager|alias|editor|command|external|hook|fsmonitor|textconv|filter")


def writes(words: list[str]) -> bool:
    return any(WRITING_FLAGS.match(w) for w in words)


def plain(words: list[str]) -> list[str]:
    return [w for w in words if w not in ("-q", "--quiet", "--")]


def allowed_git(words: list[str], cwd: Path) -> bool:
    """A git call a held build may run: a read, its post-land cleanup, or landing the split."""
    try:
        words, cwd = git_verb(words, cwd)
    except ValueError:
        return False
    if not words or writes(words):
        return False
    verb, rest = words[0], words[1:]
    if verb == "fetch" and any(":" in w or w in ("-u", "--update-head-ok") for w in rest):
        return False  # a refspec moves a local branch (`fetch . HEAD:main`)
    if verb in GIT_READ:
        return True
    if verb == "worktree":
        sub, args = (rest[:1] or [""])[0], plain(rest[1:])
        if sub in ("list", "prune"):
            return True
        if sub == "remove":
            paths = [a for a in args if not a.startswith("-")]
            return (len(paths) == 1 and not any(a in ("-f", "--force") for a in args)
                    and landed((cwd / paths[0]).resolve()))
        return False
    if verb == "branch":
        if any(w in ("-D", "-f", "--force", "-m", "-M", "-c", "-C") for w in rest):
            return False
        names = [w for w in rest if not w.startswith("-")]
        return "-d" in rest or "--delete" in rest or not names or "--list" in rest
    if verb == "add":
        paths = plain(rest)
        return bool(paths) and all(record_path(p) for p in paths)
    if verb == "commit":
        paths, skip = [], False
        for word in plain(rest):
            if skip:
                skip = False
            elif word in ("-m", "-F"):
                skip = True
            elif word.startswith("-"):
                return False  # no -a / --all: only what add already limited
            else:
                paths.append(word)
        return all(record_path(p) for p in paths)
    if verb == "push":
        return plain(rest) in ([], ["origin", "main"])
    return False


def records_only_branch(cwd: Path) -> bool:
    """The checkout's branch differs from main only in records, plan.md or AGENTS.md."""
    changed = git(cwd, "diff", "--name-only", "main...HEAD")
    names = changed.stdout.split()
    return changed.returncode == 0 and bool(names) and all(record_path(n) for n in names)


def allowed_bash(command: str, cwd: Path) -> bool:
    """Every part of the parsed line is one a held build may run (D2, D3)."""
    parts = parts_of(command)
    if parts is None:
        return False
    for part in parts:
        name = os.path.basename(part[0])
        if name == "cd":
            cwd = (cwd / os.path.expanduser(part[1])).resolve() if len(part) > 1 else Path.home()
            continue
        if name == "git" and allowed_git(part[1:], cwd):
            continue
        if writes(part[1:]) or (name == "sed" and any("w" in w for w in part[2:-1])):
            return False
        if name in READ_ONLY or part[:2] == ["sed", "-n"]:
            continue
        if part[:2] == ["python3", "tools/features_index.py"]:
            continue
        if part[:2] == ["python3", "tools/land.py"] and records_only_branch(cwd):
            continue
        return False
    return True


def allowed_call(tool: str, tool_input: dict, cwd: Path) -> bool:
    if tool in OKAY_TOOLS:
        return True
    if tool in EDIT_TOOLS:
        path = tool_input.get("file_path", "")
        return (os.path.basename(path) in ("plan.md", "AGENTS.md")
                or "/project/specs/" in path or "/project/bugs/" in path)
    if tool == "Bash":
        return allowed_bash(tool_input.get("command", ""), cwd)
    return False


def reason(why: str, extend: Path) -> str:
    return (f"Build budget guard: {why} (build.md §2): park now. Back up the diff to /tmp, write "
            "the numbers into plan.md, split the record into child records, commit and push them, "
            "end the turn. Allowed: plan.md, AGENTS.md, project/specs and project/bugs edits; "
            "read-only commands (git log/status/diff/worktree list, cat, tail, grep, ls); "
            "cleanup of landed worktrees and merged branches; git add/commit of those files; "
            "git push origin main. "
            f"Eddy extends with: ! touch {extend}")


def main() -> int:
    try:
        data = json.load(sys.stdin)
        transcript = data.get("transcript_path")
        if data.get("agent_id") or not transcript or not os.path.exists(transcript):
            return 0
        if os.environ.get("BUILD_BUDGET_EXTEND"):
            return 0
        start, goal, plan, compactions = scan(transcript)
        if start is None:
            return 0
        cwd = Path(data.get("cwd") or os.getcwd())
        top = git(cwd, "rev-parse", "--show-toplevel").stdout.strip() if cwd.is_dir() else ""
        slug = goal.lower().replace("-", "") if goal else None
        extend = Path(top or cwd) / ".working" / (slug or "<goal>") / "budget-extend"
        if slug and extend.exists():
            return 0
        why = None
        if datetime.now(timezone.utc).timestamp() - start > LIMIT_SECONDS:
            why = "build past 2 h"
        elif compactions >= COMPACTION_LIMIT:
            why = f"build past {COMPACTION_LIMIT} compactions"
        elif plan and os.path.exists(plan) and (step := missed_step(plan)):
            why = f"a step missed its proof twice ({step})"
        if why is None or allowed_call(data.get("tool_name", ""), data.get("tool_input") or {}, cwd):
            return 0
        if hold_ended(cwd, goal, start):
            return 0
        if slug:
            extend.parent.mkdir(parents=True, exist_ok=True)  # D5: the unlock can always be made
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse", "permissionDecision": "deny",
            "permissionDecisionReason": reason(why, extend)}}))
        return 0
    except Exception as error:  # fail open: never brick a session
        print(f"build_budget_guard: {error!r}", file=sys.stderr)
        return 0


if __name__ == "__main__":
    sys.exit(main())
