function _complete_options() {
	already_typed="$1"
	options="$2"
	mapfile -t COMPREPLY < <(compgen -W "${options}" -- "${already_typed}")
}

function _c3vm_complete() {
	local current previous
	current="${COMP_WORDS[COMP_CWORD]}"
	previous="${COMP_WORDS[COMP_CWORD-1]}"

	local subcommands=(
		"status" "list" "install" "enable" "add-local" "update" "remove" "use"
	)

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

	case "${previous}" in
		c3vm)
			_complete_options "${current}" "${subcommands[*]} ${global_options[*]}"
			;;
		list)
			_complete_options "${current}" "${list_options[*]}"
			;;
		install)
			_complete_options "${current}" "${install_options[*]}"
	esac
}

complete -F _c3vm_complete c3vm
