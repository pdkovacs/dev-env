#!/bin/bash

cd ${HOME}/github/pdkovacs/dev-env

grep -Ev '^[^#].*# skip backing this up' ~/.bashrc > ./dotfiles/.bashrc
cp ~/.profile ./dotfiles/
cp ~/.bash_profile ./dotfiles/
cp ~/bin/*.sh ./bin-dir/
brew leaves > ./programs/brew-packages/packages.txt

cp ~/.config/Code/User/*.json ./config/Code/User
code --list-extensions > config/Code/extensions/list.txt
