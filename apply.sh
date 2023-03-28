#!/bin/sh
# the script executes updates to a nakamochi system.
# it must be run as root or a user with equivalent privileges.

exit_code=0
# defined in the caller script
rootdir="$SYSUPDATES_ROOTDIR"

# base os
cd "$rootdir"
./base/voidlinux.sh || exit 1
cd "$rootdir"
./base/tor.sh || exit_code=$?

# nakamochi daemon and gui (ndg)
cd "$rootdir"
. ./ndg/env
ndg_apply || exit_code=$?

# bitcoin core
cd "$rootdir"
. ./btc/env
bitcoin_apply || exit_code=$?

# lnd lightning
cd "$rootdir"
. ./lnd/env
lnd_apply || exit_code=$?

# TODO: electrs

exit $exit_code
