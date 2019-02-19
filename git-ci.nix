{ pkgs }:

let git-ci-repo = pkgs.fetchFromGitHub {
      owner = "dapphub";
      repo  = "git-ci";
      rev = "a673f5e30c37a8382ba1e709ede801e35881ebe4";
      sha256 = "188jk101nqgyr2n7fgszkgbf5acr9ih19mgwxpl6afm6w1ssnzd8";
  }; in
{
  git_shell_commands = pkgs.stdenv.mkDerivation {
    name = "git-shell-commands";
    src  = git-ci-repo;
    installPhase = ''
      mkdir -p "$out/bin"
      install git-shell-commands/* "$out/bin"
    '';
  };

  git_ci = pkgs.stdenv.mkDerivation {
    name = "git-ci";
    src = git-ci-repo;
    installPhase = ''
      mkdir -p "$out/bin"
      install bin/* "$out/bin"
  '';
  };
}
