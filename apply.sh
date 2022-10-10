#!/bin/sh
# the script executes updates to a nakamochi system.
# it must be run as root or a user with equivalent privileges.

exit_code=0

# base os
./base/void-pkg.sh || exit 1

# lnd lightning
. ./lnd/env
lnd_apply || exit_code=$?

# TODO: bitcoind
# TODO: electrs
# TODO: nd and ngui

exit $exit_code
