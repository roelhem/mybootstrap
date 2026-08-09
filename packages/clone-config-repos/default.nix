{
  writeShellApplication,
  git,
  coreutils,
}:

writeShellApplication {
  name = "clone-config-repos";
  runtimeInputs = [
    git
    coreutils
  ];

  text = ''
    mkdir -p ~/workspace/roelhem
    cd ~/workspace/roelhem

    git clone https://gitea.mmrh.nl/roelhem/myemacs.git || echo "already cloned myemacs"
    git clone https://gitea.mmrh.nl/roelhem/myconf.git || echo "already cloned myconf"
    git clone https://gitea.mmrh.nl/roelhem/mybootstrap.git || echo "already cloned mybootstrap"
  '';
}
