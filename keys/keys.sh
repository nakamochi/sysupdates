#!/usr/bin/env bash

current_keys="$(gpg --list-keys --with-colons | grep '^pub' | cut -d: -f5)"

new_keylist="$(mktemp)"
for keyfile in keys/*.asc; do gpg --with-colons "$keyfile" 2>/dev/null | grep '^pub' | cut -d: -f5; done > "$new_keylist"
# Remove keys that are no longer present
for key in $current_keys; do
    if ! grep -qs "$key" "$new_keylist"; then
        echo "Removing key $key..."
        gpg --batch --yes --delete-keys "$key"
    fi
done
rm "$new_keylist"

# Import new keys
for keyfile in keys/*.asc; do
    keyid="$(gpg --with-colons "$keyfile" 2>/dev/null | grep '^pub' | cut -d: -f5)"
    if ! grep -qs "$keyid" <<< "$current_keys"; then
        echo "Importing key $keyid from $keyfile..."
        gpg --import "$keyfile"
        echo -e "trust\n5\ny\n" | gpg --batch --no-tty --command-fd 0 --expert --edit-key "$keyid"
    fi
done
