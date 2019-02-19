let
  server-ip = "FILLME!"; in
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
    # networking.usePredictableInterfaceNames = false;
    # networking.interfaces.eth2.macAddress = "6c:b3:11:23:52:c2";
    # #networking.interfaces.eth1.macAddress = "e0:d5:5e:c2:cb:a6";
    # #networking.interfaces.eth2.macAddress = "e0:d5:5e:c2:cb:a4";
    # #networking.interfaces.eth3.macAddress = "6c:b3:11:23:52:c3";
    # boot.kernelParams = [ "net.ifnames=0" "biosdevname=0" ];
    # boot.initrd.extraUdevRulesCommands = with lib;
    # let
    #   macInterfaces = filterAttrs (name: interface: interface.macAddress != null) config.networking.interfaces;
    #   extraUdevRules = pkgs.writeTextDir "10-mac-network.rules" (concatStrings (mapAttrsToList (name: interface: ''
    #     ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="${interface.macAddress}", NAME="${name}"
    #   '') macInterfaces));
    # in ''
    #   cp -v ${extraUdevRules}/*.rules $out/
    # '';
  };
}
