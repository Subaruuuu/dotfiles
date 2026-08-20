#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

# Command Line Tools（homebrew 的前置需求）
install_xcode_clt() {
	if xcode-select -p >/dev/null 2>&1; then
		log_skip "Xcode Command Line Tools 已安裝"
		return
	fi
	log_start "Xcode Command Line Tools"
	xcode-select --install
	echo "  請等安裝視窗跑完後再按 Enter 繼續..."
	read -r
	log_end "Xcode Command Line Tools"
}

install_homebrew() {
	if has brew; then
		log_skip "homebrew 已安裝"
		return
	fi

	log_start "homebrew"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	eval "$(/opt/homebrew/bin/brew shellenv)"
	log_end "homebrew"
}

# 依 Brewfile 還原 formula / cask / vscode 擴充
restore_brew_bundle() {
	log_start "brew bundle"
	brew bundle --file="$DOTFILES/Brewfile"
	log_end "brew bundle"
}

install_xcode_clt
install_homebrew
restore_brew_bundle
