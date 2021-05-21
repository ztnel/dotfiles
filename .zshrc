export CLICOLOR=1i
export LS_COLORS='di=1:fi=0:ln=31:pi=5:so=5:bd=5:cd=5:or=31:mi=0:ex=35:*.rpm=90'
export KUBECONFIG=~/.kube/incuvers-config
autoload -Uz compinit && compinit
setopt nonomatch
export PATH=$PATH:/opt/homebrew/opt/python@3.8/bin/python3
export PYENV_BASE_PATH=/Users/"$USER"/.pyenv
# custom aliases
alias python3.8=/opt/homebrew/opt/python@3.8/bin/python3
alias python=python3
alias code=/usr/local/bin/code-insiders
alias acli=/opt/homebrew/bin/arduino-cli
alias h=history
alias pd=pushd
alias pop=popd
alias d=dirs
alias v=view
alias gp="git push upstream; git push"
alias weather="curl -4 http://wttr.in"

function activate() {
    source "$PYENV_BASE_PATH"/"$1"/bin/activate
}

function create-env() {
    python -m venv "$PYENV_BASE_PATH/$1"
    printf "%b" "Created virtual environment in $PYENV_BASE_PATH/$1\n"
}

function eagle() {
   cd /Applications/EAGLE-9.6.2/eagle.app/Contents/MacOS
   ./eagle &
}

function mcdir {
    mkdir -p -- "$1" && cd -P -- "$1"
}

# Parse git branch name for display in terminal prompt string
function parse_git_branch {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

PS1="%F{red}%n%f%F{green}  %F{blue}%*%F%F{yellow} %3~ %F{15}> "
