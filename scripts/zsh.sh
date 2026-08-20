#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM="$ZSH_DIR/custom"

# macOS 從 Catalina 起預設就是 zsh，這裡只處理仍停在 bash 的情況
set_default_shell_to_zsh() {
	if [[ "$SHELL" == */zsh ]]; then
		log_skip "預設 shell 已是 zsh"
		return
	fi

	log_start "設定預設 shell 為 zsh"
	chsh -s "$(command -v zsh)"
	log_end "設定預設 shell 為 zsh"
}

install_oh_my_zsh() {
	if [[ -d "$ZSH_DIR" ]]; then
		log_skip "oh-my-zsh 已安裝"
		return
	fi

	log_start "oh-my-zsh"
	# --unattended：不要自動 chsh、也不要直接開一個新 shell 卡住後續步驟
	RUNZSH=no KEEP_ZSHRC=yes sh -c \
		"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
	log_end "oh-my-zsh"
}

# .zshrc 內 plugins=(...) 用到的兩個外掛不在 oh-my-zsh 內建清單裡
install_zsh_plugins() {
	log_start "zsh plugins"

	local repos=(
		"https://github.com/zsh-users/zsh-autosuggestions:zsh-autosuggestions"
		"https://github.com/zsh-users/zsh-syntax-highlighting:zsh-syntax-highlighting"
	)

	for entry in "${repos[@]}"; do
		local url="${entry%:*}" name="${entry##*:}"
		local dst="$ZSH_CUSTOM/plugins/$name"

		if [[ -d "$dst" ]]; then
			log_skip "$name 已安裝"
		else
			git clone --depth=1 "$url" "$dst"
		fi
	done

	log_end "zsh plugins"
}

set_default_shell_to_zsh
install_oh_my_zsh
install_zsh_plugins
