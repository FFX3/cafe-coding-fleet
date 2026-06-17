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
        ];

        # Helper to create an app from a script (scriptPath is relative to repo root)
        mkApp = name: description: scriptPath: {
          type = "app";
          program = "${pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = runtimeDeps;
            text = ''
              export INFRA_SHELL=1
              cd "${self}"
              exec ./${scriptPath} "$@"
            '';
          }}/bin/${name}";
          meta.description = description;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = runtimeDeps;

          shellHook = ''
            export INFRA_SHELL=1

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

        apps = {
          # Cluster management
          cluster-up = mkApp "cluster-up" "Start GCP cluster" "scripts/cluster-up.sh";
          cluster-down = mkApp "cluster-down" "Stop GCP cluster" "scripts/cluster-down.sh";
          local-cluster = mkApp "local-cluster" "Manage local Docker cluster" "scripts/local-cluster.sh";

          # Deployment
          deploy-apps = mkApp "deploy-apps" "Deploy all applications" "scripts/deploy-apps.sh";
          deploy-ingress = mkApp "deploy-ingress" "Deploy nginx ingress" "scripts/deploy-ingress.sh";
          deploy-cert-manager = mkApp "deploy-cert-manager" "Deploy cert-manager" "scripts/deploy-cert-manager.sh";
          deploy-postgres = mkApp "deploy-postgres" "Deploy PostgreSQL" "scripts/deploy-postgres.sh";
          deploy-twenty = mkApp "deploy-twenty" "Deploy Twenty CRM" "scripts/deploy-twenty.sh";
          deploy-test-apps = mkApp "deploy-test-apps" "Deploy test applications" "scripts/deploy-test-apps.sh";

          # Utilities
          dashboard = mkApp "dashboard" "Open Talos dashboard" "scripts/dashboard.sh";
          db-connect = mkApp "db-connect" "Connect to PostgreSQL" "scripts/db-connect.sh";
          disk-usage = mkApp "disk-usage" "Show disk usage" "scripts/disk-usage.sh";
          list-resources = mkApp "list-resources" "List GCP resources" "scripts/list-resources.sh";
          monitor = mkApp "monitor" "Monitor cluster status" "scripts/monitor-status.sh";
        };
      }
    );
}
