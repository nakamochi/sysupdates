#!/bin/sh
# the script executes updates to a nakamochi system.
# it must be run as root or a user with equivalent privileges.

# at script exit, report system/user CPU times it took to run
# the whole update while preserving exit code.
trap times EXIT
# abort if an expansion encounteres an unset variable.
set -u

exit_code=0
# defined in the caller script
rootdir="$SYSUPDATES_ROOTDIR"

# base os
printf "######## base os\n" 1>&2
cd "$rootdir"
./base/voidlinux.sh || exit 1
printf "######## tor\n" 1>&2
cd "$rootdir"
./base/tor.sh || exit_code=$?

# nakamochi daemon and gui (ndg)
printf "######## ndg\n" 1>&2
cd "$rootdir"
. ./ndg/env
ndg_apply || exit_code=$?

# bitcoin core
printf "######## bitcoind\n" 1>&2
cd "$rootdir"
. ./btc/env
bitcoin_apply || exit_code=$?

# lnd lightning
printf "######## lnd\n" 1>&2
cd "$rootdir"
. ./lnd/env
lnd_apply || exit_code=$?

# TODO: electrs

exit $exit_code
