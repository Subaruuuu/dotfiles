#!/usr/bin/env bash
#
# 在沙箱裡跑一次完整安裝流程，驗證這個 repo 沒壞掉。
#
#   ./scripts/test.sh
#
# 不會動到本機任何東西：
#   * HOME 指到一個 mktemp 出來的空目錄
#   * brew / chsh / defaults / killall / agy-ide / curl 這些都換成 stub，
#     只記錄「被呼叫了什麼參數」，不真的執行
#
# 刻意不用 set -e：測試要全部跑完才知道有幾項壞掉。
set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_HOME="$HOME"

PASS=0
FAIL=0

ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
ng() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

# check <描述> <指令...>
check() {
	local desc="$1"; shift
	if "$@" >/dev/null 2>&1; then ok "${desc}"; else ng "${desc}"; fi
}

section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# ---------------------------------------------------------------- 沙箱環境 --

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")"
SANDBOX_HOME="${SANDBOX}/home"
STUB_BIN="${SANDBOX}/bin"
CALLS="${SANDBOX}/calls.log"

cleanup() { rm -rf "${SANDBOX}"; }
trap cleanup EXIT

mkdir -p "${SANDBOX_HOME}" "${STUB_BIN}"
: > "${CALLS}"

# 把會動到系統的指令換成只記帳的假貨
make_stub() {
	local name="$1" body="${2:-}"
	cat > "${STUB_BIN}/${name}" <<STUB
#!/bin/sh
echo "${name} \$*" >> "${CALLS}"
${body}
exit 0
STUB
	chmod +x "${STUB_BIN}/${name}"
}

for cmd in brew chsh defaults killall curl sudo xcode-select mas; do
	make_stub "${cmd}"
done

# code 要能回一份「已安裝清單」，才測得出跳過既有擴充的邏輯。
# --profile 擺在 --list-extensions 前面，所以直接比對整串參數
make_stub code 'case "$*" in
  *--list-extensions*) echo "eamodio.gitlens" ;;
esac'

# agy-ide 要能回一份「已安裝清單」，才測得出跳過既有擴充的邏輯
make_stub agy-ide 'case "$1" in
  --list-extensions) echo "[createInstance] 這行是雜訊，應該被濾掉"; echo "eamodio.gitlens" ;;
esac'

sandbox() {
	env HOME="${SANDBOX_HOME}" \
	    DOTFILES="${DOTFILES}" \
	    PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
	    bash "$@"
}

# grep -c 一定會印數字，但沒找到時回非 0，這裡只取輸出不看狀態
calls_for() {
	local n
	n="$(grep -c "^$1 " "${CALLS}" 2>/dev/null)"
	echo "${n:-0}"
}

# ------------------------------------------------------------ 1. 靜態檢查 --

section "1. 語法"

for f in "${DOTFILES}/install.sh" "${DOTFILES}"/scripts/*.sh; do
	check "bash -n $(basename "${f}")" bash -n "${f}"
done

for f in "${DOTFILES}"/links/.zshrc.symlink "${DOTFILES}"/links/.zprofile.symlink; do
	check "zsh -n $(basename "${f}")" zsh -n "${f}"
done

# 用 ast.parse 而不是 py_compile：後者會在 scripts/lib/ 留下 __pycache__
for f in "${DOTFILES}"/scripts/lib/*.py; do
	check "python 語法 $(basename "${f}")" \
		python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "${f}"
done

section "2. 已知地雷"

LINT="${DOTFILES}/scripts/lib/lint.py"

# 先確認 linter 自己抓得到東西。
# 這一條是有原因的：上一版用 grep -P 寫，而 BSD grep（stock macOS 的 /usr/bin/grep）
# 根本沒有 -P，錯誤又被 2>&1 吃掉，結果不管 repo 多爛都回報「乾淨」。
lint_selftest() {
	local probe="${SANDBOX}/lint-probe.sh"
	{
		echo 'set -euo pipefail'
		printf 'echo "%s$var\xef\xbc\x88"\n' ""
		echo 'ps -Ao comm= | grep -q foo'
	} > "${probe}"

	local out
	out="$(python3 "${LINT}" "${probe}" 2>&1)"

	case "${out}" in
		*"全形字"*) ;;
		*) return 1 ;;
	esac
	case "${out}" in
		*"pipefail"*) ;;
		*) return 1 ;;
	esac
	return 0
}

if lint_selftest; then
	ok "linter 自我測試（抓得到已知的壞 pattern）"
else
	ng "linter 自我測試失敗 —— 底下的檢查結果都不可信"
fi

# test.sh 自己刻意包含壞掉的 pattern 當作 fixture，不掃它
lint_targets=("${DOTFILES}/install.sh")
for f in "${DOTFILES}"/scripts/*.sh; do
	[[ "$(basename "${f}")" == "test.sh" ]] && continue
	lint_targets+=("${f}")
done

lint_out="$(python3 "${LINT}" "${lint_targets[@]}" 2>&1)"
if [[ -z "${lint_out}" ]]; then
	ok "沒有已知地雷（bash 3.2 全形字 / pipefail SIGPIPE）"
else
	ng "掃到已知地雷"
	echo "${lint_out}" | sed 's/^/      /'
fi

section "3. 設定檔格式"

for j in vscode/profiles/node/settings.json \
         vscode/profiles/go/settings.json \
         vscode/profiles/python/settings.json \
         antigravity/settings.json zed/settings.json; do
	check "${j} 是合法 JSONC" python3 - "${DOTFILES}/${j}" <<'PY'
import json, re, sys
s = open(sys.argv[1], encoding="utf-8").read()
s = re.sub(r'//.*', '', s)
s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
s = re.sub(r',(\s*[}\]])', r'\1', s)
json.loads(s)
PY
done

check "iTerm2 plist 通過 plutil -lint" plutil -lint "${DOTFILES}/iterm2/com.googlecode.iterm2.plist"

# 匯出時砍掉了很多 key，確認砍過頭的話這裡會叫
check "iTerm2 plist 保留了 profile / 字型 / 內嵌顏色" python3 - "${DOTFILES}/iterm2/com.googlecode.iterm2.plist" <<'PY'
import plistlib, sys
d = plistlib.load(open(sys.argv[1], "rb"))
b = d["New Bookmarks"][0]
assert d.get("Default Bookmark Guid"), "缺 Default Bookmark Guid"
assert b.get("Normal Font"), "缺字型"
assert len([k for k in b if "Color" in k]) >= 80, "profile 內嵌顏色數量不對"
PY

check "iTerm2 plist 不含每次都會變的 NoSync* key" python3 - "${DOTFILES}/iterm2/com.googlecode.iterm2.plist" <<'PY'
import plistlib, sys
d = plistlib.load(open(sys.argv[1], "rb"))
noisy = [k for k in d if k.startswith(("NoSync", "NSWindow Frame", "NSToolbar Configuration"))]
assert not noisy, noisy
PY

# node 由 nvm 管，brew bundle 的 npm 會裝到系統那顆 node 上
check "Brewfile 沒有 npm 項目" bash -c '! grep -q "^npm \"" "'"${DOTFILES}"'/Brewfile"'
check "Brewfile 有 brew/cask/vscode 項目" bash -c '
	grep -q "^brew \"" "'"${DOTFILES}"'/Brewfile" &&
	grep -q "^cask \"" "'"${DOTFILES}"'/Brewfile" &&
	grep -q "^vscode \"" "'"${DOTFILES}"'/Brewfile"'

# 匯出時漏勾選項的話，.code-profile 會只剩 name + globalState，import 出來是空的
for prof in node/node go/Go python/python; do
	check "vscode/profiles/${prof}.code-profile 有 settings 和 extensions" \
		python3 - "${DOTFILES}/vscode/profiles/${prof}.code-profile" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert json.loads(d["settings"])["settings"].strip(), "settings 是空的"
assert json.loads(d["extensions"]), "extensions 是空的"
PY
done

check "vscode_profile.py 列得出擴充 id" bash -c '
	ids="$(python3 "'"${DOTFILES}"'/scripts/lib/vscode_profile.py" extensions \
		"'"${DOTFILES}"'/vscode/profiles/go/Go.code-profile")"
	test -n "${ids}" && ! grep -vE "^[A-Za-z0-9][A-Za-z0-9_-]*\.[A-Za-z0-9]" <<<"${ids}"'

check "extensions.txt 每行都是 publisher.name" bash -c '
	! grep -vE "^[A-Za-z0-9][A-Za-z0-9_-]*\.[A-Za-z0-9]" "'"${DOTFILES}"'/antigravity/extensions.txt"'

section "4. install.sh 步驟對應"

# STEPS 裡的每個名字都要有對應的 script
steps="$(sed -n 's/^STEPS=(\(.*\))$/\1/p' "${DOTFILES}/install.sh")"
if [[ -z "${steps}" ]]; then
	ng "讀不到 install.sh 的 STEPS"
else
	for step in ${steps}; do
		check "步驟 ${step} 有對應的 scripts/${step}.sh" test -f "${DOTFILES}/scripts/${step}.sh"
	done
fi

check "未知步驟會回非 0" bash -c '! "'"${DOTFILES}"'/install.sh" __nope__ 2>/dev/null'

# ------------------------------------------------------- 5. 沙箱實際執行 --

section "5. symlink.sh（沙箱 HOME）"

# 先放一個既有檔案，驗證備份而不是直接覆蓋
echo "使用者原本的 zshrc" > "${SANDBOX_HOME}/.zshrc"

sandbox "${DOTFILES}/scripts/symlink.sh" > "${SANDBOX}/symlink.log" 2>&1
check "symlink.sh 執行成功" test $? -eq 0

expected_links=(
	".zshrc"
	".zprofile"
	".bashrc"
	".gitconfig"
	".nrmrc"
	".config/git/ignore"
	".config/zed/settings.json"
	"Library/Application Support/Code/User/settings.json"
	"Library/Application Support/Antigravity IDE/User/settings.json"
)

for rel in "${expected_links[@]}"; do
	check "~/${rel} 是 symlink" test -L "${SANDBOX_HOME}/${rel}"
done

check "既有的 .zshrc 有被備份" test -f "${SANDBOX_HOME}/.zshrc.dotfiles-backup"
check "備份內容沒被動過" bash -c '
	grep -q "使用者原本的 zshrc" "'"${SANDBOX_HOME}"'/.zshrc.dotfiles-backup"'
check "連過去的 .zshrc 讀得到內容" bash -c '
	grep -q "oh-my-zsh" "'"${SANDBOX_HOME}"'/.zshrc"'

# 重跑一次應該全部 skip、不再產生新備份
sandbox "${DOTFILES}/scripts/symlink.sh" > "${SANDBOX}/symlink2.log" 2>&1
check "重跑 symlink.sh 全部 skip" bash -c '
	! grep -q "linked:" "'"${SANDBOX}"'/symlink2.log"'
check "重跑不會產生第二份備份" bash -c '
	test "$(find "'"${SANDBOX_HOME}"'" -name "*.dotfiles-backup" | wc -l)" -eq 1'

section "6. iterm2.sh"

# 這台實際上開著 iTerm2 就會走 skip 分支；沒開的話會走 import（defaults 是 stub）
before="$(calls_for defaults)"
sandbox "${DOTFILES}/scripts/iterm2.sh" > "${SANDBOX}/iterm2.log" 2>&1
rc=$?
check "iterm2.sh 回 0" test ${rc} -eq 0

if grep -q "iTerm2 正在執行" "${SANDBOX}/iterm2.log"; then
	ok "iTerm2 開著 -> 跳過匯入（本機現在就是這個狀態）"
	check "跳過時完全沒呼叫 defaults" test "$(calls_for defaults)" -eq "${before}"
else
	ok "iTerm2 沒開 -> 執行匯入"
	check "有呼叫 defaults import" bash -c '
		grep -q "defaults import com.googlecode.iterm2" "'"${CALLS}"'"'
	check "匯入前有先備份" bash -c '
		grep -q "defaults export com.googlecode.iterm2" "'"${CALLS}"'"'
fi

# 真正的 iTerm2 偏好設定不能被測試碰到
check "本機 iTerm2 設定沒被動到" bash -c '
	test -f "'"${REAL_HOME}"'/Library/Preferences/com.googlecode.iterm2.plist"'

section "7. editors.sh"

sandbox "${DOTFILES}/scripts/editors.sh" > "${SANDBOX}/editors.log" 2>&1
check "editors.sh 回 0" test $? -eq 0
check "已安裝的擴充會 skip" bash -c '
	grep -q "skip: eamodio.gitlens" "'"${SANDBOX}"'/editors.log"'
check "未安裝的擴充會 install" bash -c '
	grep -q "agy-ide --install-extension golang.go" "'"${CALLS}"'"'
check "CLI 輸出的雜訊行沒被當成擴充 id" bash -c '
	! grep -q "install-extension \[createInstance\]" "'"${CALLS}"'"'

# 把 CLI 藏起來，模擬全新機器
mv "${STUB_BIN}/agy-ide" "${STUB_BIN}/agy-ide.hidden"
sandbox "${DOTFILES}/scripts/editors.sh" > "${SANDBOX}/editors2.log" 2>&1
check "找不到 CLI 時正常跳過（不中斷）" bash -c '
	grep -q "找不到 agy-ide" "'"${SANDBOX}"'/editors2.log"'
mv "${STUB_BIN}/agy-ide.hidden" "${STUB_BIN}/agy-ide"

# VS Code 的 profile：Default 不能帶 --profile，其餘一定要帶
check "Default profile 裝擴充時不帶 --profile" bash -c '
	grep -q "^code --install-extension anthropic.claude-code --force$" "'"${CALLS}"'"'
check "Go profile 裝擴充時帶 --profile Go" bash -c '
	grep -q "^code --profile Go --install-extension golang.go --force$" "'"${CALLS}"'"'
check "python profile 裝擴充時帶 --profile python" bash -c '
	grep -q "^code --profile python --install-extension charliermarsh.ruff --force$" "'"${CALLS}"'"'
check "已裝的擴充會 skip（不重裝）" bash -c '
	! grep -q "install-extension eamodio.gitlens" "'"${CALLS}"'"'
check "沙箱裡不會去寫 profile 的 settings.json" bash -c '
	grep -q "profile 目錄" "'"${SANDBOX}"'/editors.log" ||
	grep -q "VS Code 正在執行" "'"${SANDBOX}"'/editors.log"'


section "8. brew.sh / zsh.sh（stub 底下）"

sandbox "${DOTFILES}/scripts/brew.sh" > "${SANDBOX}/brew.log" 2>&1
check "brew.sh 回 0" test $? -eq 0
check "有用 Brewfile 跑 brew bundle" bash -c '
	grep -q "brew bundle --file='"${DOTFILES}"'/Brewfile" "'"${CALLS}"'"'

# zsh.sh 會 git clone 兩個外掛，改成 clone 本機的空 repo 避免連外網
git init -q "${SANDBOX}/fake-plugin" 2>/dev/null
make_stub git 'if [ "$1" = "clone" ]; then mkdir -p "$4"; fi'
sandbox "${DOTFILES}/scripts/zsh.sh" > "${SANDBOX}/zsh.log" 2>&1
check "zsh.sh 回 0" test $? -eq 0
check "有裝 zsh-autosuggestions" bash -c '
	grep -q "zsh-autosuggestions" "'"${CALLS}"'"'
check "有裝 zsh-syntax-highlighting" bash -c '
	grep -q "zsh-syntax-highlighting" "'"${CALLS}"'"'
check "外掛清單和 .zshrc 裡的 plugins=() 一致" bash -c '
	for p in zsh-autosuggestions zsh-syntax-highlighting; do
		grep -q "$p" "'"${DOTFILES}"'/links/.zshrc.symlink" || exit 1
	done'

section "9. node.sh 設定"

check "NODE_VERSIONS 有 14.19.3 和 22.14.0" bash -c '
	grep -q "NODE_VERSIONS=(14.19.3 22.14.0)" "'"${DOTFILES}"'/scripts/node.sh"'
check "NODE_DEFAULT 是 22.14.0" bash -c '
	grep -q "NODE_DEFAULT=\"22.14.0\"" "'"${DOTFILES}"'/scripts/node.sh"'
check "NODE_DEFAULT 有在 NODE_VERSIONS 裡" bash -c '
	d=$(sed -n "s/^NODE_DEFAULT=\"\(.*\)\"$/\1/p" "'"${DOTFILES}"'/scripts/node.sh")
	grep -q "NODE_VERSIONS=(.*${d}.*)" "'"${DOTFILES}"'/scripts/node.sh"'

section "10. 沙箱有沒有外洩到真的 HOME"

check "沒有在真 HOME 產生 .dotfiles-backup" bash -c '
	test ! -e "'"${REAL_HOME}"'/.dotfiles-backup"'
check "真 HOME 的 VS Code profile settings 沒被覆蓋" bash -c '
	for d in "'"${REAL_HOME}"'/Library/Application Support/Code/User/profiles"/*/; do
		[ -f "${d}settings.json" ] || continue
		! diff -q "${d}settings.json" "'"${DOTFILES}"'/vscode/profiles/node/settings.json" >/dev/null
	done'
check "真 HOME 的 .zshrc 不是指向這個 repo" bash -c '
	test "$(readlink "'"${REAL_HOME}"'/.zshrc" 2>/dev/null)" != "'"${DOTFILES}"'/links/.zshrc.symlink"'

# ------------------------------------------------------------------ 總結 --

printf '\n\033[1m總結\033[0m\n'
printf '  通過 %d 項' "${PASS}"
if [[ ${FAIL} -gt 0 ]]; then
	printf '，\033[31m失敗 %d 項\033[0m\n' "${FAIL}"
	exit 1
fi
printf '，全部通過\n'
