#!/usr/bin/env python3
"""掃 shell script 裡兩個在這個 repo 實際踩過的地雷。

用 python 而不是 grep：BSD grep（macOS 的 /usr/bin/grep）沒有 -P，
互動 shell 裡的 grep 可能是 ugrep 之類的替代品，兩者行為不一樣。
用 grep 寫的檢查會在 stock macOS 上安靜地失效。

用法：lint.py <檔案>...
找到問題就印出來並回 1，乾淨回 0。
"""
import re
import sys

# macOS 內建 bash 3.2 會把緊接在變數後的多位元組字元併進變數名，
# 例如 "$step（" 被當成變數 step（ -> unbound variable
VAR_THEN_WIDE = re.compile(r"\$\{?[A-Za-z_][A-Za-z0-9_]*\}?[^\x00-\x7F]")

# set -o pipefail 下，pipeline 尾端如果是 grep -q / head 這種讀到一半就結束的指令，
# 前面的指令收到 SIGPIPE，整條 pipeline 回非 0
EARLY_EXIT_PIPE = re.compile(r"\|\s*(grep\s+-[A-Za-z]*q|head)(\s|$)")

CHECKS = (
    ("bash 3.2: 變數後面直接接全形字", VAR_THEN_WIDE, True),
    ("pipefail: pipeline 尾端有會提早結束的指令", EARLY_EXIT_PIPE, False),
)


def scan(paths):
    """回傳 [(檢查名稱, 檔案, 行號, 該行內容), ...]"""
    findings = []

    for path in paths:
        try:
            lines = open(path, encoding="utf-8").read().splitlines()
        except (OSError, UnicodeDecodeError) as e:
            findings.append(("讀不到檔案", path, 0, str(e)))
            continue

        # pipefail 那條只在有開 pipefail 的檔案才算問題
        has_pipefail = any("pipefail" in ln and ln.strip().startswith("set ") for ln in lines)

        for n, line in enumerate(lines, 1):
            if line.lstrip().startswith("#"):
                continue

            for name, pattern, always in CHECKS:
                if not always and not has_pipefail:
                    continue
                if pattern.search(line):
                    findings.append((name, path, n, line.strip()))

    return findings


def main(paths):
    findings = scan(paths)

    for name, path, n, line in findings:
        print("%s\n      %s:%d: %s" % (name, path, n, line))

    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
