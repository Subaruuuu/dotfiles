set -e

log_start() {
	echo "------------ Init $1 ------------"
}

log_end() {
	echo "------------ Done $1 ------------"
}

# others packages
install_other_packages() {
	if [[ ! $(npm -v) ]]; then
		log_start "Install npm"
		nvm install 14.19.3
		log_end "Install npm"
	fi
}

# npm packages
install_npm_packages() {
	if [[ $(npm -v) ]]; then
		if [[ ! $(nrm --version) ]]; then
			log_start "Install npm packages"
			npm install -g nrm nodemon concurrently
			log_end "Install npm packages"
		fi
	fi
}

install_other_packages
install_npm_packages
