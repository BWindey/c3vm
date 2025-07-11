# C3VM - a version manager for [c3c](https://github.com/c3lang/c3c)

`c3vm` is a bash-script that manages versions of the C3 compiler.

> [!WARNING]
> `c3vm` is still in beta, only `status`, `enable` and `install` are implemented.
> Feel free to use it, to report bugs, to share ideas.

There is a manpage, feel free to search the internet on how to install it.

## Example useage:
```sh
# Install and enable latest stable release
c3vm install

# Install a specific version but do not enable it
c3vm install --dont-enable v0.6.8

# Install debug compiler from source from a fork
c3vm install --from-source --remote bwindey/c3c --debug

# Enable that previous version
c3vm enable v0.6.8
```


## How to install
It's a bash script. Not so hard.
Personally I'd recommend cloning this repo (remember, it's still beta, so expect
updates in the future that you definitly want). Then you make a symlink to
a directory in your `$PATH`, I'd recommend `~/.local/bin`, but hey, it's your
computer, go crazy!


## How it works
See the manpage. It's too late at the time of writing this to be bothered to
explain it to you.


## Planned/ideas:
A 'snapshot' subcommand for installing from-source that will store the
currently enabled compiler under an alias (probably git/snapshots/<alias>/)
that allows you to quickly snapshot the version, update and compare
behaviour.

Some kind of alias to create like 'c3c_debug' or whatever as available
executable. Not trivial as the script needs to know which aliasses
are from c3vm. Might not be implemented ever.
