
set -e

log_start() {
	echo "------------ Init $1 ------------"
}

log_end() {
	echo "------------ Done $1 ------------"
}

# 安裝 xcode
install_xcode() {
	xcode-select --install
}

# 安裝 homebrew
install_homebrew() {
	if [[ !"$(which brew)" ]] ; then
		# Install Homebrew
		log_start "Intall homebrew"
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

		# 讓 zsh 可以執行 brew
		log_start "Set brew for zprofile"
		if [[ ! -a $HOME/.zprofile ]]; then
			log_start "touch .zprofile"
			touch $HOME/.zprofile
			log_end "touch .zprofile"
		fi

		log_start "add homebrew to PATH"
		echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
		eval "$(/opt/homebrew/bin/brew shellenv)"
		log_end "add homebrew to PATH"
	fi
}

# recover applications from brewfile
recover_brew_bundle() {
	# 安裝 mas
	log_start "Intall mas"
	brew install mas
	log_end "Intall mas"

	log_start "Recover applications from brew bundle"
	brew bundle --file="$HOME/dotfiles/Brewfile"
	log_end "Recover applications from brew bundle"
}

# 設定預設 shell 為 fish
set_default_shell_to_fish() {
	log_start "Set default shell to fish"

	echo $(which fish) | sudo tee -a /etc/shells
	chsh -s $(which fish)

	log_end "Set default shell to fish"
}

# 在 fish shell 內新增 $PATH
set_homebrew_path_to_fish_shell() {
	# 這邊 執行會出問題，顯示 -U invalid option
	log_start "Set fish user paths"

	if [[ ! -a $HOME/.zshrc ]]; then
		log_start "touch .zshrc"
		touch $HOME/.zprofile
		log_end "touch .zshrc"
	fi

	echo "export PATH=/opt/homebrew/bin:/opt/homebrew/sbin:$PATH" >> $HOME/.zshrc
	# export PATH=/opt/homebrew/bin:/opt/homebrew/sbin:$PATH

	log_end "Set fish user paths"
}

install_xcode
install_homebrew
recover_brew_bundle
set_default_shell_to_fish
set_homebrew_path_to_fish_shell

bash $HOME/dotfiles/scripts/appleScipt.sh
# bash $HOME/dotfiles/scripts/packages.sh
# bash $HOME/dotfiles/scripts/symlink.sh
