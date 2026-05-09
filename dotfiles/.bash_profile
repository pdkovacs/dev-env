# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# User specific environment and startup programs
export PATH=$PATH:${HOME}/bin:/usr/local/go/bin:${HOME}/Programs/nvim-linux64/bin
export PATH=/home/linuxbrew/.linuxbrew/bin:$PATH

export AWS_BASH_COMPLETER=/snap/aws-cli/current/bin/aws_completer
export PATH="$PATH:$AWS_BASH_COMPLETER"
