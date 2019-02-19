let
  inherit (import <nixpkgs> {}) fetchFromGitHub;
  nixpkgs = fetchFromGitHub {
    owner  = "livnev";
    repo   = "nixpkgs";
    rev    = "3a272796113b335bb84c4ae279805ac6ccd5af89";
    sha256 = "04vvignvld1qzm8w3cr5fn7zjndhgyf1zndfhdgwfzsk7xlbxmpn";
  };
  nixpkgs-for-dapp = builtins.fetchTarball {
    name = "nixpkgs-release-18.09";
    # pin the current release-18.09 commit
    url = "https://github.com/nixos/nixpkgs/archive/185ab27b8a2ff2c7188bc29d056e46b25dd56218.tar.gz";
    sha256 = "0bflmi7w3gas9q8wwwwbnz79nkdmiv2c1bpfc3xyplwy8npayxh2";
  };
  pkgs = import nixpkgs {};
  pkgs-for-dapp = import nixpkgs-for-dapp {
    overlays = [
      (import (builtins.fetchGit {
        url = "git@github.com:dapphub/dapptools.git";
        rev = "d8e78aedaaeda323fb583ea52bef250634399e6a";
      } + /overlay.nix)) ];
  };

  my-ssh-key    = (import ./keys.nix).my-ssh-key;
  our-keys = [ my-ssh-key ];

  buildbot-masterCfg       = ./master.cfg;
  buildbot-www-endpoint    = "http://127.0.0.1:8010";
  buildbot-master-endpoint = "localhost:9989";
  buildbot-external-domain = "FILLME!";
  reports-domain           = "FILLME!";
  proofs-domain            = "FILLME!";
  reports-publish-dir      = "/var/publish/reports";
  proofs-publish-dir       = "/var/publish/proofs";
  klab-dir                 = "/home/bbworker/klab";

  git-ci = (import ./git-ci.nix { inherit pkgs; }).git_ci;

  worker-packages = with pkgs; [
    # required for build steps
    bash
    gnumake
    git
    time
    jq
    pkgs-for-dapp.dapp
    # required for make colouring
    ncurses
    # required to fetch nixpkgs
    gnutar
    gzip
    nix
    # fancy git utilities
    git-ci
  ];
in
{
  ci-machine = { config, pkgs, ... }: {

    time.timeZone = "UTC";

    networking.firewall.allowedTCPPorts = [ 80 443 ];

    users.mutableUsers = false;

    users.extraUsers.root.openssh.authorizedKeys.keys = our-keys;

    users.extraUsers.FILLME = {
      isNormalUser = true;
      uid = 1000;
      createHome = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ my-ssh-key ];
    };

    security.sudo.wheelNeedsPassword = false;

    nix.gc.automatic = true;

    environment.systemPackages = with pkgs; [
      htop
      killall
      pstree
    ];

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
      BUILDBOT_EXTERNAL_DOMAIN = buildbot-external-domain;
      KLAB_WEBPROOF_DIR        = proofs-publish-dir;
      KLAB_REPORT_DIR          = reports-publish-dir;
      KLAB_DIR                 = klab-dir;
    };

    system.activationScripts.publish-dirs = ''
      mkdir -p ${reports-publish-dir}
      mkdir -p ${proofs-publish-dir}
      chmod 777 ${reports-publish-dir}
      chmod 777 ${proofs-publish-dir}
    '';

    containers.worker-sisyphus = {
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
          workerUser = "sisyphus";
          workerPass = "FILLME!";
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
      };
    };

    containers.worker-oedipus = {
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
          workerUser = "oedipus";
          workerPass = "FILLME!";
          masterUrl = buildbot-master-endpoint;
          packages = worker-packages;
        };
        programs.ssh.extraConfig = ''
          Host github.com
              StrictHostKeyChecking no
        '';
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
      "${buildbot-external-domain}".email = "FILLME!";
      "${reports-domain}".email           = "FILLME!";
      "${proofs-domain}".email            = "FILLME!";
    };
  };
}
