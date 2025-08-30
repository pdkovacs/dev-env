#!/bin/bash

cd ${HOME}/github/pdkovacs/dev-env

cp ~/.bashrc ./dotfiles
cp ~/.profile ./dotfiles/
brew leaves > ./programs/brew-packages/packages.txt
cp ~/.config/Code/User/*.json ./config/Code/User
