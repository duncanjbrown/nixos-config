# NixOS environment

Flake-based NixOS config for OrbStack VMs. OrbStack's machine-local files are
read live at build time — `/etc/nixos/orbstack.nix`, `/etc/nixos/incus.nix`
(which sets the hostname), and `/opt/orbstack-guest/run/extra-certs.crt`
(which carries the machine's CA certs) — so rebuilds need `--impure`; the
`rebuild` script wraps that. Nothing machine-local is committed to this repo.

- `flake.nix` — inputs; one `orb` system shared by every machine
- `orbstack.nix` — platform glue: LXC base, OrbStack files, networking
- `configuration.nix` — user account, nix settings, services (docker, postgres, neo4j, nginx)
- `home.nix` — home-manager: packages, zsh, neovim, git, opencode service
- `opencode-widget/` — optional chat widget injected into nginx-served pages

1. Start a VM in OrbStack
1. `ssh orb` from host
1. Clone and run the setup script (do **not** run with `sudo` — it handles that internally):
   ```
   nix-shell -p git --run 'git clone https://github.com/duncanjbrown/nixos-config.git ~/nixos-config'
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
