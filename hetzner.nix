let
  server-ip = "FILLME"; in
{
  network.description = "Hetzner dedicated server";

  resources.sshKeyPairs.ssh-key = {};

  ci-machine = { config, pkgs, lib, ...}: {
    deployment.targetEnv = "hetzner";
    deployment.hetzner.mainIPv4 = server-ip;
    deployment.hetzner.createSubAccount = false;
    deployment.hetzner.partitions = ''
      clearpart --all --initlabel --drives=nvme0n1,nvme1n1

      part swap1 --recommended --label=swap1 --fstype=swap --ondisk=nvme0n1
      part swap2 --recommended --label=swap2 --fstype=swap --ondisk=nvme1n1

      part raid.1 --grow --ondisk=nvme0n1
      part raid.2 --grow --ondisk=nvme1n1

      raid / --level=1 --device=md0 --fstype=ext4 --label=root raid.1 raid.2
    '';

    swapDevices = [
      {device = "/swapfile"; size = 10000;}
    ];
  };
}
