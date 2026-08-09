"""Typed client for the ``tuicr`` review CLI.

Schema facts encoded here, all verified empirically against tuicr 0.19.1,
because getting them wrong causes silent misbehaviour rather than an error:

* **Comments carry no parent or thread id.** Threading is purely *positional*:
  a reply appears under a comment only when its ``(path, start_line, end_line,
  side)`` anchor matches exactly and it was created later. See :class:`Anchor`.
* **Omitting ``--end-line`` is not "unset"**, it silently files the reply at
  ``start_line..start_line``. On a multi-line comment that is a *different*
  anchor, so the reply neither threads nor marks the comment answered — and a
  watcher will re-deliver that comment until its attempt budget is spent.
* ``tuicr review comments`` does **not** return an ``author`` field.

:meth:`Comment.reply` exists so a reply's anchor is *copied* from its parent
rather than re-derived from the diff. That turns the single most common
mis-anchoring bug into something the API will not let a caller express.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Sequence

from .errors import SkillError
from .proc import run

#: ``comment_type`` values a watcher ignores by default. ``reply`` is the type
#: an agent posts, so ignoring it prevents a self-wake loop.
DEFAULT_IGNORE_TYPES = ("reply",)


class TuicrError(SkillError):
    """A ``tuicr`` invocation failed.

    Distinct from "no comments": a transport failure that looked like an empty
    result would leave a watcher reporting healthy while ignoring the human.
    """


@dataclass(frozen=True)
class Anchor:
    """Where a comment is attached — the full identity used for threading.

    All four fields participate. Two comments with the same ``path`` and
    ``start_line`` but a different ``end_line`` are at *different* anchors.

    Attributes:
        path: Repository-relative file path.
        start_line: First line of the range.
        end_line: Last line of the range. Equal to *start_line* for a single
            line, never None.
        side: ``"old"`` or ``"new"`` side of the diff.
    """

    path: str
    start_line: int
    end_line: int
    side: str

    def as_args(self) -> list[str]:
        """This anchor as ``tuicr review add`` arguments.

        ``--end-line`` is always emitted, never conditionally, because omitting
        it silently rewrites the anchor to a single line.
        """
        return [
            "--target-file", self.path,
            "--line", str(self.start_line),
            "--end-line", str(self.end_line),
            "--side", self.side,
        ]

    def __str__(self) -> str:
        span = f"{self.start_line}" if self.start_line == self.end_line else f"{self.start_line}-{self.end_line}"
        return f"{self.path}:{span}({self.side})"


@dataclass(frozen=True)
class Comment:
    """One review comment.

    Attributes:
        id: tuicr's comment id.
        comment_type: User-configured type label (``note``, ``issue``,
            ``suggestion``, ``reply``, ...). This comes from the human's
            ``config.toml`` and is a *hint* about intent, never authoritative.
        content: Comment body.
        created_at: ISO-8601 creation timestamp; ordering is by string compare.
        anchor: Its :class:`Anchor`.
        lifecycle_state: tuicr's own state field, when present.
        raw: The undecoded JSON object, for fields not modelled here.
    """

    id: str
    comment_type: str
    content: str
    created_at: str
    anchor: Anchor
    lifecycle_state: str | None = None
    raw: dict[str, Any] | None = None

    @classmethod
    def from_json(cls, payload: dict[str, Any]) -> "Comment":
        """Build a Comment from one ``tuicr review comments`` object."""
        start = _as_int(payload.get("start_line"))
        end = _as_int(payload.get("end_line"))
        return cls(
            id=str(payload.get("id", "")),
            comment_type=str(payload.get("comment_type", "") or ""),
            content=payload.get("content") or "",
            created_at=payload.get("created_at") or "",
            anchor=Anchor(
                path=payload.get("path") or "",
                start_line=start,
                # A missing end_line means a single-line comment, not line 0.
                end_line=end if end else start,
                side=payload.get("side") or "new",
            ),
            lifecycle_state=payload.get("lifecycle_state"),
            raw=payload,
        )

    def summary(self, width: int = 60) -> str:
        """One-line ``[type] path:line - body`` preview for logs."""
        body = " ".join(self.content.split())
        if len(body) > width:
            body = body[: width - 3] + "..."
        location = self.anchor.path or "review"
        if self.anchor.start_line:
            location += f":{self.anchor.start_line}"
        return f"[{self.comment_type or '?'}] {location} - {body}"


def _as_int(value: Any) -> int:
    """Coerce a JSON value to int, treating None/garbage as 0."""
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


@dataclass(frozen=True)
class Session:
    """A tuicr review session."""

    slug: str
    active: bool
    comment_count: int
    raw: dict[str, Any] | None = None


def _invoke(args: Sequence[str]) -> str:
    """Run ``tuicr`` and return stdout, raising on failure."""
    result = run(["tuicr", *args])
    if not result.ok:
        raise TuicrError(f"tuicr {' '.join(args[:2])} failed: {result.stderr.strip() or result.stdout.strip()}")
    return result.stdout


def list_sessions(repo: str | Path) -> list[Session]:
    """Every review session known for *repo*."""
    try:
        rows = json.loads(_invoke(["review", "list", "--repo", str(repo)]) or "[]")
    except json.JSONDecodeError as exc:
        raise TuicrError(f"tuicr review list returned unparseable JSON: {exc}") from None
    return [
        Session(
            slug=str(row.get("slug", "")),
            active=bool(row.get("active")),
            comment_count=_as_int(row.get("comment_count")),
            raw=row,
        )
        for row in rows
    ]


def active_session(repo: str | Path) -> Session:
    """The single active session for *repo*.

    Raises:
        TuicrError: If zero or several sessions are active, listing the
            candidates so the caller can pass an explicit slug.
    """
    sessions = list_sessions(repo)
    active = [session for session in sessions if session.active]
    if len(active) == 1:
        return active[0]
    lines = [
        f"  {session.slug}  (active={session.active}, comments={session.comment_count})"
        for session in sessions
    ]
    detail = "\n".join(lines) if lines else "  (none)"
    raise TuicrError(
        f"could not resolve a single active session for repo '{repo}'.",
        hint="Pass an explicit session slug. Candidates:\n" + detail,
    )


def comments(repo: str | Path, session: str) -> list[Comment]:
    """Every comment in *session*.

    Raises:
        TuicrError: If tuicr fails or returns nothing. An empty session still
            returns valid JSON, so a failure here is a real transport problem
            and must never be conflated with "no comments".
    """
    raw = _invoke(["review", "comments", "--repo", str(repo), "--session", session])
    if not raw.strip():
        raise TuicrError(f"tuicr review comments returned no output for session '{session}'")
    try:
        rows = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise TuicrError(f"tuicr review comments returned unparseable JSON: {exc}") from None
    return [Comment.from_json(row) for row in rows]


def add(
    repo: str | Path,
    session: str,
    anchor: Anchor,
    body: str,
    *,
    comment_type: str = "note",
    username: str | None = None,
) -> None:
    """Add a comment at *anchor*.

    Prefer :func:`reply_to` when responding to an existing comment — it copies
    the anchor instead of trusting the caller to reproduce it.
    """
    args = [
        "review", "add",
        "--repo", str(repo),
        "--session", session,
        *anchor.as_args(),
        "--type", comment_type,
    ]
    if username:
        args += ["--username", username]
    args.append(body)
    _invoke(args)


def add_comment(
    repo: str | Path,
    session: str,
    body: str,
    *,
    anchor: Anchor | None = None,
    comment_type: str = "note",
    username: str | None = None,
) -> str:
    """Add a line-anchored or review-level comment and return its id.

    Unlike :func:`add`, this primitive also supports review-level comments,
    which intentionally have no positional anchor, and returns the created id
    needed by cross-system sidecar maps.

    Args:
        repo: Repository owning the review session.
        session: Canonical tuicr session slug.
        body: Comment body.
        anchor: Exact positional anchor, or None for a review-level comment.
        comment_type: tuicr comment type label.
        username: Optional display name shown as the comment author.

    Returns:
        str: The created tuicr comment id, or an empty string if tuicr omitted it.

    Raises:
        TuicrError: If tuicr fails or returns invalid JSON.

    Side Effects:
        Adds one local draft comment to the tuicr session.
    """
    args = [
        "review", "add",
        "--repo", str(repo),
        "--session", session,
    ]
    if anchor is not None:
        args += anchor.as_args()
    args += ["--type", comment_type]
    if username:
        args += ["--username", username]
    args.append(body)
    raw = _invoke(args)
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise TuicrError(f"tuicr review add returned unparseable JSON: {exc}") from None
    if not isinstance(payload, dict):
        raise TuicrError("tuicr review add returned a non-object JSON value")
    return str(payload.get("id", ""))


def reply_to(
    repo: str | Path,
    session: str,
    parent: Comment,
    body: str,
    *,
    username: str | None = None,
) -> None:
    """Reply to *parent*, inheriting its anchor exactly.

    Threading is positional, so the reply is only visible under *parent* — and
    only marks it answered — when all four anchor fields match. Taking the
    parent :class:`Comment` rather than loose line numbers makes that automatic;
    a caller cannot accidentally drop ``end_line``.
    """
    add(repo, session, parent.anchor, body, comment_type="reply", username=username)


def replies_by_anchor(all_comments: Iterable[Comment]) -> dict[Anchor, list[str]]:
    """Map each anchor to the ``created_at`` stamps of replies sitting on it."""
    index: dict[Anchor, list[str]] = {}
    for comment in all_comments:
        if comment.comment_type == "reply":
            index.setdefault(comment.anchor, []).append(comment.created_at)
    return index


def is_answered(comment: Comment, replies: dict[Anchor, list[str]]) -> bool:
    """Whether *comment* already has a reply posted after it at its anchor."""
    return any(stamp > comment.created_at for stamp in replies.get(comment.anchor, []))
