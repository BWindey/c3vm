function _complete_options() {
	already_typed="$1"
	options="$2"
	mapfile -t COMPREPLY < <(compgen -W "${options}" -- "${already_typed}")
}

function try_complete_c3c() {
	local index="$1"
	COMP_WORDS=("c3c" "${COMP_WORDS[@]:$index}")
	COMP_CWORD=$(( COMP_CWORD - index + 1))
	COMP_LINE="${COMP_WORDS[*]}"
	COMP_POINT="${#COMP_LINE}"

	# Call c3c completion function
	# Support both the old and new function (I wrote those too =D)
	# See https://github.com/BWindey/c3c-bash-completions
	if declare -F _c3c_complete &>/dev/null || declare -F _c3c &>/dev/null; then
		_c3c_complete
		return 0
	fi
}

# This function caches the result of `c3vm list --available` as that needs to
# do a network request to fulfill. Caching has of course the risk of not being
# up to date, so I'm decided to refresh once a day.
function get_available_versions() {
	local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/c3vm_completions"
	local cache_file
	cache_file="${cache_dir}/$(date --iso-8601)"

	if [[ -f "$cache_file" ]]; then
		tr '\n' ' ' < "$cache_file"
	else
		mkdir -p "$cache_dir"
		rm "${cache_dir}/*" 2>/dev/null 1>&2
		c3vm list --available 2>/dev/null > "$cache_file"
	fi
}

function _c3vm_complete() {
	local current previous
	current="${COMP_WORDS[COMP_CWORD]}"
	previous="${COMP_WORDS[COMP_CWORD-1]}"

	local subcommands=(
		"status" "list" "install" "enable" "add-local" "update" "remove" "use"
	)

	local subcommand=""
	for (( i = 1; i < "${#COMP_WORDS[@]}"; i++ )); do
		# Check if COMP_WORDS[i] is a subcommand, but only set it when it's not set yet
		if [[ "${subcommands[*]}" =~ (^|.+ )${COMP_WORDS[$i]}($| .+) && "$subcommand" == "" ]]
		then
			subcommand="${COMP_WORDS[$i]}"
		elif [[ "${subcommand}" == "use" && "${COMP_WORDS[$i]}" == "--" ]]; then
			# Hand completion over to `c3c`
			(( i += 1 ))
			try_complete_c3c "$i"
			return
		fi
	done

	local global_options=(
		"--verbose" "-v" "--quiet" "-q" "--help" "-h" "-hh"
	)
	local list_options=(
		"${global_options[@]}"
		"--installed" "-i"
		"--available" "-a"
		"--remote"
		"--remote-installed"
		"--remote-builds"
		"--remote-tags"
		"--remote-branches"
	)
	local install_options=(
		"${global_options[@]}"
		"--debug"
		"--dont-enable"
		"--keep-archive"
		"--from-source"
		"--checkout"
		"--local"
		"--remote"
		"--jobs" "-j"
	)
	local enable_options=(
		"${global_options[@]}"
		"--debug"
		"--from-source"
		"--checkout"
		"--local"
		"--remote"
	)
	local update_options=(
		"${global_options[@]}"
		"--dont-enable"
		"--keep-archive"
		"--jobs" "-j"
	)
	local remove_options=(
		"--interactive" "-I"
		"--fixed-match" "-F"
		"--inactive"
		"--dry-run"
		"--allow-current"
		"--entire-remote"
	)
	local use_options=(
		"${global_options[@]}"
		"--debug"
		"--from-source"
		"--checkout"
		"--local"
		"--remote"
		"--session"
		"--"
	)

	# First catch the "special" ones like flags needing arguments
	case "${previous}" in
		--remote)
			local installed_remotes
			mapfile -t installed_remotes < <(c3vm list --remote-installed)
			_complete_options "${current}" "${installed_remotes[*]}"
			return
			;;
	esac

	# Then, if no subcommand was already given, complete with subcommands
	# and global options
	if [[ "$subcommand" == "" ]]; then
		_complete_options "${current}" "${subcommands[*]} ${global_options[*]}"
		return
	fi

	# Lastly, do completions per subcommand
	case "${subcommand}" in
		list)
			_complete_options "${current}" "${list_options[*]}"
			;;
		install)
			local options="${install_options[*]}"
			if [[ "${COMP_WORDS[*]}" != *" --from-source"* ]]; then
				options+=( "$(get_available_versions)" )
			fi
			_complete_options "${current}" "${options[*]}"
			;;
		enable)
			_complete_options "${current}" "${enable_options[*]}"
			;;
		update)
			_complete_options "${current}" "${update_options[*]}"
			;;
		remove)
			_complete_options "${current}" "${remove_options[*]}"
			;;
		use)
			_complete_options "${current}" "${use_options[*]}"
			;;
	esac
}

complete -F _c3vm_complete c3vm
