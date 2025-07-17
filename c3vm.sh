#!/bin/bash

function print_long_help() {
	cat << 'LONG_HELP'
Welcome to a c3c version manager.
This is a bash script that can install and manage versions of the c3c compiler.
It can grab releases from Github or compile from scratch.

 Usage:
    c3vm [<command>] [<flags>] [<args>]

 Commands:
    - status                Print currently enabled compiler info.
    - list                  List (installed) compilers
    - install [<version>]   Install specified version, or latest when
                            version is omitted. Will also enable the installed
                            version (unless --dont-enable).
    - enable <version>      Enable an already installed version.
    - add-local <path> <name>
                            Link a local C3 compiler directory into c3vm.
                            The local compiler must use a regular CMake
                            build-system. The name will be the name of the
                            symlink, and used for 'update'.
    - update                Update the current active version.
    - remove <version>      Remove specified version (substring match)
    - use <version> [-- <args>]
                            Use the specified version for a single command
                            and pass the <args> to the compiler

 Flags:
 - Global:
    --verbose, -v           Log all info (default is just a little bit of info)
    --quiet, -q             Suppress all info (not errors)
    --help, -hh             Print this long help
    -h                      Print short help

 - List command:
    --installed, -i         List installed compilers (default)
    --available, -a         List all available compilers (from Github)

 - Install command:
    --debug                 Install the debug version
    --dont-enable           Do not enable the new version (keep old one active)
    --keep-archive          Keep the downloaded archive after extracting.
                            Not used when compiling from source.

    --from-source           Compile from source. Defaults to latest commit
                            on the default branch of remote c3lang/c3c but can
                            be tweaked with other flags.
    --checkout <ref>        Specify branch, tag or commit for --from-source as
                            you would pass it to git.
    --local <name>          Use a local repository with name <name>
    --remote <remote>       Use a remote for fetching prebuilt binaries from
                            (still from Github) or from fetching sourcecode,
                            defaults to c3lang/c3c.
                            Only supports Github remotes with tags/releases
                            following versions vx.y.z and 'latest-prerelease'.
    --jobs, -j <count>      Number of jobs to use with 'make -j <job-count>'
                            (Default 16)

 - Enable command:
    Same flags as 'install', except for '--dont-enable' or '--keep-archive'

 - Update command:
    Same flags as 'install', but '--checkout' only accepts branches.

 - Remove command:
    --interactive, -I       Prompt before removing a version
    --fixed-match, -F       Interpret <version> as fixed-string instead of
                            regex pattern
    --inactive              Remove all installed compilers except for the
                            currently enabled compiler
    --dry-run               Do everything and show everything except for actually
                            removing.
    --allow-current         Allow removing the current active version (default false).

 - Use command:
    --session               Output the exports to switch current compiler
                            version in your shell session.
                            Should be used as `eval "$(c3vm use --session <version>)"`.
    For the rest, same flags as 'install', without '--dont-enable',
    '--keep-archive' '--jobs'.

 Extra info, like example uses, directory layout for storing compilers and
 exit codes of c3vm can be found in the manpage.
LONG_HELP
}

function print_short_help() {
	cat << 'SHORT_HELP'
Usage: c3vm [<command>] [<flags>] [<args>]
Commands: list, install, enable, add-local, update, remove, use
Global flags: --verbose, --quiet, --help
SHORT_HELP
}

# Tweakable variables
dir_compilers="${XDG_DATA_HOME:-$HOME/.local/share}/c3vm"
dir_bin_link="$HOME/.local/bin/"


# All possible exit codes, has to match the help-string!
EXIT_OK=0
EXIT_MISSING_DIRS=1
EXIT_MISSING_TOOLS=2
EXIT_UNSUPPORTED_OS=3

EXIT_MULTIPLE_SUBCOMMANDS=10
EXIT_FLAG_ARGS_ISSUE=11
EXIT_FLAG_WITHOUT_SUBCOMMAND=12
EXIT_FLAG_WITH_WRONG_SUBCOMMAND=13
EXIT_CONTRADICTING_FLAGS=14
EXIT_UNKNOWN_ARG=15
EXIT_UNSUPPORTED_VERSION=16
EXIT_INVALID_VERSION=17

EXIT_STATUS_UNKNOWN_TYPE=20

# Reserved for list errors
# EXIT_LIST_=30-39

EXIT_INSTALL_NO_DIR=40
EXIT_INSTALL_UNKNOWN_VERSION=41
EXIT_INSTALL_DOWNLOAD_FAILED=42
EXIT_INSTALL_CURRENT_NO_SYMLINK=43
EXIT_INSTALL_NOT_C3VM_OWNED=44
EXIT_INSTALL_GIT_DIR=45
EXIT_INSTALL_UNRECOGNIZED_REMOTE=46
EXIT_INSTALL_CANT_CLONE=47
EXIT_INSTALL_NO_CMAKE=48
EXIT_INSTALL_BUILD_DIR=49
EXIT_INSTALL_NO_VALID_REMOTE=50
EXIT_INSTALL_UNKNOWN_REV=51
EXIT_INSTALL_BUILD_FAILURE=51

EXIT_ENABLE_BROKEN_SYMLINK=60
EXIT_ENABLE_NO_VERSION_FOUND=61
EXIT_ENABLE_MULTIPLE_VERSIONS_FOUND=61

EXIT_ADDLOCAL_NONEXISTING_PATH=70
EXIT_ADDLOCAL_INVALID_NAME=71

EXIT_UPDATE_NO_VERSION_FOUND=81

EXIT_REMOVE_FAILED_RM=90

EXIT_USE_VERSION_NOT_FOUND=100
EXIT_USE_MULTIPLE_VERSIONS_FOUND=101
EXIT_USE_NO_EXECUTABLE_FOUND=102


function ensure_directories() {
	for directory in "$dir_compilers" "$dir_bin_link"; do
		if ! [[ -e "$directory" && -d "$directory" ]]; then
			echo "$directory does not exist, but is needed for this script."
			echo -n "Create directory? [y/n] "
			read -r ans
			if [[ "$ans" == y ]]; then
				mkdir -p "$directory" || exit "$EXIT_MISSING_DIRS"
			else
				echo "Cannot continue without ${directory}, quitting..."
				exit "$EXIT_MISSING_DIRS"
			fi
		fi
	done

	mkdir -p "${dir_compilers}/git/"{local,remote}/
	mkdir -p "${dir_compilers}/prebuilt/"{releases,prereleases}/
}

# OS filled in by check_platform, used to download correct release from GitHub
operating_system=""

function check_platform() {
	local is_working_os="false"

	if [[ "$OSTYPE" == "linux-gnu"* ]]; then
		is_working_os="true"      # Linux
		operating_system="linux"
	elif [[ "$OSTYPE" == "darwin"* ]]; then
		is_working_os="true"      # MacOS
		operating_system="macos"
	fi

	if [[ "$is_working_os" != "true" ]]; then
		echo "Operating system '$OSTYPE' is not supported"
		exit "$EXIT_UNSUPPORTED_OS"
	fi
}

# Depends on '$operating_system' being set
function ensure_tools() {
	local missing_something="false"

	local needed_commands=(
		"curl" "git" "jq" "ln" "readlink" "unlink" "find" "realpath"
	)
	case "$operating_system" in
		linux)
			needed_commands+=( "tar" )
			;;
		macos)
			needed_commands+=( "unzip" )
			;;
	esac

	for command in "${needed_commands[@]}"; do
		if ! command -v "$command" >/dev/null; then
			echo "Missing '${command}'"
			missing_something="true"
		fi
	done

	if [[ "$missing_something" != "false" ]]; then
		exit "$EXIT_MISSING_TOOLS"
	fi
}

ensure_directories
check_platform
ensure_tools


# Default values that can be changed with subcommands and flags
verbose="false"
quiet="false"

subcommand=""


# Global options
version=""
remote="c3lang/c3c"
local_name=""
from_source="false"
from_rev="default"
keep_archive="false"
debug_version="false"
enable_after="true"
jobcount="16"

# List options
list_filter=""

# All-local options
add_local_path=""
add_local_name=""

# Remove options
remove_interactive="false"
remove_regex_match="true"
remove_inactive="false"
remove_dryrun="false"
remove_allow_current="false"

# Use options
use_session="false"
use_compiler_args=()


function check_subcommand_already_in_use() {
	if [[ "$subcommand" != "" ]]; then
		echo "Cannot specify more than one subcommand!" >&2
		echo "Subcommand '$subcommand' was already specified when you added '$1'" >&2
		exit "$EXIT_MULTIPLE_SUBCOMMANDS"
	fi
}

function check_flag_for_subcommand() {
	flag="$1"
	shift
	expected_subcommands=( "$@" )
	if [[ "$subcommand" == "" ]]; then
		IFS='/'; echo "Flag '${flag}' requires '${expected_subcommands[*]}' to be in front of it." >&2
		exit "$EXIT_FLAG_WITHOUT_SUBCOMMAND"
	fi

	local found_sc="false"
	for sc in "${expected_subcommands[@]}"; do
		if [[ "$subcommand" == "$sc" ]]; then
			found_sc="true"
			break
		fi
	done
	if [[ "$found_sc" != "true" ]]; then
		IFS='/'; echo "Flag '${flag}' does not belong to subcommand '${subcommand}' but to '${expected_subcommands[*]}'" >&2
		exit "$EXIT_FLAG_WITH_WRONG_SUBCOMMAND"
	fi
}

# Check if the version passed as argument is valid, and echo back a "normalised"
# version (which means that it adds a 'v' in front if needed)
return_check_valid_version=""
function check_valid_version() {
	if [[ "$1" =~ ^v?0\.[0-5]\..* ]]; then
		echo "Versions below v0.6.0 are not supported (asked for '${1}')" >&2
		exit "$EXIT_UNSUPPORTED_VERSION"
	fi
	if [[ "$1" =~ ^latest([-_]prerelease)?$ ]]; then
		return_check_valid_version="${1/_/-}"
		return
	fi
	if ! [[ "$1" =~ ^v?[0-9]\.[0-9]+\.[0-9]+(-debug)?$ ]]; then
		echo "Tried to use '$1' as version, but does not match the version-regex." >&2
		echo "A valid version is of the form (v)?<num>.<num>.<num>(-debug)? or latest(-prerelease)?" >&2
		exit "$EXIT_INVALID_VERSION"
	fi
	if [[ "$1" == "v"* ]]; then
		return_check_valid_version="$1"
	else
		return_check_valid_version="v$1"
	fi
}

if ! [[ "$1" ]]; then
	print_short_help
	exit "$EXIT_UNKNOWN_ARG"
fi

while [[ "$1" ]]; do case $1 in
# Global flags
	-v | --verbose )
		if [[ "$quiet" == "true" ]]; then
			echo "It is not possible to set '${1}' after '--quiet/-q'." >&2
			exit "$EXIT_CONTRADICTING_FLAGS"
		fi
		verbose="true"
		;;
	-q | --quiet)
		if [[ "$verbose" == "true" ]]; then
			echo "It is not possible to set '${1}' after '--verbose/-v'."
			exit "$EXIT_CONTRADICTING_FLAGS"
		fi
		quiet="true"
		;;
	-h)
		print_short_help
		exit "$EXIT_OK"
		;;
	--help | -hh)
		print_long_help
		exit "$EXIT_OK"
		;;

# Subcommands
	status)
		check_subcommand_already_in_use "status"
		subcommand="status"
		;;
	list)
		check_subcommand_already_in_use "list"
		subcommand="list"
		;;
	install)
		check_subcommand_already_in_use "install"
		subcommand="install"
		;;
	enable)
		check_subcommand_already_in_use "enable"
		subcommand="enable"
		;;
	add-local)
		check_subcommand_already_in_use "add-local"
		subcommand="add-local"
		;;
	update)
		check_subcommand_already_in_use "update"
		subcommand="update"
		;;
	remove)
		check_subcommand_already_in_use "remove"
		subcommand="remove"
		;;
	use)
		check_subcommand_already_in_use "use"
		subcommand="use"
		;;
	upgrade)
		echo "Why does @FoxKiana nag so much?"
		sleep 1
		echo "I don't think I'll understand..."
		sleep 1
		echo "."
		sleep 1
		echo "Sigh..."
		sleep 1
		echo "Ok then..."
		sleep 1
		c3vm_directory="$(realpath "$0" | xargs dirname)"
		c3vm_name="$(realpath "$0" | xargs basename)"
		if [[ -d "${c3vm_directory}/.git/" ]]; then
			git -C "$c3vm_directory" pull
		else
			url="https://raw.githubusercontent.com/BWindey/c3vm/refs/heads/main/c3vm.sh"
			curl --progress-bar -L -o "${c3vm_directory}/${c3vm_name}" "$url"
		fi
		exit
		;;

# List flags
	--installed | -i)
		check_flag_for_subcommand "$1" "list"
		if [[ "$list_filter" != "" ]]; then
			echo "It is not possible to filter on more than one category." >&2
			exit "$EXIT_CONTRADICTING_FLAGS"
		fi
		list_filter="installed"
		;;
	--available | -a)
		check_flag_for_subcommand "$1" "list"
		if [[ "$list_filter" != "" ]]; then
			echo "It is not possible to filter on more than one category." >&2
			exit "$EXIT_CONTRADICTING_FLAGS"
		fi
		list_filter="available"
		;;

# Multi-subcommand flags (mainly 'install')
	--dont-enable)
		check_flag_for_subcommand "$1" "install" "update"
		enable_after="false"
		;;
	--keep-archive)
		check_flag_for_subcommand "$1" "install" "update"
		keep_archive="true"
		;;

	--from-source)
		check_flag_for_subcommand "$1" "install" "update" "enable" "use"
		from_source="true"
		;;
	--checkout)
		check_flag_for_subcommand "$1" "install" "update" "enable" "use"
		if [[ "$#" -le 1 ]]; then
			echo "Expected argument <rev> after --checkout" >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		shift
		from_rev="$1"
		;;
	--local)
		check_flag_for_subcommand "$1" "install" "update" "enable" "use"
		if [[ "$#" -le 1 ]]; then
			echo "Expected argument <name> after --local" >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		shift
		local_name="$1"
		;;
	--remote)
		check_flag_for_subcommand "$1" "install" "update" "enable" "use"
		if [[ "$#" -le 1 ]]; then
			echo "Expected <remote> behind --remote" >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		elif [[ ! "$2" =~ ^[^/]+/[^/]+$  ]]; then
			echo "--remote did not get valid remote '$2'" >&2
			echo "The remote should be of the form <owner>/<project>" >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		shift
		remote="$1"
		;;
	--debug)
		case "$subcommand" in
			install | enable | update | use) debug_version="true" ;;
			"")
				echo "'--debug' is only supported for subcommands ('install', 'enable', 'update', 'use')." >&2
				exit "$EXIT_FLAG_WITHOUT_SUBCOMMAND"
				;;
			*)
				echo "'--debug' is not supported for subcommand '${subcommand}'" >&2
				exit "$EXIT_FLAG_WITH_WRONG_SUBCOMMAND"
				;;
		esac
		;;
	--jobs | -j)
		check_flag_for_subcommand "$1" "install" "update"
		if [[ "$#" -le 1 ]]; then
			echo "Expected <count> behind ${1}" >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		elif [[ ! "$2" =~ ^[0-9]+$  ]]; then
			echo "${1} did not get valid number '$2'" >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		shift
		jobcount="$1"
		;;

# Remove flags
	--interactive | -I)
		check_flag_for_subcommand "$1" "remove"
		remove_interactive="true"
		;;
	--no-regex | -F)
		check_flag_for_subcommand "$1" "remove"
		if [[ "$remove_inactive" == "true" ]]; then
			echo "It is not possible to use '${1}' together with '--inactive'." >&2
			exit "$EXIT_CONTRADICTING_FLAGS"
		fi
		remove_regex_match="false"
		;;
	--inactive)
		check_flag_for_subcommand "$1" "remove"
		if [[ "$remove_regex_match" == "false" ]]; then
			echo "It is not possible to use '--inactive' together with '--no-regex/-F'." >&2
			exit "$EXIT_CONTRADICTING_FLAGS"
		elif [[ "$remove_allow_current" == "true" ]]; then
			echo "It is not possible to use '--inactive' together with '--allow-current'." >&2
			exit "$EXIT_CONTRADICTING_FLAGS"
		fi
		remove_inactive="true"
		;;
	--dry-run)
		check_flag_for_subcommand "$1" "remove"
		remove_dryrun="true"
		;;
	--allow-current)
		check_flag_for_subcommand "$1" "remove"
		if [[ "$remove_inactive" == "true" ]]; then
			echo "It is not possible to use '--allow-current' together with '--inactive'" >&2
			exit "$EXIT_CONTRADICTING_FLAGS"
		fi
		remove_allow_current="true"
		;;

# Use flags
	--session)
		check_flag_for_subcommand "$1" "use"
		if [[ "${#use_compiler_args[@]}" -gt 0 ]]; then
			echo "Use '--session' without arguments after ' -- '" >&2
			exit "$EXIT_CONTRADICTING_FLAGS"
		fi
		use_session="true"
		;;
	--)
		check_flag_for_subcommand "$1" "use"
		if [[ "$use_session" == "true" ]]; then
			echo "Use '--session' without arguments after ' -- '" >&2
			exit "$EXIT_CONTRADICTING_FLAGS"
		fi
		# Skip the '--' and process all remaining args
		shift
		while [[ "$1" ]]; do
			use_compiler_args+=( "$1" )
			shift
		done
		;;

	# Anything that wasn't catched before is either an argument of a subcommand
	# or just something wrong that we can error on
	*)
		case "$subcommand" in
			status | list)
				echo "Received unknown argument for '${subcommand}': '${1}'" >&2
				exit "$EXIT_UNKNOWN_ARG"
				;;
			install | enable | use)
				if [[ "$version" != "" ]]; then
					echo "Version was already set to '${version}', cannot reset it to '${1}'" >&2
					exit "$EXIT_CONTRADICTING_FLAGS"
				fi
				check_valid_version "$1"
				version="${return_check_valid_version}"
				;;
			add-local)
				if [[ "$add_local_name" != "" ]]; then
					echo "Link-local path and name were already set, cannot reset it to '${1}'" >&2
					exit "$EXIT_CONTRADICTING_FLAGS"
				elif [[ "$add_local_path" != "" ]]; then
					add_local_name="$1"
				else
					add_local_path="$1"
				fi
				;;
			remove)
				# Seperate case because no version validity check needed
				if [[ "$version" != "" ]]; then
					echo "Version was already set to '${version}', cannot reset it to '${1}'" >&2
					exit "$EXIT_CONTRADICTING_FLAGS"
				fi
				version="$1"
				;;
			*)
				echo "Received unknown argument: '${1}'"
				exit "$EXIT_UNKNOWN_ARG"
				;;
		esac
		;;
esac; shift; done


# Check that the subcommands who need it got their arguments
# We do that here instead of in the argparsing because I want to allow
# subcommand-arguments behind flags.
# F.e.'c3vm remove --interactive v0.6*' is valid
case "$subcommand" in
	enable | use)
		if [[ "$from_source" != "true" && "$version" == "" ]]; then
			echo "Expected version behind '${subcommand}' subcommand." >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		;;
	add-local)
		if [[ "$add_local_path" == "" || "$add_local_name" ]]; then
			echo "Expected path and name behind 'add-local' subcommand." >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		if ! [[ -e "$add_local_path" ]]; then
			echo "Path '$add_local_path' does not exist." >&2
			exit "$EXIT_ADDLOCAL_NONEXISTING_PATH"
		fi
		if [[ "$add_local_name" =~ .*/.* ]]; then
			echo "'add-local' <name> cannot contain slashes ('/')" >&2
			exit "$EXIT_ADDLOCAL_INVALID_NAME"
		fi
		;;
	remove)
		if [[ "$version" == "" && "$remove_inactive" != "true" ]]; then
			echo "Expected version behind 'remove' subcommand." >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		if [[ "$remove_regex_match" == "false" ]]; then
			# Catch the echo in a variable to not accidently print to stdout
			check_valid_version "$version"
			version="$return_check_valid_version"
		fi
		;;
esac

function log_info() {
	[[ "$quiet" != "true" ]] && echo "$1"
}

function log_verbose() {
	[[ "$verbose" == "true" ]] && echo "$1"
}

# Here follow the implementations of each subcommand.
# They assume that argument-parsing happened correctly, and will use the
# global variables.
#

function is_arch_distro() {
	grep --quiet --ignore-case \
		'^ID(_LIKE)?=["'\'']\?arch["'\'']\?$' \
		/etc/os-release
	return "$?"
}

# NOTE:
# 	This function is the one that does the actual building.
# 	If you need to change something for your platform, then change it here.
function actually_build_from_source() {
	local source_dir="$1"
	local output_dir="$2"
	local cmake_build_type="Release"

	if [[ "$debug_version" == "true" ]]; then
		cmake_build_type="Debug"
	fi

	log_info "Building inside '${output_dir}'..."

	local cmake_flags=(
		-D CMAKE_BUILD_TYPE="${cmake_build_type}"
		-S "${source_dir}"
		-B "${output_dir}"
	)

	if is_arch_distro; then
		echo "What are you doing on Arch??? Get a real distro, like Void Linux."
		cmake_flags+=( -D C3_LINK_DYNAMIC=ON )
	fi

	local make_flags=(
		--jobs="${jobcount}"
		-C "${output_dir}"
	)

	if [[ "$verbose" != "true" ]]; then
		cmake_flags+=( --log-level=ERROR )
		make_flags+=( --quiet )
	fi


	if [[ "$quiet" == "true" ]]; then
		if ! cmake "${cmake_flags[@]}" >/dev/null; then
			echo "Failed to exectute 'cmake ${cmake_flags[*]}'" >&2
			exit "$EXIT_INSTALL_BUILD_FAILURE"
		fi

		if ! make "${make_flags[@]}" >/dev/null; then
			echo "Failed to execute 'make ${make_flags[*]}'" >&2
			exit "$EXIT_INSTALL_BUILD_FAILURE"
		fi
	else
		if ! cmake "${cmake_flags[@]}"; then
			echo "Failed to call CMake" >&2
			exit "$EXIT_INSTALL_BUILD_FAILURE"
		fi

		if ! make "${make_flags[@]}"; then
			echo "Failed to execute make" >&2
			exit "$EXIT_INSTALL_BUILD_FAILURE"
		fi
	fi
}

function c3vm_status() {
	local c3c_path
	local enabled_compiler

	c3c_path="$(which c3c 2>/dev/null)"

	if [[ "$c3c_path" == "" ]]; then
		echo "No c3c in \$PATH."
		exit "$EXIT_OK"
	elif [[ ! -h "$c3c_path" ]]; then
		echo "'${c3c_path}' is not managed by c3vm (not a symlink)."
		exit "$EXIT_OK"
	fi

	enabled_compiler="$(readlink "$c3c_path")"

	if ! [[ "$enabled_compiler" == "$dir_compilers"* ]]; then
		echo "Currently enabled compiler is not managed by c3vm!"
		exit "$EXIT_OK"
	fi
	local without_pref="${enabled_compiler#"$dir_compilers"/}"
	local type="${without_pref%%/*}" # prebuilt or git
	local rest="${without_pref#*/}"

	case "$type" in
		git)
			local git_type="${rest%%/*}"
			rest="${rest#*/}"

			case "$git_type" in
				local)
					# TODO:
					;;
				remote)
					local remote_name="${rest%%/*}"
					rest="${rest#*build/}"
					local build_folder="${rest%%/*}"

					local build_type="${build_folder##*_}" # release/debug
					local git_rev="${build_folder%"$build_type"}"
					if [[ "$git_rev" == "" ]]; then
						git_rev="default branch"
					else
						git_rev="rev ${git_rev%_}"
					fi

					echo "Current active compiler: compiled from source from remote '${remote_name}'."
					echo "${build_type^} build on ${git_rev}."
					;;
				*)
					echo "Unexpected git-type: ${git_type}" >&2
					echo "Kapoetskie" >&2
					exit "$EXIT_STATUS_UNKNOWN_TYPE"
					;;
			esac
			;;
		prebuilt)
			local release_type="${rest%%/*}"
			rest="${rest#*/}"
			local release_version="${rest%%/*}"

			echo "Current active compiler: ${type} ${release_type%s} on version ${release_version}"
			[[ "$verbose" == "true" ]] && echo "Stored in: ${enabled_compiler}"
			;;
		*)
			echo "Unexpected type '${type}'." >&2
			echo "Please check the man-page for how to fix this." >&2
			exit "$EXIT_STATUS_UNKNOWN_TYPE"
			;;
	esac
}

function c3vm_list_installed() {
	tree -L 2 --noreport "${dir_compilers}/prebuilt" |
		sed '1s/^.*$/Prebuilt:/'
	echo ''

	# Sadly the `git/` folder is a loooot more work, as `tree` does not provide
	# a neat way to filter and manipulate the output like we want.
	# TODO: locals

	declare -A remote_targets

	# Gather all remotes with their build-targets
	for remote_path in "${dir_compilers}/git/remote/"*; do
		remote_name="$(basename "$remote_path")"
		build_dir="${remote_path}/build"

		# Skip remotes without build/ directory
		if [[ ! -d "$build_dir" ]]; then
			remote_targets["$remote_name"]="__no_targets__"
			continue
		fi

		targets=()
		for target in "$build_dir"/*; do
			[[ -d "$target" ]] && targets+=("$(basename "$target")")
		done

		if [[ "${#targets[@]}" -eq 0 ]]; then
			echo "Remote '$remote_name' has empty 'build/' folder!" >&2
			continue
		fi

		remote_targets["$remote_name"]="${targets[*]}"
	done

	# Print it!
	echo "From source:"

	# Get sorted list of remotes
	readarray -t remotes < <(printf '%s\n' "${!remote_targets[@]}" | sort)

	for r_index in "${!remotes[@]}"; do
		remote="${remotes[$r_index]}"
		prefix_1="└──"
		[[ $r_index -lt $((${#remotes[@]} - 1)) ]] && prefix_1="├──"
		echo "${prefix_1} ${remote}"

		prefix_1="    "
		[[ $r_index -lt $((${#remotes[@]} - 1)) ]] && prefix_1="│   "

		IFS=' ' read -r -a targets <<< "${remote_targets[$remote]}"
		for t_index in "${!targets[@]}"; do
			prefix="└──"
			[[ $t_index -lt $((${#targets[@]} - 1)) ]] && prefix="├──"
			echo "${prefix_1}${prefix} ${targets[$t_index]}"
		done
	done
}

function get_available_versions() {
	log_verbose "Getting the available version from GitHub..."
	curl -s "https://api.github.com/repos/${remote}/releases" \
	| jq -r '.[].tag_name' \
	| grep "^\(v[0-9]\+\(\.[0-9]\+\)\{2\}\|latest-prerelease\)$"
}

function c3vm_list_available() {
	get_available_versions
}

function c3vm_list() {
	case "$list_filter" in
		"" | installed)
			c3vm_list_installed
			;;
		available)
			c3vm_list_available
			;;
	esac
}

function determine_download_release() {
	if [[ "$version" == "" ]]; then
		# Get available versions and take second in list
		version="$(get_available_versions | sed -n '2P')"
	fi
}

return_determine_directory=""
function determine_directory_prebuilt() {
	determine_download_release

	local result="${dir_compilers}/prebuilt"

	case "${version}" in
		latest-prerelease)
			result="${result}/prereleases/latest-prereleases_" # Leave open
			;;
		v*)
			result="${result}/releases/${version}"
			;;
		*)
			echo "Encountered unexpected error: did not recognize version '${version}'" >&2
			exit "$EXIT_INSTALL_UNKNOWN_VERSION"
			;;
	esac

	if [[ "$debug_version" == "true" ]]; then
		result="${result}-debug"
	fi
	return_determine_directory="${result}"
}

# This function determines which directory to use for the operations from all
# the globals like 'version', 'from_source', 'from_rev', ...
function determine_directory_from_globals() {
	if [[ "$from_source" == "true" ]]; then
		echo "TODO"
	else
		determine_directory_prebuilt
	fi
}

# This function creates the necessary directories if needed, exits the script
# when needed and returns 0 when everything can continue or 1 when download
# can be aborted because the requested version is already installed
function ensure_download_directory() {
	local output_dir="$1"

	# If the directory does not exist, create it
	if [[ ! -e "$output_dir" ]]; then
		if ! mkdir -p "$output_dir"; then
			echo "Failed to create '$output_dir'." >&2
			exit "$EXIT_INSTALL_NO_DIR"
		fi
		return 0
	fi

	# If it exists, check if it contains a c3c executable
	# The '| grep -q .' trick ensures we get a return value to compare
	if find "$output_dir" -type f -executable -name "c3c" | grep -q .; then
		# c3c already installed in this directory
		echo "Requested version already installed in ${output_dir}."
		return 1
	else
		echo "'$output_dir' already exists but does not contain a 'c3c' binary."
		echo -n "Continue and overwrite directory? [y/n] "
		read -r ans
		if [[ "$ans" == y ]]; then
			if ! rm -r "${output_dir}"; then
				echo "Failed to remove '$output_dir' before recreating." >&2
				exit "$EXIT_INSTALL_NO_DIR"
			fi
			if ! mkdir -p "$output_dir"; then
				echo "Failed to create '$output_dir'." >&2
				exit "$EXIT_INSTALL_NO_DIR"
			fi
		else
			echo "Aborting install." >&2
			exit "$EXIT_INSTALL_NO_DIR"
		fi
	fi
}

function enable_compiler_symlink() {
	local output_dir="$1"
	local symlink_location="$HOME/.local/bin/c3c"

	echo "Linking (installed) executable to ${symlink_location}..."

	# Check first if it's a symlink, so we can detect if it's broken if -e
	# returns false
	if [[ -h "${symlink_location}" ]]; then
		if [[ ! -e "${symlink_location}" ]]; then
			# Broken symlink
			echo "Symlink '${symlink_location}' is broken."
			echo "It currently points to:"
			readlink "$symlink_location"
			echo -n "Permission to overwrite? [y/n] "
			read -r ans
			if [[ "$ans" ]]; then
				unlink "$symlink_location"
			else
				echo "Cannot continue before broken link is removed or fixed." >&2
				exit "$EXIT_ENABLE_BROKEN_SYMLINK"
			fi
		elif [[ "$(readlink "$symlink_location")" != "$dir_compilers"* ]]; then
			echo "Symlink is not managed by 'c3vm' (points to '$(readlink "$symlink_location")')"
			echo -n "Unlink and link c3vm-installed version? [y/n] "
			read -r ans
			if [[ "$ans" == y ]]; then
				unlink "$symlink_location"
			else
				echo "Aborting install." >&2
				exit "$EXIT_INSTALL_NOT_C3VM_OWNED"
			fi
		else
			unlink "$symlink_location"
		fi

	elif [[ -e "${symlink_location}" ]]; then
		# Not a symlink but does exist -> regular file
		echo "'${symlink_location}' exists but is not a symlink, aborting installation" >&2
		exit "$EXIT_INSTALL_CURRENT_NO_SYMLINK"
	fi

	# Not hardcoding path because macos zips are of the form 'macos/c3c'
	# while the linux tar.gz is of the form 'c3/c3c'.
	local exe_path
	exe_path="$(find "${output_dir}" -type f -executable -name "c3c" -exec realpath '{}' \;)"
	ln -s "${exe_path}" "$HOME/.local/bin/c3c"
}

function download_known_release() {
	determine_directory_prebuilt
	local output_dir="${return_determine_directory}"

	if [[ "$output_dir" == *"latest-prerelease" ]]; then
		local current_date
		current_date="$(date +%Y%M%d_%H%S)" # Unique per second
		output_dir="${output_dir}${current_date}"
	fi

	# Determine the name of the file to download
	local asset_name="c3-${operating_system}"
	local extension=""
	case "$operating_system" in
		linux) extension="tar.gz" ;;
		macos) extension="zip" ;;
	esac

	if [[ "$debug_version" == "true" ]]; then
		asset_name="${asset_name}-debug"
	fi
	asset_name="${asset_name}.${extension}"

	# Set up the output directory
	if ! ensure_download_directory "$output_dir"; then
		# Directory already contains c3c -> just enable if requested
		if [[ "$enable_after" == "true" ]]; then
			enable_compiler_symlink "$output_dir"
		fi
		exit "$EXIT_OK"
	fi

	local url="https://github.com/${remote}/releases/download/${version}/${asset_name}"
	local output_file="${output_dir}/${asset_name}"

	# Download the file
	log_info "Downloading ${url}..."
	curl --progress-bar --location --output "${output_file}" "$url"

	# Check for too small file or HTML error-page
	local file_size
	file_size=$(wc -c < "${output_file}") # '<' to only get count, no name
	if [[ "$file_size" -lt 1000000 ]] ||  # < 1 MB (normal compiler is >40MB)
		grep -qE '<html|Not Found' "${output_file}"
	then
		echo "Download failed or invalid archive received." >&2
		rm "${output_file}"
		exit "$EXIT_INSTALL_DOWNLOAD_FAILED"
	fi

	echo "Extracting ${asset_name}..."
	# TODO: handle verbose/quiet options
	case "$extension" in
		tar.gz)
			tar --extract --directory="${output_dir}" --file="${output_dir}/${asset_name}"
			;;
		zip)
			unzip "${output_dir}/${asset_name}" -d "${output_dir}"
	esac

	if [[ "$keep_archive" != "true" ]]; then
		echo "Removing archive..."
		rm "${output_dir}/${asset_name}"
	fi

	if [[ "$enable_after" == "true" ]]; then
		enable_compiler_symlink "$output_dir"
	fi
}

# Signal if we need to git clone first or if it already exists
return_ensure_remote_git_directory="true"
function ensure_remote_git_directory() {
	local git_dir="$1"

	if [[ -e "$git_dir" ]]; then
		if ! [[ -e "${git_dir}/.git/" || -d "${git_dir}/.git/" ]]; then
			echo "'${git_dir}' already exists but is not a git repository."
			echo "Continue and overwrite directory? [y/n] "
			read -r ans
			if [[ "$ans" == y ]]; then
				if ! rm -r "${git_dir}"; then
					echo "Failed to remove '${git_dir}' before recreating." >&2
					exit "$EXIT_INSTALL_NO_DIR"
				fi
				if ! mkdir -p "${git_dir}"; then
					echo "Failed to create '${git_dir}'." >&2
					exit "$EXIT_INSTALL_NO_DIR"
				fi
			else
				echo "Aborting install." >&2
				exit "$EXIT_INSTALL_NO_DIR"
			fi

		else
			# Check if it the git-directory is the requested remote
			local current_remote_link
			current_remote_link="$(
				git -C "$git_dir" remote -v 2>/dev/null |
					grep -F "fetch" |
					tr '\t' ' ' |
					cut -d ' ' -f 2
			)"

			case "$current_remote_link" in
				"https://github.com/${remote}"* | "git@github.com:${remote}"*)
					# Everything fine
					;;
				*)
					echo "Did not recognize git-remote link: '${current_remote_link}'" >&2
					echo "while checking if '${git_dir}' has the expected remote." >&2
					exit "$EXIT_INSTALL_UNRECOGNIZED_REMOTE"
			esac

			return_ensure_remote_git_directory="false" # git repo already exists
		fi
	else
		mkdir -p "$git_dir"
		echo "NOTE: this could be the first time you're building from source with c3vm."
		echo "      If something goes wrong, please look at https://github.com/c3lang/c3c/?tab=readme-ov-file#compiling"
		echo "      for your platforms instructions, and modify the function 'actually_build_from_source'"
		echo "      accordingly. (Arch Linux is known to require modification.)"
		echo "      The function can be found just below this scripts argument parsing, around line 580."
	fi
}

return_determine_git_build_dir=""
function determine_git_build_dir() {
	local git_dir="$1"

	local build_dir="${git_dir}/build"

	# Check if 'origin' is
	local remotes
	remotes="$(git -C "$git_dir" remote show -n)"
	if [[ "$remotes" != *"origin"* ]]; then
		echo "Could not find remote 'origin', which is required to make this work." >&2
		exit "$EXIT_INSTALL_NO_VALID_REMOTE"
	fi
	local default_branch
	default_branch="$(git -C "$git_dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"
	if [[ "$default_branch" == "" ]]; then
		echo "Did not find a default branch." >&2
		exit "$EXIT_INSTALL_NO_VALID_REMOTE"
	fi

	# If not default branch, determine what to add before release/debug
	if [[ "$from_rev" != "default" ]]; then
		# Check if it's a branch
		if git -C "$git_dir" show-ref --verify --quiet "refs/heads/${from_rev}"; then
			build_dir="${build_dir}/${from_rev}_"

		# Check if it's a tag
		elif git -C "$git_dir" show-ref --verify --quiet "refs/tags/${from_rev}"; then
			build_dir="${build_dir}/${from_rev}_"

		# Check if it's a valid commit (full or short hash)
		elif git -C "$git_dir" rev-parse --quiet --verify "${from_rev}^{commit}" >/dev/null; then
			local commit_hash
			commit_hash="$(git -C "$git_dir" rev-parse --quiet --verify "${from_rev}^{commit}" >/dev/null)"
			build_dir="${build_dir}/${commit_hash::7}"

		else
			echo "Git does not know '${from_rev}'." >&2
			exit "$EXIT_INSTALL_UNKNOWN_REV"
		fi
	else
		build_dir="${build_dir}/"
	fi

	if [[ "$debug_version" == "true" ]]; then
		build_dir="${build_dir}debug"
	else
		build_dir="${build_dir}release"
	fi

	return_determine_git_build_dir="${build_dir}"
}

# This function assumes you're already inside the git repository, and will
# return inside the created build-folder from where 'cmake ../..' can be executed
return_install_setup_build_folders=""
function install_setup_build_folders() {
	local git_dir="$1"

	determine_git_build_dir "$git_dir"
	local build_dir="${return_determine_git_build_dir}"

	if ! [[ -e "$build_dir" ]]; then
		if ! mkdir -p "$build_dir"; then
			echo "Failed to create '${build_dir}' to build compiler in." >&2
			exit "$EXIT_INSTALL_BUILD_DIR"
		fi
	fi
	if ! [[ -d "$build_dir" ]]; then
		echo "'${build_dir}' is not a directory, but is needed to build in."
		echo -n "Permission to remove it? [y/n] "
		read -r ans
		if [[ "$ans" == y ]]; then
			if ! rm "$build_dir"; then
				echo "Failed to remove ${build_dir}." >&2
				exit "$EXIT_INSTALL_BUILD_DIR"
			fi
		else
			echo "Cannot continue without '${build_dir}' available." >&2
			exit "$EXIT_INSTALL_BUILD_DIR"
		fi
	fi

	# Enter build directory
	return_install_setup_build_folders="${build_dir}"
}

function install_from_source() {
	local git_dir="${dir_compilers}/git/remote/${remote/\//_}"
	ensure_remote_git_directory "$git_dir"

	if ! cd "$git_dir"; then
		echo "Failed to enter '${git_dir}' to install '${version}' in it"
		exit "$EXIT_INSTALL_GIT_DIR"
	fi

	if [[ "$return_ensure_remote_git_directory" == "true" ]]; then
		echo -n "To clone the remote repository, use https or ssh? [h/s] "
		read -r ans
		local clone_link
		case "$ans" in
			h)
				clone_link="https://github.com/${remote}.git"
				;;
			s)
				clone_link="git@github.com:${remote}.git"
				;;
			*)
				echo "Unknown answer '${ans}' (expected 'h' or 's')" 2>&1
				exit "$EXIT_INSTALL_CANT_CLONE"
				;;
		esac

		if ! git clone "${clone_link}" "${git_dir}" ; then
			echo "Failed to clone '${clone_link}'" >&2
			exit "$EXIT_INSTALL_CANT_CLONE"
		fi
	fi

	if ! [[ -e "${git_dir}/CMakeLists.txt" ]]; then
		echo "Couldn't find CMakeLists.txt inide ${git_dir}, cannot build." >&2
		exit "$EXIT_INSTALL_NO_CMAKE"
	fi

	for command in "cmake" "make"; do
		if ! command -v "$command" >/dev/null; then
			echo "Missing '${command}' to build"
			exit "$EXIT_MISSING_TOOLS"
		fi
	done

	install_setup_build_folders "${git_dir}"

	actually_build_from_source "${git_dir}" "${return_install_setup_build_folders}"

	if [[ "$enable_after" ]]; then
		enable_compiler_symlink "$(pwd)"
	fi
}

function c3vm_install() {
	if [[ "$from_source" == "true" ]]; then
		install_from_source
	else
		download_known_release
	fi
}

function enable_prebuilt() {
	local to_search="${version}"
	if [[ "$debug_version" == "true" ]]; then
		to_search="${to_search}-debug"
	fi

	local matches
	mapfile -t matches < <(find "${dir_compilers}/prebuilt/" -type d -name "${to_search}*" 2>/dev/null)

	match_count="${#matches[@]}"

	case "$match_count" in
		0)
			echo "No compilers installed that match ${to_search}" >&2
			exit "$EXIT_ENABLE_NO_VERSION_FOUND"
			;;
		1)
			enable_compiler_symlink "${matches[0]}"
			exit "$EXIT_OK"
			;;
		*)
			echo "Found multiple matches:"
			printf '%s\n' "${matches[@]}"
			echo "Run command again with one of those."
			exit "$EXIT_ENABLE_MULTIPLE_VERSIONS_FOUND"
			;;
		esac
	}

function enable_from_source() {
	local git_dir="${dir_compilers}/git/remote/${remote/\//_}"

	if [[ ! -d "$git_dir" || ! -d "${git_dir}/.git" ]]; then
		echo "Git repository not found in '${git_dir}'." >&2
		echo "Try running: c3vm install --from-source ..." >&2
		exit "$EXIT_ENABLE_NO_VERSION_FOUND"
	fi

	determine_git_build_dir "$git_dir"
	local build_dir="${return_determine_git_build_dir}"

	if [[ ! -d "$build_dir" ]]; then
		echo "Build folder not found: ${build_dir}" >&2
		echo "Try running: c3vm install --from-source ..." >&2
		exit "$EXIT_ENABLE_NO_VERSION_FOUND"
	fi

	enable_compiler_symlink "$build_dir"
}

function c3vm_enable() {
	if [[ "$from_source" == "true" ]]; then
		enable_from_source
	else
		enable_prebuilt
	fi
}

function update_from_source() {
	local git_dir="${dir_compilers}/git/remote/${remote/\//_}"

	if [[ ! -d "$git_dir" || ! -d "${git_dir}/.git" ]]; then
		echo "Git repository not found in '${git_dir}'." >&2
		echo "Try running: c3vm install --from-source ..." >&2
		exit "$EXIT_UPDATE_NO_VERSION_FOUND"
	fi

	determine_git_build_dir "$git_dir"
	local build_dir="${return_determine_git_build_dir}"

	if [[ ! -d "$build_dir" ]]; then
		echo "Build folder not found: ${build_dir}" >&2
		echo "Try running: c3vm install --from-source ..." >&2
		exit "$EXIT_UPDATE_NO_VERSION_FOUND"
	fi

	local answer
	answer="$(git -C "${git_dir}" pull 2>/dev/null)"
	if [[ "$answer" != "Already up to date." ]]; then
		actually_build_from_source "${git_dir}" "${build_dir}"
	else
		echo "Already up to date."
	fi

	if [[ "$enable_after" == "true" ]]; then
		enable_compiler_symlink "$build_dir"
	fi
}

function c3vm_update() {
	if [[ "$from_source" == "true" ]]; then
		update_from_source
	else
		download_known_release
	fi
}

current_active_version=""
function get_current_version() {
	current_active_version="$(which c3c 2>/dev/null | xargs readlink 2>/dev/null)"
}

function is_removeable_version() {
	local release_dir="$1"
	local release
	release="$(basename "$release_dir")"

	if [[ "$remove_inactive" == "true" ]]; then
		if [[ "$current_active_version" != "$release_dir"* ]]; then
			return 0
		else
			return 1
		fi
	fi

	if [[ "$release" != *"$version"* ]]; then
		return 1
	elif [[ "$remove_regex_match" != "true" && "$release" != "$version" ]]; then
		return 1
	fi
}

function c3vm_remove() {
	local found_match="false"

	local dir_releases="${dir_compilers}/prebuilt/releases/"
	local dir_prerels="${dir_compilers}/prebuilt/prereleases/"

	get_current_version

	local release

	for release_dir in "${dir_releases}"* "${dir_prerels}"*; do
		release="$(basename "$release_dir")"
		if [[ "$release" == "*" ]]; then continue; fi # Empty dir

		if ! is_removeable_version "$release_dir"; then
			continue
		fi

		if [[ "$remove_allow_current" != "true" && "$current_active_version" == "$release_dir"* ]]
		then
			log_info "Cannot remove '${release}' as it is currently active (use '--allow-current' if needed)."
			continue
		fi

		if [[ "$remove_interactive" == "true" ]]; then
			echo -n "Remove version '$release'? [y/n] "
			read -r ans
			if [[ "$ans" != y ]]; then
				log_info "Skipped '$release'."
				continue
			fi
		fi
		if [[ "$remove_dryrun" != "true" ]]; then
			if ! rm -r "$release_dir"; then
				echo "Failed to remove '${release_dir}'." >&2
				exit "$EXIT_REMOVE_FAILED_RM"
			fi
		fi
		log_info "Removed '$release'."
		if [[ "$current_active_version" == "$release_dir"* ]]; then
			log_info "The removed version was the currently active version."
			log_info "Use 'c3vm enable <version>' to enable a new version."
			log_info "Removing (now broken) symlink..."
			# Safe to unlink (managed by c3vm) as the current active version
			# matches one of the versions inside '~/.local/bin/c3vm/'
			unlink "$HOME/.local/bin/c3c"
		fi
		found_match="true"
	done

	if [[ "$found_match" != "true" ]]; then
		log_info "No matches found."
	fi

	# TODO: git directories? How finegrained?
}

function use_prebuilt() {
	determine_directory_prebuilt
	local found_version="${return_determine_directory}"

	if ! [[ -d "$found_version" ]]; then
		echo "Could not find installed version '${version}'." >&2
		exit "$EXIT_USE_VERSION_NOT_FOUND"
	fi

	local executable_path
	executable_path="$(find "${found_version}" -type f -executable -name "c3c")"

	if ! [[ -e "$executable_path" ]]; then
		echo "Could not find the 'c3c' executable inside '${found_version}'" >&2
		exit "$EXIT_USE_NO_EXECUTABLE_FOUND"
	fi

	if [[ "$use_session" == "true" ]]; then
		echo "export PATH=\"$(dirname "$executable_path"):\$PATH\""
	else
		local command=( "${executable_path}" "${use_compiler_args[@]}" )
		"${command[@]}"
	fi
}

function c3vm_use() {
	use_prebuilt
}

case "$subcommand" in
	status)
		c3vm_status
		;;
	list)
		c3vm_list
		;;
	install)
		c3vm_install
		;;
	enable)
		c3vm_enable
		;;
	update)
		c3vm_update
		;;
	remove)
		c3vm_remove
		;;
	use)
		c3vm_use
		;;
	*)
		echo "'${subcommand}' not implemented yet"
esac
