cd ${HOME}/github/pdkovacs/dev-env

cp ~/.config/tmux-sessionizer/tmux-sessionizer.conf ./dotfiles
cp ~/.tmux.conf ./dotfiles
cp ~/.bashrc ./dotfiles
cp ~/.profile dotfiles/

brew ls >>programs/brew-packages
