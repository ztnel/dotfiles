#!/usr/bin/env bash
set -euo pipefail

# Transport + selection tests for lib/tuicr_watch.py.
#
# Uses only POSIX-common tools plus bash/python3 so the suite runs on Linux,
# macOS and WSL — deliberately no rg and no sha1sum.

libDir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)"
watcher="${libDir}/tuicr_watch.py"
skillDir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
has()  { grep -q "$1" "$2" 2>/dev/null; }

sessionId="11111111-1111-1111-1111-111111111111"

ledgerHas() {
    local dir="$1" cid="$2"
    python3 - "$dir" "$cid" <<'PY'
import glob, json, sys
for path in glob.glob(sys.argv[1] + "/*.json"):
    try:
        with open(path) as fh:
            data = json.load(fh)
    except Exception:
        continue
    if sys.argv[2] in data:
        raise SystemExit(0)
raise SystemExit(1)
PY
}

makeFakes() {
    local bin="$1"
    mkdir -p "${bin}"
    cat >"${bin}/tuicr" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-} ${2:-}" in
    "review comments")
        [ "${FAKE_COMMENTS_FAIL:-0}" = "1" ] && exit 9
        printf '%s\n' "${FAKE_COMMENTS}" ;;
    "review list")
        [ "${FAKE_LIST_FAIL:-0}" = "1" ] && exit 9
        [ "${FAKE_LIST_EMPTY:-0}" = "1" ] && { printf '[]\n'; exit 0; }
        printf '[{"slug":"review","active":true}]\n' ;;
    *) exit 2 ;;
esac
EOF
    cat >"${bin}/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${FAKE_TMUX_LOG}"
case "${1:-}" in
    list-commands)
        printf 'send-keys (send) [-FHKlMRX] [-c target-client] [-t target-pane] key ...\n' ;;
    list-panes)
        printf '%%99 %s\n' "${FAKE_PANE_PID}" ;;
    display-message)
        format="${*: -1}"
        case "${format}" in
            *pane_id*) printf '%%99\n' ;;
            *pane_pid*)
                n="$(cat "${FAKE_PANE_QUERIES}")"; n=$((n + 1))
                printf '%s\n' "${n}" >"${FAKE_PANE_QUERIES}"
                if [ "${FAKE_PANE_FLIP_AFTER:-0}" != "0" ] && [ "${n}" -gt "${FAKE_PANE_FLIP_AFTER}" ]; then
                    printf '1\n'
                else
                    printf '%s\n' "${FAKE_PANE_PID}"
                fi ;;
            *window_active*) printf '%s\n' "${FAKE_WINDOW_ACTIVE}" ;;
            *) exit 2 ;;
        esac
        ;;
    load-buffer)  cat >"${FAKE_BUFFER}" ;;
    paste-buffer) cp "${FAKE_BUFFER}" "${FAKE_INPUT}" ;;
    capture-pane)
        printf '%s\n' '────────────────────────────────────────'
        printf '❯ '
        cat "${FAKE_INPUT}" 2>/dev/null || true
        printf '\n%s\n' '────────────────────────────────────────'
        ;;
    send-keys)
        key="${*: -1}"
        if [[ "$*" == *"-H 1b 5b 31 33 75"* ]]; then key="CSI_ENTER"
        elif [[ "$*" == *"-H 1b 5b 49"* ]]; then key="FOCUS_IN"
        elif [[ "$*" == *"-H 1b 5b 4f"* ]]; then key="FOCUS_OUT"
        fi
        [ "${key}" = "FOCUS_IN" ] && exit 0
        [ "${key}" = "FOCUS_OUT" ] && exit 0
        count="$(cat "${FAKE_SEND_COUNT}")"; count=$((count + 1))
        printf '%s\n' "${count}" >"${FAKE_SEND_COUNT}"
        persist() {
            PROMPT="$1" python3 - "${FAKE_EVENTS}" <<'PY'
import json, os, sys
with open(sys.argv[1], "a", encoding="utf-8") as fh:
    fh.write(json.dumps({"type": "user.message", "data": {"content": os.environ["PROMPT"]}}) + "\n")
PY
        }
        case "${FAKE_SUBMIT_MODE}" in
            raw)     [ "${key}" = "CSI_ENTER" ] && { persist "$(cat "${FAKE_INPUT}")"; : >"${FAKE_INPUT}"; } ;;
            named)   [ "${key}" = "Enter" ]     && { persist "$(cat "${FAKE_INPUT}")"; : >"${FAKE_INPUT}"; } ;;
            delayed) [ "${key}" = "CSI_ENTER" ] && {
                         prompt="$(cat "${FAKE_INPUT}")"; : >"${FAKE_INPUT}"
                         (sleep "${FAKE_EVENT_DELAY}"; persist "${prompt}") & } ;;
        esac
        exit 0
        ;;
    *) exit 2 ;;
esac
EOF
    chmod +x "${bin}/tuicr" "${bin}/tmux"
}

makeSession() {
    local root="$1" lockPid="$2"
    mkdir -p "${root}/${sessionId}"
    printf 'id: %s\n' "${sessionId}" >"${root}/${sessionId}/workspace.yaml"
    : >"${root}/${sessionId}/events.jsonl"
    : >"${root}/${sessionId}/inuse.${lockPid}.lock"
}

setUp() {
    local dir="$1" lockPid="${2:-$$}"
    mkdir -p "${dir}/repo" "${dir}/state"
    makeFakes "${dir}/bin"
    makeSession "${dir}/sessions" "${lockPid}"
    : >"${dir}/tmux.log"; : >"${dir}/buffer"
    printf '%s' "${FAKE_INITIAL_INPUT:-}" >"${dir}/input"
    printf '0\n' >"${dir}/send-count"
    printf '0\n' >"${dir}/pane-queries"
}

exportFakeEnv() {
    local dir="$1" comments="$2" mode="${3:-raw}"
    export FAKE_COMMENTS="${comments}" \
        FAKE_SUBMIT_MODE="${mode}" \
        FAKE_PANE_PID="$$" \
        FAKE_PANE_FLIP_AFTER="${FAKE_PANE_FLIP_AFTER:-0}" \
        FAKE_PANE_QUERIES="${dir}/pane-queries" \
        FAKE_WINDOW_ACTIVE="0" \
        FAKE_TMUX_LOG="${dir}/tmux.log" \
        FAKE_BUFFER="${dir}/buffer" \
        FAKE_INPUT="${dir}/input" \
        FAKE_SEND_COUNT="${dir}/send-count" \
        FAKE_EVENT_DELAY="0.12" \
        FAKE_EVENTS="${dir}/sessions/${sessionId}/events.jsonl" \
        TMUX="fake" \
        PATH="${dir}/bin:${PATH}"
}

# Always invoked in a subshell so the exported fakes never leak between cases.
runWatcher() {
    local dir="$1" comments="$2" mode="$3"; shift 3
    (
        exportFakeEnv "${dir}" "${comments}" "${mode}"
        "${watcher}" \
            --repo "${dir}/repo" --session review \
            --cli-session "${sessionId}" --cli-pane %99 \
            --session-state-dir "${dir}/sessions" --state-dir "${dir}/state" \
            --interval 0.01 --submit-step 0.01 --event-timeout 0.08 \
            --queue-timeout 0.3 --submit-tries 1 --once "$@"
    )
}

issue() {
    printf '[{"id":"%s","comment_type":"issue","path":"src/a.cpp","start_line":7,"end_line":7,"side":"new","created_at":"2026-01-01T00:00:00Z","content":"fix it"}]' "$1"
}

# --- happy path: paste, focus, CSI-u submit, confirm, record ----------------
d="${tmp}/success"; setUp "${d}"
runWatcher "${d}" "$(issue c1)" raw --replay >/dev/null
has 'paste-buffer' "${d}/tmux.log" || fail "prompt was not pasted through a tmux buffer"
has '^send-keys.*-H 1b 5b 31 33 75' "${d}/tmux.log" || fail "CSI-u Enter was not submitted"
has '^send-keys.*-H 1b 5b 49' "${d}/tmux.log" || fail "inactive pane did not get focus-in"
has '^send-keys.*-H 1b 5b 4f' "${d}/tmux.log" || fail "pane focus was not restored"
has '"type": "user.message"' "${d}/sessions/${sessionId}/events.jsonl" || fail "wake was not persisted"
ledgerHas "${d}/state" c1 || fail "confirmed comment was not recorded as delivered"

# --- the wake prompt stays minimal -----------------------------------------
prompt="$(cat "${d}/buffer")"
case "${prompt}" in
    *"tuicr wake tuicr-"*"pending comment"*"review session review"*) ;;
    *) fail "wake prompt lost its identifying shape: ${prompt}" ;;
esac
case "${prompt}" in
    *unstaged*|*verdict*|*"--type reply"*|*commit*)
        fail "wake prompt still carries the behavioural contract; it belongs in SKILL.md" ;;
esac
[ "${#prompt}" -le 200 ] || fail "wake prompt is ${#prompt} chars; expected a terse wake"
case "${prompt}" in *"fix it"*) fail "wake prompt echoed the human's comment text" ;; esac

# --- named-Enter fallback when CSI-u is ignored ----------------------------
d="${tmp}/fallback"; setUp "${d}"
runWatcher "${d}" "$(issue c-fb)" named --replay --submit-tries 3 >/dev/null 2>&1
has '^send-keys.*Enter' "${d}/tmux.log" || fail "named Enter fallback was never attempted"
ledgerHas "${d}/state" c-fb || fail "fallback-submitted wake was not recorded"

# --- delayed persistence must not resubmit ---------------------------------
d="${tmp}/delayed"; setUp "${d}"
runWatcher "${d}" "$(issue c-delay)" delayed --replay --submit-tries 3 >/dev/null
[ "$(grep -c '^send-keys.*-H 1b 5b 31 33 75' "${d}/tmux.log")" -eq 1 ] ||
    fail "delayed persistence caused a duplicate submit"
ledgerHas "${d}/state" c-delay || fail "delayed wake was not recorded"

# --- unconfirmed wake stays pending ----------------------------------------
d="${tmp}/failure"; setUp "${d}"
if runWatcher "${d}" "$(issue c2)" fail --replay >/dev/null 2>&1; then
    fail "unconfirmed wake unexpectedly succeeded"
fi
if ledgerHas "${d}/state" c2; then fail "unconfirmed comment was recorded as delivered"; fi

# --- never overwrite human input -------------------------------------------
d="${tmp}/occupied"; FAKE_INITIAL_INPUT="human draft" setUp "${d}"
if FAKE_INITIAL_INPUT="human draft" runWatcher "${d}" "$(issue c-occ)" raw --replay >/dev/null 2>&1; then
    fail "watcher overwrote an occupied input box"
fi
if grep -qE '^(paste-buffer|send-keys)' "${d}/tmux.log"; then fail "watcher touched an occupied input box"; fi

# --- a pane reclaimed by something else must not receive a wake ------------
# Otherwise the prompt would be typed into a shell prompt and submitted.
d="${tmp}/rebound"; setUp "${d}"
if FAKE_PANE_FLIP_AFTER=1 runWatcher "${d}" "$(issue c-rebound)" raw --replay >/dev/null 2>&1; then
    fail "wake was delivered to a pane no longer hosting the session"
fi
if grep -qE '^paste-buffer' "${d}/tmux.log"; then fail "pasted into a rebound pane"; fi

# --- ignored types ----------------------------------------------------------
d="${tmp}/ignored"; setUp "${d}"
runWatcher "${d}" '[{"id":"r1","comment_type":"reply","path":"src/c.cpp","start_line":9,"side":"new","created_at":"2026-01-01T00:00:00Z","content":"ack"}]' raw --replay >/dev/null
if grep -qE '^send-keys' "${d}/tmux.log"; then fail "reply comment triggered a wake"; fi

d="${tmp}/ignored-extra"; setUp "${d}"
runWatcher "${d}" '[{"id":"a1","comment_type":"mirror","path":"src/d.cpp","start_line":9,"side":"new","created_at":"2026-01-01T00:00:00Z","content":"synced"}]' raw --replay --ignore-type mirror >/dev/null
if grep -qE '^send-keys' "${d}/tmux.log"; then fail "extra ignored type triggered a wake"; fi

# --- anchor threading: a later reply at the same anchor closes the comment --
answered='[{"id":"q1","comment_type":"note","path":"src/a.cpp","start_line":7,"end_line":7,"side":"new","created_at":"2026-01-01T00:00:00Z","content":"why?"},
           {"id":"r9","comment_type":"reply","path":"src/a.cpp","start_line":7,"end_line":7,"side":"new","created_at":"2026-01-02T00:00:00Z","content":"because"}]'
d="${tmp}/answered"; setUp "${d}"
runWatcher "${d}" "${answered}" raw --replay >/dev/null
if grep -qE '^send-keys' "${d}/tmux.log"; then fail "a comment already answered at its anchor still woke the agent"; fi

# An earlier reply must NOT suppress a newer question at the same anchor.
followup='[{"id":"r9","comment_type":"reply","path":"src/a.cpp","start_line":7,"end_line":7,"side":"new","created_at":"2026-01-01T00:00:00Z","content":"because"},
           {"id":"q2","comment_type":"note","path":"src/a.cpp","start_line":7,"end_line":7,"side":"new","created_at":"2026-01-02T00:00:00Z","content":"still unclear"}]'
d="${tmp}/followup"; setUp "${d}"
runWatcher "${d}" "${followup}" raw --replay >/dev/null
ledgerHas "${d}/state" q2 || fail "a follow-up after a reply did not wake the agent"

# A reply at a DIFFERENT anchor must not close the comment.
elsewhere='[{"id":"q3","comment_type":"note","path":"src/a.cpp","start_line":7,"end_line":7,"side":"new","created_at":"2026-01-01T00:00:00Z","content":"why?"},
           {"id":"r10","comment_type":"reply","path":"src/b.cpp","start_line":7,"end_line":7,"side":"new","created_at":"2026-01-02T00:00:00Z","content":"unrelated"}]'
d="${tmp}/elsewhere"; setUp "${d}"
runWatcher "${d}" "${elsewhere}" raw --replay >/dev/null
ledgerHas "${d}/state" q3 || fail "a reply at another anchor wrongly closed the comment"

# --- startup backlog: unanswered comments are DELIVERED, not silently seen --
# Seeding can only ever suppress genuinely unanswered comments (answered ones
# are filtered earlier), and the ledger is keyed by (repo, session) so every new
# review cycle starts empty. Seeding by default therefore dropped live review
# feedback whenever a watcher attached after the human had already commented.
d="${tmp}/backlog"; setUp "${d}"
backlog='[{"id":"old1","comment_type":"issue","path":"src/a.cpp","start_line":7,"end_line":7,"side":"new","created_at":"2026-01-01T00:00:00Z","content":"old"},
          {"id":"old2","comment_type":"suggestion","path":"src/b.cpp","start_line":3,"end_line":3,"side":"new","created_at":"2026-01-01T00:00:01Z","content":"older"}]'
runWatcher "${d}" "${backlog}" raw >/dev/null 2>&1 || true
has '^paste-buffer' "${d}/tmux.log" || fail "a pre-existing backlog was not delivered"
case "$(cat "${d}/buffer")" in
    *"2 pending comments in"*) ;;
    *) fail "backlog wake should report both comments: $(cat "${d}/buffer")";;
esac
ledgerHas "${d}/state" old1 || fail "delivered backlog comment was not recorded"
ledgerHas "${d}/state" old2 || fail "delivered backlog comment was not recorded"

# --- the count reports TOTAL unaddressed work, not just the trigger ---------
# An earlier comment held back by the re-arm window is still outstanding, so a
# wake triggered by a newer comment must not understate what is waiting.
d="${tmp}/count"; setUp "${d}"
runWatcher "${d}" "${backlog}" raw >/dev/null 2>&1 || true
: >"${d}/tmux.log"
runWatcher "${d}" "${backlog%]}"',{"id":"new1","comment_type":"issue","path":"src/c.cpp","start_line":1,"end_line":1,"side":"new","created_at":"2026-01-02T00:00:00Z","content":"new"}]' raw >/dev/null
has '^paste-buffer' "${d}/tmux.log" || fail "a new comment did not wake the agent"
case "$(cat "${d}/buffer")" in
    *"3 pending comments in"*) ;;
    *) fail "wake should count all 3 unanswered, not just the trigger: $(cat "${d}/buffer")";;
esac
ledgerHas "${d}/state" new1 || fail "new comment was not recorded"

# --- --seed-existing keeps the old opt-out available ------------------------
d="${tmp}/seed"; setUp "${d}"
runWatcher "${d}" "${backlog}" raw --seed-existing >/dev/null 2>&1 || true
if grep -qE '^paste-buffer' "${d}/tmux.log"; then fail "--seed-existing still woke the agent on a pre-existing backlog"; fi
ledgerHas "${d}/state" old1 || fail "--seed-existing did not record the existing backlog"
ledgerHas "${d}/state" old2 || fail "--seed-existing did not record the whole existing backlog"

# a genuinely new comment after the seed still fires
: >"${d}/tmux.log"
runWatcher "${d}" "${backlog%]}"',{"id":"new1","comment_type":"issue","path":"src/c.cpp","start_line":1,"end_line":1,"side":"new","created_at":"2026-01-02T00:00:00Z","content":"new"}]' raw --seed-existing >/dev/null
has '^paste-buffer' "${d}/tmux.log" || fail "a new comment after the seed did not wake the agent"
ledgerHas "${d}/state" new1 || fail "post-seed comment was not recorded"

# --- already-persisted deterministic wake is reconciled, not resent --------
d="${tmp}/duplicate"; setUp "${d}"
token="tuicr-$(printf '%s' 'review|c5' | python3 -c 'import hashlib,sys; print(hashlib.sha1(sys.stdin.buffer.read()).hexdigest()[:16])')"
printf '{"type":"user.message","data":{"content":"%s"}}\n' "${token}" \
    >>"${d}/sessions/${sessionId}/events.jsonl"
runWatcher "${d}" "$(issue c5)" fail --replay >/dev/null
if grep -qE '^send-keys' "${d}/tmux.log"; then fail "an already-accepted wake was submitted again"; fi
ledgerHas "${d}/state" c5 || fail "already-accepted wake was not reconciled"

# --- re-arm: a delivered comment that never got a reply is retried ---------
d="${tmp}/rearm"; setUp "${d}"
REPO_KEY="$(cd "${d}/repo" && pwd)" python3 - "${d}/state" <<'PY'
import hashlib, json, os, sys
state = sys.argv[1]
key = hashlib.sha1(("%s|review" % os.environ["REPO_KEY"]).encode()).hexdigest()[:16]
with open(os.path.join(state, key + ".json"), "w") as fh:
    json.dump({"c-rearm": {"attempts": 1, "last": 0}}, fh)
PY
runWatcher "${d}" "$(issue c-rearm)" raw --rearm 1 >/dev/null
has '^send-keys.*-H 1b 5b 31 33 75' "${d}/tmux.log" ||
    fail "an unanswered delivered comment was never re-armed"

# ...but not while it is still inside the re-arm window.
d="${tmp}/norearm"; setUp "${d}"
REPO_KEY="$(cd "${d}/repo" && pwd)" python3 - "${d}/state" <<'PY'
import hashlib, json, os, sys, time
state = sys.argv[1]
key = hashlib.sha1(("%s|review" % os.environ["REPO_KEY"]).encode()).hexdigest()[:16]
with open(os.path.join(state, key + ".json"), "w") as fh:
    json.dump({"c-quiet": {"attempts": 1, "last": time.time()}}, fh)
PY
runWatcher "${d}" "$(issue c-quiet)" raw --rearm 900 >/dev/null
if grep -qE '^send-keys' "${d}/tmux.log"; then fail "a recently delivered comment was re-woken too soon"; fi

# --- a read failure must never look like "no comments" ---------------------
d="${tmp}/readfail"; setUp "${d}"
if FAKE_COMMENTS_FAIL=1 runWatcher "${d}" "$(issue c-rf)" raw --replay >/dev/null 2>&1; then
    fail "a tuicr read failure was reported as success"
fi

# --- pane/session PID mismatch is refused ----------------------------------
d="${tmp}/mismatch"; setUp "${d}" 1
if runWatcher "${d}" "$(issue c3)" raw --replay >/dev/null 2>&1; then
    fail "pane/session PID mismatch was accepted"
fi

# --- a second daemon on the same session is refused ------------------------
d="${tmp}/singleton"; setUp "${d}"
lockKey="$(REPO_KEY="$(cd "${d}/repo" && pwd)" python3 -c '
import hashlib, os
print(hashlib.sha1(("%s|review" % os.environ["REPO_KEY"]).encode()).hexdigest()[:16])')"
printf '%s\n' "$$" >"${d}/state/${lockKey}.lock"
if runWatcher "${d}" "$(issue c-lock)" raw --replay >/dev/null 2>&1; then
    fail "a second watcher on the same session was allowed"
fi
rm -f "${d}/state/${lockKey}.lock"

# --- dry-run mutates nothing -----------------------------------------------
d="${tmp}/dry"; setUp "${d}"
FAKE_COMMENTS="$(issue c6)" PATH="${d}/bin:${PATH}" \
    "${watcher}" --repo "${d}/repo" --session review \
    --state-dir "${d}/missing-state" --replay --once --dry-run >/dev/null
[ ! -e "${d}/missing-state" ] || fail "dry-run mutated state"

# --- a vanished session is given up on; a transient outage is not -----------
# Observed live: a watcher whose tuicr window had been closed logged 920
# consecutive read failures and would have polled forever. Refusing to treat a
# read failure as "no comments" is correct, but it must not mean waiting
# forever — the two cases have to be told apart, and only one is terminal.
d="${tmp}/vanished"; setUp "${d}"
out="${d}/vanished.log"
(
    exportFakeEnv "${d}" "$(issue c7)"
    export FAKE_COMMENTS_FAIL=1 FAKE_LIST_EMPTY=1
    timeout 20 "${watcher}" --repo "${d}/repo" --session review \
        --cli-session "${sessionId}" --cli-pane %99 \
        --session-state-dir "${d}/sessions" --state-dir "${d}/state" \
        --interval 0.01 --replay
) >"${out}" 2>&1 && rc=0 || rc=$?
[ "${rc}" -eq 0 ] || fail "vanished session should exit 0, got ${rc}"
has 'no longer exists' "${out}" || fail "vanished session gave no reason for exiting"

# The mirror image: tuicr itself is down, so the session's fate is unknown and
# the daemon must keep waiting rather than quietly abandoning the human.
d="${tmp}/transient"; setUp "${d}"
out="${d}/transient.log"
(
    exportFakeEnv "${d}" "$(issue c8)"
    export FAKE_COMMENTS_FAIL=1 FAKE_LIST_FAIL=1
    timeout 3 "${watcher}" --repo "${d}/repo" --session review \
        --cli-session "${sessionId}" --cli-pane %99 \
        --session-state-dir "${d}/sessions" --state-dir "${d}/state" \
        --interval 0.01 --replay
) >"${out}" 2>&1 && rc=0 || rc=$?
[ "${rc}" -eq 124 ] || fail "transient tuicr outage must not end the watch (exited ${rc})"
has 'not treating this as' "${out}" || fail "transient outage was not reported as a read failure"

# --- portability guards -----------------------------------------------------
# Stock macOS has no sha1sum, setsid or rg. Comments may name them; code may not.
for f in "${skillDir}"/tests/*.sh; do
    if grep -vE '^[[:space:]]*#' "$f" | grep -qE '\bsha1sum\b|^[[:space:]]*rg |\| *rg '; then
        fail "$f uses a tool missing on stock macOS"
    fi
    if grep -vE '^[[:space:]]*#' "$f" | grep -qE '\bsetsid\b' &&
       ! grep -q 'command -v setsid' "$f"; then
        fail "$f calls setsid without a portable fallback"
    fi
done
if grep -qE '^[^#]*develop' "${libDir}/tuicr_up.py"; then
    fail "tuicr_up.py still hardcodes a project default branch"
fi

# --- legacy state-dir adoption ----------------------------------------------
# The shell implementation recorded pidfiles under ~/.local/state/tuicr-watch/;
# the Python port moved them to ~/.local/state/tuicr/watch/. Watchers outlive
# the port by weeks, so a lookup that ignores the old location reports success
# while leaving live daemons running. HOME is redirected so these cases never
# touch the human's real watchers.
legacyHome="$(mktemp -d)"
mkdir -p "${legacyHome}/.local/state/tuicr-watch" "${legacyHome}/.local/state/tuicr/watch"
# The stand-in must look like a watcher in `ps`, because stop now verifies
# identity before signalling. Background helpers also detach from the harness
# stdout: a process still holding the pipe keeps a consuming `tail` from ever
# seeing EOF.
fakeWatcher="${legacyHome}/tuicr_watch.py"
printf '#!/bin/sh\nsleep 600\n' > "${fakeWatcher}"
chmod +x "${fakeWatcher}"
"${fakeWatcher}" >/dev/null 2>&1 & legacyPid=$!
echo "${legacyPid}" > "${legacyHome}/.local/state/tuicr-watch/old-c1-root.pid"

legacyOut="${legacyHome}/list.out"
HOME="${legacyHome}" python3 "${libDir}/watch_up.py" --list >"${legacyOut}" 2>&1
has 'old-c1-root' "${legacyOut}" || fail "--list does not surface a legacy-dir watcher"
has 'legacy' "${legacyOut}" || fail "legacy watcher is not tagged as such"
has 'live' "${legacyOut}" || fail "legacy watcher liveness not reported"

# An explicit --state-dir means isolation; reaching into the legacy location
# from there would let a scoped caller stop unrelated real watchers.
iso="$(mktemp -d)"
isoOut="$(HOME="${legacyHome}" python3 "${libDir}/watch_up.py" --list --state-dir "${iso}" 2>&1)"
[ -z "${isoOut}" ] || fail "--state-dir must not scan the legacy dir (got: ${isoOut})"

# --stop must find a legacy pidfile by name and actually kill the process.
# `cond && fail` would abort the whole suite under `set -e` on the PASSING
# branch, so every assertion below uses an if/then.
HOME="${legacyHome}" python3 "${libDir}/watch_up.py" --stop old-c1-root >/dev/null 2>&1
sleep 0.3
if kill -0 "${legacyPid}" 2>/dev/null; then fail "--stop did not kill the legacy watcher"; fi
if [ -f "${legacyHome}/.local/state/tuicr-watch/old-c1-root.pid" ]; then
    fail "--stop did not clear the legacy pidfile"
fi

# --stop-all must sweep the legacy dir too, or teardown silently leaks.
"${fakeWatcher}" >/dev/null 2>&1 & legacyPid2=$!
echo "${legacyPid2}" > "${legacyHome}/.local/state/tuicr-watch/scope-c1-root.pid"
HOME="${legacyHome}" python3 "${libDir}/watch_up.py" --stop-all --prefix 'scope-' >/dev/null 2>&1
sleep 0.3
if kill -0 "${legacyPid2}" 2>/dev/null; then fail "--stop-all did not sweep the legacy dir"; fi
kill "${legacyPid}" "${legacyPid2}" 2>/dev/null || true

# PID reuse: a stale pidfile names a PID the kernel has since handed to an
# unrelated process. Stopping must never signal it.
sleep 600 >/dev/null 2>&1 & innocentPid=$!
echo "${innocentPid}" > "${legacyHome}/.local/state/tuicr-watch/scope-c1-stale.pid"
HOME="${legacyHome}" python3 "${libDir}/watch_up.py" --stop-all --prefix 'scope-' >/dev/null 2>&1
sleep 0.3
if ! kill -0 "${innocentPid}" 2>/dev/null; then
  fail "stop killed an innocent process named by a stale pidfile"
fi
if [ -f "${legacyHome}/.local/state/tuicr-watch/scope-c1-stale.pid" ]; then
  fail "stop left the stale pidfile in place"
fi
kill "${innocentPid}" 2>/dev/null || true

rm -rf "${legacyHome}" "${iso}"

echo "PASS: tuicr-watch transport, selection and portability tests"
