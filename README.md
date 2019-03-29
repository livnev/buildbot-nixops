# buildbot-nixops

This is a nix derivation for deploying a [buildbot](https://buildbot.net/) CI server using [nixops](https://nixos.org/nixops/). It comes preinstalled with some useful utility commands from [git-ci](https://github.com/ehildenb/git-ci).

## configure

First, search this repo for `FILLME` and fill in all fields:

```sh
$ grep FILLME *
```

## deploying

Firstly, `nixops` is currently broken in `nixpkgs` master, in two different ways: [here](https://github.com/NixOS/nixops/issues/1086) and [here](https://github.com/NixOS/nixpkgs/issues/50419). Hence I'm using a custom `nixpkgs` which is provided as a submodule in this repo.

Make sure the custom `nixpkgs` submodule is initialised:

```sh
$ git submodule update --init --recursive
```

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

Now we can deploy it, specifying the path to our custom `nixpkgs` submodule:

```sh
$ nixops deploy -d ci-server -I"nixpkgs=./nixpkgs"
```

That's it!

### modifying existing deployment

Edit the configuration and then run:

```sh
$ nixops deploy -d ci-server -I"nixpkgs=./nixpkgs"
```

### debugging buildbot

If something went wrong with `buildbot`, `ssh` into `root` on the deployed machine, and then try one of the following to tail the logs of the mater or one of the two workers:

```sh
$ journalctl -n100 -fu buildbot-master
$ journalctl -M worker-sisyphus -n100 -fu buildbot-worker
$ journalctl -M worker-oedipus -n100 -fu buildbot-worker
```

### TODOs

-Fix annoying networking (spurious `eth2` interface) bug in `nixops` Hetzner backend.
