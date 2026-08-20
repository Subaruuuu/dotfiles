#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

# 都會裝，NODE_DEFAULT 那個設成預設版本
NODE_VERSIONS=(14.19.3 22.14.0)
NODE_DEFAULT="22.14.0"

NPM_PACKAGES=(nrm @colbymchenry/codegraph)

load_nvm() {
	export NVM_DIR="$HOME/.nvm"
	mkdir -p "$NVM_DIR"

	if [[ ! -s "/opt/homebrew/opt/nvm/nvm.sh" ]]; then
		echo "  找不到 nvm，請先跑 scripts/brew.sh" >&2
		exit 1
	fi

	# shellcheck disable=SC1091
	source "/opt/homebrew/opt/nvm/nvm.sh"
}

install_node() {
	local version
	for version in "${NODE_VERSIONS[@]}"; do
		if nvm ls "$version" >/dev/null 2>&1; then
			log_skip "node $version 已安裝"
		else
			log_start "node $version"
			nvm install "$version"
			log_end "node $version"
		fi
	done

	nvm alias default "$NODE_DEFAULT"
	nvm use default
}

# 全域套件只裝在 default 版本上，舊版 node 通常只是拿來跑舊專案
install_npm_packages() {
	log_start "npm 全域套件 (node $NODE_DEFAULT)"

	for pkg in "${NPM_PACKAGES[@]}"; do
		if npm ls -g --depth=0 "$pkg" >/dev/null 2>&1; then
			log_skip "$pkg 已安裝"
		else
			npm install -g "$pkg"
		fi
	done

	log_end "npm 全域套件"
}

load_nvm
install_node
install_npm_packages
