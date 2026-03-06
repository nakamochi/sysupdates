#!/bin/sh
set -u

exit_code=0

# shellcheck disable=SC2329
add_user_to_group() {
    user="$1"
    group="$2"

    if ! getent passwd "$user" >/dev/null 2>&1; then
        echo "User not found: $user" >&2
        return 1
    fi

    if ! getent group "$group" >/dev/null 2>&1; then
        echo "Group not found: $group" >&2
        return 1
    fi

    if ! id -nG "$user" | tr ' ' '\n' | grep -Fxq "$group"; then
        usermod -a -G "$group" "$user"
    fi
}

run() {
    "$@" || exit_code=$?
}

run add_user_to_group lnd tor
run add_user_to_group uiuser input
run add_user_to_group uiuser video

exit "$exit_code"
