set -e

log_start() {
	echo "------------ Init $1 ------------"
}

log_end() {
	echo "------------ Done $1 ------------"
}

# install omf
install_omf() {
	# omf
	log_start "Install oh my fish"

	curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish

	log_end "Install oh my fish"
}

# install fisher
install_fisher() {
	# fisher
	log_start "Install fisher"

	curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher

	log_end "Install fisher"
}

# intall omf and fisher packages
install_omf_and_fisher_packages() {
	# bass
	if [[ ! $(omf -v) ]]; then
		log_start "Install bass"
		omf install bass
		log_end "Install bass"
	fi


	# fzf.fish
	if [[ ! $(fisher -v) ]]; then
		log_start "Install fzf.fish"
		fisher install PatrickF1/fzf.fish
		log_end "Install fzf.fish"
	fi
}



install_omf
install_fisher
install_omf_and_fisher_packages

bash $HOME/dotfiles/scripts/symlink.sh
