#!/usr/bin/env python3
"""把本機的 iTerm2 偏好設定匯出成乾淨、可 diff 的 XML plist。

會丟掉兩類東西：
  * NoSync* / 視窗位置 / 工具列狀態 —— 每次關掉 iTerm2 都會變，留著只會製造 diff
  * Custom Color Presets —— 201 組 iTerm2-Color-Schemes 的配色「素材庫」，
    佔掉整份檔案 1.7MB。實際在用的顏色是內嵌在 profile 裡的，丟掉不影響外觀。
"""
import os
import plistlib
import subprocess
import sys

DEFAULT_SRC = os.path.expanduser("~/Library/Preferences/com.googlecode.iterm2.plist")

DROP_KEYS = {"Custom Color Presets"}
DROP_PREFIXES = (
    "NoSync",
    "NSWindow Frame",
    "NSToolbar Configuration",
    "NSSplitView Subview Frames",
    "NSOSPLastRootDirectory",
    "findMode_",
)


def main(src, dst):
    xml = subprocess.run(
        ["plutil", "-convert", "xml1", "-o", "-", src],
        capture_output=True, check=True,
    ).stdout
    prefs = plistlib.loads(xml)

    kept = {
        k: v for k, v in prefs.items()
        if k not in DROP_KEYS and not k.startswith(DROP_PREFIXES)
    }

    with open(dst, "wb") as f:
        plistlib.dump(kept, f, sort_keys=True)

    print("  iTerm2: 保留 %d 個 key，略過 %d 個" % (len(kept), len(prefs) - len(kept)))


if __name__ == "__main__":
    args = sys.argv[1:]
    if len(args) == 1:
        main(DEFAULT_SRC, args[0])
    else:
        main(args[0], args[1])
