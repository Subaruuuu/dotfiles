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

# VS Code 開著的時候，profile 的 settings.json 可能被記憶體裡那份蓋回去。
# 不接 `| grep -q`：pipefail 下 grep 提早結束會讓 ps 收到 SIGPIPE，整條 pipeline 回非 0。
vscode_is_running() {
	local procs
	procs="$(ps -Ao comm=)"
	[[ "$procs" == *"/Visual Studio Code.app/Contents/MacOS/Code"* ]]
}

# Brewfile 的 vscode "..." 只認得 Default profile（brew bundle 的實作固定跑
# `code --list-extensions` / `--install-extension`，沒有 --profile；在 Brewfile 寫
# `vscode "x", profile: "Go"` 會直接被判 unknown options）。
# 其他 profile 的擴充和 settings.json 只能自己來。
restore_vscode_profiles() {
	if ! has code; then
		log_skip "找不到 code, 略過 VS Code profiles"
		return
	fi

	log_start "VS Code profiles"

	local entry name dir export_name profile_file installed ext pdir
	for entry in "${VSCODE_PROFILES[@]}"; do
		IFS='|' read -r name dir export_name <<<"$entry"
		profile_file="$DOTFILES/vscode/profiles/$dir/$export_name.code-profile"

		if [[ ! -f "$profile_file" ]]; then
			log_skip "找不到 $profile_file"
			continue
		fi

		# 這個 profile 不存在的話，code --profile 會順手建一個空的
		installed="$(code_in_profile "$name" --list-extensions 2>/dev/null \
			| grep -E "$EXT_ID_RE" | tr '[:upper:]' '[:lower:]' || true)"

		while IFS= read -r ext; do
			[[ -z "$ext" ]] && continue

			if grep -qxF "$(echo "$ext" | tr '[:upper:]' '[:lower:]')" <<<"$installed"; then
				log_skip "$name / $ext"
			else
				code_in_profile "$name" --install-extension "$ext" --force
			fi
		done < <(python3 "$VSCODE_PROFILE_LIB" extensions "$profile_file")

		# Default 的 settings.json 由 scripts/symlink.sh 連過去，這裡不碰
		[[ "$name" == "Default" ]] && continue

		if vscode_is_running; then
			echo "  !! VS Code 正在執行，略過 ${name} 的 settings.json" >&2
			echo "  !! 請結束 VS Code 再跑：./install.sh editors" >&2
			continue
		fi

		# profile 目錄的 id 是每台機器隨機產的，裝完擴充之後才查得到
		pdir="$(python3 "$VSCODE_PROFILE_LIB" resolve "$name" 2>/dev/null || true)"
		if [[ -z "$pdir" ]]; then
			log_skip "查不到 ${name} 的 profile 目錄，settings.json 沒還原"
			continue
		fi

		cp "$DOTFILES/vscode/profiles/$dir/settings.json" "$pdir/settings.json"
		echo "  ${name}: settings.json -> $pdir"
	done

	log_end "VS Code profiles"
}

# VS Code Default profile 的擴充寫在 Brewfile 的 vscode "..." 裡，由 brew bundle 處理
install_extensions "agy-ide" "$DOTFILES/antigravity/extensions.txt" "Antigravity IDE"
restore_vscode_profiles
