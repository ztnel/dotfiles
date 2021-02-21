export CLICOLOR=1i
export LS_COLORS='di=1:fi=0:ln=31:pi=5:so=5:bd=5:cd=5:or=31:mi=0:ex=35:*.rpm=90'
export KUBECONFIG=~/.kube/incuvers-config
PS1="%F{27}%n%f@%F{green}  %*%F%F{yellow} %3~ %F{15}%% "
autoload -Uz compinit && compinit
setopt nonomatch
export PATH=$PATH:/usr/local/Cellar/python@3.8/3.8.6/Frameworks/Python.framework/Versions/3.8/bin
# custom aliases
alias python=python3
alias code=/usr/local/bin/code-insiders
alias acli=/usr/local/bin/arduino-cli
alias h=history
alias pd=pushd
alias pop=popd
alias d=dirs
alias v=view
alias gp="git push upstream; git push"

function eagle() {
   cd /Applications/EAGLE-9.6.2/eagle.app/Contents/MacOS
   ./eagle &
}
