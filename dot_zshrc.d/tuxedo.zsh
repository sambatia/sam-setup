# ~/.zshrc.d/tuxedo.zsh
# Tuxedo / todo.txt

export TODO_DIR="$HOME/Documents/todo"
export TODO_FILE="$TODO_DIR/todo.txt"
export DONE_FILE="$TODO_DIR/done.txt"

alias tx='tuxedo "$TODO_FILE"'
alias txw='tuxedo-workspaces "$TODO_FILE"'
alias todo-ui='tuxedo "$TODO_FILE"'
alias todo-file='$EDITOR "$TODO_FILE"'
