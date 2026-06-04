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
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Talos CLI
            talosctl

            # Kubernetes CLI
            kubectl

            # Infrastructure provisioning
            terraform

            # GCP CLI
            google-cloud-sdk

            # Secrets management
            sops
            age
            # Frappe build dependencies
            python314
            python314Packages.pip
            python314Packages.virtualenv
            nodejs_22
            yarn
            git
            pkg-config
            libmysqlclient  # Required to build mysqlclient Python package (Frappe supports both MySQL and PostgreSQL)
          ];

          shellHook = ''
            echo ""
            echo "══════════════════════════════════════════════════════════════════"
            echo "  Infrastructure Environment"
            echo "══════════════════════════════════════════════════════════════════"
            echo ""
            echo "  Tools: talosctl, kubectl, terraform, gcloud, sops, age"
            echo ""
            echo "  Local cluster (Docker):"
            echo "    ./scripts/local-cluster.sh up      Create cluster"
            echo "    ./scripts/local-cluster.sh down    Destroy cluster"
            echo ""
            echo "  GCP cluster:"
            echo "    ./scripts/setup-gcp-image.sh       (first time only)"
            echo "    ./scripts/cluster-up.sh            (create VM and bootstrap)"
            echo "    ./scripts/cluster-down.sh          (destroy VM, keep disks)"
            echo ""
            echo "  Frappe assets:"
            echo "    ./scripts/build-frappe-assets.sh   Build and upload to GCS"
            echo ""
            echo "  View resources:"
            echo "    ./scripts/list-resources.sh"
            echo ""
            echo "  First time setup:"
            echo "    gcloud auth application-default login"
            echo "    age-keygen -o ~/.config/sops/age/keys.txt  (see docs/sops-secrets.md)"
            echo "    sops terraform/secrets.enc.yaml            (see docs/cloudflare-setup.md)"
            echo ""
            echo "══════════════════════════════════════════════════════════════════"
            echo ""
          '';
        };
      }
    );
}
