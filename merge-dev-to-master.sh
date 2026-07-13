#!/usr/bin/env bash
set -euo pipefail

REMOTE="${REMOTE:-origin}"
DEV_BRANCH="${DEV_BRANCH:-dev}"
MASTER_BRANCH="${MASTER_BRANCH:-master}"
KEYS_DIR="${KEYS_DIR:-keys}"
DO_PUSH=0

usage() {
    cat <<EOF
Usage: $0 [--push]

Options:
    --push    Push the resulting master branch to the remote.
    -h, --help
              Show this help.

Environment variables:
    REMOTE         Default: origin
    DEV_BRANCH     Default: dev
    MASTER_BRANCH  Default: master
    KEYS_DIR       Default: keys
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --push)
            DO_PUSH=1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

die() {
    echo "error: $*" >&2
    exit 1
}

info() {
    echo "==> $*"
}

require_clean_worktree() {
    if [ -n "$(git status --porcelain)" ]; then
        die "working tree is not clean; commit, stash, or clean your changes first"
    fi
}

require_branch_exists() {
    local ref="$1"

    git rev-parse --verify --quiet "$ref" >/dev/null ||
        die "ref does not exist: $ref"
}

current_branch() {
    git symbolic-ref --quiet --short HEAD 2>/dev/null || true
}

load_allowed_gpg_key_ids() {
    local keyfile
    local keyid

    [ -d "$KEYS_DIR" ] || die "keys directory does not exist: $KEYS_DIR"

    ALLOWED_GPG_KEY_IDS=""

    for keyfile in "$KEYS_DIR"/*.asc; do
        [ -e "$keyfile" ] || continue

        keyid="$(
            gpg --with-colons "$keyfile" 2>/dev/null |
                grep '^pub' |
                cut -d: -f5 |
                head -n 1 ||
                true
        )"

        if [ -n "$keyid" ]; then
            ALLOWED_GPG_KEY_IDS+="${keyid}"$'\n'
        fi
    done

    if [ -z "$ALLOWED_GPG_KEY_IDS" ]; then
        die "no usable .asc public keys found in $KEYS_DIR"
    fi
}

commit_signature_key_id() {
    local commit="$1"
    local status
    local keyid

    status="$(git log -1 --format=%G? "$commit" 2>/dev/null || true)"
    keyid="$(git log -1 --format=%GK "$commit" 2>/dev/null || true)"

    case "$status" in
        G | U) ;;
        *) return 1 ;;
    esac

    [ -n "$keyid" ] || return 1

    printf '%s\n' "$keyid"
}

key_id_is_allowed() {
    local keyid="$1"
    local short_keyid

    # Handle full fingerprints by checking if the last 16 chars match
    if [ "${#keyid}" -gt 16 ]; then
        short_keyid="${keyid: -16}"
    else
        short_keyid="$keyid"
    fi

    printf '%s\n' "$ALLOWED_GPG_KEY_IDS" | grep -iFxq "$short_keyid"
}

require_new_commits_signed_by_known_asc_keys() {
    local range="$1"
    local commits
    local commit
    local keyid
    local bad=0

    load_allowed_gpg_key_ids

    commits="$(git rev-list "$range")"

    if [ -z "$commits" ]; then
        info "no new commits to verify"
        return 0
    fi

    info "verifying signatures for commits in $range"

    while IFS= read -r commit; do
        [ -n "$commit" ] || continue

        keyid="$(commit_signature_key_id "$commit" || true)"

        if [ -z "$keyid" ]; then
            echo
            echo "unsigned commit:"
            echo "$commit"
            git log -1 --show-signature --format=fuller "$commit" || true
            bad=1
            continue
        fi

        if key_id_is_allowed "$keyid"; then
            echo "ok: $commit signed by known key $keyid"
        else
            echo
            echo "commit signed by unknown key:"
            echo "$commit"
            echo "key: $keyid"
            git log -1 --show-signature --format=fuller "$commit" || true
            bad=1
        fi
    done <<<"$commits"

    if [ "$bad" != "0" ]; then
        die "refusing to push: one or more new commits are unsigned or not signed by keys in $KEYS_DIR/*.asc"
    fi
}

info "checking repository"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "not inside a Git repository"

require_clean_worktree

ORIGINAL_BRANCH="$(current_branch)"

info "fetching $REMOTE"
git fetch --prune "$REMOTE"

require_branch_exists "$REMOTE/$DEV_BRANCH"
require_branch_exists "$REMOTE/$MASTER_BRANCH"

info "checking out $MASTER_BRANCH"
if git show-ref --verify --quiet "refs/heads/$MASTER_BRANCH"; then
    git checkout "$MASTER_BRANCH"
else
    git checkout -b "$MASTER_BRANCH" "$REMOTE/$MASTER_BRANCH"
fi

info "updating local $MASTER_BRANCH from $REMOTE/$MASTER_BRANCH"
git merge --ff-only "$REMOTE/$MASTER_BRANCH"

info "verifying $MASTER_BRANCH does not contain commits missing from $DEV_BRANCH"

MISSING_FROM_DEV="$(git rev-list "$REMOTE/$DEV_BRANCH..HEAD")"

if [ -n "$MISSING_FROM_DEV" ]; then
    echo
    echo "The current $MASTER_BRANCH contains commits that are not in $DEV_BRANCH:"
    echo "$MISSING_FROM_DEV"
    echo
    die "merge $MASTER_BRANCH back into $DEV_BRANCH first, then retry"
fi

info "merging $REMOTE/$DEV_BRANCH into $MASTER_BRANCH"

git merge --ff-only "$REMOTE/$DEV_BRANCH"

info "verifying resulting $MASTER_BRANCH contains $REMOTE/$DEV_BRANCH"

if ! git merge-base --is-ancestor "$REMOTE/$DEV_BRANCH" HEAD; then
    die "post-merge check failed: $MASTER_BRANCH does not contain $REMOTE/$DEV_BRANCH"
fi

if [ "$DO_PUSH" = "1" ]; then
    require_new_commits_signed_by_known_asc_keys "$REMOTE/$MASTER_BRANCH..HEAD"

    info "pushing $MASTER_BRANCH to $REMOTE"
    git push "$REMOTE" "HEAD:$MASTER_BRANCH"
    info "done; pushed $MASTER_BRANCH to $REMOTE"
else
    echo
    info "merge complete, not pushed"
    echo "Review the result, then push with:"
    echo
    echo "  $0 --push"
    echo
    echo "or manually:"
    echo
    echo "  git push $REMOTE HEAD:$MASTER_BRANCH"
fi

if [ -n "$ORIGINAL_BRANCH" ] && [ "$ORIGINAL_BRANCH" != "$MASTER_BRANCH" ]; then
    echo
    echo "You started on branch: $ORIGINAL_BRANCH"
    echo "You are now on branch: $MASTER_BRANCH"
fi
