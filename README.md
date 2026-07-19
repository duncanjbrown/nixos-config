# NixOS environment

1. Start a VM in OrbStack
1. `ssh orb` from host
1. Get a shell with git in it (and vim just in case): `nix-shell -p git vim`
1. Clone and run the setup script (do **not** run with `sudo` — it handles that internally):
   ```
   git clone https://github.com/duncanjbrown/nixos-config.git ~/nixos-config
   ~/nixos-config/setup.sh
   ```
1. `gh auth login` for GitHub
1. Log out and log back in again
