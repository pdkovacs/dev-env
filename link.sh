#!/bin/bash

# Symlink the dotfiles and VS Code settings kept in this repo into $HOME.
#
# Usage: link.sh [-n] [-f]
#   -n  dry run: only print what would be done
#   -f  also replace files whose content differs from the repo version
#       (they are backed up first)
#
# An existing file is backed up as <file>.bak.<timestamp> before being replaced.
# Without -f, a file that differs from the repo version is left alone and the
# diff is shown, so nothing is lost (e.g. lines that belong in ~/.bashrc.local).

REPO_DIR=$(cd "$(dirname "$0")" && pwd)

dry_run=
force=
while getopts "nf" opt; do
	case $opt in
	n) dry_run=1 ;;
	f) force=1 ;;
	*) echo "Usage: $0 [-n] [-f]" >&2; exit 1 ;;
	esac
done

run() {
	echo "  $*"
	[ -n "$dry_run" ] || "$@"
}

link() {
	local src="$REPO_DIR/$1"
	local dst="$2"

	if [ "$(readlink "$dst")" = "$src" ]; then
		echo "ok:      $dst"
		return
	fi

	if [ -e "$dst" ] || [ -L "$dst" ]; then
		if ! cmp -s "$src" "$dst" && [ -z "$force" ]; then
			echo "DIFFERS: $dst (skipped; reconcile it or use -f)"
			diff -u "$dst" "$src" | sed 's/^/    /'
			return
		fi
		echo "replace: $dst"
		run mv "$dst" "$dst.bak.$(date +%Y%m%d-%H%M%S)"
	else
		echo "create:  $dst"
		run mkdir -p "$(dirname "$dst")"
	fi
	run ln -s "$src" "$dst"
}

link dotfiles/.bashrc       ~/.bashrc
link dotfiles/.profile      ~/.profile
link dotfiles/.bash_profile ~/.bash_profile

for f in "$REPO_DIR"/config/Code/User/*.json; do
	link "config/Code/User/$(basename "$f")" ~/.config/Code/User/"$(basename "$f")"
done
