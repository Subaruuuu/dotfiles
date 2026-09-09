#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

BACKUP_SUFFIX=".dotfiles-backup"

# $1 = 來源（repo 內），$2 = 目的地（家目錄）
link_file() {
	local src="$1" dst="$2"

	# 已經指向同一個檔案就什麼都不做
	if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
		log_skip "$dst 已連結"
		return
	fi

	# 既有的實體檔案先備份，不直接砍掉
	if [[ -e "$dst" || -L "$dst" ]]; then
		echo "  backup: $dst -> $dst$BACKUP_SUFFIX"
		mv -f "$dst" "$dst$BACKUP_SUFFIX"
	fi

	mkdir -p "$(dirname "$dst")"
	ln -s "$src" "$dst"
	echo "  linked: $dst -> $src"
}

# links/.foo.symlink  ->  ~/.foo
link_home_files() {
	local src dst
	while IFS= read -r src; do
		dst="$HOME/$(basename "${src%.symlink}")"
		link_file "$src" "$dst"
	done < <(find "$DOTFILES/links" -maxdepth 1 -name '*.symlink')
}

# config/git/ignore  ->  ~/.config/git/ignore
link_config_files() {
	local src rel dst
	while IFS= read -r src; do
		rel="${src#"$DOTFILES/config/"}"
		dst="$HOME/.config/$rel"
		link_file "$src" "$dst"
	done < <(find "$DOTFILES/config" -type f -not -name '.DS_Store')
}

# 編輯器的設定檔路徑各自不同，用一張表列出來
# 格式：<repo 內的相對路徑>|<家目錄底下的絕對路徑>
EDITOR_SETTINGS=(
	"vscode/profiles/node/settings.json|$HOME/Library/Application Support/Code/User/settings.json"
	"antigravity/settings.json|$HOME/Library/Application Support/Antigravity IDE/User/settings.json"
	"zed/settings.json|$HOME/.config/zed/settings.json"
)

# 這些目錄要等 app 第一次啟動才會建，先建起來讓 app 啟動時就讀得到設定
link_editor_settings() {
	local entry src dst
	for entry in "${EDITOR_SETTINGS[@]}"; do
		src="$DOTFILES/${entry%%|*}"
		dst="${entry#*|}"

		if [[ ! -f "$src" ]]; then
			log_skip "找不到 $src"
			continue
		fi

		link_file "$src" "$dst"
	done
}

log_start "symlink"
link_home_files
link_config_files
link_editor_settings
log_end "symlink"
