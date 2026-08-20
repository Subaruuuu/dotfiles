#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

# Antigravity 的 CLI 是 app 裝好後才會出現，install.sh 跑在 bash 底下讀不到 .zshrc 的 PATH
export PATH="$HOME/.antigravity-ide/antigravity-ide/bin:$PATH"

# 只認得 publisher.name 這種格式的行，其餘（CLI 自己印的警告）丟掉
EXT_ID_RE='^[A-Za-z0-9][A-Za-z0-9_-]*\.[A-Za-z0-9]'

# settings.json 由 scripts/symlink.sh 連過去，這裡只負責裝擴充套件
install_extensions() {
	local cli="$1" list="$2" label="$3"

	if ! has "$cli"; then
		log_skip "找不到 ${cli}, 略過 ${label} 擴充套件"
		return
	fi
	if [[ ! -f "$list" ]]; then
		log_skip "找不到 $list"
		return
	fi

	log_start "$label 擴充套件"

	local installed
	installed="$("$cli" --list-extensions 2>/dev/null | grep -E "$EXT_ID_RE" | tr '[:upper:]' '[:lower:]' || true)"

	while IFS= read -r ext; do
		[[ -z "$ext" || "$ext" == \#* ]] && continue

		if grep -qxF "$(echo "$ext" | tr '[:upper:]' '[:lower:]')" <<<"$installed"; then
			log_skip "$ext"
		else
			"$cli" --install-extension "$ext" --force
		fi
	done < "$list"

	log_end "$label 擴充套件"
}

# VS Code 的擴充已經寫在 Brewfile 的 vscode "..." 裡，由 brew bundle 處理
install_extensions "agy-ide" "$DOTFILES/antigravity/extensions.txt" "Antigravity IDE"
