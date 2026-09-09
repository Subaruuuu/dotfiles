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
mkdir -p ~/dotfiles
curl -fsSL https://github.com/Subaruuuu/dotfiles/archive/refs/heads/master.tar.gz \
  | tar -xz --strip-components=1 -C ~/dotfiles
~/dotfiles/install.sh
```

這樣拉下來的目錄沒有 `.git`，之後想用 `git pull` 更新的話，裝完後補接上遠端：

```sh
cd ~/dotfiles
git init -b master && git remote add origin https://github.com/Subaruuuu/dotfiles.git
git fetch origin && git reset --mixed origin/master
git branch -u origin/master master
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
│   ├── test.sh                  # 沙箱測試
│   ├── lib/lint.py              # shell script 地雷掃描
│   └── lib/vscode_profile.py    # 產 .code-profile / 查 profile 目錄
├── iterm2/
│   └── com.googlecode.iterm2.plist
├── vscode/
│   └── profiles/       # 一個 profile 一個資料夾
│       ├── node/       # = Default profile
│       │   ├── settings.json     # -> ~/Library/Application Support/Code/User/settings.json
│       │   └── node.code-profile # 手動從 VS Code 匯出／匯入
│       ├── go/
│       │   ├── settings.json
│       │   └── Go.code-profile
│       └── python/
│           ├── settings.json
│           └── python.code-profile
├── antigravity/
│   ├── settings.json   # -> ~/Library/Application Support/Antigravity IDE/User/settings.json
│   └── extensions.txt  # agy-ide --install-extension 用
└── zed/
    └── settings.json   # -> ~/.config/zed/settings.json
```

## 編輯器

三個編輯器的 `settings.json` 都是 symlink 回這個 repo，所以在編輯器裡改設定 = 直接改 repo，不需要另外同步。VS Code 這邊連過去的是 Default profile，也就是 `vscode/profiles/node/settings.json`。

擴充套件有三套機制：

| 對象 | 機制 |
| --- | --- |
| VS Code Default profile | Brewfile 的 `vscode "..."`，`brew bundle` 處理 |
| VS Code 其他 profile | `.code-profile` 裡的清單，`scripts/editors.sh` 用 `code --profile` 裝 |
| Antigravity | `antigravity/extensions.txt`，它不是 Homebrew 認得的編輯器 |

### VS Code profile

`vscode/profiles/` 一個 profile 一個資料夾，裡面兩份東西：

- `settings.json` —— 純文字，方便 review 和 diff
- `<名字>.code-profile` —— VS Code 的匯出格式，含 settings + 擴充清單 + snippets + UI 版面狀態，可以直接在 GUI 匯入

`Brewfile` 的 `vscode "..."` **只認得 Default profile**。`brew bundle` 的實作固定跑 `code --list-extensions` / `code --install-extension`，沒有帶 `--profile`；在 Brewfile 寫 `vscode "golang.go", profile: "Go"` 會直接被擋下：

```
Error: Invalid Brewfile: unknown options([:profile]) for vscode
```

所以非 Default 的 profile 只能自己來，`scripts/editors.sh` 用 `code --profile <名字> --install-extension`。

`.code-profile` 也沒有 CLI 可以匯出或匯入（`code --help` 只有 `--profile <name>`，那是「用這個 profile 開資料夾」）。GUI 匯出的其實是一份普通 JSON，`scripts/lib/vscode_profile.py` 直接照那個格式產，資料從本機 profile 目錄讀。有兩個地方會踩到：

1. **`displayName` 可能是 `%displayName%`** —— 擴充的 `package.json` 用 NLS 佔位符時，真正的字串在 `package.nls.json` 裡
2. **`settings.json` 是 CRLF** —— python 預設的 universal newlines 會把它轉成 LF，匯出的內容就跟 GUI 產的那份對不起來，要用 `newline=""` 讀寫

還原時 `.code-profile` 只是給你手動 import 用的備份；`install.sh` 走的是擴充用 CLI 裝、`settings.json` 直接複製進 profile 目錄。profile 目錄的 id 是每台機器隨機產的，所以要先裝擴充（順手把 profile 建出來）才查得到目錄。**VS Code 開著的時候 `editors.sh` 不會寫 `settings.json`**，記憶體裡那份會蓋回去。

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

涵蓋範圍：所有 script 的語法、兩個踩過的地雷（bash 3.2 的全形字變數名解析、`pipefail` 遇上提早結束的 pipeline）、五份 `settings.json` 的 JSONC 合法性、三份 `.code-profile` 有沒有真的含到 settings 和擴充清單、iTerm2 plist 的完整性、`install.sh` 的 `STEPS` 有沒有對應的 script、`symlink.sh` 在乾淨 HOME 上的行為（連結、備份、重跑冪等），以及 `editors.sh` / `brew.sh` / `zsh.sh` 在 stub 底下實際跑一遍。

沙箱測不到的只有真的要碰網路和系統的部分：`brew bundle` 實際下載、`chsh` 換 shell、`nvm install`。那些要驗證只能開一個乾淨的 macOS 使用者帳號跑 `./install.sh`。

```bash
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
  ✓ python 語法 iterm2_export.py
  ✓ python 語法 lint.py
  ✓ python 語法 vscode_profile.py

2. 已知地雷
  ✓ linter 自我測試（抓得到已知的壞 pattern）
  ✓ 沒有已知地雷（bash 3.2 全形字 / pipefail SIGPIPE）

3. 設定檔格式
  ✓ vscode/profiles/node/settings.json 是合法 JSONC
  ✓ vscode/profiles/go/settings.json 是合法 JSONC
  ✓ vscode/profiles/python/settings.json 是合法 JSONC
  ✓ antigravity/settings.json 是合法 JSONC
  ✓ zed/settings.json 是合法 JSONC
  ✓ iTerm2 plist 通過 plutil -lint
  ✓ iTerm2 plist 保留了 profile / 字型 / 內嵌顏色
  ✓ iTerm2 plist 不含每次都會變的 NoSync* key
  ✓ Brewfile 沒有 npm 項目
  ✓ Brewfile 有 brew/cask/vscode 項目
  ✓ vscode/profiles/node/node.code-profile 有 settings 和 extensions
  ✓ vscode/profiles/go/Go.code-profile 有 settings 和 extensions
  ✓ vscode/profiles/python/python.code-profile 有 settings 和 extensions
  ✓ vscode_profile.py 列得出擴充 id
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
  ✓ Default profile 裝擴充時不帶 --profile
  ✓ Go profile 裝擴充時帶 --profile Go
  ✓ python profile 裝擴充時帶 --profile python
  ✓ 已裝的擴充會 skip（不重裝）
  ✓ 沙箱裡不會去寫 profile 的 settings.json

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
  ✓ 真 HOME 的 VS Code profile settings 沒被覆蓋
  ✓ 真 HOME 的 .zshrc 不是指向這個 repo

總結
  通過 82 項，全部通過
```

項目數不是固定的：第 6 節會依本機狀態走不同分支——iTerm2 開著時是「跳過匯入」那 2 項，沒開時是「實際匯入」那 3 項，所以總數是 82 或 83。

## 維護

把本機現在的狀態倒回 repo：

```sh
~/dotfiles/scripts/dump.sh
```

它會更新 `Brewfile`、`iterm2/com.googlecode.iterm2.plist`、`vscode/profiles/*/`（三個 profile 的 `settings.json` 和 `.code-profile`）和 `antigravity/extensions.txt`，跑完用 `git diff` 檢查。VS Code Default profile 的 `settings.json` 是 symlink，本來就同步。

（`brew bundle dump` 會把 `npm "..."` 一起寫進去，`dump.sh` 會濾掉——node 由 nvm 管，全域套件寫在 `scripts/node.sh` 的 `NPM_PACKAGES`。）

## 沒有納入版控的東西

- `user.name` / `user.email`
- nvim 設定（獨立 repo，由 `scripts/nvim.sh` clone）
- Zed 的 `prompts/`、`conversations/`；各編輯器的 `globalStorage` / `workspaceStorage`
- iTerm2 的 `Custom Color Presets`（見上）
- `vscode/profiles/node/settings.json` 和 `antigravity/settings.json` 裡的 `vscode-neovim.neovimInitVimPaths.darwin` 是絕對路徑（那個擴充不保證展開 `~`），換使用者名稱要手改
