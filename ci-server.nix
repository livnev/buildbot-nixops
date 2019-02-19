let
  dapptools_git = builtins.fetchGit {
    url = "git@github.com:dapphub/dapptools.git";
    rev = "138946e3323376d7e3acf7536b094b0108b81636";
  };

  dapptools = import (dapptools_git) {};

  pkgs = import <nixpkgs> {};

  my-ssh-key    = (import ./keys.nix).lev-ssh-key;
  our-keys = [ my-ssh-key ];

  buildbot-masterCfg       = ./master.cfg;
  buildbot-www-endpoint    = "http://127.0.0.1:8010";
  buildbot-master-endpoint = "localhost:9989";
  buildbot-external-domain = "buildbot.FILLME";
  reports-domain           = "FILLME";
  proofs-domain            = "proof.FILLME";
  reports-publish-dir      = "/var/publish/reports";
  proofs-publish-dir       = "/var/publish/proofs";
  klab-dir                 = "/home/bbworker/klab";
  klab-persistent-dir      = "/home/bbworker/persistent/klab_out";

  git-ci = (import ./git-ci.nix { inherit pkgs; }).git_ci;

  worker-packages = with pkgs; [
    # required for build steps
    git
    time
    dapptools.dapp
    # required for make colouring
    ncurses
    # required to fetch nixpkgs
    gnutar
    gzip
    nix
    # fancy git utilities
    git-ci
  ];
  load-klab-env = pkgs.writeShellScriptBin "load-klab-env" ''
    exec su -l bbworker -c 'cd ~/worker/klab/build && \
    NIX_PATH=nixpkgs=https://github.com/NixOS/nixpkgs-channels/archive/nixos-19.03.tar.gz nix-shell'
  '';
in
{
  ci-machine = { config, pkgs, ... }: {

    time.timeZone = "UTC";

    networking.firewall.allowedTCPPorts = [ 80 443 ];

    users.mutableUsers = false;

    users.users.root.openssh.authorizedKeys.keys = our-keys;

    users.users.FILLME = {
      isNormalUser = true;
      uid = 1000;
      createHome = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ my-ssh-key ];
    };

    security.sudo.wheelNeedsPassword = false;

    nix.gc.automatic = false;

    environment.systemPackages = with pkgs; [
      htop
      killall
      pstree
      neovim
      git
    ];

    programs.mosh.enable = true;

    services.buildbot-master = {
      enable = true;
      masterCfg = buildbot-masterCfg;
      packages = [
        pkgs.git
      ];
      pythonPackages =
        pythonPackages: with pythonPackages; [
        requests
        service-identity
        txrequests
      ];
    };
    systemd.services.buildbot-master.environment = {
      DAPPTOOLS                = dapptools_git.outPath;
      BUILDBOT_EXTERNAL_DOMAIN = buildbot-external-domain;
      KLAB_WEBPROOF_DIR        = proofs-publish-dir;
      KLAB_REPORT_DIR          = reports-publish-dir;
      KLAB_PATH                = klab-dir;
      KLAB_PERSISTENT_DIR      = klab-persistent-dir;
    };

    system.activationScripts.publish-dirs = ''
      mkdir -p ${reports-publish-dir}
      mkdir -p ${proofs-publish-dir}
      chmod 777 ${reports-publish-dir}
      chmod 777 ${proofs-publish-dir}
    '';

    containers.worker-FILLME = {
      autoStart = true;
      bindMounts = {
        "/var/publish/reports" = {
          hostPath   = reports-publish-dir;
          isReadOnly = false;
        };
        "/var/publish/proofs"  = {
          hostPath   = proofs-publish-dir;
          isReadOnly = false;
        };
      };
      config = { config, pkgs, ... }:
      {
        services.buildbot-worker = {
          enable = true;
          workerUser = "FILLME";
          workerPass = "FILLME";
          masterUrl = buildbot-master-endpoint;
          packages = worker-packages;
        };
        programs.ssh.extraConfig = ''
          Host github.com
              StrictHostKeyChecking no
            '';
            systemd.services.buildbot-worker.preStart = let git = "${pkgs.git}/bin/git"; in ''
              (cd ${klab-dir} && ${git} status) || (${git} clone https://github.com/dapphub/klab.git ${klab-dir} --recursive)
        '';
        environment.systemPackages = [ load-klab-env ];
      };
    };

    services.nginx = {
      enable = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      virtualHosts = {
        "${buildbot-external-domain}" = {
          locations."/" = {
            proxyPass = "${buildbot-www-endpoint}";
            extraConfig = ''
              proxy_set_header Host $http_host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
          locations."/sse" = {
            proxyPass = "${buildbot-www-endpoint}";
            extraConfig = ''
              proxy_buffering off;
            '';
          };
          locations."/ws" = {
            proxyPass = "${buildbot-www-endpoint}";
            extraConfig = ''
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
              proxy_read_timeout 6000s;
            '';
          };
          enableACME = true;
          forceSSL = true;
        };
        "${reports-domain}" = {
          locations."/".root = reports-publish-dir;
          enableACME = true;
          forceSSL = true;
        };
        "${proofs-domain}" = {
          locations."/".root = proofs-publish-dir;
          enableACME = true;
          forceSSL = true;
        };
      };
    };

    security.acme.certs = {
      "${buildbot-external-domain}".email = "FILLME";
      "${reports-domain}".email           = "FILLME";
      "${proofs-domain}".email            = "FILLME";
    };
  };
}
