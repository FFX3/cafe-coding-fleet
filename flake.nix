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

        lib = pkgs.lib;

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
          jq
          dig
          nodejs_22
          pnpm
        ];

        # ============================================================
        # Service Registry
        # ============================================================
        # Define all cluster services. Deploy order is computed from dependsOn.
        # Set enable = true to deploy a service (and its dependencies).

        servicesDef = {
          ingress = {
            enable = true;
            namespace = "ingress-nginx";
            manifests = "apps/nginx-ingress";
            dependsOn = [];
          };

          command-center = {
            enable = true;
            namespace = "command-center";
            manifests = "command-center";
            dependsOn = [ "ingress" ];
            description = "Privileged shell pod for cluster admin";
          };

          cert-manager = {
            enable = true;
            namespace = "cert-manager";
            manifests = "apps/cert-manager";
            dependsOn = [ "ingress" ];
          };

          postgres = {
            enable = true;
            namespace = "postgres";
            manifests = "apps/postgres";
            dependsOn = [ "cert-manager" ];
          };

          email = {
            enable = true;
            namespace = "email";
            manifests = "apps/email";
            dependsOn = [ "cert-manager" ];
          };

          platform-services = {
            enable = true;
            namespace = "platform-services";
            manifests = "apps/platform-services";
            dependsOn = [ "postgres" ];
            description = "GoTrue (auth) and PostgREST (API)";
          };

          studio = {
            enable = true;
            namespace = "studio";
            manifests = "apps/studio";
            dependsOn = [ "postgres" "platform-services" ];
            build = {
              context = "apps/studio";
              dockerfile = "Dockerfile";
              image = "studio";
            };
          };

          webstudio = {
            enable = true;
            namespace = "webstudio";
            manifests = "apps/webstudio";
            dependsOn = [ "postgres" "platform-services" ];
            build = {
              context = "forks/webstudio";
              dockerfile = "Dockerfile.builder";
              image = "webstudio-builder";
            };
          };

          twenty = {
            enable = true;
            namespace = "twenty";
            manifests = "apps/twenty";
            dependsOn = [ "postgres" ];
            description = "CRM application";
          };

          conduit = {
            enable = false;
            namespace = "conduit";
            manifests = "apps/conduit";
            dependsOn = [ "cert-manager" ];
            description = "Matrix homeserver";
          };

          hermes = {
            enable = false;
            namespace = "hermes";
            manifests = "apps/hermes";
            dependsOn = [ "platform-services" ];
            description = "AI agent";
          };

          passbolt = {
            enable = true;
            namespace = "passbolt";
            manifests = "apps/passbolt";
            dependsOn = [ "postgres" "email" ];
            description = "Password manager";
          };

          test-app = {
            enable = false;
            namespace = "test-app";
            manifests = "apps/test-app";
            dependsOn = [ "ingress" ];
          };

          test-app-2 = {
            enable = false;
            namespace = "test-app-2";
            manifests = "apps/test-app-2";
            dependsOn = [ "ingress" ];
          };
        };

        # Resolve enable flags: auto-enable dependencies of enabled services
        resolveEnabled = services:
          let
            # Get all explicitly enabled services
            explicitlyEnabled = lib.filterAttrs (n: s: s.enable or false) services;

            # Recursively collect all deps of a service
            collectDeps = name:
              if !(services ? ${name}) then []
              else
                let svc = services.${name};
                    deps = svc.dependsOn or [];
                in [name] ++ (lib.concatMap collectDeps deps);

            # All services needed (enabled + their deps)
            allNeeded = lib.unique (lib.concatMap collectDeps (lib.attrNames explicitlyEnabled));

            # Check for conflicts: dep explicitly disabled but required
            checkConflicts = name:
              let
                svc = services.${name};
                deps = svc.dependsOn or [];
                disabledDeps = lib.filter (d:
                  (services.${d}.enable or false) == false &&
                  services ? ${d} &&
                  services.${d} ? enable
                ) deps;
              in
                if (svc.enable or false) && (builtins.length disabledDeps > 0)
                then throw "Service '${name}' requires ${toString disabledDeps}, but they are explicitly disabled"
                else true;

            # Validate all enabled services
            _ = lib.all checkConflicts (lib.attrNames explicitlyEnabled);
          in
            lib.genAttrs allNeeded (name:
              services.${name} // { enable = true; _autoEnabled = !(explicitlyEnabled ? ${name}); }
            );

        # Topological sort by dependsOn (returns list in deploy order)
        topoSort = services:
          let
            names = lib.attrNames services;
            # For toposort: returns true if 'a' should come before 'b'
            before = a: b:
              let deps = services.${b}.dependsOn or [];
              in lib.elem a deps;
            sorted = lib.toposort before names;
          in
            if sorted ? cycle
            then throw "Dependency cycle detected: ${toString sorted.cycle}"
            else sorted.result;

        # Final resolved services (enabled + auto-enabled deps)
        services = resolveEnabled servicesDef;
        deployOrder = topoSort services;

        # Generate JSON config for shell scripts
        servicesJson = pkgs.writeText "services.json" (builtins.toJSON {
          inherit services;
          order = deployOrder;
          all = servicesDef;  # Include all services for deps command
        });

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
              export SERVICES_JSON="${servicesJson}"
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
        # Expose services config as a package
        packages.services-config = servicesJson;

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
