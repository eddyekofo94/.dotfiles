#!/usr/bin/env python3
"""Build budget guard: stop a /build session past 2 hours, 400 turns or two missed tries (Eddy, 2026-10-24).

PreToolUse hook (all tools; subagents carry `agent_id` and are skipped). It makes
`.claude/playbooks/build.md` §2 mechanical: "A step that misses its proof twice is
parked ... A record that runs past ... about two hours stops at its next landable
point and is split into small records."

Active only in a build session: the transcript holds a user message that starts
`/build` (or `$build`, or the slash-command wrapper `<command-name>/build`). Build
start = that first message's timestamp (the transcript file survives compaction).

Every rule counts inside a window that opens at the build start (BS-IOS-BUG-670 D2).
Eddy's own message typed in this tab after one of this guard's denials opens a new one:
a real user turn (`origin.kind` human), never hook text, a task notification or a tool
result. The new window counts time, compactions and turns from that message, and the
step a denial named no longer counts as missed. Nothing else lifts a hold but the
build ending; there is no file to make.

Rules, each denying the tool call with a "park and split" reason:
  time   working time in the window > 2 h (D1): the gaps between transcript rows, and
         from the last row to now, each capped at 10 min, so an idle night adds 10 min
  compactions  the transcript holds 2 or more `compact_boundary` rows after the build
         start (retro 2026-10-27: every top /build compacted 4-8 times; split at the second)
  turns  400 or more distinct main-thread assistant `message.id`s after the build start
         (BS-IOS-TASK-671: a tight loop that finishes inside 2 h)
  tries  in the build's plan.md (the last plan.md the transcript Edit/Write'd), one
         step (a top-level `- [ ]` / `- [x]` bullet plus its indented lines) holds two
         or more markers ("missed its proof", "failed, not ticked", "**failed") and is
         not marked parked (`parked`, `skip:`)

The hold ends with the build (BS-IOS-BUG-581 D1): once the record's `Status:` no
longer reads Ready To Build, Ready To Act or IN PROGRESS, or the checkout's HEAD is in
`origin/main` (or `main`) and was committed after the build began, nothing is held.

Calls still allowed so the agent can park:
  Read, Glob, Grep; Edit/Write/MultiEdit on a plan file (`plan.md`, or `plan-<id>.md`
  beside a `decisions.md`, BS-IOS-BUG-845), `AGENTS.md`, files under `project/specs/`
  or `project/bugs/`, or anything under /tmp (BS-IOS-BUG-660 D2); Bash parsed, not
  matched as text (D2): `&&`, `||`, `;`, `|` and newlines split it, git's globals
  (`-C dir`, `-c k=v`, `--no-pager`) and `-q` are skipped, and a line passes when every
  part does. A part may be read-only (D3): git log/status/diff/show/fetch/rev-parse/
  merge-base/ls-files/ls-tree/worktree list/branch listing; cd, cat, head, tail, grep,
  rg, ls, wc, echo, pwd, sort, sed -n; cp, mkdir, python3 tools/features_index.py,
  herdr-goal-done; clearing the build's dirt once a byte-identical copy of each file sits
  under /tmp (BS-IOS-BUG-660 D2): `git checkout -- <file>…` and `rm [-f] <file>…`;
  post-land cleanup: `git worktree remove` (no --force) of a worktree whose HEAD is in
  main, `git worktree prune`, `git branch -d`; and so the split can land, `git add` /
  `commit` (-m/-F, no -a) of records, plan files and AGENTS.md only, `git push [origin
  main]`, and `python3 tools/land.py` when the branch differs from main only in those
  files. Redirects and `--output=` pass only to /dev/null, between streams (`2>&1`) or
  to an absolute path under /tmp; `$(` and backticks never pass.

Escape hatch for scripts: env BUILD_BUDGET_EXTEND=1.

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
GAP_CAP_SECONDS = 600  # D1: one gap between rows counts at most 10 min of work
COMPACTION_LIMIT = 2
TURN_LIMIT = 400
MISS = ("missed its proof", "failed, not ticked", "**failed")
PARKED = ("parked", "skip:")
OKAY_TOOLS = {"Read", "Glob", "Grep"}
EDIT_TOOLS = {"Edit", "Write", "MultiEdit"}
#: Commands that only read, or that a parked build needs (D3); judged by argv[0].
READ_ONLY = {"cd", "cat", "head", "tail", "grep", "rg", "ls", "wc", "echo", "pwd", "true",
             "sort", "cp", "mkdir", "herdr-goal-done"}
#: git verbs that only read (D3).
GIT_READ = {"log", "status", "diff", "show", "fetch", "rev-parse", "merge-base", "ls-files",
            "ls-tree", "rev-list", "shortlog", "blame", "describe"}
#: Where a parked build backs up its work (BS-IOS-BUG-660 D2); `/tmp` is a link on macOS.
TMP = os.path.realpath("/tmp")
#: A plan file: `plan.md`, or `plan-<id>.md` when builds share a decision folder (BUG-845).
PLAN = re.compile(r"^plan(-[\w.-]+)?\.md$")
#: git globals whose value is the next word; `-C`'s names the checkout (D2).
GIT_VALUE_GLOBALS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}
SEPARATORS = {"&&", "||", ";", "|", "\n"}
ACTIVE = ("ready to build", "ready to act", "in progress")
BUILD_START = re.compile(r"^\s*(?:<command-message>build</command-message>\s*)?"
                         r"(?:<command-name>)?[/$]build\b")
STEP = re.compile(r"^- \[[ xX]\]")
#: This guard's own denial as Claude writes it into the tool result (D2).
DENIAL = re.compile(r"^(?:PreToolUse:\S+ hook error: )?Build budget guard: (.*)", re.S)
MISSED = re.compile(r"a step missed its proof twice \((.*)\) \(build\.md")
#: Text Claude injects as a user row that Eddy did not type (no `origin` on older rows).
NOT_TYPED = ("<task-notification>", "<system-reminder>", "<local-command", "Caveat:",
             "[Request interrupted")


def when(stamp: str) -> float:
    return datetime.fromisoformat(stamp.replace("Z", "+00:00")).timestamp()


def text_of(content) -> str:
    if isinstance(content, str):
        return content
    return " ".join(b.get("text", "") for b in content or [] if isinstance(b, dict)
                    and b.get("type") == "text")


def typed(row: dict) -> bool:
    """A message Eddy typed in this tab (D2): never hook text, a notification or a result."""
    if row.get("isMeta") or row.get("isCompactSummary"):
        return False
    origin = row.get("origin")
    if isinstance(origin, dict):
        return origin.get("kind") == "human"
    content = (row.get("message") or {}).get("content")
    if not isinstance(content, str) and any(isinstance(b, dict) and b.get("type") == "tool_result"
                                            for b in content or []):
        return False
    text = text_of(content).lstrip()
    return bool(text) and not text.startswith(NOT_TYPED)


def denial(row: dict) -> str | None:
    """The reason of this guard's denial in a tool result row, else None."""
    for block in (row.get("message") or {}).get("content") or []:
        if isinstance(block, dict) and block.get("type") == "tool_result":
            body = block.get("content")
            found = DENIAL.match(text_of(body).lstrip() if not isinstance(body, str) else body)
            if found:
                return found.group(1)
    return None


class Window:
    """What the transcript says about the build (D1, D2): its start, goal and plan, and the
    open window's working time, compactions and turns, with the steps Eddy waved on."""

    def __init__(self):
        self.started = self.goal = self.plan = self.last = None
        self.working = 0.0
        self.compactions = 0
        self.turns: set[str] = set()
        self.denials: list[str] = []
        self.excused: set[str] = set()

    def tick(self, stamp: str | None) -> None:
        if not stamp:
            return
        now = when(stamp)
        if self.last is not None and now > self.last:
            self.working += min(now - self.last, GAP_CAP_SECONDS)
        self.last = max(now, self.last or now)

    def reopen(self, stamp: str) -> None:
        """Eddy replied after a denial: a fresh window from his message (D2)."""
        self.last = when(stamp)
        self.working, self.compactions, self.turns = 0.0, 0, set()
        self.excused |= {m.group(1) for d in self.denials if (m := MISSED.search(d))}
        self.denials = []

    def working_until(self, now: float) -> float:
        tail = min(max(now - self.last, 0), GAP_CAP_SECONDS) if self.last is not None else 0
        return self.working + tail


def scan(transcript: str) -> Window:
    """Read the transcript once into a Window (the file survives compaction)."""
    window = Window()
    with open(transcript, encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            started = window.started is not None
            if not started and '"user"' not in raw and not ('"tool_use"' in raw and "plan.md" in raw):
                continue
            try:
                row = json.loads(raw)
            except ValueError:
                continue
            if row.get("isSidechain"):
                continue
            message = row.get("message") or {}
            kind = row.get("type")
            if not started:
                if kind == "user" and BUILD_START.match(text_of(message.get("content"))):
                    text = text_of(message.get("content"))
                    window.started = window.last = when(row["timestamp"])
                    args = re.search(r"<command-args>\s*([^\s<]+)", text) or re.search(
                        r"[/$]build\s+(\S+)", text)
                    window.goal = args.group(1) if args else None
            else:
                if kind == "user" and window.denials and typed(row) and row.get("timestamp"):
                    window.reopen(row["timestamp"])
                else:
                    window.tick(row.get("timestamp"))
                if kind == "user" and (reason := denial(row)):
                    window.denials.append(reason)
                elif kind == "system" and row.get("subtype") == "compact_boundary":
                    window.compactions += 1
                elif kind == "assistant" and message.get("id"):
                    window.turns.add(message["id"])  # one turn streams as several rows, one id
            for block in message.get("content") or []:
                if not isinstance(block, dict) or block.get("type") != "tool_use":
                    continue
                path = (block.get("input") or {}).get("file_path", "")
                if block.get("name") in EDIT_TOOLS and PLAN.match(os.path.basename(path)):
                    window.plan = path
    return window


def missed_step(plan: str, excused: set[str] = frozenset()) -> str | None:
    """First step with two or more miss markers that is not parked or waved on, else None."""
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
        name = lines[0].strip()[:80]
        if (sum(text.count(m) for m in MISS) >= 2 and not any(p in text for p in PARKED)
                and name not in excused):
            return name
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


def plan_file(path: str, cwd: Path) -> bool:
    """`plan.md`, or a `plan-<id>.md` beside a decision file (BS-IOS-BUG-845)."""
    name = os.path.basename(path)
    if name == "plan.md":
        return True
    return bool(PLAN.match(name)) and (cwd / os.path.dirname(path) / "decisions.md").is_file()


def record_path(path: str, cwd: Path) -> bool:
    """A file a parked build may land: a record, a plan file or an AGENTS.md."""
    return (bool(re.search(r"(^|/)project/(specs|bugs)/", path))
            or os.path.basename(path) == "AGENTS.md" or plan_file(path, cwd))


def in_tmp(path: str) -> bool:
    """An absolute path that resolves under /tmp (D2): where a parked build backs up.
    A relative one never counts, since a `cd` earlier in the line moves it."""
    path = os.path.expanduser(path)
    return os.path.isabs(path) and os.path.realpath(path).startswith(TMP + os.sep)


def backed_up(path: Path) -> bool:
    """A byte-identical copy of the file `path`, under its own name, sits under /tmp
    (D2), so clearing it from the checkout loses nothing."""
    if not path.is_file() or in_tmp(str(path)):
        return False
    body = path.read_bytes()
    for root, dirs, files in os.walk(TMP):
        dirs[:] = [] if root[len(TMP):].count(os.sep) >= 5 else [d for d in dirs if d != ".git"]
        copy = Path(root) / path.name
        if path.name in files and copy.is_file() and copy.stat().st_size == len(body) \
                and copy.read_bytes() == body:
            return True
    return False


def plain_paths(words: list[str]) -> bool:
    """Literal file names only: no glob, no pathspec magic, nothing for the shell to grow."""
    return bool(words) and not any(re.search(r"[*?\[{$]", w) or w.startswith(":") for w in words)


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
            backup = word in (">", ">>", "&>") and in_tmp(target)  # D2
            if not (stream or backup or target == "/dev/null"):
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
    """A flag that writes or runs something; `--output` into /tmp is a backup (D2)."""
    for index, word in enumerate(words):
        if word == "--output" or word.startswith("--output="):
            target = word[len("--output="):] if "=" in word else (words[index + 1:] or [""])[0]
            if in_tmp(target):
                continue
        if WRITING_FLAGS.match(word):
            return True
    return False


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
    if verb == "checkout":  # D2: restore a file only once its copy sits under /tmp
        if "--" not in rest or any(w not in ("-q", "--quiet") for w in rest[:rest.index("--")]):
            return False
        paths = rest[rest.index("--") + 1:]
        return plain_paths(paths) and all(
            backed_up(cwd / p) or not (cwd / p).exists() for p in paths)
    if verb == "add":
        paths = plain(rest)
        return bool(paths) and all(record_path(p, cwd) for p in paths)
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
        return all(record_path(p, cwd) for p in paths)
    if verb == "push":
        return plain(rest) in ([], ["origin", "main"])
    return False


def records_only_branch(cwd: Path) -> bool:
    """The checkout's branch differs from main only in records, plan.md or AGENTS.md."""
    changed = git(cwd, "diff", "--name-only", "main...HEAD")
    names = changed.stdout.split()
    top = Path(git(cwd, "rev-parse", "--show-toplevel").stdout.strip() or cwd)
    return changed.returncode == 0 and bool(names) and all(record_path(n, top) for n in names)


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
        if name == "sort" and any(re.match(r"-[^-]*o|--compress", w) for w in part[1:]):
            return False  # `-o` writes, `--compress-program` runs a command
        if name == "rm":  # D2: clear a file only once its copy sits under /tmp
            paths = [w for w in part[1:] if w not in ("-f", "--")]
            if (plain_paths(paths) and not any(p.startswith("-") for p in paths)
                    and all(backed_up(cwd / os.path.expanduser(p)) for p in paths)):
                continue
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
        return record_path(path, cwd) or in_tmp(path)
    if tool == "Bash":
        return allowed_bash(tool_input.get("command", ""), cwd)
    return False


def reason(why: str) -> str:
    return (f"Build budget guard: {why} (build.md §2): park now. 1. Back up: `cp <file> /tmp/<id>/` "
            "(each file under its own name), `git diff > /tmp/<id>/build.diff` or "
            "`git diff --output=/tmp/<id>/build.diff`. 2. Write the numbers into the build's plan "
            "file. 3. Clear the dirt the copies hold: `git checkout -- <file>`, `rm <file>`. "
            "4. Split the record into child records, `git add`/`commit` them (a land message "
            "goes to /tmp with Write), `python3 tools/land.py <branch> -F /tmp/<id>/msg` or "
            "`git push origin main`. 5. End the turn. Also allowed: reads (git log/status/diff/"
            "ls-tree, cat, tail, grep, sort, ls), cleanup of landed worktrees and merged branches. "
            "Eddy's next message in this tab lifts the hold and gives the build 2 more hours: "
            "say so in one closeout line, \"reply to give it 2 more hours\", and never ask him "
            "to run a command.")


def main() -> int:
    try:
        data = json.load(sys.stdin)
        transcript = data.get("transcript_path")
        if data.get("agent_id") or not transcript or not os.path.exists(transcript):
            return 0
        if os.environ.get("BUILD_BUDGET_EXTEND"):
            return 0
        window = scan(transcript)
        if window.started is None:
            return 0
        cwd = Path(data.get("cwd") or os.getcwd())
        plan, now = window.plan, datetime.now(timezone.utc).timestamp()
        why = None
        if window.working_until(now) > LIMIT_SECONDS:
            why = "build past 2 h of working time"
        elif window.compactions >= COMPACTION_LIMIT:
            why = f"build past {COMPACTION_LIMIT} compactions"
        elif len(window.turns) >= TURN_LIMIT:
            why = f"build past {TURN_LIMIT} turns"
        elif plan and os.path.exists(plan) and (step := missed_step(plan, window.excused)):
            why = f"a step missed its proof twice ({step})"
        if why is None or allowed_call(data.get("tool_name", ""), data.get("tool_input") or {}, cwd):
            return 0
        if hold_ended(cwd, window.goal, window.started):
            return 0
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse", "permissionDecision": "deny",
            "permissionDecisionReason": reason(why)}}))
        return 0
    except Exception as error:  # fail open: never brick a session
        print(f"build_budget_guard: {error!r}", file=sys.stderr)
        return 0


if __name__ == "__main__":
    sys.exit(main())
