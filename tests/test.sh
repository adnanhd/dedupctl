#!/usr/bin/env bash
#
# tests/test.sh - unit and invariant tests for the backup tools of this
# repository.
#
# Every run of a tool happens inside a fresh scratch tree made by this
# script: HOME, the XDG directories, BORG_BASE_DIR, TMPDIR and the backup
# roots all point into it, every inherited BORG_* variable is dropped, the
# repositories are throwaway ones the test creates, and the tree is refused
# if any directory above it holds a .borgbackup or .myrsyncbackup.  Needs
# borg (for a Borg tool) or rsync (for an rsync tool), and python3: the
# invariant runs are built from `scripts/gen-docs.py --options`, which
# reads the option parsing from the source.
#
#   tests/test.sh                 run every test
#   SCRATCH_PARENT=DIR tests/test.sh
#                                 make the scratch trees under DIR
#                                 (default: $TMPDIR, else /tmp)
#   KEEP=1 tests/test.sh          leave the scratch trees for inspection

set -o nounset
set -o pipefail

PROGS=(dedupctl)

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PARENT=${SCRATCH_PARENT:-${TMPDIR:-/tmp}}
ORIG_PATH=$PATH
PASS=0
FAIL=0
TREES=()

pass() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$*"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$*"; }
check() {  # check DESCRIPTION CONDITION...
    local what="$1"
    shift
    if "$@"; then pass "$what"; else fail "$what"; fi
}

cleanup() {
    [ "${KEEP:-}" = 1 ] && return
    local t
    for t in "${TREES[@]}"; do
        chmod -R u+w "$t" 2>/dev/null
        rm -rf "$t"
    done
}
trap cleanup EXIT

# flavour PROG: borg or rsync, from the config file its dispatcher names
flavour() {
    if grep -q '\.borgbackup' "$ROOT/$1"; then echo borg; else echo rsync; fi
}

# new_tree: a fresh scratch tree T with a source tree and a nested one
#   $T/home          HOME, XDG_*, BORG_BASE_DIR
#   $T/tmp           TMPDIR
#   $T/backups       BORG_BACKUP_ROOT, RSYNC_BACKUP_ROOT
#   $T/src           outer source tree; src/plain is a plain subdirectory,
#                    src/inner a nested tree with a repository of its own
new_tree() {
    mkdir -p "$PARENT"
    T=$(mktemp -d "$PARENT/backup-tools-test.XXXXXX") || exit 1
    TREES+=("$T")
    local d
    d=$(dirname "$T")
    while :; do
        if [ -e "$d/.borgbackup" ] || [ -e "$d/.myrsyncbackup" ]; then
            echo "refusing: $d holds a backup configuration" >&2
            exit 1
        fi
        [ "$d" = / ] && break
        d=$(dirname "$d")
    done
    mkdir -p "$T/home" "$T/tmp" "$T/backups" "$T/src/plain" "$T/src/inner/sub"
    echo outer > "$T/src/a.txt"
    echo plain > "$T/src/plain/p.txt"
    echo inner > "$T/src/inner/b.txt"
    echo sub > "$T/src/inner/sub/c.txt"
    local v
    for v in $(compgen -e | grep '^BORG_'); do unset "$v"; done
    export HOME="$T/home"
    export XDG_CONFIG_HOME="$T/home/.config" XDG_CACHE_HOME="$T/home/.cache"
    export XDG_DATA_HOME="$T/home/.local/share" XDG_STATE_HOME="$T/home/.local/state"
    export TMPDIR="$T/tmp"
    export BORG_BASE_DIR="$T/home" BORG_BACKUP_ROOT="$T/backups" RSYNC_BACKUP_ROOT="$T/backups"
    export BORG_PASSPHRASE=throwaway BORG_DISPLAY_PASSPHRASE=no
    export PATH=$ORIG_PATH
}

# tool DIR PROG ARGS...: run PROG in DIR with no terminal; sets RC and OUT
tool() {
    local dir="$1" prog="$2"
    shift 2
    OUT=$(cd "$dir" && timeout 120 "$ROOT/$prog" "$@" </dev/null 2>&1)
    RC=$?
}

# tool_input INPUT DIR PROG ARGS...: the same, with INPUT on stdin
tool_input() {
    local input="$1" dir="$2" prog="$3"
    shift 3
    OUT=$(cd "$dir" && printf '%s' "$input" | timeout 120 "$ROOT/$prog" "$@" 2>&1)
    RC=$?
}

# state: every file's checksum, and every directory and symlink, under $T
state() {
    ( cd "$T" &&
      find . -type f -print0 | LC_ALL=C sort -z | xargs -0r sha256sum &&
      find . \( -type d -o -type l \) -printf '%y %p %l\n' | LC_ALL=C sort )
}

# repo_of DIR PROG: the repository (Borg) or backup storage (rsync) of DIR
repo_of() {
    if [ "$(flavour "$2")" = borg ]; then
        ( . "$1/.borgbackup"; echo "$BORG_REPO" )
    else
        ( . "$1/.myrsyncbackup"; echo "$BACKUP_DIR" )
    fi
}

# count DIR PROG: archives or snapshots held for DIR
count() {
    local repo
    repo=$(repo_of "$1" "$2")
    if [ "$(flavour "$2")" = borg ]; then
        borg list --short "$repo" </dev/null 2>/dev/null | wc -l
    else
        find "$repo/data" -mindepth 1 -maxdepth 1 -type d ! -name latest 2>/dev/null | wc -l
    fi
}

# setup PROG: both repositories initialized, and one real backup of each
setup() {
    local prog="$1" verb
    verb=$(take_verb "$prog")
    new_tree
    tool "$T/src" "$prog" init
    tool "$T/src/inner" "$prog" init
    tool "$T/src/inner" "$prog" "$verb"
    sleep 1    # archive and snapshot names have one-second resolution
}

take_verb() {
    if [ "$(flavour "$1")" = borg ]; then echo backup; else echo snapshot; fi
}

unchanged() { [ "$1" = "$2" ]; }

# ---------------------------------------------------------------------------
# unit tests, one per fix

test_nested_dry_run() {  # fix 1: the parent's run keeps --dry-run
    local prog="$1" verb before
    verb=$(take_verb "$prog")
    setup "$prog"
    before=$(state)
    tool "$T/src/inner" "$prog" "$verb" --dry-run
    check "$prog: nested $verb --dry-run exits 0" [ "$RC" -eq 0 ]
    check "$prog: nested $verb --dry-run reaches the parent" grep -q "parent" <<<"$OUT"
    check "$prog: nested $verb --dry-run changes nothing, parent included" unchanged "$before" "$(state)"
}

test_nested_real_run() {  # fix 1: the parent's run still happens, with the options
    local prog="$1" verb outer inner
    verb=$(take_verb "$prog")
    setup "$prog"
    outer=$(count "$T/src" "$prog")
    inner=$(count "$T/src/inner" "$prog")
    tool "$T/src/inner" "$prog" "$verb"
    check "$prog: nested $verb exits 0" [ "$RC" -eq 0 ]
    check "$prog: nested $verb adds one to the inner repository" [ "$(count "$T/src/inner" "$prog")" -eq $((inner + 1)) ]
    check "$prog: nested $verb adds one to the parent repository" [ "$(count "$T/src" "$prog")" -eq $((outer + 1)) ]
    if [ "$(flavour "$prog")" = rsync ]; then
        # --force-full reaches the parent: its new snapshot shares no inode
        sleep 1
        tool "$T/src/inner" "$prog" snapshot --force-full
        local data prev last
        data="$(repo_of "$T/src" "$prog")/data"
        prev=$(find "$data" -mindepth 1 -maxdepth 1 -type d ! -name latest | sort | tail -n 2 | head -n 1)
        last=$(find "$data" -mindepth 1 -maxdepth 1 -type d ! -name latest | sort | tail -n 1)
        check "$prog: nested snapshot --force-full copies the parent in full" \
            [ "$(stat -c %i "$prev/a.txt")" != "$(stat -c %i "$last/a.txt")" ]
    fi
}

test_init_refuses_options() {  # fix 2
    local prog="$1" before opt
    new_tree
    before=$(state)
    for opt in --dry-run --force-full --create --no-such-option; do
        tool "$T/src" "$prog" init "$opt"
        check "$prog: init $opt exits 2" [ "$RC" -eq 2 ]
        check "$prog: init $opt creates nothing" unchanged "$before" "$(state)"
    done
    tool "$T/src" "$prog" init "$T/no/such/dir"
    check "$prog: init on a missing directory exits 2 and creates nothing" \
        [ "$RC" -eq 2 -a "$before" = "$(state)" ]
    tool "$T/src" "$prog" init "$T/src/plain" "$T/src/inner"
    check "$prog: init with two paths exits 2 and creates nothing" \
        [ "$RC" -eq 2 -a "$before" = "$(state)" ]
    tool "$T/src" "$prog" init --help
    check "$prog: init --help exits 0 and creates nothing" [ "$RC" -eq 0 -a "$before" = "$(state)" ]
    tool "$T/src" "$prog" init "$T/src/plain"
    check "$prog: init PATH still initializes PATH" [ "$RC" -eq 0 ]
}

# complete_bash PROG WORD...: what the bash completion offers after WORDs
complete_bash() {
    local prog="$1"
    shift
    (
        source "$ROOT/completions/bash/$prog.bash"
        fn=$(sed -n "s/^complete -F \([^ ]*\) $prog\$/\1/p" "$ROOT/completions/bash/$prog.bash")
        COMP_WORDS=("$prog" "$@")
        COMP_CWORD=$#
        COMPREPLY=()
        "$fn"
        printf '%s\n' "${COMPREPLY[@]}"
    )
}

# complete_fish PROG LINE: what the fish completion offers for LINE
complete_fish() {
    XDG_CONFIG_HOME="$T/home/.config" HOME="$T/home" timeout 30 \
        fish -c "source '$ROOT/completions/fish/$1.fish'; complete -C '$2'" </dev/null 2>/dev/null | cut -f1
}

test_completions() {  # fix 2 and fix 4: what the completions offer
    local prog="$1" verb want
    verb=$(take_verb "$prog")
    new_tree
    check "$prog: bash completion offers no option to init" [ -z "$(complete_bash "$prog" init '')" ]
    if [ "$(flavour "$prog")" = borg ]; then want="--dry-run"; else want="--create --dry-run --force-full"; fi
    check "$prog: bash completion of $verb offers $want" \
        [ "$(complete_bash "$prog" "$verb" '' | sort | tr '\n' ' ')" = "$want " ]
    if command -v fish >/dev/null; then
        check "$prog: fish completion offers no option to init" \
            [ -z "$(complete_fish "$prog" "$prog init -" | grep -- '^-')" ]
        check "$prog: fish completion of $verb offers $want" \
            [ "$(complete_fish "$prog" "$prog $verb -" | grep -- '^-' | sort | tr '\n' ' ')" = "$want " ]
    else
        echo "skip  $prog: fish is not installed"
    fi
}

test_restore_target() {  # fix 3: restore writes into the repository root
    local prog="$1" snap
    [ "$(flavour "$prog")" = rsync ] || return 0
    setup "$prog"
    snap=$(find "$(repo_of "$T/src" "$prog")/data" -mindepth 1 -maxdepth 1 -type d ! -name latest | sort | tail -n 1)
    rm "$T/src/a.txt"
    tool_input $'y\n' "$T/src/plain" "$prog" restore "$(basename "$snap")"
    check "$prog: restore from a subdirectory exits 0" [ "$RC" -eq 0 ]
    check "$prog: restore puts the file back in the repository root" [ -f "$T/src/a.txt" ]
    check "$prog: restore writes nothing into the subdirectory it ran from" [ ! -e "$T/src/plain/a.txt" ]
    tool "$T" "$prog" --help
    check "$prog: the help says restore writes into the repository root" grep -q "into the repository root" <<<"$OUT"
}

test_force_full() {  # fix 4
    local prog="$1" before
    setup "$prog"
    if [ "$(flavour "$prog")" = borg ]; then
        before=$(state)
        for opt in --force-full --create; do
            tool "$T/src" "$prog" backup "$opt"
            check "$prog: backup $opt is refused (exit 2) and changes nothing" \
                [ "$RC" -eq 2 -a "$before" = "$(state)" ]
        done
        tool "$T" "$prog" --help
        check "$prog: the help no longer offers --force-full" bash -c '! grep -q -- --force-full <<<"$1"' _ "$OUT"
    else
        local data first second third
        data="$(repo_of "$T/src" "$prog")/data"
        tool "$T/src" "$prog" snapshot
        sleep 1
        tool "$T/src" "$prog" snapshot --create
        mapfile -t snaps < <(find "$data" -mindepth 1 -maxdepth 1 -type d ! -name latest | sort)
        first=${snaps[-3]} second=${snaps[-2]} third=${snaps[-1]}
        check "$prog: a plain snapshot hard-links unchanged files" \
            [ "$(stat -c %i "$first/a.txt")" = "$(stat -c %i "$second/a.txt")" ]
        check "$prog: snapshot --create copies everything" \
            [ "$(stat -c %i "$second/a.txt")" != "$(stat -c %i "$third/a.txt")" ]
    fi
}

test_usage() {  # fix 5 and fix 6
    local prog="$1" verb before
    verb=$(take_verb "$prog")
    setup "$prog"
    before=$(state)
    tool "$T" "$prog" --help
    check "$prog --help exits 0" [ "$RC" -eq 0 ]
    check "$prog: the usage line lists no global option" [ "$(head -n 1 <<<"$OUT")" = "usage: $prog <command> [<options>]" ]
    tool "$T" "$prog" -h
    check "$prog -h exits 0" [ "$RC" -eq 0 ]
    tool "$T" "$prog"
    check "$prog with no command exits 1" [ "$RC" -eq 1 ]
    tool "$T/src" "$prog" --dry-run "$verb"
    check "$prog --dry-run $verb is refused and changes nothing" [ "$RC" -ne 0 -a "$before" = "$(state)" ]
    tool "$T/src" "$prog" "$verb" --help
    check "$prog $verb --help exits 0 and changes nothing" [ "$RC" -eq 0 -a "$before" = "$(state)" ]
    tool "$T/src" "$prog" "$verb" --dryrun
    check "$prog $verb with a mistyped option exits 2 and changes nothing" [ "$RC" -eq 2 -a "$before" = "$(state)" ]
}

# ---------------------------------------------------------------------------
# invariants, over every subcommand and option the source parses

# combos OPTS...: every subset of OPTS, one per line, values filled in
combos() {
    local n=$# mask i out
    local -a opts=("$@")
    for ((mask = 0; mask < (1 << n); mask++)); do
        out=""
        for ((i = 0; i < n; i++)); do
            if ((mask & (1 << i))); then
                case "${opts[i]}" in
                    *:value) out+=" ${opts[i]%:value} 1" ;;
                    *) out+=" ${opts[i]%:flag}" ;;
                esac
            fi
        done
        echo "${out# }"
    done
}

# invariant_run DIR PROG EXPECT ARGS...: EXPECT is 0 (must succeed) or
# fail (must exit non-zero); either way the tree must not change
invariant_run() {
    local dir="$1" prog="$2" expect="$3" before
    shift 3
    before=$(state)
    tool "$dir" "$prog" "$@"
    local after
    after=$(state)
    local where=${dir#"$T/"}
    if [ "$before" != "$after" ]; then
        BROKEN+=("$prog $* (from $where, exit $RC): changed the tree")
    elif [ "$expect" = 0 ] && [ "$RC" -ne 0 ]; then
        BROKEN+=("$prog $* (from $where): exit $RC, expected 0")
    elif [ "$expect" = fail ] && [ "$RC" -eq 0 ]; then
        BROKEN+=("$prog $* (from $where): exit 0, expected a refusal")
    fi
    RUNS=$((RUNS + 1))
}

test_invariants() {
    local prog="$1" table cmd optlist dir combo expect
    table=$(cd "$ROOT" && python3 scripts/gen-docs.py --options "$prog") || {
        fail "$prog: scripts/gen-docs.py --options failed"
        return
    }
    setup "$prog"
    local dirs=("$T/src" "$T/src/plain" "$T/src/inner")

    # 1. every --dry-run run, over every subcommand and option combination
    BROKEN=() RUNS=0
    while IFS=$'\t' read -r cmd optlist; do
        local -a opts=()
        local parses_dry=fail o
        for o in $optlist; do
            if [ "$o" = --dry-run:flag ]; then parses_dry=0; else opts+=("$o"); fi
        done
        while IFS= read -r combo; do
            for dir in "${dirs[@]}"; do
                # shellcheck disable=SC2086
                invariant_run "$dir" "$prog" "$parses_dry" "$cmd" --dry-run $combo
                [ -n "$combo" ] && invariant_run "$dir" "$prog" "$parses_dry" "$cmd" $combo --dry-run
            done
        done < <(combos "${opts[@]}")
    done <<<"$table"
    if [ ${#BROKEN[@]} -eq 0 ]; then
        pass "$prog: invariant 1, $RUNS --dry-run runs leave the tree unchanged"
    else
        fail "$prog: invariant 1, ${#BROKEN[@]} of $RUNS --dry-run runs broke it:"
        printf '        %s\n' "${BROKEN[@]}"
    fi

    # 2. any unknown flag, alone or after a valid option, is refused
    BROKEN=() RUNS=0
    local bad
    for dir in "${dirs[@]}"; do
        for bad in --no-such-option -Z; do
            invariant_run "$dir" "$prog" fail "$bad"
        done
    done
    while IFS=$'\t' read -r cmd optlist; do
        for dir in "${dirs[@]}"; do
            for bad in --no-such-option -Z; do
                invariant_run "$dir" "$prog" fail "$cmd" "$bad"
            done
            for o in $optlist; do
                case "$o" in
                    *:value) invariant_run "$dir" "$prog" fail "$cmd" "${o%:value}" 1 --no-such-option ;;
                    *) invariant_run "$dir" "$prog" fail "$cmd" "${o%:flag}" --no-such-option ;;
                esac
            done
        done
    done <<<"$table"
    if [ ${#BROKEN[@]} -eq 0 ]; then
        pass "$prog: invariant 2, $RUNS runs with an unknown flag are refused and change nothing"
    else
        fail "$prog: invariant 2, ${#BROKEN[@]} of $RUNS unknown-flag runs broke it:"
        printf '        %s\n' "${BROKEN[@]}"
    fi
}

# ---------------------------------------------------------------------------

for prog in "${PROGS[@]}"; do
    need=$( [ "$(flavour "$prog")" = borg ] && echo borg || echo rsync )
    if ! command -v "$need" >/dev/null; then
        fail "$prog: $need is not installed; its tests cannot run"
        continue
    fi
    test_nested_dry_run "$prog"
    test_nested_real_run "$prog"
    test_init_refuses_options "$prog"
    test_completions "$prog"
    test_restore_target "$prog"
    test_force_full "$prog"
    test_usage "$prog"
    test_invariants "$prog"
done

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
