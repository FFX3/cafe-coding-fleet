# Nix Flake

This project uses a [Nix flake](https://nixos.wiki/wiki/Flakes) for reproducible tooling and command discovery.

## What is a Flake?

A flake is a Nix project with:
- **Locked dependencies** (`flake.lock`) - exact versions of all inputs
- **Standardized outputs** - dev shells, packages, apps
- **Pure evaluation** - only sees git-tracked files (no `.gitignore`d files)

Think of it as `package.json` + `package-lock.json` but for system tools.

## What This Flake Provides

### Dev Shell

```bash
nix develop
```

Drops you into a shell with all required tools:
- `talosctl` - Talos cluster management
- `kubectl` - Kubernetes CLI
- `terraform` - Infrastructure as code
- `gcloud` - Google Cloud SDK
- `sops` / `age` - Secrets encryption
- `docker` - Container runtime
- `yq` - YAML processor

### Apps (Commands)

```bash
nix run .#cluster-up
nix run .#deploy-postgres
nix run .#db-connect
# ... etc
```

Each app wraps a script with the dev shell's tools available.

## Discovering Available Commands

```bash
nix flake show
```

Output shows all available apps:

```
git+file:///home/justinm/infrastructure
├───apps
│   └───x86_64-linux
│       ├───cluster-down: app
│       ├───cluster-up: app
│       ├───dashboard: app
│       ├───db-connect: app
│       ├───deploy-apps: app
│       ├───deploy-postgres: app
│       ...
```

## How Auto-Discovery Works

The flake automatically generates apps from `scripts/*.sh`:

```nix
# Read all files in scripts/
scriptsDir = builtins.readDir "${self}/scripts";

# Filter to .sh files
scriptFiles = pkgs.lib.filterAttrs
  (name: type: type == "regular" && pkgs.lib.hasSuffix ".sh" name)
  scriptsDir;

# Generate apps from each script
autoApps = pkgs.lib.mapAttrs' (filename: _:
  let appName = toAppName filename;  # remove .sh, replace _ with -
  in {
    name = appName;
    value = mkApp appName (toDescription appName) "scripts/${filename}";
  }
) scriptFiles;
```

**Key point:** `scripts/my-script.sh` becomes `nix run .#my-script`

## Adding a New Command

1. Create the script:
   ```bash
   cat > scripts/my-command.sh << 'EOF'
   #!/usr/bin/env bash
   set -euo pipefail
   source "$(dirname "$0")/internal/require-env.sh"

   echo "Hello from my-command!"
   EOF
   chmod +x scripts/my-command.sh
   ```

2. **Important:** Add to git (flakes only see tracked files):
   ```bash
   git add scripts/my-command.sh
   ```

3. Use it:
   ```bash
   nix run .#my-command
   ```

No `flake.nix` edits required.

## Why Git Tracking Matters

Flakes use **pure evaluation** - they only see files tracked by git. This ensures:
- Reproducibility (same inputs = same outputs)
- No accidental inclusion of local-only files
- Clean CI/CD (what you commit is what runs)

If a script isn't showing up in `nix flake show`, check:
```bash
git status scripts/
```

Untracked files won't be discovered.

## Passing Arguments

Arguments after `--` are passed to the script:

```bash
# Pass --force to cluster-down.sh
nix run .#cluster-down -- --force

# Pass "up" to local-cluster.sh
nix run .#local-cluster -- up
```

## Running Without Nix Shell

Each `nix run` command includes all dependencies. You don't need to be in `nix develop`:

```bash
# These work from anywhere
nix run .#cluster-up
nix run .#deploy-apps

# vs running scripts directly (requires nix develop first)
nix develop
./scripts/cluster-up.sh
```

## Common Commands Reference

| Command | Description |
|---------|-------------|
| `nix flake show` | List all available apps |
| `nix flake update` | Update all flake inputs (nixpkgs, etc.) |
| `nix develop` | Enter dev shell with all tools |
| `nix develop -c <cmd>` | Run single command in dev shell |
| `nix run .#<app>` | Run an app |
| `nix run .#<app> -- <args>` | Run an app with arguments |

## Flake Structure

```
flake.nix          # Flake definition
flake.lock         # Locked dependency versions (auto-generated)
```

Key sections in `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "...";      # Where to get packages
  };

  outputs = { self, nixpkgs, ... }: {
    devShells.default = ...;  # nix develop
    apps = ...;               # nix run .#<name>
  };
}
```

## Troubleshooting

### "command not found" in nix run

The script might not be executable:
```bash
chmod +x scripts/my-script.sh
```

### Script not appearing in flake show

Not tracked by git:
```bash
git add scripts/my-script.sh
```

### Old version of script running

Nix caches builds. Force rebuild:
```bash
nix run .#my-command --rebuild
```

Or the file might have unstaged changes that git hasn't seen yet.

### "pure evaluation" errors

You're trying to access a path outside the flake. All paths must be:
- Inside the repo, AND
- Tracked by git

## Further Reading

- [Nix Flakes Wiki](https://nixos.wiki/wiki/Flakes)
- [Practical Nix Flakes](https://serokell.io/blog/practical-nix-flakes)
- [flake-utils](https://github.com/numtide/flake-utils) - Helper library we use
