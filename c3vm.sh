#!/bin/bash

# Welcome to my highly advanced c3c version manager.
# This is a bash script that can install and manage versions of the c3c compiler.
# It can grab releases from Github or compile from scratch
#
# Usage:
# 	c3vm <command> <flags>
#
# 	Commands:
# 		- list                  List (installed) compilers
# 		- install [<version>]   Install specified version, or latest when
# 		                        version is omitted
# 		- remove <version>      Remove specified version (regex match with grep)
# 		- use <version>         Use the specified version for a single command
#
# 	Flags:
# 	- Global:
# 		--version, -V           Print version of this script
# 		--verbose, -v           Verbose logging of all subcommands
# 		--help, -hh             Print this long help
# 		-h                      Print short help
#
# 	- List command:
# 		--installed, -i         List installed compilers (default)
# 		--enabled, -e           List only the single enabled compiler
# 		--all, -a               List all available compilers (from Github)
# 		--release               Filter on release version
# 		--debug                 Filter on debug versions
#
# 	- Install command:
# 		--from-source [<hash>]  Compile from source. Defaults to latest commit
# 	                            on the default branch, but can be tweaked by
# 	                            specifying the hash of the commit or with --branch
# 		--branch <branch>       Specify branch for --edge or --commit
# 		--remote <url>          Use a different git-remote,
# 		                        default https://github.com/c3lang/c3c
# 		--debug                 Install the debug version
# 		--dont-enable           Do not enable the new version (keep old one active)
#
# 	- Remove command:
# 		--interactive, -I       Prompt before removing a version
# 		--no-regex, -F          Interpret <version> as fixed-string instead of
# 		                        regex pattern
# 		--inactive              Remove all installed compilers except for the
# 		                        currently enabled compiler
#
# 	- Use command:
# 		--install               Install the version first if it wasn't already
#                               (behind this flag you can add the "install" flags)
# 		--session               Set an environment variable to use the specified
# 		                        version for the rest of your shell session
#
#
# 	Additional info:
#		The compilers are stored under $XDG_DATA_HOME/c3vm/, where $XDG_DATA_HOME
#		defaults to $HOME/.local/share/.
#
#		Building from git will happen inside $XDG_CACHE_HOME/c3vm/, where
#		$XDG_CACHE_HOME defaults to $HOME/.cache/.
#
#		Versions are according to the tag on github. You can request a debug-
#		build either with '--debug' or by adding '-debug' to the version,
#		f.e. '0.7.3-debug'.
#
#		The current enabled version is symlinked (`ln -s`) to $HOME/.local/bin.
#
#		There are quite some other configurable things you can tweak by
#		tweaking some bash variable below this explanation. Or just straight up
#		tweak the source code.


version="0.7.3" # Following the c3c release cycle a bit. Seems fun.

data_home="${XDG_DATA_HOME:-$HOME/.local/share}/c3vm"
cache_home="${XDG_CACHE_HOME:-$HOME/.cache}/c3vm"
bin_home="$HOME/.local/bin/"

function ensure_directories() {
	for directory in "$data_home" "$cache_home" "$bin_home"; do
		if ! [[ -e "$directory" && -d "$directory" ]]; then
			echo "$directory does not exist to store compilers in."
			echo -n "Create directory? [y/n] "
			read -r ans
			if [[ "$ans" == y ]]; then
				mkdir -p "$directory"
			else
				echo "Cannot continue without ${directory}, quitting..."
				exit 1
			fi
		fi
	done
}

ensure_directories

function print_short_help() {
	# TODO:
	echo "TODO"
}

function print_long_help() {
	# TODO:
	echo "TODO"
}

# Parse subcommand and options
verbose="false"
subcommand=""
install_version=""
remove_version=""
use_version=""

list_filters=()

install_from_source="false"
install_from_commit=""
install_from_branch=""
install_debug="false"
install_remote_url="https://github.com/c3lang/c3c"
enable_after_install="true"

function check_subcommand_already_in_use() {
	if [[ "$subcommand" != "" ]]; then
		echo "Cannot specify more then one subcommand!" >&2
		echo "Subcommand '$subcommand' was already specified when you added '$1'" >&2
		exit 2
	fi
}

function check_flag_for_subcommand() {
	flag="$1"
	expected_subcommand="$2"
	if [[ "$subcommand" == "" ]]; then
		echo "Flag '${flag}' requires '${expected_subcommand}' to be in front of it." >&2
		exit 4
	fi
	if [[ "$subcommand" != "$expected_subcommand" ]]; then
		echo "Flag '${flag}' does not belong to subcommand '${subcommand}' but to '${expected_subcommand}'" >&2
	fi
}

while [[ "$1" ]]; do case $1 in
# Global flags
	-V | --version )
		echo "$version"
		exit
		;;
	-v | --verbose )
		verbose="true"
		;;
# Subcommands
	list)
		check_subcommand_already_in_use "list"
		subcommand="list"
		;;
	install)
		check_subcommand_already_in_use "install"
		subcommand="install"
		if [[ "$#" -gt 1 && "$2" =~ v?[0-9]+.* ]]; then
			shift
			install_version="$1"
		fi
		;;
	remove)
		check_subcommand_already_in_use "remove"
		subcommand="remove"
		if [[ "$#" -gt 1 && "$2" =~ v?[0-9]+.* ]]; then
			shift
			remove_version="$1"
		else
			echo "Expected version behind 'remove' subcommand." >&2
			if [[ "$#" -gt 1 ]]; then
				echo "Version '$2' is not a valid version." >&2
			fi
			exit 3
		fi
		;;
	use)
		check_subcommand_already_in_use "use"
		subcommand="use"
		if [[ "$#" -gt 1 && "$2" =~ v?[0-9]+.* ]]; then
			shift
			use_version="$1"
		else
			echo "Expected version behind 'use' subcommand." >&2
			if [[ "$#" -gt 1 ]]; then
				echo "Version '$2' is not a valid version." >&2
			fi
			exit 3
		fi
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
	--all | -a)
		check_flag_for_subcommand "$1" "list"
		list_filters+=( "all" )
		;;
	--release)
		check_flag_for_subcommand "$1" "list"
		list_filters+=( "release" )
		;;
	--debug)
		check_flag_for_subcommand "$1" "list"
		list_filters+=( "debug" )
		;;

# Install flags
	--link)
		check_flag_for_subcommand "$1" "install"
		if [[ "$#" -le 1 ]]; then
			echo "Expected <url> behind --link" >&2
		fi
		shift
		install_url="$1"
		;;
	--remote)
		if [[ "$#" -le 1 ]]; then
			echo "Expected <url> behind --remote" >&2
		elif [[ ! "$2" =~ (^https?://.*)|(^git@.*)  ]]; then
			echo "--remote did not get valid url '$2'" >&2
			echo "The url should start with 'http(s)://' or with 'git@'" >&2
		fi
		shift
		install_remote_url="$1"
		;;

	*)
		echo "Unknown argument '$1'." >&2
		print_short_help
		;;
esac; shift; done

