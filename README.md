# C3VM - a version manager for [c3c](https://github.com/c3lang/c3c)

`c3vm` is a bash-script that manages versions of the C3 compiler.

> [!WARNING]
> `c3vm` is still in beta, the `add-local` subcommand and related functionality
> is missing, and some flags and such are also not there yet.
> Feel free to use it, to report bugs, to share ideas.
> Installation instructions will improve when this script is considered finished.

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
A quick way to get started with `c3vm` + `c3c` you can execute the following
three commands (you can copy them and paste them and your shell will execute them in order):
```sh
curl -o c3vm https://raw.githubusercontent.com/BWindey/c3vm/refs/heads/main/c3vm.sh
chmod u+x c3vm
./c3vm install
```

If you want to continue using `c3vm`, you'll want to move the script to somewhere
in your `$PATH`.

You can also clone this repository and move the script or symlink it to somewhere
in your `$PATH`.

### Tab completions
Currently there are
[bash completions](https://raw.githubusercontent.com/BWindey/c3vm/refs/heads/main/c3vm_bash_completions.sh)
(pretty good ones imo).
You can download the script and then in your `~/.bashrc` do
```sh
source path/to/completion/script
```
If you're using another shell then Bash, I don't have an answer yet for you,
but I'll gladly accept contributions that add completions for your shell.

### Manpage
There also is a
[manpage](https://raw.githubusercontent.com/BWindey/c3vm/refs/heads/main/c3vm.1).
After downloading it (or getting it by cloning this repository), you can copy
or symlink it to your manpage folder, usually located in `/usr/local/share/man/man1/`.
See more info here: https://www.baeldung.com/linux/man-pages-manual-install .
(You might need to run `mandb` to update the `man` database.)


## How it works
See the manpage. It's too late at the time of writing this to be bothered to
explain it to you.


## Planned/ideas:
- A 'snapshot' subcommand for installing from-source that will store the
    currently enabled compiler under an alias (probably git/snapshots/<alias>/)
    that allows you to quickly snapshot the version, update and compare
    behaviour.

- Some kind of alias to create like 'c3c_debug' or whatever as available
    executable. Not trivial as the script needs to know which aliasses
    are from c3vm. Might not be implemented ever.

- A bash completion script for this bash script. Because the greatest ally
    for your commandline adventures is good old `<tab><tab>`.


## For @foxkiana
There is the undocumented `c3vm upgrade` command. It will try to update the `c3vm`
script itself, by checking if it is inside a git repo (and then do `git pull`)
or else try to download it from Github with `curl`.

This `upgrade` subcommand will remain undocumented, as it is not meant to be used.
After all, this `c3vm` script shouldn't really need to receive any updates
anymore after the "beta" tag is lifted (see top of this README).
