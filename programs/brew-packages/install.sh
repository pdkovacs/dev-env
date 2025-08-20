cat /home/pkovacs/github/pdkovacs/dev-env/programs/brew-packages/packages.txt | while read pack; do echo $pack; brew install $pack; done
