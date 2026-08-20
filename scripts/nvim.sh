#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

# neovim 設定放在獨立 repo，這裡只負責 clone 回來
NVIM_REPO="https://github.com/Subaruuuu/nvim-config.git"
NVIM_DIR="$HOME/.config/nvim"

if [[ -d "$NVIM_DIR" ]]; then
	log_skip "$NVIM_DIR 已存在"
	exit 0
fi

log_start "nvim config"
git clone "$NVIM_REPO" "$NVIM_DIR"
log_end "nvim config"
