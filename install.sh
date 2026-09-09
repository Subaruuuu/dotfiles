#!/usr/bin/env bash
#
# 新 macOS 一鍵還原開發環境
#
#   mkdir -p ~/dotfiles
#   curl -fsSL https://github.com/Subaruuuu/dotfiles/archive/refs/heads/master.tar.gz \
#     | tar -xz --strip-components=1 -C ~/dotfiles
#   ~/dotfiles/install.sh
#
set -euo pipefail

export DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES/scripts/_lib.sh"

STEPS=(brew zsh symlink node nvim editors iterm2)

main() {
	echo "dotfiles: $DOTFILES"

	# 有給參數就只跑指定的步驟，例如 ./install.sh symlink
	local steps=("${STEPS[@]}")
	[[ $# -gt 0 ]] && steps=("$@")

	for step in "${steps[@]}"; do
		local script="$DOTFILES/scripts/$step.sh"

		if [[ ! -f "$script" ]]; then
			echo "未知的步驟: ${step} (可用: ${STEPS[*]})" >&2
			exit 1
		fi

		bash "$script"
	done

	echo ""
	echo "全部完成，開一個新的 terminal 讓設定生效。"
	echo "記得補上 git 身分："
	echo "  git config --global user.name  \"Your Name\""
	echo "  git config --global user.email \"you@example.com\""
}

main "$@"
