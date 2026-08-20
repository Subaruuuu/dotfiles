<div align="center">
  <h1>dotfiles</h1>
  <p>用一支 script 把新的 macOS 還原成慣用的開發環境</p>
</div>

<p align="center">
  <img src="https://img.shields.io/badge/-macOS-000000?style=flat-square&logo=Apple&logoColor=white" alt="macOS">
  <img src="https://img.shields.io/badge/-zsh-1A1A1A?style=flat-square&logo=gnubash&logoColor=white" alt="zsh">
  <img src="https://img.shields.io/badge/-Homebrew-FBB040?style=flat-square&logo=Homebrew&logoColor=black" alt="Homebrew">
  <img src="https://img.shields.io/badge/-Starship-DD0B78?style=flat-square&logo=starship&logoColor=white" alt="Starship">
</p>

## 用法

在一台全新的 mac 上：

```sh
git clone https://github.com/Subaruuuu/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

跑完之後開一個新的 terminal。最後補上 git 身分（刻意不放進 repo）：

```sh
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
```

也可以只跑其中一個步驟：

```sh
~/dotfiles/install.sh symlink        # 只重建 symlink
~/dotfiles/install.sh brew node      # 只跑這兩步
```

## install.sh 做了什麼

| 步驟 | script | 內容 |
| --- | --- | --- |
| `brew` | `scripts/brew.sh` | Xcode CLT → Homebrew → `brew bundle`（formula / cask / VS Code 擴充） |
| `zsh` | `scripts/zsh.sh` | 確認預設 shell 是 zsh、安裝 oh-my-zsh 與 autosuggestions / syntax-highlighting |
| `symlink` | `scripts/symlink.sh` | 把 `links/`、`config/` 和三個編輯器的 `settings.json` 連到家目錄 |
| `node` | `scripts/node.sh` | 用 nvm 裝 node 14.19.3 與 22.14.0（default 是 22.14.0），安裝全域 npm 套件 |
| `nvim` | `scripts/nvim.sh` | clone [nvim-config](https://github.com/Subaruuuu/nvim-config) 到 `~/.config/nvim` |
| `editors` | `scripts/editors.sh` | 裝 Antigravity IDE 的擴充套件（VS Code 的走 Brewfile） |
| `iterm2` | `scripts/iterm2.sh` | `defaults import` 匯入 iTerm2 偏好設定 |

每個步驟都可重跑，已經裝好的會直接跳過；symlink 遇到既有檔案會先備份成 `*.dotfiles-backup`，不會直接覆蓋掉。

## 目錄結構

```
.
├── install.sh          # 入口
├── Brewfile            # brew bundle dump 的產物
├── links/              # .foo.symlink -> ~/.foo
│   ├── .zshrc.symlink
│   ├── .zprofile.symlink
│   ├── .bashrc.symlink
│   ├── .gitconfig.symlink
│   └── .nrmrc.symlink
├── config/             # 對應 ~/.config/
│   └── git/ignore
├── scripts/
│   ├── test.sh         # 沙箱測試
│   └── lib/lint.py     # shell script 地雷掃描
├── iterm2/
│   └── com.googlecode.iterm2.plist
├── vscode/
│   ├── settings.json   # -> ~/Library/Application Support/Code/User/settings.json
│   └── *.code-profile  # 手動從 VS Code 匯入
├── antigravity/
│   ├── settings.json   # -> ~/Library/Application Support/Antigravity IDE/User/settings.json
│   └── extensions.txt  # agy-ide --install-extension 用
└── zed/
    └── settings.json   # -> ~/.config/zed/settings.json
```

## 編輯器

三個編輯器的 `settings.json` 都是 symlink 回這個 repo，所以在編輯器裡改設定 = 直接改 repo，不需要另外同步。

擴充套件則是兩套機制：VS Code 的寫在 Brewfile 的 `vscode "..."` 由 `brew bundle` 處理；Antigravity 的走 `antigravity/extensions.txt`，因為它不是 Homebrew 認得的編輯器。

Zed 只存 `settings.json`，`~/.config/zed/` 底下的 `prompts/`（sqlite）跟 `conversations/` 是本機狀態，沒有納入。

## iTerm2

`iterm2/com.googlecode.iterm2.plist` 是清乾淨的 XML 版偏好設定，還原方式是 `defaults import`。

匯入前**一定要先完全結束 iTerm2**——它會在退出時把記憶體裡的整份設定寫回 preferences，開著的時候匯入會被蓋掉。`scripts/iterm2.sh` 偵測到 iTerm2 在跑就會直接跳過並提醒你。所以在全新機器上，這一步請從 Terminal.app 執行。

匯出時丟掉了兩類東西（見 `scripts/lib/iterm2_export.py`）：

- `NoSync*`、視窗位置、工具列狀態——每次關掉 iTerm2 都會變，留著只會製造 diff
- `Custom Color Presets`——201 組 [iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes) 的配色素材庫，佔掉原始檔 457KB 中的 1.7MB（XML 展開後）。實際在用的顏色是內嵌在 profile 裡的 83 個 key，丟掉不影響外觀；要整包素材庫的話重新從上游匯入即可

清完是 45 個 key、35KB。

## shell 環境

zsh + [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh)，prompt 用 [starship](https://starship.rs)（所以 `ZSH_THEME` 留空）。

外掛：`git`、`zsh-autosuggestions`、`zsh-syntax-highlighting`。

`.zshrc` 內載入的東西都有做存在性檢查（pyenv / gvm / fzf / mysql / Antigravity），少裝哪個不會讓 shell 噴錯。

## 測試

```sh
~/dotfiles/scripts/test.sh
```

不會動到本機任何東西：`HOME` 指到 `mktemp` 出來的空目錄，`brew` / `chsh` / `defaults` / `killall` / `agy-ide` / `curl` 這些全部換成只記錄呼叫參數的 stub。跑完會列出通過／失敗項目，有失敗就回非 0。

涵蓋範圍：所有 script 的語法、兩個踩過的地雷（見下）、三份 `settings.json` 的 JSONC 合法性、iTerm2 plist 的完整性、`install.sh` 的 `STEPS` 有沒有對應的 script、`symlink.sh` 在乾淨 HOME 上的行為（連結、備份、重跑冪等），以及 `editors.sh` / `brew.sh` / `zsh.sh` 在 stub 底下實際跑一遍。

沙箱測不到的只有真的要碰網路和系統的部分：`brew bundle` 實際下載、`chsh` 換 shell、`nvm install`。那些要驗證只能開一個乾淨的 macOS 使用者帳號跑 `./install.sh`。

```bash
❯ bash ./dotfiles/scripts/test.sh

1. 語法
  ✓ bash -n install.sh
  ✓ bash -n _lib.sh
  ✓ bash -n brew.sh
  ✓ bash -n dump.sh
  ✓ bash -n editors.sh
  ✓ bash -n iterm2.sh
  ✓ bash -n node.sh
  ✓ bash -n nvim.sh
  ✓ bash -n symlink.sh
  ✓ bash -n test.sh
  ✓ bash -n zsh.sh
  ✓ zsh -n .zshrc.symlink
  ✓ zsh -n .zprofile.symlink
  ✓ python3 -m py_compile iterm2_export.py

2. 已知地雷
  ✓ linter 自我測試（抓得到已知的壞 pattern）
  ✓ 沒有已知地雷（bash 3.2 全形字 / pipefail SIGPIPE）

3. 設定檔格式
  ✓ vscode/settings.json 是合法 JSONC
  ✓ antigravity/settings.json 是合法 JSONC
  ✓ zed/settings.json 是合法 JSONC
  ✓ iTerm2 plist 通過 plutil -lint
  ✓ iTerm2 plist 保留了 profile / 字型 / 內嵌顏色
  ✓ iTerm2 plist 不含每次都會變的 NoSync* key
  ✓ Brewfile 沒有 npm 項目
  ✓ Brewfile 有 brew/cask/vscode 項目
  ✓ extensions.txt 每行都是 publisher.name

4. install.sh 步驟對應
  ✓ 步驟 brew 有對應的 scripts/brew.sh
  ✓ 步驟 zsh 有對應的 scripts/zsh.sh
  ✓ 步驟 symlink 有對應的 scripts/symlink.sh
  ✓ 步驟 node 有對應的 scripts/node.sh
  ✓ 步驟 nvim 有對應的 scripts/nvim.sh
  ✓ 步驟 editors 有對應的 scripts/editors.sh
  ✓ 步驟 iterm2 有對應的 scripts/iterm2.sh
  ✓ 未知步驟會回非 0

5. symlink.sh（沙箱 HOME）
  ✓ symlink.sh 執行成功
  ✓ ~/.zshrc 是 symlink
  ✓ ~/.zprofile 是 symlink
  ✓ ~/.bashrc 是 symlink
  ✓ ~/.gitconfig 是 symlink
  ✓ ~/.nrmrc 是 symlink
  ✓ ~/.config/git/ignore 是 symlink
  ✓ ~/.config/zed/settings.json 是 symlink
  ✓ ~/Library/Application Support/Code/User/settings.json 是 symlink
  ✓ ~/Library/Application Support/Antigravity IDE/User/settings.json 是 symlink
  ✓ 既有的 .zshrc 有被備份
  ✓ 備份內容沒被動過
  ✓ 連過去的 .zshrc 讀得到內容
  ✓ 重跑 symlink.sh 全部 skip
  ✓ 重跑不會產生第二份備份

6. iterm2.sh
  ✓ iterm2.sh 回 0
  ✓ iTerm2 開著 -> 跳過匯入（本機現在就是這個狀態）
  ✓ 跳過時完全沒呼叫 defaults
  ✓ 本機 iTerm2 設定沒被動到

7. editors.sh
  ✓ editors.sh 回 0
  ✓ 已安裝的擴充會 skip
  ✓ 未安裝的擴充會 install
  ✓ CLI 輸出的雜訊行沒被當成擴充 id
  ✓ 找不到 CLI 時正常跳過（不中斷）

8. brew.sh / zsh.sh（stub 底下）
  ✓ brew.sh 回 0
  ✓ 有用 Brewfile 跑 brew bundle
  ✓ zsh.sh 回 0
  ✓ 有裝 zsh-autosuggestions
  ✓ 有裝 zsh-syntax-highlighting
  ✓ 外掛清單和 .zshrc 裡的 plugins=() 一致

9. node.sh 設定
  ✓ NODE_VERSIONS 有 14.19.3 和 22.14.0
  ✓ NODE_DEFAULT 是 22.14.0
  ✓ NODE_DEFAULT 有在 NODE_VERSIONS 裡

10. 沙箱有沒有外洩到真的 HOME
  ✓ 沒有在真 HOME 產生 .dotfiles-backup
  ✓ 真 HOME 的 .zshrc 不是指向這個 repo

總結
  通過 68 項，全部通過
```

### 兩個踩過的地雷

`scripts/lib/lint.py` 會掃這兩個，`test.sh` 每次都跑：

1. **bash 3.2 的變數名解析** —— macOS 內建的是 bash 3.2，會把緊接在變數後的多位元組字元併進變數名。`"$step（"` 會被當成變數 `step（`，在 `set -u` 底下直接 unbound variable 爆掉。全形字要嘛放變數前面，要嘛用 `${step}` 把邊界框起來。

2. **`pipefail` + 提早結束的 pipeline** —— `ps -Ao comm= | grep -q foo` 在 `set -o pipefail` 底下永遠回非 0：`grep -q` 找到就結束，`ps` 收到 SIGPIPE，pipefail 就把整條 pipeline 判定為失敗。這個 bug 讓 iTerm2 的「有沒有在執行」偵測永遠回 false。

linter 用 python 而不是 grep 寫，是因為 BSD grep（stock macOS 的 `/usr/bin/grep`）沒有 `-P`。第一版用 `grep -P` 寫的檢查在 script 裡會直接報錯，錯誤又被 `2>&1` 吃掉，結果不管 repo 多爛都回報「乾淨」。`test.sh` 因此有一條 linter 的自我測試，先確認它抓得到已知的壞 pattern，再相信它的結果。

## 維護

把本機現在的狀態倒回 repo：

```sh
~/dotfiles/scripts/dump.sh
```

它會更新 `Brewfile`、`iterm2/com.googlecode.iterm2.plist` 和 `antigravity/extensions.txt`，跑完用 `git diff` 檢查。編輯器的 `settings.json` 是 symlink，本來就同步，不在它的處理範圍。

（`brew bundle dump` 會把 `npm "..."` 一起寫進去，`dump.sh` 會濾掉——node 由 nvm 管，全域套件寫在 `scripts/node.sh` 的 `NPM_PACKAGES`。）

## 沒有納入版控的東西

- `user.name` / `user.email`
- nvim 設定（獨立 repo，由 `scripts/nvim.sh` clone）
- Zed 的 `prompts/`、`conversations/`；各編輯器的 `globalStorage` / `workspaceStorage`
- iTerm2 的 `Custom Color Presets`（見上）
- `vscode/settings.json` 和 `antigravity/settings.json` 裡的 `vscode-neovim.neovimInitVimPaths.darwin` 是絕對路徑（那個擴充不保證展開 `~`），換使用者名稱要手改
