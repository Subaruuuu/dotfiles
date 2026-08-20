# 共用函式，由其他 script source

DOTFILES="${DOTFILES:-$HOME/dotfiles}"

log_start() { echo ""; echo "------------ Init $1 ------------"; }
log_end()   { echo "------------ Done $1 ------------"; }
log_skip()  { echo "  skip: $1"; }

has() { command -v "$1" >/dev/null 2>&1; }
