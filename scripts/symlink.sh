# 開始 symlink
start_link() {
	# local src=$1 dst=$2
	ln -s "$1" "$2"
	echo "success linked $1 to $2"
}

init() {
	for src in $(find $HOME/dotfiles/links -maxdepth 2 -name '*.symlink' -not -path '*.git*')
	do
		if [[ "$(basename "${src%.*}")" == "config.fish" ]]; then
			dst="$HOME/.config/fish/$(basename "${src%.*}")"
		else
			dst="$HOME/$(basename "${src%.*}")"
		fi

		# if config.fish exist
		if [[ -a $dst ]]; then
			echo "delete current $dst"
			rm "$dst"
		fi

		if [[ ! -a $dst ]]; then
			# echo "source" $src
			# echo "destination" $dst

			start_link "$src" "$dst"
		fi
	done
}

init

bash $HOME/dotfiles/scripts/nvm.sh
