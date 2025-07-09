# C3VM - a version manager for [c3c](https://github.com/c3lang/c3c)

`c3vm` is a bash-script that manages versions of the C3 compiler.


## Planned/ideas:
A 'snapshot' subcommand for installing from-source that will store the
currently enabled compiler under an alias (probably git/snapshots/<alias>/)
that allows you to quickly snapshot the version, update and compare
behaviour.

Some kind of alias to create like 'c3c_debug' or whatever as available
executable. Not trivial as the script needs to know which aliasses
are from c3vm. Might not be implemented ever.
