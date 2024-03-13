export CLICOLOR=1i
export LS_COLORS='di=1:fi=0:ln=31:pi=5:so=5:bd=5:cd=5:or=31:mi=0:ex=35:*.rpm=90'
export KUBECONFIG=~/.kube/incuvers-config
export LD_LIBRARY_PATH=/Applications/ti/ccs1120/ccs/ccs_base/emulation/drivers:/Applications/ti/ccs1120/ccs/ccs_base/emulation/analysis/bin
# export DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH":/Applications/ti/ccs1120/ccs/ccs_base/emulation/drivers:/Applications/ti/ccs1120/ccs/ccs_base/emulation/analysis/bin
export PYENV_BASE_PATH=/Users/"$USER"/.pyenv
PS1='%F{red}%n%f%F{green} '$'\Uf8ff'' %*%F%F{yellow} %3~ %F{15}%% '
autoload -Uz compinit && compinit
setopt nonomatch
# custom aliases
alias python=python3
alias acli=/usr/local/bin/arduino-cli
alias h=history
alias pd=pushd
alias pop=popd
alias d=dirs
alias vi=nvim
alias v=view
alias gp="git push upstream; git push"

function activate() {
    source "$PYENV_BASE_PATH"/"$1"/bin/activate
}

function create-env() {
    python3.9 -m venv "$PYENV_BASE_PATH/$1"
    printf "%b" "Created virtual environment in $PYENV_BASE_PATH/$1\n"
}

function eagle() {
   cd /Applications/EAGLE-9.6.2/eagle.app/Contents/MacOS
   ./eagle &
}
export PATH="/usr/local/opt/python@3.8/bin:/Applications/ARM/bin:$PATH"
export PATH="/usr/local/sbin:$PATH"



export STM32CubeMX_PATH=/Applications/STMicroelectronics/STM32CubeMX.app/Contents/Resources
