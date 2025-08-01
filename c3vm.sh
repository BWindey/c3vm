#!/bin/bash

function print_long_help() {
	cat << 'LONG_HELP'
Usage: c3vm [<command>] [<flags>] [<args>]

 Welcome to a c3c version manager.
 This is a bash script that can install and manage versions of the c3c compiler.
 It can grab releases from Github or compile from scratch.

 All subcommands that accept flags (see '<subcommand> --help') only accept their
 flags after the subcommand. Global flags can be placed anywhere behind the 'c3vm'
 command.

 Subcommands:
    - status                Print currently enabled compiler info.
    - list                  List (installed) compilers
    - install [<version>]   Install specified version, or latest when
                            version is omitted. Will also enable the installed
                            version (unless --dont-enable).
    - enable [<version>]    Enable an already installed version.
    - add-local <path> <name>
                            Link a local C3 compiler directory into c3vm.
                            The local compiler must use a regular CMake
                            build-system. The name will be the name of the
                            symlink, and used for '--local <name>' in other commands.
    - update                Update the current active version, if possible.
    - remove [<version>]    Remove specified version (substring match)
    - use [<version>] [-- <args...>]
                            Use the specified version for a single command
                            and pass the <args> to the compiler

 Global flags:
    --verbose, -v           Log all info (default is just a little bit of info)
    --quiet, -q             Suppress all info (not errors)
    --help, -h              Print this long help

 Extra info per subcommand can be found with '<subcommand> --help', other
 extra info, like example uses, directory layout for storing compilers and
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

function print_status_help() {
	cat << 'STATUS_HELP'
Usage: c3vm status

 The 'status' subcommand shows the currently enabled compiler, if any.
STATUS_HELP
}

function print_list_help() {
	cat << 'LIST_HELP'
Usage: c3vm list [<flags>]

 The 'list' subcommand can show a list of compiler versions. The default
 prints some sort of tree showcasing all compilers on your computer.
 The '--available' flag is useful to see which versions are available to
 download from GitHub releases.
 You can only use one flag per usage.

 Flags:
    --installed, -i         List installed compilers in pretty output (default)
    --available, -a         List all available versions from GitHub releases
    --remote <remote>       Change the GitHub remote for '--available',
                            (default 'c3lang/c3c')

 The following flags are mostly useful for other tools. The completion script
 for example relies on these flags to provide good completions. They are
 just a plain list of items, no markup, seperated by newlines.
 The last three flags use the default remote 'c3lang/c3c', but can be overriden
 with '--remote <remote>'.

 Flags:
    --prebuilt-installed    List all installed prebuilts
    --local-installed       List all "checked in" locals (see 'add-local' help)
    --remote-installed      List all installed remotes
    --remote-builds         List all builds for a remote (can use --remote)
    --remote-tags           List all tags for a remote (can use --remote)
    --remote-branches       List all branches for a remote (can use --remote)
LIST_HELP
}

function print_install_help() {
	cat << 'INSTALL_HELP'
Usage: c3vm install [<version>] [<flags>]

 The 'install' subcommand allows you to install a certain version of the c3c
 compiler on your system. Without a version or flags, it installs the latest
 release from GitHub (default from the 'c3lang/c3c' repository). This is not
 the prerelease, for that you need to specify 'latest-prerelease' as version.
 You can see the available versions with 'c3vm list --available'.
 After installing the version, it will enable it on your system.

 Flags for prebuilt versions:
    --keep-archive          Do not remove the '.tar.gz' or '.zip' after
                            downloading and unpacking the downloaded release

 Flags for both prebuilt and from-source (see below):
    --debug                 Install a debug version
    --dont-enable           Do not enable (symlink) the installed version
    --remote <remote>       Specify a GitHub remote to download the releases
                            from, or to clone for from-source
                            (default 'c3lang/c3c)


 With the flags you can also request to build a version from source. Just
 specifying '--from-source' will clone the 'c3lang/c3c' repository and build
 from the latest commit on the master branch.
 Using '--remote <remote>' allows you to pick a different repository.
 Using '--checkout <rev>' allows you to build on something else then the master
 branch. It recognizes branches, tags or commits.

 Flags for from-source:
    --from-source           Request to build a version from-source
    --checkout <ref>        Specify branch, tag or commit as you would pass it
                            to 'git checkout <rev>'
    --jobs, -j <count>      Number of jobs to use with 'make -j <count>',
                            default 16.

 Additionally you can also use 'c3vm install' to build from a local directory
 that you previously checked into c3vm using 'c3vm add-local'.
 To do that, specify '--local <name>' instead of '--from-source'. This does not
 use '--checkout <ref>', only '--debug' and '--jobs' are recognized.
INSTALL_HELP
}

function print_enable_help() {
	cat << 'ENABLE_HELP'
Usage: c3vm enable [<version>] [<flags>]

 The 'enable' subcommand can enable an already installed version on your system.
 This is done by symlinking it to '~/.local/bin/c3c', which is assumed to be
 in your $PATH.

 The flags are all from the 'install' subcommand, but only those used to specify
 a version, not those that specify behaviour.

 Flags:
    --debug                 Enable the debug version
    --from-source           Enable version built from source
    --remote <remote>       Specify remote for '--from-source'
                            (default 'c3lang/c3c')
    --checkout <ref>        Specify branch, tag or commit for '--from-source'
    --local <name>          Enable local version with specified name
ENABLE_HELP
}

function print_add_local_help() {
	cat << 'ADD_LOCAL_HELP'
Usage: c3vm add-local <path> <name>

 The 'add-local' subcommand is used to check in a local directory into c3vm.
 It can then be use with '--local <name>' for the 'install', 'enable', 'remove'
 or 'use' subcommands.

 The <path> should be a directory which contains a 'CMakeLists.txt', like the
 official c3c repository.
 The <name> cannot contain forward slashes ('/') as it will be used as a
 directory name (symbolic link to be precise).
ADD_LOCAL_HELP
}

function print_update_help() {
	cat << 'UPDATE_HELP'
Usage: c3vm update [<flags>]

 The 'update' subcommand is used to update the current active version.

 For prebuilt versions, it will check the newest release on GitHub, and if you
 have not downloaded that yet, it will. When using the latest-prerelease, it will
 always reinstall the latest prerelease, as there is no (easy?) way of checking
 if the currently installed prerelease is older then the latest one on GitHub.
 When a new version gets downloaded, you can choose to not enable it by using the
 '--dont-enable' flag.

 Flags for prebuilt:
    --dont-enable           Do not enable (symlink) the installed version
    --keep-archive          Do not remove the '.tar.gz' or '.zip' after
                            downloading and unpacking the downloaded release
    --remote <remote>       Specify remote for getting releases from
                            (default 'c3lang/c3c')

 For versions built from source, it will do a 'git pull' and then build again.
 Note that when a version built on a commit or tag cannot be updated, as both
 specify a fixed point in history, not a changing one - as branches do.

 Flags for from-source:
    --jobs, -j <count>      Number of jobs to use with 'make -j <count>'
                            (default 16)
UPDATE_HELP
}

function print_remove_help() {
	cat << 'REMOVE_HELP'
Usage: c3vm remove [<version>] [<flags>]

 The 'remove' subcommand can remove installed versions. Specifying a <version>
 will remove all prebuilts which match with a substring match
 (some_ver == *"<version>"*). With '--full-match/-F' this can be changed to
 require a full match.
 By default disallows to remove the current active version, but can be overridden
 with '--allow-current'.
 Has the same selection flags as 'install' and 'enable' for from-source.

 Flags for prebuilt:
    --full-match,  -F       Version must match exactly instead of substring match
    --inactive              Remove all versions that are currently not enabled

 Flags for prebuilt and from-source:
    --interactive, -I       Prompt before removing
    --dry-run               Do everything except the actual removing
    --allow-current         Allow removing the current active version
    --debug                 Remove debug version

 Flags for from-source:
    --from-source           Remove version built from source
    --remote <remote>       Specify remote (default 'c3lang/c3c')
    --checkout <rev>        Specify branch, tag or commit
    --entire-remote         Remove the entire remote as opposed to a single target

    --local <name>          Check a local directory out of c3vm
REMOVE_HELP
}

function print_use_help() {
	cat << 'USE_HELP'
Usage: c3vm use [<version>] [-- <args...>]

 The 'use' subcommand lets you use a specific version for a single c3c command.
 F.e.: 'c3vm use v0.7.2 -- --version'.

 Accepts the same flags as 'enable' to select a prebuilt version or one
 from-source.

 Special flag '--session' can be used to print out the path-modification to use
 the specified version in your shell session. Use it as:
    eval "$(c3vm use --session <version>)"

 Flags for selection:
    --debug                 Use a debug version
    --from-source           Use version built from source
    --remote <remote>       Specify remote (default 'c3lang/c3c')
    --checkout <rev>        Specify branch, tag or commit
    --local <name>          Use local directory
USE_HELP
}

# Tweakable variables
dir_compilers="${XDG_DATA_HOME:-$HOME/.local/share}/c3vm"
dir_prebuilt="${dir_compilers}/prebuilt"
dir_prebuilt_releases="${dir_compilers}/prebuilt/releases"
dir_prebuilt_prereleases="${dir_compilers}/prebuilt/prereleases"
dir_from_source="${dir_compilers}/from_source"
dir_from_source_remote="${dir_compilers}/from_source/remote"
dir_from_source_local="${dir_compilers}/from_source/local"

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
EXIT_INSTALL_UNRECOGNIZED_REMOTE=45
EXIT_INSTALL_CANT_CLONE=46
EXIT_INSTALL_NO_CMAKE=47
EXIT_INSTALL_BUILD_DIR=48
EXIT_INSTALL_NO_VALID_REMOTE=49
EXIT_INSTALL_UNKNOWN_REV=50
EXIT_INSTALL_BUILD_FAILURE=51

EXIT_ENABLE_BROKEN_SYMLINK=60
EXIT_ENABLE_NO_VERSION_FOUND=61
EXIT_ENABLE_MULTIPLE_VERSIONS_FOUND=61

EXIT_ADDLOCAL_NONEXISTING_PATH=70
EXIT_ADDLOCAL_INVALID_NAME=71
EXIT_ADDLOCAL_ALREADY_ADDED=72
EXIT_ADDLOCAL_ALREADY_BUSY=73

EXIT_UPDATE_ON_IMMUTABLE=80
EXIT_UPDATE_UNKNOWN_REV=81
EXIT_UPDATE_NOT_MANAGED_BY_C3VM=82
EXIT_UPDATE_NO_C3C_IN_PATH=83

EXIT_REMOVE_FAILED_RM=90
EXIT_REMOVE_NOT_FOUND=91

EXIT_USE_VERSION_NOT_FOUND=100
EXIT_USE_NO_EXECUTABLE_FOUND=101
EXIT_USE_MULTIPLE_EXECUTABLES_FOUND=101


function ensure_directories() {
	local directories=(
		"${dir_compilers}"
		"${dir_prebuilt}"
		"${dir_prebuilt_releases}"
		"${dir_prebuilt_prereleases}"
		"${dir_from_source}"
		"${dir_from_source_remote}"
		"${dir_from_source_local}"
		"${dir_bin_link}"
	)
	for directory in "${directories[@]}"; do
		mkdir -p "${directory}" || exit "$EXIT_MISSING_DIRS"
	done
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
printiehelpie="false"


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
remove_entire_remote="false"

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

function check_only_one_list_filter() {
	if [[ "$list_filter" != "" ]]; then
		echo "It is not possible to filter on more than one category." >&2
		exit "$EXIT_CONTRADICTING_FLAGS"
	fi
}

# Check if the version passed as argument is valid, and echo back a "normalised"
# version (which means that it adds a 'v' in front if needed)
# TODO: allow everywhere to end on '_?debug' or '_?release' for easier working
return_check_valid_version=""
function check_valid_version() {
	if [[ "$1" =~ ^v?0\.[0-5]\..* ]]; then
		echo "Versions below v0.6.0 are not supported (asked for '${1}')" >&2
		exit "$EXIT_UNSUPPORTED_VERSION"
	fi
	if [[ "$1" =~ ^latest([-_]prerelease.*)?$ ]]; then
		if [[ "$1" == "latest_prerelease"* ]]; then
			return_check_valid_version="${1/_/-}"
		else
			return_check_valid_version="$1"
		fi
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
	--help | -h)
		printiehelpie="true"
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
		echo "Why does @FoxKiana nag so much?"   && sleep 1
		echo "I don't think I'll understand..."  && sleep 1
		echo "."                                 && sleep 1
		echo "Sigh..."                           && sleep 1
		echo "Ok then..."
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
		check_only_one_list_filter
		list_filter="installed"
		;;
	--available | -a)
		check_flag_for_subcommand "$1" "list"
		check_only_one_list_filter
		list_filter="available"
		;;
	--prebuilt-installed)
		check_flag_for_subcommand "$1" "list"
		check_only_one_list_filter
		list_filter="prebuilt-installed"
		;;
	--local-installed)
		check_flag_for_subcommand "$1" "list"
		check_only_one_list_filter
		list_filter="local-installed"
		;;
	--remote-installed)
		check_flag_for_subcommand "$1" "list"
		check_only_one_list_filter
		list_filter="remote-installed"
		;;
	--remote-builds)
		check_flag_for_subcommand "$1" "list"
		check_only_one_list_filter
		list_filter="remote-builds"
		;;
	--remote-tags)
		check_flag_for_subcommand "$1" "list"
		check_only_one_list_filter
		list_filter="remote-tags"
		;;
	--remote-branches)
		check_flag_for_subcommand "$1" "list"
		check_only_one_list_filter
		list_filter="remote-branches"
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
		check_flag_for_subcommand "$1" "install" "enable" "use" "remove"
		if [[ "$local_name" != "" ]]; then
			echo "Cannot specify '--from-source' and '--local' at the same time" >&2
			exit "$EXIT_CONTRADICTING_FLAGS"
		fi
		from_source="true"
		;;
	--checkout)
		check_flag_for_subcommand "$1" "install" "enable" "use" "remove"
		if [[ "$local_name" != "" ]]; then
			echo "Cannot specify '--checkout' and '--local' at the same time" >&2
			exit "$EXIT_CONTRADICTING_FLAGS"
		elif [[ "$#" -le 1 ]]; then
			echo "Expected argument <rev> after --checkout" >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		shift
		from_rev="$1"
		;;
	--local)
		check_flag_for_subcommand "$1" "install" "enable" "use" "remove"
		if [[ "$from_source" == "true" ]]; then
			echo "Cannot specify '--from-source' and '--local' at the same time" >&2
			exit "$EXIT_CONTRADICTING_FLAGS"
		elif [[ "$remote" != "c3lang/c3c" ]]; then
			echo "Cannot specify '--remote' and '--local' at the same time" >&2
			exit "$EXIT_CONTRADICTING_FLAGS"
		elif [[ "$from_rev" != "default" ]]; then
			echo "Cannot specify '--checkout' and '--local' at the same time" >&2
			exit "$EXIT_CONTRADICTING_FLAGS"
		elif [[ "$#" -le 1 ]]; then
			echo "Expected argument <name> after --local" >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		shift
		local_name="$1"
		;;
	--remote)
		check_flag_for_subcommand "$1" "install" "enable" "use" "remove" "list" "update"
		if [[ "$local_name" != "" ]]; then
			echo "Cannot specify '--remote' and '--local' at the same time" >&2
			exit "$EXIT_CONTRADICTING_FLAGS"
		elif [[ "$#" -le 1 ]]; then
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
			install | enable | use | remove)
				debug_version="true"
				;;
			"")
				echo "'--debug' is only supported for subcommands ('install', 'enable', 'use', 'remove')" >&2
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
	--full-match | -F)
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
	--entire-remote)
		check_flag_for_subcommand "$1" "remove"
		remove_entire_remote="true"
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

if [[ "$printiehelpie" == "true" ]]; then
	case "$subcommand" in
		status)
			print_status_help
			;;
		list)
			print_list_help
			;;
		install)
			print_install_help
			;;
		enable)
			print_enable_help
			;;
		add-local)
			print_add_local_help
			;;
		update)
			print_update_help
			;;
		remove)
			print_remove_help
			;;
		use)
			print_use_help
			;;
		"")
			print_long_help
			;;
	esac
	exit "$EXIT_OK"
fi

# Check that the subcommands who need it got their arguments
# We do that here instead of in the argparsing because I want to allow
# subcommand-arguments behind flags.
# F.e.'c3vm remove --interactive v0.6*' is valid
case "$subcommand" in
	enable | use)
		if [[
			"$from_source" != "true"
			&& "$version" == ""
			&& "$local_name" == ""
		]]; then
			echo "Expected version behind '${subcommand}' subcommand." >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		;;
	add-local)
		if [[ "$add_local_path" == "" || "$add_local_name" == "" ]]; then
			echo "Expected path and name behind 'add-local' subcommand." >&2
			exit "$EXIT_FLAG_ARGS_ISSUE"
		fi
		if ! [[ -e "$add_local_path" ]]; then
			echo "Path '$add_local_path' does not exist." >&2
			exit "$EXIT_ADDLOCAL_NONEXISTING_PATH"
		else
			add_local_path="$(realpath --no-symlinks "${add_local_path}")"
		fi
		if [[ "$add_local_name" =~ .*/.* ]]; then
			echo "'add-local' <name> cannot contain slashes ('/')" >&2
			exit "$EXIT_ADDLOCAL_INVALID_NAME"
		fi
		;;
	remove)
		if [[
			"$version" == ""
			&& "$remove_inactive" != "true"
			&& "$from_source" != "true"
			&& "$local_name" == ""
		]]
		then
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
		/etc/os-release 2>/dev/null
	return "$?"
}

function check_build_tools_available() {
	for command in "cmake" "make"; do
		if ! command -v "$command" >/dev/null; then
			echo "Missing '${command}' to build"
			exit "$EXIT_MISSING_TOOLS"
		fi
	done
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
		log_verbose "What are you doing on Arch??? Get a real distro, like Void Linux."
		log_info "Detected arch(-like) distro, turning on dynamic linking..."
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

return_is_symlink_local_name=""
return_is_symlink_local_path=""
return_is_symlink_local_type=""
function is_symlink_local_c3vm() {
	local symlink actual locale local_path
	symlink="$1"
	actual="$(readlink "$symlink")"

	for locale in "${dir_from_source_local}/"*; do
		local_path="$(readlink "$locale")"
		case "$actual" in
			"${local_path}/build/release/c3c" )
				return_is_symlink_local_path="${local_path}/"
				return_is_symlink_local_name="$(basename "${locale}")"
				return_is_symlink_local_type="release"
				return 0
				;;
			"${local_path}/build/debug/c3c")
				return_is_symlink_local_path="${local_path}/"
				return_is_symlink_local_name="$(basename "${locale}")"
				return_is_symlink_local_type="debug"
				return 0
				;;
		esac
	done
	return 1
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

	if is_symlink_local_c3vm "$c3c_path"; then
		local local_path local_name type_build

		local_path="${return_is_symlink_local_path}"
		local_name="${return_is_symlink_local_name}"
		type_build="${return_is_symlink_local_type}"

		echo "Current active compiler: compiled from source from local '${local_name}'."
		echo "Path '${local_path}', ${type_build} build."
		exit "$EXIT_OK"
	fi

	if ! [[ "$enabled_compiler" == "$dir_compilers"* ]]; then
		echo "Currently enabled compiler is not managed by c3vm!"
		exit "$EXIT_OK"
	fi
	local without_pref="${enabled_compiler#"$dir_compilers"/}"
	local type="${without_pref%%/*}" # prebuilt or from_source
	local rest="${without_pref#*/}"

	case "$type" in
		from_source)
			local from_source_type="${rest%%/*}"
			rest="${rest#*/}"

			case "$from_source_type" in
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
				# local) already catched
				*)
					echo "Unexpected git-type: ${from_source_type}" >&2
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

# This function will print the local / remote tree.
# It takes in 'is_last="$1"' to know whether to print the | in front or not.
# It takes in 'directory="$2"' which should be like 'remote' or 'local'
function c3vm_print_build_tree() {
	local is_last="$1"
	local directory="$2"

	local t_joint="├── "
	local end_joint="└── "

	local prefix_1
	if [[ "$is_last" == "true" ]]; then
		echo "${end_joint}${directory^}:"
		prefix_1="    "
	else
		echo "${t_joint}${directory^}:"
		prefix_1="│   "
	fi

	# All remotes/locals
	local droopies=()
	for dir in "${dir_from_source}/${directory}/"*; do
		# Check if was empty or not valid
		[[ "${dir}" == "*" || ! -d "${dir}" ]] && continue
		droopies+=( "$dir" )
	done

	# Sort
	mapfile -t droopies < <(printf '%s\n' "${droopies[@]}" | sort)

	# Loop with index
	local name index target targets t_index t_name mid_joint
	for index in "${!droopies[@]}"; do
		[[ "$index" == "" ]] && continue

		name="$(basename "${droopies[${index}]}")"

		if [[ $(( index + 1 )) == "${#droopies[@]}" ]]; then
			echo "${prefix_1}${end_joint}${name}"
			mid_joint="    "
		else
			echo "${prefix_1}${t_joint}${name}"
			mid_joint="│   "
		fi

		# All build targets
		targets=()
		for target in "${droopies[${index}]}/build/"*; do
			# Check if was empty or not valid
			[[ "${target}" == "*" || ! -d "${target}" ]] && continue

			targets+=( "$target" )
		done

		# Sort
		mapfile -t targets < <(printf '%s\n' "${targets[@]}" | sort --reverse)

		# Skip when no targets
		[[ "${targets[*]}" == "" ]] && continue

		for t_index in "${!targets[@]}"; do
			[[ "$t_index" == "" ]] && continue

			t_name="$(basename "${targets[${t_index}]}")"

			if [[ $(( t_index + 1 )) == "${#targets[@]}" ]]; then
				echo "${prefix_1}${mid_joint}${end_joint}${t_name}"
			else
				echo "${prefix_1}${mid_joint}${t_joint}${t_name}"
			fi
		done
	done
}

function c3vm_list_installed() {
	local plain="false"
	if [[ "$1" == "prebuilt-installed" ]]; then
		plain="true"
	fi

	# This used to be a 'tree' call, but that is not something that is installed
	# on most systems, so we do some manual work.
	if [[ "$plain" == "false" ]]; then
		echo "Prebuilt:"
		echo "├── Prereleases:"
	fi

	# First gather so we know how many so we can use different prefix for the last
	local prereleases=()
	for prerelease in "${dir_prebuilt_prereleases}/"*; do
		# Catch when there is nothing in 'prereleases/'
		if [[ "$prerelease" != *"/*" ]]; then
			prereleases+=( "$( basename "${prerelease}")" )
		fi
	done

	# Print the prereleases
	for index in "${!prereleases[@]}"; do
		if [[ "$plain" == "true" ]]; then
			echo "${prereleases[$index]}"
		elif (( index < ${#prereleases[@]} - 1 )); then
			echo "│   ├── ${prereleases[$index]}"
		else
			echo "│   └── ${prereleases[$index]}"
		fi
	done

	if [[ "$plain" == "false" ]]; then
		echo "└── Releases"
	fi

	# Now the same for releases
	local releases=()
	for release in "${dir_prebuilt_releases}/"*; do
		if [[ "$release" != *"/*" ]]; then
			releases+=( "$( basename "${release}")" )
		fi
	done

	# Print the releases
	for index in "${!releases[@]}"; do
		if [[ "$plain" == "true" ]]; then
			echo "${releases[$index]}"
		elif (( index < ${#releases[@]} - 1 )); then
			echo "    ├── ${releases[$index]}"
		else
			echo "    └── ${releases[$index]}"
		fi
	done


	# Seperator between prebuilt and from-source
	if [[ "$plain" == "false" ]]; then
		echo ""
	else
		return
	fi

	echo "From source:"
	c3vm_print_build_tree "false" "remote"
	c3vm_print_build_tree "true" "local"
}

function get_available_versions() {
	log_verbose "Getting the available version from GitHub..."
	curl -s "https://api.github.com/repos/${remote}/releases" |
		jq -r ".[].tag_name" |
		grep "^\(v[0-9]\+\(\.[0-9]\+\)\{2\}\|latest-prerelease\)$" |
		grep -v "v0.5.*"
}

function c3vm_list_available() {
	get_available_versions
}

function list_remote_installed() {
	ls -1 "${dir_from_source_remote}/" | tr '_' '/'
}

function list_remote_builds() {
	ls -1 "${dir_from_source_remote}/${remote/\//_}/build/"
}

function list_remote_tags() {
	git -C "${dir_from_source_remote}/${remote/\//_}/" tag -l
}

function list_remote_branches() {
	git -C "${dir_from_source_remote}/${remote/\//_}/" branch -r |
		grep -v "/HEAD" |
		sed -s "s+ *origin/++"
}

function c3vm_list() {
	case "$list_filter" in
		"" | installed | prebuilt-installed)
			c3vm_list_installed "$list_filter"
			;;
		available)
			c3vm_list_available
			;;
		local-installed)
			ls -1 "${dir_from_source_local}/"
			;;
		remote-installed)
			list_remote_installed
			;;
		remote-builds)
			list_remote_builds
			;;
		remote-tags)
			list_remote_tags
			;;
		remote-branches)
			list_remote_branches
			;;
	esac
}

function determine_download_release() {
	mapfile -t available_versions < <(get_available_versions)
	local latest_version="${available_versions[0]}"
	if [[ "$latest_version" == "prerelease"* ]]; then
		latest_version="${available_versions[1]}"
	fi

	if [[ "$version" == "" ]]; then
		# Get available versions and take second in list
		version="${latest_version}"
	else
		# We already checked if the version is too low (< v0.6.0)
		# but now also need to check if the version exists
		local found_match="false"
		for av_version in "${available_versions[@]}"; do
			if [[ "$av_version" == "$version" ]]; then
				found_match="true"
				break
			fi
		done

		if [[ "$found_match" != "true" ]]; then
			echo "Version '${version}' is not an available version." >&2
			exit "$EXIT_INVALID_VERSION"
		fi
	fi
}

return_determine_directory=""
function determine_directory_prebuilt() {
	# HACK:
	# this solves an issue I had with 'c3vm use latest-prerelease_xxx'
	# not sure if this is the proper solution o.O
	if [[ "$1" == "use" && "$version" == "latest-prerelease"* ]]; then
		for directory in "${dir_prebuilt_prereleases}/${version}"*; do
			if [[ "$return_determine_directory" ]]; then
				echo "Found multiple preleases matching '${version}'" >&2
				exit "$EXIT_INSTALL_UNKNOWN_VERSION"
			fi
			return_determine_directory="${directory}"
		done
		return
	fi

	[[ "$1" != "use" ]] && determine_download_release

	local result

	case "${version}" in
		latest-prerelease)
			result="${dir_prebuilt_prereleases}/latest-prerelease_" # Leave open
			;;
		v*)
			result="${dir_prebuilt_releases}/${version}"
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
		log_info "Requested version already installed in '${output_dir}'."
		return 1
	else
		echo "'${output_dir}' already exists but does not contain a 'c3c' binary."
		ls -l "$output_dir"
		echo -n "Continue and overwrite directory? [y/n] "
		read -r ans
		if [[ "$ans" == y ]]; then
			if ! rm -r "${output_dir}"; then
				echo "Failed to remove '${output_dir}' before recreating." >&2
				exit "$EXIT_INSTALL_NO_DIR"
			fi
			if ! mkdir -p "$output_dir"; then
				echo "Failed to create '${output_dir}'." >&2
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
	local symlink_location="${dir_bin_link}/c3c"

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
			if [[ "$ans" == "y" ]]; then
				unlink "$symlink_location"
			else
				echo "Cannot continue before broken link is removed or fixed." >&2
				exit "$EXIT_ENABLE_BROKEN_SYMLINK"
			fi
		elif ! is_symlink_local_c3vm "${symlink_location}" && [[
			"$(readlink "$symlink_location")" != "$dir_compilers"*
		]]; then
			echo "Symlink is not managed by 'c3vm' (points to '$(readlink "${symlink_location}")')"
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
	# while the linux tar.gz is of the form 'c3/c3c' or 'linux/c3c'...
	local exe_path
	exe_path="$(find "${output_dir}" -type f -executable -name "c3c" -exec realpath '{}' \;)"
	log_info "Linking '${exe_path}' executable to '${symlink_location}'..."
	ln -s "${exe_path}" "${symlink_location}"
}

# Little helper function to send output to /dev/null if $quiet is set
function executies() {
	if [[ "$quiet" == "true" ]]; then
		"$@" >/dev/null
	else
		"$@"
	fi
	return "$?"
}

function download_known_release() {
	determine_directory_prebuilt "download"
	local output_dir="${return_determine_directory}"

	if [[ "$output_dir" == *"latest-prerelease_" ]]; then
		local current_date
		current_date="$(date +%Y%M%d_%H%S)" # Unique per second
		log_verbose "Setting version to 'latest-prerelease_${current_date}'"
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
		grep -E --quiet "<html|Not Found" "${output_file}"
	then
		echo "Download failed or invalid archive received." >&2
		rm "${output_file}"
		exit "$EXIT_INSTALL_DOWNLOAD_FAILED"
	fi

	log_info "Extracting ${asset_name}..."
	case "$extension" in
		tar.gz)
			local tar_flags=(
				--extract
				--directory="${output_dir}"
				--file="${output_dir}/${asset_name}"
			)
			[[ "$verbose" == "true" ]] && tar_flags+=( --verbose )
			executies tar "${tar_flags[@]}"
			;;
		zip)
			local unzip_flags=(
				"${output_dir}/${asset_name}"
				-d "${output_dir}"
			)
			[[ "$verbose" == "true" ]] && unzip_flags+=( -v )
			executies unzip "${unzip_flags[@]}"
	esac

	if [[ "$keep_archive" != "true" ]]; then
		log_info "Removing archive..."
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
			ls -l "${git_dir}"
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
		echo "      The function can be found just below this scripts argument parsing, around line 928."
	fi
}

return_git_get_default_branch=""
function git_get_default_branch() {
	local git_dir="$1"

	# We can only get a default branch from the remote, sooooo, first determine remote
	local remotes
	remotes="$(git -C "$git_dir" remote show -n)"
	if [[ "$remotes" != *"origin"* ]]; then
		echo "Could not find remote 'origin', which is required to determine default branch." >&2
		exit "$EXIT_INSTALL_NO_VALID_REMOTE"
	fi

	# And now query for default branch
	local default_branch
	default_branch="$(
		git -C "$git_dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null
	)"
	return_git_get_default_branch="${default_branch#origin/}"

	# And last check to see if we actually got something
	if [[ "$return_git_get_default_branch" == "" ]]; then
		echo "Did not find a default branch." >&2
		exit "$EXIT_INSTALL_NO_VALID_REMOTE"
	fi

	log_verbose "Determined '${return_git_get_default_branch}' as default branch in '${git_dir}'"
}

function git_rev_is_branch() {
	local rev="$1"
	local git_dir="$2"

	git -C "$git_dir" branch -r --list "origin/${rev}" | grep -F --quiet "origin/${rev}"
	return "$?"
}

function git_rev_is_tag() {
	local rev="$1"
	local git_dir="$2"
	git -C "$git_dir" show-ref --verify --quiet "refs/tags/${rev}"
	return "$?"
}

return_git_rev_is_commit=""
function git_rev_is_commit() {
	local rev="$1"
	local git_dir="$2"
	return_git_rev_is_commit="$(
		git -C "$git_dir" rev-parse --quiet --verify "${rev}^{commit}" >/dev/null
	)"
	return "$?"
}

# This function does two things:
# - parse the 'from-rev' into the right build folder
# - 'git checkout'
# - return the build folder
# Which are actually three things. Sad sad sad
return_determine_git_build_dir=""
function determine_git_build_dir() {
	local git_dir="$1"

	local build_dir="${git_dir}/build"

	git_get_default_branch "${git_dir}"
	local default_branch="${return_git_get_default_branch}"

	# If not default branch, determine what to add before release/debug
	if [[ "$from_rev" != "default" ]]; then
		# Check if it's a branch
		if git_rev_is_branch "${from_rev}" "${git_dir}"; then
			build_dir="${build_dir}/${from_rev}_"

		# Check if it's a tag
		elif git_rev_is_tag "${from_rev}" "${git_dir}"; then
			build_dir="${build_dir}/${from_rev}_"

		# Check if it's a valid commit (full or short hash)
		elif git_rev_is_commit "${from_rev}" "${git_dir}"; then
			local commit_hash
			commit_hash="${return_git_rev_is_commit}"
			build_dir="${build_dir}/${commit_hash::7}"

		else
			echo "Git does not know '${from_rev}'." >&2
			exit "$EXIT_INSTALL_UNKNOWN_REV"
		fi

		if [[ "$verbose" == "true" ]]; then
			echo -n "git: "
			git -C "$git_dir" checkout "$from_rev"
		else
			git -C "$git_dir" checkout "$from_rev" >/dev/null 2>&1
		fi
	else
		build_dir="${build_dir}/"
		if [[ "$verbose" == "true" ]]; then
			echo -n "git: "
			git -C "$git_dir" switch "$default_branch"
		else
			git -C "$git_dir" switch "$default_branch" >/dev/null 2>&1
		fi
	fi

	if [[ "$debug_version" == "true" ]]; then
		build_dir="${build_dir}debug"
	else
		build_dir="${build_dir}release"
	fi

	return_determine_git_build_dir="${build_dir}"
}

# This function calls 'determine_git_build_dir()' and creates that build dir
# if needed, and returns the build directory.
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
		ls -l "$build_dir"
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

	return_install_setup_build_folders="$build_dir"
}

function install_from_source() {
	local git_dir="${dir_from_source_remote}/${remote/\//_}"
	ensure_remote_git_directory "$git_dir"

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

		if ! git clone "$clone_link" "$git_dir" ; then
			echo "Failed to clone '${clone_link}'" >&2
			exit "$EXIT_INSTALL_CANT_CLONE"
		fi
	fi

	if ! [[ -e "${git_dir}/CMakeLists.txt" ]]; then
		echo "Couldn't find CMakeLists.txt inide '${git_dir}', cannot build" >&2
		exit "$EXIT_INSTALL_NO_CMAKE"
	fi

	check_build_tools_available

	install_setup_build_folders "$git_dir"
	local build_dir="$return_install_setup_build_folders"

	actually_build_from_source "$git_dir" "$build_dir"

	if [[ "$enable_after" == "true" ]]; then
		enable_compiler_symlink "$build_dir"
	fi
}

function install_setup_local_build_folders() {
	local local_dir="$1"
	local build_dir="${local_dir}/build"

	if [[ "$debug_version" == "true" ]]; then
		build_dir="${build_dir}/debug"
	else
		build_dir="${build_dir}/release"
	fi

	if [[ -e "$build_dir" ]]; then
		if [[ ! -d "$build_dir" ]]; then
			echo "'${build_dir}' exists but is not a directory."
			ls -l "$build_dir"
			echo "Permission to remove it and continue? [y/n] "
			read -r ans
			if [[ "$ans" != y ]]; then
				echo "Aborting." >&2
				exit "$EXIT_INSTALL_BUILD_DIR"
			elif ! rm "$build_dir"; then
				echo "Failed to remove '${build_dir}'" >&2
				exit "$EXIT_INSTALL_BUILD_DIR"
			fi
		fi
	else
		mkdir -p "$build_dir"
	fi

	return_install_setup_build_folders="$build_dir"
}

function install_local() {
	local local_dir="${dir_from_source_local}/${local_name}"

	if [[ ! -e "$local_dir" ]]; then
		echo "'${local_dir}' does not exist" >&2
		exit "$EXIT_INSTALL_NO_DIR"
	elif [[ ! -d "$local_dir" ]]; then
		echo "'${local_dir}' is not a directory" >&2
		exit "$EXIT_INSTALL_NO_DIR"
	elif [[ ! -e "${local_dir}/CMakeLists.txt" ]]; then
		echo "Couldn't find CMakeLists.txt inside '${local_dir}', cannot build" >&2
		exit "$EXIT_INSTALL_NO_CMAKE"
	fi

	check_build_tools_available

	install_setup_local_build_folders "$local_dir"
	local build_dir="$return_install_setup_build_folders"

	actually_build_from_source "$local_dir" "$build_dir"

	if [[ "$enable_after" == "true" ]]; then
		enable_compiler_symlink "$build_dir"
	fi
}

function c3vm_install() {
	if [[ "$local_name" != "" ]]; then
		install_local
	elif [[ "$from_source" == "true" ]]; then
		install_from_source
	else
		download_known_release
	fi
}

function enable_prebuilt() {
	local to_search="$version"
	if [[ "$debug_version" == "true" ]]; then
		to_search="${to_search}-debug"
	fi

	local matches
	mapfile -t matches < \
		<(find "${dir_prebuilt}/" -type d -name "${to_search}*" 2>/dev/null)

	if (( ${#matches[@]} == 0 )); then
		echo "No compilers installed that match ${to_search}" >&2
		exit "$EXIT_ENABLE_NO_VERSION_FOUND"
	elif (( ${#matches[@]} > 1 )); then
		echo "Found multiple matches:" >&2
		for match in "${matches[@]}"; do
			echo "- ${match}" >&2
		done
		echo "Run command again with one of those." >&2
		exit "$EXIT_ENABLE_MULTIPLE_VERSIONS_FOUND"
	fi

	enable_compiler_symlink "${matches[0]}"
}

function enable_from_source() {
	local git_dir="${dir_from_source_remote}/${remote/\//_}"

	if [[ ! -d "$git_dir" || ! -d "${git_dir}/.git" ]]; then
		echo "Git repository not found in '${git_dir}'." >&2
		echo "Try running: c3vm install --from-source ..." >&2
		exit "$EXIT_ENABLE_NO_VERSION_FOUND"
	fi

	determine_git_build_dir "$git_dir"
	local build_dir="$return_determine_git_build_dir"

	if [[ ! -d "$build_dir" ]]; then
		echo "Build folder not found: '${build_dir}'" >&2
		echo "Try running: c3vm install --from-source ..." >&2
		exit "$EXIT_ENABLE_NO_VERSION_FOUND"
	fi

	enable_compiler_symlink "$build_dir"
}

function enable_local() {
	local local_path="${dir_from_source_local}/${local_name}"

	if [[ ! -d "$local_path" ]]; then
		echo "'${local_name}' is not recognized by c3vm" >&2
		exit "$EXIT_ENABLE_NO_VERSION_FOUND"
	fi

	local_path="${local_path}/build/"
	if [[ "$debug_version" == "true" ]]; then
		local_path="${local_path}/debug"
	else
		local_path="${local_path}/release"
	fi

	if [[ ! -d "$local_path" ]]; then
		echo "Did not find the requested buildfolder (${local_path})" >&2
		exit "$EXIT_ENABLE_NO_VERSION_FOUND"
	fi

	enable_compiler_symlink "$local_path"
}

function c3vm_enable() {
	if [[ "$local_name" != "" ]]; then
		enable_local
	elif [[ "$from_source" == "true" ]]; then
		enable_from_source
	else
		enable_prebuilt
	fi
}

function update_from_source() {
	local current_active="${1#"${dir_from_source}/"}"

	# Extract the needed info from the current-active-path
	current_active="${current_active#remote/}"

	local active_remote="${current_active%%/*}"
	local git_dir="${dir_from_source_remote}/${active_remote}"

	current_active="${current_active#"${active_remote}/build/"}"

	local target="${current_active%%/*}"
	local build_type="${target##*_}"   # 'release' or 'debug'
	local git_rev="${target%"${build_type}"}"

	if [[ "$git_rev" == "" ]]; then
		git_get_default_branch "$git_dir"
		git_rev="${return_git_get_default_branch}"
	elif [[ "$git_rev" == *_ ]]; then
		git_rev="${git_rev::-1}"
	fi

	if git_rev_is_branch "$git_rev" "$git_dir"; then
		true # Do nothing
	elif git_rev_is_tag "$git_rev" "$git_dir"; then
		echo "Current version is built on a tag, that cannot be updated." >&2
		exit "$EXIT_UPDATE_ON_IMMUTABLE"
	elif git_rev_is_commit "$git_rev" "$git_dir"; then
		echo "Current version is built on a commit, that cannot be updated." >&2
		exit "$EXIT_UPDATE_ON_IMMUTABLE"
	else
		echo "Huh? Something is wrong. You're on a version that is neither a tag, commit or branch." >&2
		exit "$EXIT_UPDATE_UNKNOWN_REV"
	fi

	# Make sure we're on the right branch
	if [[ "$verbose" == "true" ]]; then
		echo -n "git: "
		git -C "$git_dir" switch "$git_rev"
	else
		git -C "$git_dir" switch "$git_rev" >/dev/null 2>&1
	fi

	local build_dir="${1%/*}/"

	log_info "Pulling from remote repository inside '${git_dir}'..."
	local answer
	answer="$(git -C "${git_dir}" pull 2>/dev/null)"
	if [[ "$answer" != "Already up to date." ]]; then
		log_info "New commits found, building again..."
		actually_build_from_source "$git_dir" "$build_dir"
		enable_compiler_symlink "$build_dir"
	else
		log_info "Already up to date."
	fi
}

function update_prebuilt() {
	local current_active="${1#"${dir_prebuilt}/"}"
	current_active="${current_active#*releases/}" # Strip (pre)releases
	current_active="${current_active%%/*}" # Strip everything behind first '/'

	if [[ "$current_active" == *"-debug" ]]; then
		debug_version="true"
	fi
	if [[ "$current_active" == "latest-prerelease"* ]]; then
		version="latest-prerelease"
	fi
	# Else leave version on default so it will pick out the latest release

	download_known_release
}

function try_update_local() {
	local current_active
	current_active="$(which c3c 2>/dev/null)"

	if [[ "$current_active" == "" ]]; then
		echo "No c3c in \$PATH." >&2
		exit "$EXIT_UPDATE_NO_C3C_IN_PATH"
	elif ! is_symlink_local_c3vm "${current_active}"; then
		echo "Current compiler is not managed by c3vm (${current_active})." >&2
		exit "$EXIT_UPDATE_NOT_MANAGED_BY_C3VM"
	fi

	# Resolve symlink
	current_active="$(readlink "${current_active}")"

	# Now we're sure it's of the form '.../build/{release/debug}/c3c'
	# Let's extract the source dir and output dir
	local output_dir="${current_active%/c3c}"

	local source_dir="${output_dir}"

	if [[ "${source_dir}" == *"/release" ]]; then
		source_dir="${source_dir%/release}"
	elif [[ "${source_dir}" == *"/debug" ]]; then
		source_dir="${source_dir%/debug}"
	fi

	source_dir="${source_dir%/build}"

	actually_build_from_source "${source_dir}" "${output_dir}"
}

current_active_version=""
function get_current_version() {
	current_active_version="$(which c3c 2>/dev/null | xargs readlink 2>/dev/null)"
	log_verbose "Checking currently active: '${current_active_version}'"
}

function c3vm_update() {
	get_current_version

	case "$current_active_version" in
		"${dir_from_source_remote}/"*)
			update_from_source "$current_active_version"
			;;
		"${dir_prebuilt}/"*)
			update_prebuilt "$current_active_version"
			;;
		*)
			try_update_local
			;;
	esac
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

function c3vm_remove_prebuilt() {
	local found_match="false"

	get_current_version

	local release

	for release_dir in "${dir_prebuilt_releases}"* "${dir_prebuilt_prereleases}"*; do
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
			echo -n "Remove version '${release}'? [y/n] "
			read -r ans
			if [[ "$ans" != y ]]; then
				log_info "Skipped '${release}'."
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
			# matches one of the versions inside '~/.local/share/c3vm/'
			unlink "${dir_bin_link}/c3c"
		fi
		found_match="true"
	done

	if [[ "$found_match" != "true" ]]; then
		log_info "No matches found."
	fi
}

function c3vm_remove_from_source() {
	local git_dir="${dir_from_source_remote}/${remote/\//_}"

	if [[ ! -d "$git_dir" ]]; then
		echo "Cannot remove because '${git_dir}' does not exist." >&2
		exit "$EXIT_REMOVE_NOT_FOUND"
	fi

	local dir_to_remove="$git_dir"

	if [[ "$remove_entire_remote" != "true" ]]; then
		determine_git_build_dir "$git_dir"
		dir_to_remove="$return_determine_git_build_dir"
	fi

	if [[ "$remove_interactive" == "true" ]]; then
		echo -n "Remove '${dir_to_remove}'? [y/n] "
		read -r ans
		if [[ "$ans" != y ]]; then
			log_info "Skipped '${dir_to_remove}'."
			exit "$EXIT_OK"
		fi
	fi

	if [[ "$remove_dryrun" != "true" ]] && ! rm -rf "${dir_to_remove}"
	then
		echo "Failed to remove remote directory '${dir_to_remove}'." >&2
		exit "$EXIT_REMOVE_FAILED_RM"
	else
		log_info "Removed '${dir_to_remove}'"
		exit "$EXIT_OK"
	fi
}

function c3vm_remove_local() {
	local path="${dir_from_source_local}/${local_name}"

	if [[ ! -h "$path" ]]; then
		echo "'${local_name}' is not a recognized name." >&2
		exit "$EXIT_REMOVE_NOT_FOUND"
	fi

	if [[ "$remove_interactive" == "true" ]]; then
		echo -n "Check out '${local_name}' out of c3vm? [y/n] "
		read -r ans
		if [[ "$ans" != y ]]; then
			log_info "Skipped '${local_name}'."
			exit "$EXIT_OK"
		fi
	fi

	log_info "Checking '${local_name}' out of c3vm..."
	unlink "$path"
}

function c3vm_remove() {
	if [[ "$local_name" != "" ]]; then
		c3vm_remove_local
	elif [[ "$from_source" == "true" ]]; then
		c3vm_remove_from_source
	else
		c3vm_remove_prebuilt
	fi
}

function use_from_directory() {
	local search_dir="$1"

	# Check that there is only a single executable called 'c3c', otherwise I'm confused
	local -a found_executables
	mapfile -t found_executables < \
		<(find "${search_dir}" -type f -executable -name "c3c")

	if (( ${#found_executables[@]} == 0 )); then
		echo "Could not find the 'c3c' executable inside '${search_dir}'" >&2
		exit "$EXIT_USE_NO_EXECUTABLE_FOUND"
	elif (( ${#found_executables[@]} > 1 )); then
		echo "Multiple 'c3c' executables found in '${search_dir}':" >&2
		for found_executable in "${found_executables[@]}"; do
			echo "- ${found_executable}" >&2
		done
		exit "$EXIT_USE_MULTIPLE_EXECUTABLES_FOUND"
	fi

	local executable_path="${found_executables[0]}"

	if ! [[ -e "$executable_path" ]]; then
		echo "Could not find the 'c3c' executable inside '${search_dir}'" >&2
		exit "$EXIT_USE_NO_EXECUTABLE_FOUND"
	fi

	if [[ "$use_session" == "true" ]]; then
		echo "export PATH=\"$(dirname "$executable_path"):\$PATH\""
	else
		local command=( "$executable_path" "${use_compiler_args[@]}" )
		"${command[@]}"
	fi
}

function use_prebuilt() {
	determine_directory_prebuilt "use"
	local found_version="$return_determine_directory"

	if ! [[ -d "$found_version" ]]; then
		echo "Could not find installed version '${version}'." >&2
		exit "$EXIT_USE_VERSION_NOT_FOUND"
	fi

	use_from_directory "$found_version"
}

function use_from_source() {
	local git_dir="${dir_from_source_remote}/${remote/\//_}"

	if [[ ! -d "${git_dir}" ]]; then
		echo "Could not find git-remote ${remote}." >&2
		exit
	fi

	determine_git_build_dir "$git_dir"

	use_from_directory "$return_determine_git_build_dir"
}

function use_local() {
	local local_path="${dir_from_source_local}/${local_name}"

	if [[ ! -d "$local_path" ]]; then
		echo "'${local_name}' is not recognized by c3vm" >&2
		exit "$EXIT_ENABLE_NO_VERSION_FOUND"
	fi

	local_path="${local_path}/build/"
	if [[ "$debug_version" == "true" ]]; then
		local_path="${local_path}/debug"
	else
		local_path="${local_path}/release"
	fi

	if [[ ! -d "${local_path}" ]]; then
		echo "Did not find the requested buildfolder (${local_path})" >&2
		exit "$EXIT_USE_VERSION_NOT_FOUND"
	fi

	use_from_directory "$local_path"
}

function c3vm_use() {
	if [[ "$local_name" != "" ]]; then
		use_local
	elif [[ "$from_source" == "true" ]]; then
		use_from_source
	else
		use_prebuilt
	fi
}

function c3vm_add_local() {
	local local_dir="${dir_from_source_local}/${add_local_name}"

	if [[ -e "$local_dir" ]]; then
		if [[ -d "$local_dir" && -e "${local_dir}/CMakeLists.txt" ]]; then
			echo "'${add_local_name}' already exists." >&2
			exit "$EXIT_ADDLOCAL_ALREADY_ADDED"
		else
			echo "'${add_local_name}' already exists but has no 'CMakeLists.txt'."
			ls -l "$local_dir"
			echo -n "Remove '${local_dir}' and continue? [y/n] "
			read -r answer
			if [[ "$answer" != y ]]; then
				echo "Aborting." >&2
				exit "$EXIT_ADDLOCAL_ALREADY_BUSY"
			else
				rm -r "$local_dir"
			fi
		fi
	fi

	log_info "Checking '${add_local_path}' into c3vm in '${local_dir}'..."
	ln -s "$add_local_path" "$local_dir"
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
	add-local)
		c3vm_add_local
		;;
	*)
		echo "'${subcommand}' not implemented yet"
esac
