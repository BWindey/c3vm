# Bash completion script
# $1 = name of command -> c3vm
# $2 = current word being completed
# $3 = word before current word
#
# $COMP_WORDS = array of all words typed on commandline
# $COMP_CWORD = amount of words typed on commandline
# $COMP_LINE = string of all words typed on commandline
# $COMP_POINT = index in string $COMP_LINE where cursor is

function _complete_options() {
	already_typed="$1"
	options="$2"
	mapfile -t COMPREPLY < <(compgen -W "${options}" -- "${already_typed}")
}

function try_complete_c3c() {
	local index="$1"
	COMP_WORDS=("c3c" "${COMP_WORDS[@]:${index}}")
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

function get_available_checkouts() {
	# Check if '--remote' is present, we need it. Else we don't (default remote).
	local remote=""
	local previous_written=""
	for written in "${COMP_WORDS[@]}"; do
		if [[ "$previous_written" == "--remote" ]]; then
			remote="$written"
			break
		fi
		previous_written="$written"
	done

	if [[ "$remote" == "" ]]; then
		c3vm list --remote-tags 2>/dev/null
		c3vm list --remote-branches 2>/dev/null
	else
		c3vm list --remote "$remote" --remote-tags 2>/dev/null
		c3vm list --remote "$remote" --remote-branches 2>/dev/null
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

function get_prebuilt_installed_versions() {
	c3vm list --prebuilt-installed 2>/dev/null
}

function _c3vm_complete() {
	local current previous
	current="$2"
	previous="$3"

	local subcommands=(
		"status" "list" "install" "enable" "add-local" "update" "remove" "use"
	)

	local subcommand=""
	local processed_chars
	declare -i processed_chars="${#COMP_WORDS[0]}"

	for (( i = 1; i < "${#COMP_WORDS[@]}"; i++ )); do
		(( processed_chars += "${#COMP_WORDS[${i}]}" ))

		# Check if COMP_WORDS[i] is a subcommand, but only set it when it's not set yet
		if [[ "${subcommands[*]}" =~ (^|.+ )${COMP_WORDS[$i]}($| .+) && "$subcommand" == "" ]]
		then
			subcommand="${COMP_WORDS[$i]}"
		elif [[
			"${subcommand}" == "use"
			&& "${COMP_WORDS[$i]}" == "--"
			&& ! (( processed_chars > "${COMP_POINT}" ))
		]]; then
			# Hand completion over to `c3c`
			(( i += 1 ))
			try_complete_c3c "$i"
			return
		fi
	done

	local global_options=(
		"--verbose" "-v" "--quiet" "-q" "--help" "-h"
	)
	local list_options=(
		"${global_options[@]}"
		"--installed" "-i"
		"--available" "-a"
		"--remote"
		"--prebuilt-installed"
		"--local-installed"
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
		"--remote"
		"--jobs" "-j"
	)
	local remove_options=(
		"--interactive" "-I"
		"--full-match" "-F"
		"--inactive"
		"--dry-run"
		"--allow-current"
		"--entire-remote"
		"--debug"
		"--from-source"
		"--checkout"
		"--local"
		"--remote"
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
		--checkout)
			_complete_options "$current" "$(get_available_checkouts)"
			return
			;;
		--local)
			local installed_locals
			mapfile -t installed_locals < <(c3vm list --local-installed)
			_complete_options "$current" "${installed_locals[*]}"
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
			if [[
				"${COMP_WORDS[*]}" != *" --from-source"*
				&& "${COMP_WORDS[*]}" != *" --local"*
			]]; then
				install_options+=( "$(get_available_versions)" )
			fi
			_complete_options "${current}" "${install_options[*]}"
			;;
		enable)
			if [[ "${COMP_WORDS[*]}" != *" --from-source"* ]]; then
				enable_options+=( "$(get_prebuilt_installed_versions)" )
			fi
			_complete_options "${current}" "${enable_options[*]}"
			;;
		update)
			_complete_options "${current}" "${update_options[*]}"
			;;
		remove)
			if [[ "${COMP_WORDS[*]}" != *" --from-source"* ]]; then
				remove_options+=( "$(get_prebuilt_installed_versions)" )
			fi
			_complete_options "${current}" "${remove_options[*]}"
			;;
		use)
			if [[ "${COMP_WORDS[*]}" != *" --from-source"* ]]; then
				use_options+=( "$(get_prebuilt_installed_versions)" )
			fi
			_complete_options "${current}" "${use_options[*]}"
			;;
		add-local)
			# Complete <path> with the normal bash completion for files
			# I tried also adding the global options, but was not succesful.
			compopt -o default
			return
			;;
		*)
			# status command I think? if others don't have flags they will be
			# catched here too
			_complete_options "${global_options[*]}"
	esac
}

complete -F _c3vm_complete c3vm
