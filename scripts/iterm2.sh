#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

PLIST="$DOTFILES/iterm2/com.googlecode.iterm2.plist"
DOMAIN="com.googlecode.iterm2"
BACKUP_DIR="$HOME/.dotfiles-backup"

if [[ ! -f "$PLIST" ]]; then
	log_skip "找不到 $PLIST"
	exit 0
fi

# pgrep 在這台看不到 iTerm2（不論 -x 或 -f 都 no match），改用 ps 比對執行檔路徑。
# 不接 `| grep -q`：pipefail 下 grep 提早結束會讓 ps 收到 SIGPIPE，整條 pipeline 回非 0。
iterm_is_running() {
	local procs
	procs="$(ps -Ao comm=)"
	[[ "$procs" == */iTerm.app/Contents/MacOS/iTerm2* ]]
}

# iTerm2 會在退出時把記憶體裡的設定整份寫回 preferences，
# 所以開著的時候匯入等於白做，晚點還會被蓋回去
if iterm_is_running; then
	echo "" >&2
	echo "  !! iTerm2 正在執行，略過偏好設定匯入。" >&2
	echo "  !! 它退出時會把記憶體裡的設定寫回去，現在匯入會被蓋掉。" >&2
	echo "  !! 請完全結束 iTerm2，再從 Terminal.app 跑：./install.sh iterm2" >&2
	echo "" >&2
	exit 0
fi

log_start "iTerm2 偏好設定"

if defaults read "$DOMAIN" >/dev/null 2>&1; then
	mkdir -p "$BACKUP_DIR"
	backup="$BACKUP_DIR/$DOMAIN.plist"
	defaults export "$DOMAIN" "$backup"
	echo "  backup: $backup"
	echo "  要還原的話: defaults import ${DOMAIN} ${backup}"
fi

defaults import "$DOMAIN" "$PLIST"

# cfprefsd 有快取，不重啟的話 iTerm2 下次啟動可能還是讀到舊的
killall cfprefsd 2>/dev/null || true

echo "  已匯入，開啟 iTerm2 生效"
log_end "iTerm2 偏好設定"
