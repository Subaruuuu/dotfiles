#!/usr/bin/env bash
#
# 把本機現在的設定倒回這個 repo。
# 編輯器的 settings.json 是 symlink，本來就同步，不在這裡處理。
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

dump_brewfile() {
	log_start "Brewfile"

	local tmp="$DOTFILES/.Brewfile.tmp"
	brew bundle dump --file="$tmp" --force

	{
		echo '# Brewfile — 由 scripts/dump.sh 產生，用 `brew bundle --file=Brewfile` 還原'
		echo '#'
		echo '# npm 全域套件刻意不寫在這裡（node 由 nvm 管理，見 scripts/node.sh）'
		echo
		# node 由 nvm 管，brew bundle 裝 npm 套件會裝到錯的 node 上
		grep -v '^npm "' "$tmp"
	} > "$DOTFILES/Brewfile"

	rm -f "$tmp"
	echo "  brew $(grep -c '^brew ' "$DOTFILES/Brewfile") / cask $(grep -c '^cask ' "$DOTFILES/Brewfile") / vscode $(grep -c '^vscode ' "$DOTFILES/Brewfile")"
	log_end "Brewfile"
}

dump_iterm2() {
	log_start "iTerm2"

	# 讀 live domain 而不是硬碟上的 plist：iTerm2 開著的時候硬碟那份可能是舊的
	local tmp="$DOTFILES/.iterm2.tmp.plist"
	defaults export com.googlecode.iterm2 "$tmp"
	python3 "$DOTFILES/scripts/lib/iterm2_export.py" "$tmp" "$DOTFILES/iterm2/com.googlecode.iterm2.plist"
	rm -f "$tmp"

	log_end "iTerm2"
}

dump_vscode_profiles() {
	log_start "VS Code profiles"

	local entry name dir export_name
	for entry in "${VSCODE_PROFILES[@]}"; do
		IFS='|' read -r name dir export_name <<<"$entry"

		if ! python3 "$VSCODE_PROFILE_LIB" resolve "$name" >/dev/null 2>&1; then
			log_skip "本機沒有 ${name} profile"
			continue
		fi

		python3 "$VSCODE_PROFILE_LIB" dump "$name" "$export_name" \
			"$DOTFILES/vscode/profiles/$dir"
	done

	log_end "VS Code profiles"
}

dump_antigravity_extensions() {
	export PATH="$HOME/.antigravity-ide/antigravity-ide/bin:$PATH"

	if ! has agy-ide; then
		log_skip "找不到 agy-ide"
		return
	fi

	log_start "Antigravity 擴充清單"
	agy-ide --list-extensions 2>/dev/null \
		| grep -E '^[A-Za-z0-9][A-Za-z0-9_-]*\.[A-Za-z0-9]' \
		| sort -u > "$DOTFILES/antigravity/extensions.txt"
	echo "  $(wc -l < "$DOTFILES/antigravity/extensions.txt" | tr -d ' ') 個擴充套件"
	log_end "Antigravity 擴充清單"
}

dump_brewfile
dump_iterm2
dump_vscode_profiles
dump_antigravity_extensions

echo ""
echo "跑完了，用 git diff 看有哪些變動。"
