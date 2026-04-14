# shellcheck shell=sh

write_if_changed() {
    src="$1"
    dst="$2"
    mode="$3"

    chmod "$mode" "$src" || {
        rm -f "$src"
        return 1
    }

    if test -f "$dst" && cmp -s "$dst" "$src"; then
        rm -f "$src"
        return 0
    fi

    mv "$src" "$dst" || {
        rm -f "$src"
        return 1
    }

    return 0
}
