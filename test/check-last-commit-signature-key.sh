#!/bin/sh
# check that last git commit is signed and signer's key is present in keys directory

cd "$(dirname "$0")" || exit 1

last_commit_key_id="$(git log --no-merges --show-signature | grep -E "using [A-Za-z0-9]+ key" | head -n 1 | tail -c 17)"

if [ -z "$last_commit_key_id" ]; then
    echo "Last commit is not signed"
    exit 1
fi

for keyfile in ../keys/*.asc; do
    keyid="$(gpg --with-colons "$keyfile" 2>/dev/null | grep '^pub' | cut -d: -f5)"
    if [ "$keyid" = "$last_commit_key_id" ]; then
        echo "Last commit is signed with a known key: $last_commit_key_id"
        exit 0
    fi
done

echo "Last commit is signed with an unknown key: $last_commit_key_id"
exit 1
