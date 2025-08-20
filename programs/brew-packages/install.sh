cat /home/pkovacs/github/pdkovacs/dev-env/programs/brew-packages | while read pack; do echo $pack; brew install $pack; done
