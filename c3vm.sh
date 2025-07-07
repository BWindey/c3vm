#!/bin/bash

function print_long_help() {
	cat << 'LONG_HELP'
Welcome to my highly advanced c3c version manager.
This is a bash script that can install and manage versions of the c3c compiler.
It can grab releases from Github or compile from scratch

 Usage:
    c3vm [<command>] [<flags>] [<args>]

 Commands:
    - list                  List (installed) compilers
    - install [<version>]   Install specified version, or latest when
                            version is omitted. Will also enable the installed
                            version (unless --dont-enable).
                            When the version is already installed, just
                            enable that version.
    - remove <version>      Remove specified version (regex match with grep)
    - use <version> [-- <args>]
                            Use the specified version for a single command
                            and pass the <args> to the compiler

 Flags:
 - Global:
    --version, -V           Print version of this script
    --verbose, -v           Log all info
    --quiet, -q             Suppress all info (not errors)
    --help, -hh             Print this long help
    -h                      Print short help

 - List command:
    --installed, -i         List installed compilers (default)
    --enabled, -e           List only the single enabled compiler
    --available, -a         List all available compilers (from Github)
    --remote <remote>       See --remote for 'install' below

 - Install command:
    --from-source [<hash>]  Compile from source. Defaults to latest commit
                            on the default branch, but can be tweaked by
                            specifying the hash of the commit or with --branch
    --branch <branch>       Specify branch or tag for --from-source
    --remote <remote>       Use a different git-remote, default c3lang/c3c.
                            Only supports Github remotes with same tags/releases
                            as c3lang/c3c.
    --debug                 Install the debug version
    --dont-enable           Do not enable the new version (keep old one active)
    --keep-archive          Keep the downloaded archive after extracting.
                            Not used when compiling from source.

 - Remove command:
    --interactive, -I       Prompt before removing a version
    --no-regex, -F          Interpret <version> as fixed-string instead of
                            regex pattern
    --inactive              Remove all installed compilers except for the
                            currently enabled compiler

 - Use command:
    --install               Install the version first if it wasn't already
                            (behind this flag you can add the "install" flags)
    --session               Output the exports to switch current compiler
                            version in your shell session.
                            Should be used as `eval "$(c3vm use --session <version>)"`.


 Additional info:
    The compilers are stored under $XDG_DATA_HOME/c3vm/, where $XDG_DATA_HOME
    defaults to $HOME/.local/share/.

    Building from git will happen inside $XDG_CACHE_HOME/c3vm/, where
    $XDG_CACHE_HOME defaults to $HOME/.cache/.

    Versions are according to the tag on github. You can request a debug-
    build with '--debug'.

    The current enabled version is symlinked (`ln -s`) to $HOME/.local/bin.

    There are quite some other configurable things you can tweak by
    tweaking some bash variable below this explanation. Or just straight up
    tweak the source code.


 Exit codes:
    0 - OK
 - Starting checks:
    1 - Required directories missing and not able to create them
    2 - Required tools are missing
    3 - Unsupported OS (only GNU/Linux and MacOS supported)
 - Argument parsing failures:
    10 - Multiple subcommands found
    11 - Flag misses (correct) argument
    12 - Flag is used without its subcommand
    13 - Flag is used with wrong subcommand
    14 - Contradicting flags
    15 - Unknow argument/flag
    16 - Version did not match version-regex
 - Install failures
    20 - Directory not available to save into
    21 - Current c3c installation is not a symlink
    22 - Current c3c installation is not managed by c3vm
LONG_HELP
}

function print_short_help() {
	cat << 'SHORT_HELP'
Usage: c3vm [<command>] [<flags>] [<args>]
Commands: list, install [<version>], remove <version>, use <version>
Global flags: --version, --verbose, --quiet, --help
SHORT_HELP
}

# Tweakable variables
VERSION="0.7.3" # Following the c3c release cycle a bit. Seems fun.

dir_compilers="${XDG_DATA_HOME:-$HOME/.local/share}/c3vm"
dir_git_repos="${XDG_CACHE_HOME:-$HOME/.cache}/c3vm"
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
EXIT_INVALID_VERSION=16

EXIT_INSTALL_NO_DIR=20
EXIT_INSTALL_CURRENT_NO_SYMLINK=21
EXIT_INSTALL_NOT_C3VM_OWNED=22


function ensure_directories() {
	for directory in "$dir_compilers" "$dir_git_repos" "$dir_bin_link"; do
		if ! [[ -e "$directory" && -d "$directory" ]]; then
			echo "$directory does not exist to store compilers in."
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
}

function ensure_tools() {
	local missing_something="false"

	local needed_commands=( "curl" "wget" "git" "jq" "ln" "readlink" )
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

ensure_directories
ensure_tools
check_platform


# Default values that can be changed with subcommands and flags
verbose="false"
quiet="false"
subcommand=""
install_version=""
remove_version=""
use_version=""

list_filters=()

remote="c3lang/c3c"

install_version="latest"
install_from_source="false"
install_from_commit=""
install_from_branch="master"
install_debug="false"
install_keep_archive="false"
enable_after_install="true"

remove_version=""
remove_interactive="false"
remove_regex_match="true"
remove_inactive="false"

use_version=""
use_install="false"
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
	expected_subcommand="$2"
	if [[ "$subcommand" == "" ]]; then
		echo "Flag '${flag}' requires '${expected_subcommand}' to be in front of it." >&2
		exit "$EXIT_FLAG_WITHOUT_SUBCOMMAND"
	fi
	if [[ "$subcommand" != "$expected_subcommand" ]]; then
		echo "Flag '${flag}' does not belong to subcommand '${subcommand}' but to '${expected_subcommand}'" >&2
		exit "$EXIT_FLAG_WITH_WRONG_SUBCOMMAND"
	fi
}

function check_valid_version() {
	if [[ "$1" =~ ^latest(-prerelease)?$ ]]; then
		return 0
	fi
	if ! [[ "$1" =~ ^v?[0-9]\.[0-9]+\.[0-9]+(-debug)?$ ]]; then
		echo "Tried to use '$1' as version, but does not match the version-regex." >&2
		echo "A valid version is of the form (v)?<num>.<num>.<num>(-debug)? or latest(-prerelease)?" >&2
		exit "$EXIT_INVALID_VERSION"
	fi
}

if ! [[ "$1" ]]; then
	print_short_help
	exit "$EXIT_UNKNOWN_ARG"
fi

while [[ "$1" ]]; do case $1 in
# Global flags
	-V | --version )
		echo "$VERSION"
		exit "$EXIT_OK"
		;;
	-v | --verbose )
		if [[ "$quiet" == "true" ]]; then
			echo "--quiet was already set before ${1}." >&2
			exit "$EXIT_CONTRADICTING_FLAGS"
		fi
		verbose="true"
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
	list)
		check_subcommand_already_in_use "list"
		subcommand="list"
		;;
	install)
		check_subcommand_already_in_use "install"
		subcommand="install"
		;;
	link-local)
		check_subcommand_already_in_use "link-local"
		subcommand="link-local"
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
		list_filters+=( "installed" )
		;;
	--enabled | -e)
		check_flag_for_subcommand "$1" "list"
		list_filters+=( "enabled" )
		;;
	--available | -a)
		check_flag_for_subcommand "$1" "list"
		list_filters+=( "available" )
		;;
	--release)
		check_flag_for_subcommand "$1" "list"
		list_filters+=( "release" )
		;;

# Install flags
	--from-source)
		check_flag_for_subcommand "$1" "install"
		install_from_source="true"
		if [[ "$#" -gt 1 && "$2" =~ ^[a-z0-9]*$ ]]; then
			shift
			install_from_commit="$1"
		fi
		;;
	--branch)
		check_flag_for_subcommand "$1" "install"
		if [[ "$#" -le 1 ]]; then
			echo "Expected argument <branch> after --branch" >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		shift
		install_from_branch="$1"
		;;
	--remote)
		case "$subcommand" in
			list | install)
				# OK
				;;
			"")
				echo "Flag '${flag}' requires '${expected_subcommand}' to be in front of it." >&2
				exit "$EXIT_FLAG_WITHOUT_SUBCOMMAND"
				;;
			*)
				echo "Flag '${flag}' does not belong to subcommand '${subcommand}' but to 'list' or 'install'" >&2
				exit "$EXIT_FLAG_WITH_WRONG_SUBCOMMAND"
				;;
		esac
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
		check_flag_for_subcommand "$1" "install"
		install_debug="true"
		;;
	--dont-enable)
		check_flag_for_subcommand "$1" "install"
		enable_after_install="false"
		;;
	--keep-archive)
		check_flag_for_subcommand "$1" "install"
		install_keep_archive="true"
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
	--install)
		check_flag_for_subcommand "$1" "use"
		use_install="true"
		;;
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
	*)
		case "$subcommand" in
			list)
				echo "Received unknown argument for 'list': '${1}'" >&2
				exit "$EXIT_UNKNOWN_ARG"
				;;
			install)
				if [[ "$install_version" != "latest" && "$1" != "latest" ]]; then
					echo "Version was already set to '${install_version}', cannot reset it to '${1}'" >&2
					exit "$EXIT_CONTRADICTING_FLAGS"
				fi
				check_valid_version "$1"
				if [[ "$1" == "v"* || "$1" =~ latest(-prerelease)? ]]; then
					install_version="$1"
				else
					install_version="v$1"
				fi
				;;
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
				if [[ "$1" == "v"* || "$1" =~ latest(-prerelease)? ]]; then
					use_version="$1"
				else
					use_version="v$1"
				fi
				;;
			*)
				echo "Received unknown argument: '${1}'"
				exit "$EXIT_UNKNOWN_ARG"
				;;
		esac
		;;
esac; shift; done


# Check that 'remove' and 'use' have gotten a version.
# We do that here instead of in the 'case remove)' because
# 'c3vm remove --interactive v0.6*' is valid
case "$subcommand" in
	remove)
		if [[ "$remove_version" == "" ]]; then
			echo "Expected version behind 'remove' subcommand." >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		if [[ "$remove_regex_match" == "false" ]]; then
			check_valid_version "$remove_version"
		fi
		;;
	use)
		if [[ "$use_version" == "" ]]; then
			echo "Expected version behind 'use' subcommand." >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		;;
esac

# Here follow the implementations of each subcommand.
# They assume that argument-parsing happened correctly, and will use the
# global variables.

declare -i _amount_filters_printed=0

function start_list() {
	filter_name="$1"
	amount_filters="${#list_filters[@]}"

	if [[ "$amount_filters" -gt 1 ]]; then
		echo -e "\e[1;4m${filter_name}:\e[0m"
	fi
	_amount_filters_printed+=1
}

function end_list() {
	amount_filters="${#list_filters[@]}"

	if (( _amount_filters_printed < amount_filters )); then
		echo ""
	fi
}

function c3vm_list_installed() {
	installed_compilers=$(ls -1 "$dir_compilers")

	start_list "Installed"

	if [[ "$installed_compilers" == "" ]]; then
		echo "No versions installed yet. Install one with 'c3vm install'."
	else
		echo "$installed_compilers"
	fi

	end_list
}

function c3vm_list_enabled() {
	enabled_compiler=$(readlink "$(which c3c 2>/dev/null)")

	start_list "Enabled"

	if [[ "$enabled_compiler" == "" ]]; then
		echo "No compiler was enabled yet. Enable one with 'c3vm install'."
	elif ! [[ "$enabled_compiler" == "$dir_compilers"* ]]; then
		echo "Currently enabled compiler is not managed by c3vm!"
	else
		echo "$enabled_compiler"
	fi

	end_list
}

available_versions=""
function get_available_versions() {
	available_versions="$(
		curl -s "https://api.github.com/repos/${remote}/releases" \
		| jq -r '.[].tag_name' \
		| grep "^\(v[0-9]\+\(\.[0-9]\+\)\{2\}\|latest-prerelease\)$" \
	)"
}

function c3vm_list_available() {
	get_available_versions

	start_list "Available"

	echo "$available_versions"

	end_list
}

function c3vm_list() {
	if [[ "${#list_filters}" == 0 ]]; then
		list_filters+=( "installed" )
	fi

	for filter in "${list_filters[@]}"; do
		case "$filter" in
			installed)
				c3vm_list_installed
				;;
			enabled)
				c3vm_list_enabled
				;;
			available)
				c3vm_list_available
				;;
		esac
	done
}

function determine_download_release() {
	if [[ "$install_version" == "latest" ]]; then
		get_available_versions
		sed -n '2P' <<< "$available_versions"
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

	if [[ -e "${symlink_location}" ]]; then
		if ! [[ -h "$symlink_location" ]]; then
			echo "'${symlink_location}' is not a symlink, aborting installation" >&2
			exit "$EXIT_INSTALL_CURRENT_NO_SYMLINK"
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

	local output_dir="${dir_compilers}/${version}"

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

	if ! ensure_download_directory "$output_dir"; then
		# Directory already contains c3c → just enable if requested
		if [[ "$enable_after_install" == "true" ]]; then
			enable_compiler_symlink "$output_dir"
		fi
		exit "$EXIT_OK"
	fi

	local url="https://github.com/${remote}/releases/download/${version}/${asset_name}"

	echo "Downloading ${url}..."
	curl --progress-bar -L -o "${output_dir}/${asset_name}" "$url"

	# Check for too small file or HTML error-page
	file_size=$(wc -c < "${output_dir}/${asset_name}")
	if [[ "$file_size" -lt 1000000 ]] ||
		grep -qE '<html|Not Found' "${output_dir}/${asset_name}"
	then
		echo "Download failed or invalid archive received." >&2
		rm "${output_dir}/${asset_name}"
		exit "$EXIT_DOWNLOAD_FAILED"
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

function ensure_git_directory() {
	local git_dir="${}"
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
	list)
		c3vm_list
		;;
	install)
		c3vm_install
		;;
	*)
		echo "'$subcommand' not implemented yet"
esac
