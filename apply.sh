#!/bin/sh
# the script executes updates to a nakamochi system.
# it must be run as root or a user with equivalent privileges.

exit_code=0

# base os
./base/voidlinux.sh || exit 1

# bitcoin core
. ./btc/env
bitcoin_apply || exit_code=$?

# lnd lightning
. ./lnd/env
lnd_apply || exit_code=$?

# TODO: electrs
# TODO: nd and ngui

exit $exit_code
