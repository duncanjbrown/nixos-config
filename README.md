# NixOS environment

1. Start a VM in OrbStack
1. `ssh orb` from host
1. `nix-shell -p git vim` and 
    1. `git clone` this repo under home directory
    1. `cd /etc/nixos`
    1. `ln -s /home/duncanbrown/nixos-config ./duncan`
    1. `sudo vi configuration.nix` and add `duncan.nix` alongside the other .nix includes.
1. `sudo nix-rebuild switch`
1. `cd ~/.dotfiles; rcup` (not sure why this isn't working yet)
1. Log out and log back in again

