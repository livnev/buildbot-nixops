# buildbot-nixops

This is a nix derivation for deploying a [buildbot](https://buildbot.net/) CI server using [nixops](https://nixos.org/nixops/). It comes preinstalled with some useful utility commands from [git-ci](https://github.com/ehildenb/git-ci).

## configure

First, search this repo for `FILLME` and fill in all fields:

```sh
$ grep FILLME *
```

## deploying

### new deployment

The simplest option is to use the DigitalOcean backend, supplied in `do.nix`. For that, you just need to get an auth token and then do:

```sh
$ export DIGITAL_OCEAN_AUTH_TOKEN=????
```

We will instead use a Hetzner dedicated server. For this, you need to set `deployment.hetzner.robotUser` in `hetzner.nix` and export the username and password for your Hetzner Robot subaccount using:

```sh
$ export HETZNER_ROBOT_USER=???
$ export HETZNER_ROBOT_PASS=???
```

From now on we will use the Hetzner backend with `hetzner.nix`, if you are using a different backend, like DigitalOcean, then replace `hetzner.nix` with `do.nix` in every command.

Then, create a bare-bones deployment and name it `ci-server`:

```sh
$ nixops create ./hetzner.nix ./ci-server.nix -d ci-server
```

Now we can deploy it:

```sh
$ nixops deploy -d ci-server -I"nixpkgs=https://nixos.org/channels/nixos-19.03/nixexprs.tar.xz"
```

That's it!

### modifying existing deployment

Edit the configuration and then run:

```sh
$ nixops deploy -d ci-server -I"nixpkgs=https://nixos.org/channels/nixos-19.03/nixexprs.tar.xz"
```

### debugging buildbot

If something went wrong with `buildbot`, `ssh` into `root` on the deployed machine, and then try one of the following to tail the logs of the mater or one of the two workers:

```sh
$ journalctl -n100 -fu buildbot-master
$ journalctl -M worker-sisyphus -n100 -fu buildbot-worker
$ journalctl -M worker-oedipus -n100 -fu buildbot-worker
```

### entering buildbot worker environments

To enter a buildbot worker environment, run one of

```sh
$ ssh root@buildbot.dapp.ci -t "nixos-container root-login worker-oedipus"
# ./load-klab-env.sh
```
to enter the environment of the `klab` builder, or

```sh
$ ssh root@buildbot.dapp.ci -t "nixos-container root-login worker-sisyphus"
# ./load-k-dss-env.sh
```

### TODOs

-Fix annoying networking (spurious `eth2` interface) bug in `nixops` Hetzner backend.
