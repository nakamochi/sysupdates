#!/bin/sh
# https://github.com/nakamochi/sysupdates
# pull changes from a remote git repo and run the "apply" script.
# commits are expected to be signed by gpg keys with a sufficient
# trust level to satisfy git pull --verify-signatures.
# the script is expected to be run as root, to allow making changes to the
# operating system.
# in the future, the plan is to provide an on-screen git diff and apply updates
# after user confirmation.

# git branch to pull from. defaults to master.
# another value is "dev", for a development aka unstable version.
BRANCH="${1:-master}"
REMOTE_URL="${2:-https://github.com/nakamochi/sysupdates.git}"
# output everything to a temp file and print its contents only in case of an error,
# so that when run via a cronjob, the output is empty on success which prevents
# needless emails, were any configured.
LOGFILE="${LOGFILE:-/var/log/sysupdate.log}"
# a local git repo dir where to pull the updates into.
REPODIR="${REPODIR:-/ssd/sysupdates}"

# multiple running instances of the script would certainly result in race conditions.
# so, we serialize runs using a lock file, timing out with an error after 15min.
if [ -z "$NAKAMOCHI_SYSUPDATE_LOCK" ]; then
    # use the script itself as the lock file
    lockfile=$0
    exec env NAKAMOCHI_SYSUPDATE_LOCK=1 \
      flock --exclusive --timeout 900 "$lockfile" "$0" "$@"
fi

# start of the sysupdate; trim prevously logged runs
date > "$LOGFILE"

# fetch updates from remote
cd "$REPODIR" || exit 1
if ! {
    echo "Fetching updates from $REMOTE_URL, branch $BRANCH" &&
    git remote set-url origin "$REMOTE_URL" &&
    git fetch origin &&          # in case the refspec is unknown locally yet
    git reset --hard HEAD &&     # remove local changes
    git clean -fd &&             # force-delete untracked files
    git checkout "$BRANCH" &&
    git pull --rebase --verify-signatures &&
    git submodule sync --recursive &&
    git submodule update --init --recursive
} >> "$LOGFILE" 2>&1 ; then
    echo "ERROR: repository update failed"
    cat "$LOGFILE"
    exit 1
fi

# run repo's update script
export SYSUPDATES_ROOTDIR="$REPODIR"
export SYSUPDATES_CHANNEL="$BRANCH"
if ! ./apply.sh >> "$LOGFILE" 2>&1; then
    echo "ERROR: apply failed"
    cat "$LOGFILE"
    exit 1
else
    # read commit from $REPODIR even if apply.sh changed CWD; write atomically and log failures
    if hash="$(git -C "$REPODIR" rev-parse --short=12 HEAD 2>>"$LOGFILE")"; then
        tmp=/etc/sysupdates-applied.$$
        printf '%s\n' "$hash" > "$tmp" &&
        chmod 0644 "$tmp" &&
        mv -f "$tmp" /etc/sysupdates-applied
    else
        echo "ERROR: unable to determine current git commit" >> "$LOGFILE"
        cat "$LOGFILE"
        exit 1
    fi
fi
