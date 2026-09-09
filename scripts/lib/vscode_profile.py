#!/usr/bin/env python3
"""VS Code profile 的匯出／定位。

VS Code 沒有 CLI 可以匯出或匯入 .code-profile（`code --help` 只有 --profile
<name>，那是「用這個 profile 開資料夾」）。GUI 的 Profiles: Export Profile… 產出
的其實是一份普通 JSON，欄位如下（各欄位本身又是 JSON 字串）：

    name          profile 名稱
    settings      {"settings": "<settings.json 原文>"}
    extensions    [{"identifier": {"id", "uuid"}, "displayName", ...}]
    snippets      {"snippets": {"<檔名>": "<內容>"}}
    globalState   {"storage": {...}}   UI 版面狀態

所以這裡直接照這個格式產檔案，資料從本機 profile 目錄讀。globalState 是 UI 狀態，
沒辦法從設定檔重建，沿用既有那份。

用法：
    vscode_profile.py dump       <vscode-profile-名> <匯出用的名字> <輸出目錄>
    vscode_profile.py resolve    <vscode-profile-名>
    vscode_profile.py extensions <.code-profile 檔>

`dump` 會在輸出目錄寫 settings.json 和 <匯出用的名字>.code-profile。
`resolve` 印出該 profile 在本機的目錄，找不到就回非 0。
`extensions` 一行一個擴充 id，給 editors.sh 餵 code --install-extension。
Default profile 的名字寫 Default。
"""

import json
import os
import sys

USER_DIR = os.path.expanduser("~/Library/Application Support/Code/User")
# Default profile 的擴充清單不在 User/ 底下，在這裡（已對過 code --list-extensions）
DEFAULT_EXTENSIONS_JSON = os.path.expanduser("~/.vscode/extensions/extensions.json")


def profile_dir(name):
	"""profile 名 -> 本機目錄。Default 是 User/ 本身，其餘查 storage.json。"""
	if name == "Default":
		return USER_DIR

	storage = os.path.join(USER_DIR, "globalStorage", "storage.json")
	with open(storage, encoding="utf-8") as f:
		profiles = json.load(f).get("userDataProfiles") or []

	for p in profiles:
		if p.get("name") == name:
			return os.path.join(USER_DIR, "profiles", p["location"])
	return None


def read_text(path):
	"""newline="" 是必要的：本機的 settings.json 是 CRLF，用預設的 universal
	newlines 讀會被轉成 LF，匯出的內容就跟 GUI 產的那份對不起來。"""
	if not os.path.isfile(path):
		return None
	with open(path, encoding="utf-8", newline="") as f:
		return f.read()


def display_name(location, identifier_id):
	"""package.json 的 displayName 可能是 %key% 這種 NLS 佔位符，真正的字串在
	package.nls.json 裡。"""
	pkg = read_text(os.path.join(location, "package.json"))
	if not pkg:
		return identifier_id

	name = json.loads(pkg).get("displayName")
	if not name:
		return identifier_id

	if name.startswith("%") and name.endswith("%"):
		nls = read_text(os.path.join(location, "package.nls.json"))
		if nls:
			name = json.loads(nls).get(name[1:-1]) or identifier_id
		else:
			name = identifier_id
	return name


def extensions_for(name, pdir):
	"""從本機 extensions.json 組出 .code-profile 的 extensions 陣列。

	displayName 在 extensions.json 裡沒有（那邊只有 publisherDisplayName），
	要去擴充自己的 package.json 撈。
	"""
	path = DEFAULT_EXTENSIONS_JSON if name == "Default" else os.path.join(pdir, "extensions.json")
	if not os.path.isfile(path):
		return []

	with open(path, encoding="utf-8") as f:
		installed = json.load(f)

	# 同一個擴充可能留著兩個版本（舊版沒被清掉），GUI 匯出只列一筆，取新的那個
	newest = {}
	for ext in installed:
		key = ext["identifier"]["id"].lower()
		stamp = (ext.get("metadata") or {}).get("installedTimestamp") or 0
		if key not in newest or stamp > (newest[key].get("metadata") or {}).get("installedTimestamp", 0):
			newest[key] = ext

	out = []
	for ext in sorted(newest.values(), key=lambda e: e["identifier"]["id"].lower()):
		meta = ext.get("metadata") or {}
		if meta.get("isBuiltin"):
			continue

		identifier = dict(ext["identifier"])
		# 有些擴充的 identifier 沒帶 uuid，但 metadata.id 就是同一個值
		if not identifier.get("uuid") and meta.get("id"):
			identifier["uuid"] = meta["id"]
		entry = {"identifier": identifier}

		location = (ext.get("location") or {}).get("path")
		entry["displayName"] = (display_name(location, ext["identifier"]["id"])
		                        if location else ext["identifier"]["id"])

		# 匯出時 preRelease 只有 true 才會出現，false 就整個欄位不寫
		if meta.get("preRelease"):
			entry["preRelease"] = True
		entry["applicationScoped"] = bool(meta.get("isApplicationScoped"))

		out.append(entry)
	return out


def snippets_for(pdir):
	sdir = os.path.join(pdir, "snippets")
	if not os.path.isdir(sdir):
		return None

	snippets = {}
	for fname in sorted(os.listdir(sdir)):
		body = read_text(os.path.join(sdir, fname))
		if body is not None:
			snippets[fname] = body
	return snippets or None


def dump(vscode_name, export_name, out_dir):
	pdir = profile_dir(vscode_name)
	if pdir is None:
		sys.exit(f"找不到 profile: {vscode_name}")

	os.makedirs(out_dir, exist_ok=True)

	settings = read_text(os.path.join(pdir, "settings.json"))
	if settings is None:
		sys.exit(f"{vscode_name} 沒有 settings.json（{pdir}）")

	with open(os.path.join(out_dir, "settings.json"), "w", encoding="utf-8", newline="") as f:
		f.write(settings)

	profile = {"name": export_name, "settings": json.dumps({"settings": settings})}

	extensions = extensions_for(vscode_name, pdir)
	if extensions:
		profile["extensions"] = json.dumps(extensions)

	snippets = snippets_for(pdir)
	if snippets:
		profile["snippets"] = json.dumps({"snippets": snippets})

	# globalState 是 UI 版面狀態，重建不出來，沿用既有那份
	out_path = os.path.join(out_dir, f"{export_name}.code-profile")
	old = read_text(out_path)
	if old:
		previous = json.loads(old).get("globalState")
		if previous:
			profile["globalState"] = previous

	with open(out_path, "w", encoding="utf-8") as f:
		json.dump(profile, f, ensure_ascii=False)

	print(f"  {export_name}: settings {len(settings)} bytes / 擴充 {len(extensions)} 個"
	      f" / snippets {len(snippets or {})} 個")


def list_extensions(path):
	with open(path, encoding="utf-8") as f:
		profile = json.load(f)

	for ext in json.loads(profile.get("extensions") or "[]"):
		print(ext["identifier"]["id"])


def main():
	if len(sys.argv) >= 2 and sys.argv[1] == "dump" and len(sys.argv) == 5:
		dump(sys.argv[2], sys.argv[3], sys.argv[4])
	elif len(sys.argv) == 3 and sys.argv[1] == "resolve":
		pdir = profile_dir(sys.argv[2])
		if pdir is None or not os.path.isdir(pdir):
			sys.exit(1)
		print(pdir)
	elif len(sys.argv) == 3 and sys.argv[1] == "extensions":
		list_extensions(sys.argv[2])
	else:
		sys.exit(__doc__)


if __name__ == "__main__":
	main()
