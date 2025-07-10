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
    - remove <version>      Remove specified version (regex match with grep)
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

 - Enable command:
    --debug                 Enable the debug version

 - Update command:
    Same flags as 'install', but '--checkout' only accepts branches.

 - Remove command:
    --interactive, -I       Prompt before removing a version
    --no-regex, -F          Interpret <version> as fixed-string instead of
                            regex pattern
    --inactive              Remove all installed compilers except for the
                            currently enabled compiler

 - Use command:
    --debug                 Use debug version
    --session               Output the exports to switch current compiler
                            version in your shell session.
                            Should be used as `eval "$(c3vm use --session <version>)"`.

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

EXIT_INSTALL_NO_DIR=30
EXIT_INSTALL_UNKNOWN_VERSION=31
EXIT_INSTALL_DOWNLOAD_FAILED=32
EXIT_INSTALL_CURRENT_NO_SYMLINK=33
EXIT_INSTALL_NOT_C3VM_OWNED=34
EXIT_INSTALL_GIT_DIR=35

EXIT_ENABLE_BROKEN_SYMLINK=40

EXIT_ADDLOCAL_NONEXISTING_PATH=50
EXIT_ADDLOCAL_INVALID_NAME=51


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

install_version="latest"
enable_version=""
remove_version=""
use_version=""

list_filter=""

# Global options
remote="c3lang/c3c"

install_keep_archive="false"
install_debug="false"
enable_after_install="true"
install_local=""
install_from_source="false"
install_from_rev="master"

enable_debug=""

add_local_path=""
add_local_name=""

update_keep_archive="false"
update_debug="false"
enable_after_update="true"
update_local=""
update_from_source="false"
update_from_branch=""

remove_version=""
remove_interactive="false"
remove_regex_match="true"
remove_inactive="false"

use_version=""
use_debug="false"
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

# Install && update flags
	--dont-enable)
		check_flag_for_subcommand "$1" "install" "update"
		case "$subcommand" in
			install) enable_after_install="false" ;;
			update)  enable_after_update="false"  ;;
		esac
		;;
	--keep-archive)
		check_flag_for_subcommand "$1" "install" "update"
		case "$subcommand" in
			install) install_keep_archive="true" ;;
			update)  update_keep_archive="true"  ;;
		esac
		;;

	--from-source)
		check_flag_for_subcommand "$1" "install" "update"
		case "$subcommand" in
			install) install_from_source="true" ;;
			update)  update_from_source="true"  ;;
		esac
		;;
	--checkout)
		check_flag_for_subcommand "$1" "install" "update"
		if [[ "$#" -le 1 ]]; then
			echo "Expected argument <rev> after --checkout" >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		shift
		case "$subcommand" in
			install) install_from_rev="$1"  ;;
			update) update_from_branch="$1" ;;
		esac
		;;
	--local)
		check_flag_for_subcommand "$1" "install" "update"
		if [[ "$#" -le 1 ]]; then
			echo "Expected argument <name> after --local" >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		shift
		case "$subcommand" in
			install) install_local="$1" ;;
			update)  update_local="$1"  ;;
		esac
		;;
	--remote)
		check_flag_for_subcommand "$1" "install" "update"
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

# Remove flags
	--interactive | -I)
		check_flag_for_subcommand "$1" "remove"
		remove_interactive="true"
		;;
	--no-regex | -F)
		check_flag_for_subcommand "$1" "remove"
		remove_regex_match="false"
		;;
	--inactive)
		check_flag_for_subcommand "$1" "remove"
		remove_inactive="true"
		;;

# Use flags
	--session)
		check_flag_for_subcommand "$1" "use"
		use_session="true"
		;;
	--)
		check_flag_for_subcommand "$1" "use"
		shift
		while [[ "$1" ]]; do
			use_compiler_args+=( "$1" )
			shift
		done
		;;

# Multi-command flags
	--debug)
		case "$subcommand" in
			install) install_debug="true" ;;
			enable)  enable_debug="true"  ;;
			update)  update_debug="true"  ;;
			use)     use_debug="true"     ;;
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

	# Anything that wasn't catched before is either an argument of a subcommand
	# or just something wrong that we can error on
	*)
		case "$subcommand" in
			status | list | version)
				echo "Received unknown argument for '${subcommand}': '${1}'" >&2
				exit "$EXIT_UNKNOWN_ARG"
				;;
			install)
				if [[ "$install_version" != "latest" && "$1" != "latest" ]]; then
					echo "Version was already set to '${install_version}', cannot reset it to '${1}'" >&2
					exit "$EXIT_CONTRADICTING_FLAGS"
				fi
				check_valid_version "$1"
				install_version="${return_check_valid_version}"
				;;
			enable)
				if [[ "$enable_version" != "" ]]; then
					echo "Version was already set to '${install_version}', cannot reset it to '${1}'" >&2
					exit "$EXIT_CONTRADICTING_FLAGS"
				fi
				check_valid_version "$1"
				enable_version="${return_check_valid_version}"
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
				if [[ "$remove_version" != "" ]]; then
					echo "Version was already set to '${remove_version}', cannot reset it to '${1}'" >&2
					exit "$EXIT_CONTRADICTING_FLAGS"
				fi
				# No validity-check because this can be a regex
				remove_version="$1"
				;;
			use)
				if [[ "$use_version" != "" ]]; then
					echo "Version was already set to '${use_version}', cannot reset it to '${1}'" >&2
					exit "$EXIT_CONTRADICTING_FLAGS"
				fi
				check_valid_version "$1"
				use_version="${return_check_valid_version}"
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
		if [[ "$enable_version" == "" ]]; then
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
		if [[ "$remove_version" == "" ]]; then
			echo "Expected version behind 'remove' subcommand." >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		if [[ "$remove_regex_match" == "false" ]]; then
			# Catch the echo in a variable to not accidently print to stdout
			check_valid_version "$remove_version"
		fi
		;;
esac

function log_info() {
	if [[ "$quiet" != "true" ]]; then
		echo "$1"
	fi
}

function log_verbose() {
	if [[ "$verbose" == "true" ]]; then
		echo "$1"
	fi
}

# Here follow the implementations of each subcommand.
# They assume that argument-parsing happened correctly, and will use the
# global variables.

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
			# TODO:
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
	# TODO: implement
	echo "TODO"
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
		installed)
			c3vm_list_installed
			;;
		available)
			c3vm_list_available
			;;
	esac
}

function determine_download_release() {
	if [[ "$install_version" == "latest" ]]; then
		# Get available versions and take second in list
		get_available_versions | sed -n '2P'
	else
		echo "$install_version"
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
	local version
	version="$(determine_download_release)"

	# Determine output directory
	local output_dir="${dir_compilers}/prebuilt"
	case "${version}" in
		latest-prerelease)
			output_dir="${output_dir}/prereleases"
			local current_date
			current_date="$(date +%Y%M%d_%H%S)" # Unique per second
			output_dir="${output_dir}/latest-prerelease_${current_date}"
			;;
		v*)
			output_dir="${output_dir}/releases/${version}"
			;;
		*)
			echo "Encountered unexpected error: did not recognize version '${version}'" >&2
			exit "$EXIT_INSTALL_UNKNOWN_VERSION"
			;;
	esac

	# Determine the name of the file to download
	local asset_name=""
	local extension=""
	case "$operating_system" in
		linux)
			extension="tar.gz"
			;;
		macos)
			extension="zip"
			;;
	esac

	if [[ "$install_debug" == "true" ]]; then
		asset_name="c3-${operating_system}-debug.${extension}"
		output_dir="${output_dir}-debug"
	else
		asset_name="c3-${operating_system}.${extension}"
	fi

	# Set up the output directory
	if ! ensure_download_directory "$output_dir"; then
		# Directory already contains c3c -> just enable if requested
		if [[ "$enable_after_install" == "true" ]]; then
			enable_compiler_symlink "$output_dir"
		fi
		exit "$EXIT_OK"
	fi

	# Download the file
	local url="https://github.com/${remote}/releases/download/${version}/${asset_name}"

	[[ "$quiet" != "true" ]] && echo "Downloading ${url}..."
	curl --progress-bar -L -o "${output_dir}/${asset_name}" "$url"

	# Check for too small file or HTML error-page
	file_size=$(wc -c < "${output_dir}/${asset_name}")
	if [[ "$file_size" -lt 1000000 ]] ||
		grep -qE '<html|Not Found' "${output_dir}/${asset_name}"
	then
		echo "Download failed or invalid archive received." >&2
		rm "${output_dir}/${asset_name}"
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

	if [[ "$install_keep_archive" != "true" ]]; then
		echo "Removing archive..."
		rm "${output_dir}/${asset_name}"
	fi

	enable_compiler_symlink "$output_dir"
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
			local current_pwd
			current_pwd="$(pwd)"

			if ! cd "$git_dir"; then
				echo "Failed to enter '${git_dir}' to check it"
				exit "$EXIT_INSTALL_GIT_DIR"
			fi
			local current_remote_link
			current_remote_link="$(
				git remote -v 2>/dev/null |
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
					exit "$EXIT_INSTALL_UNRECOGOGNIZED_REMOTE"
			esac

			cd "$current_pwd" || exit
			return_ensure_remote_git_directory="false" # git repo already exists
		fi
	else
		mkdir -p "$git_dir"
	fi
}

function c3vm_install_from_source() {
	true
}

function c3vm_install() {
	if [[ "$install_from_source" == "true" ]]; then
		c3vm_install_from_source
	else
		download_known_release
	fi
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
	*)
		echo "'${subcommand}' not implemented yet"
esac
