#!/bin/bash

# Dotfiles and VS Code settings are symlinked into place by link.sh, so only
# generated lists and ~/bin scripts need copying here.

cd ${HOME}/github/pdkovacs/dev-env

test -f ~/bin/*.sh && cp ~/bin/*.sh ./bin-dir/
brew leaves > ./programs/brew-packages/packages.txt

code --list-extensions > config/Code/extensions/list.txt
