# NixOS environment

Flake-based NixOS config for OrbStack VMs. OrbStack's machine-local files are
read live at build time — `/etc/nixos/orbstack.nix`, `/etc/nixos/incus.nix`
(which sets the hostname), and `/opt/orbstack-guest/run/extra-certs.crt`
(which carries the machine's CA certs) — so rebuilds need `--impure`; the
`rebuild` script wraps that. Nothing machine-local is committed to this repo.

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

## Rebuilding after changes

```
~/nixos-config/rebuild
```

## Updating packages

```
cd ~/nixos-config
nix flake update
./rebuild
```

Review the `flake.lock` diff before committing.
