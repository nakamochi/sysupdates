#!/bin/sh

set -eu

BOOT_FILES_SOURCE="img/rootfiles/boot"
BOOT_FILES_TARGET="/boot"

if [ -f $BOOT_FILES_SOURCE/cmdline.txt ] && [ -f $BOOT_FILES_SOURCE/config.txt ]; then
    # cp overwrites in-place; if the write is interrupted you may leave
    # /boot/config.txt empty and render the device unbootable. Use an atomic
    # move.
    # Also diff first to not do extra wear with unnecessary writes to uSD card.
    for fn in cmdline.txt config.txt; do
        if ! diff "${BOOT_FILES_SOURCE}/${fn}" "${BOOT_FILES_TARGET}/${fn}"; then
            echo "Updating ${BOOT_FILES_TARGET}/${fn}"
            cp "${BOOT_FILES_SOURCE}/${fn}" "${BOOT_FILES_TARGET}/${fn}.new"
            mv "${BOOT_FILES_TARGET}/${fn}.new" "${BOOT_FILES_TARGET}/${fn}"
        fi
    done
fi
