{
  description = "Infrastructure tooling for Talos Kubernetes cluster";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg:
            builtins.elem (nixpkgs.lib.getName pkg) [
              "terraform"
              "google-cloud-sdk"
            ];
        };

        # Shared runtime dependencies
        runtimeDeps = with pkgs; [
          talosctl
          kubectl
          terraform
          google-cloud-sdk
          sops
          age
          docker
          yq-go
        ];

        # Helper to create an app from a script (scriptPath is relative to repo root)
        mkApp = name: description: scriptPath: {
          type = "app";
          program = "${pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = runtimeDeps;
            text = ''
              export INFRA_SHELL=1
              export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
              export INFRA_ROOT="$PWD"
              mkdir -p "$TF_PLUGIN_CACHE_DIR"
              exec "${self}/${scriptPath}" "$@"
            '';
          }}/bin/${name}";
          meta.description = description;
        };

        # Auto-discover scripts in scripts/ directory
        scriptsDir = builtins.readDir "${self}/scripts";

        # Filter to .sh files only (not directories)
        scriptFiles = pkgs.lib.filterAttrs
          (name: type: type == "regular" && pkgs.lib.hasSuffix ".sh" name)
          scriptsDir;

        # Convert filename to app name: remove .sh, replace _ with -
        toAppName = filename:
          builtins.replaceStrings ["_"] ["-"]
            (pkgs.lib.removeSuffix ".sh" filename);

        # Generate description from app name
        toDescription = appName:
          let
            # Capitalize first letter of each word
            capitalize = s:
              let len = builtins.stringLength s;
              in if len == 0 then ""
                 else (pkgs.lib.toUpper (builtins.substring 0 1 s)) + (builtins.substring 1 len s);
            words = builtins.filter (s: s != "") (pkgs.lib.splitString "-" appName);
            capitalized = builtins.concatStringsSep " " (map capitalize words);
          in
            if pkgs.lib.hasPrefix "deploy-" appName
            then "Deploy ${pkgs.lib.removePrefix "Deploy " capitalized}"
            else capitalized;

        # Generate apps from all scripts
        autoApps = pkgs.lib.mapAttrs' (filename: _:
          let appName = toAppName filename;
          in {
            name = appName;
            value = mkApp appName (toDescription appName) "scripts/${filename}";
          }
        ) scriptFiles;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = runtimeDeps;

          shellHook = ''
            export INFRA_SHELL=1
            export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
            mkdir -p "$TF_PLUGIN_CACHE_DIR"

            echo ""
            echo "══════════════════════════════════════════════════════════════════"
            echo "  Infrastructure Environment"
            echo "══════════════════════════════════════════════════════════════════"
            echo ""
            echo "  Tools: talosctl, kubectl, terraform, gcloud, sops, age, docker"
            echo ""
            echo "  Commands (also available via 'nix run .#<command>'):"
            echo "    ./scripts/cluster-up.sh        Start GCP cluster"
            echo "    ./scripts/cluster-down.sh      Stop GCP cluster"
            echo "    ./scripts/local-cluster.sh     Local Docker cluster (up/down)"
            echo "    ./scripts/deploy-apps.sh       Deploy all applications"
            echo "    ./scripts/dashboard.sh         Open Talos dashboard"
            echo "    ./scripts/db-connect.sh        Connect to PostgreSQL"
            echo ""
            echo "  First time setup:"
            echo "    gcloud auth application-default login"
            echo "    age-keygen -o ~/.config/sops/age/keys.txt"
            echo ""
            echo "══════════════════════════════════════════════════════════════════"
            echo ""
          '';
        };

        # All apps are auto-generated from scripts/*.sh
        # Add a new script to scripts/ and it becomes available as `nix run .#script-name`
        apps = autoApps;
      }
    );
}
