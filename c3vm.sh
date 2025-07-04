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

