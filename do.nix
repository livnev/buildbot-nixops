{
  network.description = "DigitalOcean droplet";

  resources.sshKeyPairs.ssh-key = {};

  ci-machine = { config, pkgs, ... }: {
    deployment.targetEnv = "digitalOcean";
    deployment.digitalOcean.region = "ams3";
    deployment.digitalOcean.size = "1gb";

  };
}
