#!/usr/bin/env python3
"""Launch tuicr in a new tmux window to review git changes.

Refreshes the review refs (so the diff reflects the remote, not a stale local
copy), opens a detached tmux window running tuicr over the resolved revset,
switches focus to it, and blocks until tuicr exits — then surfaces whatever
tuicr exported.

Usage::

    tuicr_up.py [directory]

Arguments:
    directory: Git repository to review. Default: current directory.

Environment variables:
    TUICR_WINDOW_NAME: Name of the new tmux window. Default: ``tuicr``.
    TUICR_BASE_REF: Base ref for the review revset. Default: the remote's
        default branch — never a hardcoded name, so this works in any repo.
    TUICR_HEAD_REF: Head ref for the review revset. Default: ``HEAD``.
    TUICR_REMOTE: Remote refreshed before a branch review. Default: ``origin``.
"""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "_lib"))

from skillkit.cli import parse_metadata, run_main  # noqa: E402
from skillkit.errors import SkillError  # noqa: E402
from skillkit.gitio import git  # noqa: E402
from skillkit.proc import run, which  # noqa: E402
from skillkit.tmuxio import inside_tmux  # noqa: E402

#: ANSI colours for the `[tuicr]` log prefix. Suppressed when stdout is not a
#: TTY so captured output stays clean.
_GREEN = "\033[0;32m"
_YELLOW = "\033[1;33m"
_RED = "\033[0;31m"
_RESET = "\033[0m"


def _log(colour: str, message: str, stream=sys.stdout) -> None:
    """Print a ``[tuicr]`` prefixed line, coloured only for a terminal."""
    if stream.isatty():
        print(f"{colour}[tuicr]{_RESET} {message}", file=stream, flush=True)
    else:
        print(f"[tuicr] {message}", file=stream, flush=True)


def log_info(message: str) -> None:
    """Informational progress line."""
    _log(_GREEN, message)


def log_warn(message: str) -> None:
    """Warning line."""
    _log(_YELLOW, message)


def log_error(message: str) -> None:
    """Error line."""
    _log(_RED, message, stream=sys.stderr)


def tuicr_supports_stdout() -> bool:
    """Whether this tuicr accepts ``--stdout``.

    Older builds export to the clipboard instead, which cannot be captured, so
    the caller has to fall back to asking the human to paste.
    """
    result = run(["tuicr", "--help"], merge_stderr=True)
    return "--stdout" in result.stdout


def already_reviewing(directory: str) -> bool:
    """Whether a tuicr pane is already open on *directory*.

    Scoped to this checkout deliberately: a global check would block reviewing
    a second repository at the same time.
    """
    result = run(["tmux", "list-panes", "-a", "-F", "#{pane_current_command} #{pane_current_path}"])
    return result.ok and f"tuicr {directory}" in result.lines()


def resolve_revset(target_dir: str) -> str:
    """Refresh the review refs and return the resolved revset.

    Raises:
        SkillError: If the refresh helper is missing or fails.
    """
    helper = Path(__file__).resolve().parent / "refresh_review_refs.py"
    if not helper.is_file():
        raise SkillError(f"Review-ref refresh helper not found: {helper}")

    args = [
        sys.executable, str(helper),
        "--repo", target_dir,
        "--head", os.environ.get("TUICR_HEAD_REF", "HEAD"),
        "--remote", os.environ.get("TUICR_REMOTE", "origin"),
    ]
    base = os.environ.get("TUICR_BASE_REF", "")
    if base:
        args += ["--base", base]

    result = run(args)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    if not result.ok:
        raise SkillError("could not refresh review refs", code=result.returncode)

    revset = parse_metadata(result.stdout).get("REVIEW_REVSET", "")
    if not revset:
        raise SkillError("refresh helper did not emit REVIEW_REVSET")
    return revset


def launch(target_dir: str) -> int:
    """Open tuicr in a tmux window and block until it exits."""
    window_name = os.environ.get("TUICR_WINDOW_NAME", "tuicr")
    remote = os.environ.get("TUICR_REMOTE", "origin")

    log_info(f"Refreshing review refs from '{remote}'")
    revset = resolve_revset(target_dir)

    log_info(f"Launching tuicr in a new tmux window ('{window_name}')")
    log_info(f"Directory: {target_dir}")
    log_info(f"Review target: {revset}")

    # tmux signals this channel when the window's command finishes, which is
    # how the caller blocks on an interactive TUI it does not own.
    wait_channel = f"tuicr-{os.getpid()}"

    output_file = ""
    if tuicr_supports_stdout():
        handle, output_file = tempfile.mkstemp(prefix="tuicr-output.", dir=os.environ.get("TMPDIR", "/tmp"))
        os.close(handle)
        inner = f"tuicr -r {_sh_quote(revset)} --stdout > {_sh_quote(output_file)}"
        log_info("Using --stdout mode (output will be captured)")
    else:
        inner = f"tuicr -r {_sh_quote(revset)}"
        log_warn("tuicr --stdout not supported, output will be copied to clipboard")

    command = f"cd {_sh_quote(target_dir)} && {inner}; tmux wait-for -S {_sh_quote(wait_channel)}"
    created = run(
        ["tmux", "new-window", "-d", "-P", "-F", "#{pane_id}", "-n", window_name, "-c", target_dir, command]
    )
    if not created.ok:
        raise SkillError(f"could not create tmux window: {created.stderr}")
    pane_id = created.stdout.strip()

    run(["tmux", "select-window", "-t", pane_id])
    log_info(f"tuicr is running in window '{window_name}' (pane {pane_id})")
    log_info("Waiting for tuicr to exit...")
    run(["tmux", "wait-for", wait_channel], timeout=None)
    log_info("tuicr finished")

    if output_file and Path(output_file).is_file():
        content = Path(output_file).read_text(encoding="utf-8", errors="replace")
        if content.strip():
            print()
            print("=== TUICR INSTRUCTIONS ===")
            print(content, end="" if content.endswith("\n") else "\n")
            print("=== END TUICR INSTRUCTIONS ===")
        else:
            log_info("No instructions exported from tuicr")
            log_info("If you exported to clipboard, paste the instructions here")
        Path(output_file).unlink(missing_ok=True)
    else:
        log_info("If you exported instructions, they are in your clipboard - paste them here")
    return 0


def _sh_quote(value: str) -> str:
    """Quote *value* for the shell command string tmux runs.

    tmux's ``new-window`` takes a command *string*, not an argument vector, so
    this one interface genuinely needs quoting.
    """
    import shlex

    return shlex.quote(value)


def main(argv: list[str]) -> int:
    """Entry point."""
    if argv and argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0

    if which("tuicr") is None:
        log_error("tuicr not found. Install it first.")
        return 1

    target = argv[0] if argv else "."
    if not Path(target).is_dir():
        log_error(f"Not a git repository: {target}")
        return 1
    target_dir = str(Path(target).resolve())

    if not git(target_dir, "rev-parse", "--git-dir").ok:
        log_error(f"Not a git repository: {target_dir}")
        return 1

    if not inside_tmux():
        log_error("Not running inside tmux!")
        print()
        print("To use tuicr with your coding agent, run that agent inside tmux.")
        print()
        print("1. Exit the current agent session.")
        print()
        print("2. Restart the agent inside tmux.")
        print()
        print("3. Then run /tuicr again.")
        return 1

    if already_reviewing(target_dir):
        log_warn(f"tuicr is already reviewing {target_dir} in another window")
        log_info("Switch to it with Ctrl-b + w (window list)")
        return 0

    return launch(target_dir)


if __name__ == "__main__":
    run_main(main)
