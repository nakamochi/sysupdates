#!/bin/sh

current_keys="$(gpg --list-keys --with-colons | grep '^pub' | cut -d: -f5)"
last_commit_key_id="$(git log --show-signature | grep "Primary key fingerprint" | head -n 1 | tail -c 20 | tr -d ' ')"

new_keylist="$(mktemp)"
for keyfile in keys/*.asc; do gpg --with-colons "$keyfile" 2>/dev/null | grep '^pub' | cut -d: -f5; done > "$new_keylist"
# Remove keys that are no longer present.
# But, as a safeguard, never allow removal of key that signed last commit.
for key in $current_keys; do
    if ! grep -qs "$key" "$new_keylist" && [ "$key" != "$last_commit_key_id" ]; then
        echo "Removing key $key..."
        gpg --batch --yes --delete-keys "$key"
    fi
done
rm "$new_keylist"

# Import new keys
current_keylist="$(mktemp)"
echo "$current_keys" > "$current_keylist"
for keyfile in keys/*.asc; do
    keyid="$(gpg --with-colons "$keyfile" 2>/dev/null | grep '^pub' | cut -d: -f5)"
    if ! grep -qs "$keyid" "$current_keylist"; then
        echo "Importing key $keyid from $keyfile..."
        gpg --import "$keyfile"
        printf "trust\n5\ny\n" | gpg --batch --no-tty --command-fd 0 --expert --edit-key "$keyid"
    fi
done
rm "$current_keylist"
