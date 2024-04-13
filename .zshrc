export CLICOLOR=1
export GIT_EDITOR=nvim
export LS_COLORS='di=1:fi=0:ln=31:pi=5:so=5:bd=5:cd=5:or=31:mi=0:ex=35:*.rpm=90'
export PYENV_BASE_PATH=/Users/"$USER"/.pyenv

autoload -Uz compinit && compinit
setopt nonomatch

# custom aliases
alias h=history
alias pd=pushd
alias pop=popd
alias d=dirs
alias vi=nvim
alias v=view

function activate() {
    source "$PYENV_BASE_PATH"/"$1"/bin/activate
}

function create-env() {
    python"$1" -m venv "$PYENV_BASE_PATH/$2"
    printf "%b" "Created virtual environment in $PYENV_BASE_PATH/$2\n"
}

# prompt
PS1='%F{red}%n%f%F{green} '$'\Uf8ff'' %*%F%F{yellow} %3~ %F{15}%% '

