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
	if declare -F _c3c_complete &>/dev/null; then
		_c3c_complete
		return 0
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
		"--installed" "-i" "--available" "-a"
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
	# case "${previous}" in
	# 	*)
	# 		;;
	# esac

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
			_complete_options "${current}" "${install_options[*]}"
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
