# 共用函式，由其他 script source

DOTFILES="${DOTFILES:-$HOME/dotfiles}"

log_start() { echo ""; echo "------------ Init $1 ------------"; }
log_end()   { echo "------------ Done $1 ------------"; }
log_skip()  { echo "  skip: $1"; }

has() { command -v "$1" >/dev/null 2>&1; }

# VS Code profile 對應表：<VS Code 裡的 profile 名>|<repo 資料夾>|<.code-profile 的名字>
# VS Code 裡的 Default profile，在這個 repo 裡叫 node
VSCODE_PROFILES=(
	"Default|node|node"
	"Go|go|Go"
	"python|python|python"
)

VSCODE_PROFILE_LIB="$DOTFILES/scripts/lib/vscode_profile.py"

# Default 不能加 --profile：加了會被當成另一個叫 Default 的新 profile
code_in_profile() {
	local name="$1"; shift
	if [[ "$name" == "Default" ]]; then
		code "$@"
	else
		code --profile "$name" "$@"
	fi
}
