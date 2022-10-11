# system updates

the plan is for this repo to contain all system updates, incremental in a form
of text/source code. a node periodically runs the `update.sh` script which pulls
the repo to receive updates executes `apply.sh`. the latter then makes changes
and updates the operating system.

at the moment, all updates are executed in form of shell scripts. these are
error-prone and hard to reason about in a comprehesive way once the codebase
gets sufficiently large. the short term goal is to migrate shell scripts to
something more managaeble like [saltstack](https://github.com/saltstack/salt)
but with less resource requirements, suitable for embedded devices without
python dependencies.

typical update examples are: upgrade bitcoind, lnd and other services, system
packages, improve configuration of components such as firewall.
the run sequence on the node is approximately as follows:

1. fetch updates with a `git fetch`.
2. provide a git diff on the screen and confirm with the user.
3. pull in the changes with a `git pull --verify-signatures`.
4. run `apply.sh`.

at the moment, an on-screen diff and confirmation aren't implemented yet.
`nd` and `ngui` is where it'll happen,
in the [ndg](https://git.qcode.ch/nakamochi/ndg) repo.

when configuring a new node, clone this repo and set up a cron job to execute
the `update.sh` script once a day. The script requires `REPODIR` and `LOGFILE`
env variables set.

TODO: add a list of supported platforms; the "native" is void linux.
