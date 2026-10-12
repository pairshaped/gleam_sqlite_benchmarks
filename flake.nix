{
  description = "SQLite request-shape benchmarks: Rust, Gleam, and Bun";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      # Pin each toolchain to an exact release. Gleam and Bun use the projects'
      # own release binaries so a new release doesn't wait on nixpkgs.
      gleamVersion = "1.19.2";
      gleamReleases = {
        x86_64-linux = {
          target = "x86_64-unknown-linux-musl";
          hash = "sha256-K6Kvtmyp9tzAGkpukWm2lCljutZIO+yVcd3AeM/m9B8=";
        };
        aarch64-linux = {
          target = "aarch64-unknown-linux-musl";
          hash = "sha256-0dGp1T9rMXwFY6SAaHPIzKzlQpHq0CM3NyivN5QC1PE=";
        };
        aarch64-darwin = {
          target = "aarch64-apple-darwin";
          hash = "sha256-+nxhE+Fiqx2Xn3Ln3ePpB7h+SzDFGK8Xh2jld9GAMk0=";
        };
      };

      bunVersion = "1.4.3";
      bunReleases = {
        # The standard x64 build needs AVX2. Check `grep -c avx2 /proc/cpuinfo`
        # on old x86 hosts; Bun also publishes a `bun-linux-x64-baseline` build.
        x86_64-linux = {
          target = "linux-x64";
          hash = "sha256-PnMFKNiXdfA/h/BcBnh8TfQJnQo38/JS57gpyyOBbhg=";
        };
        aarch64-linux = {
          target = "linux-aarch64";
          hash = "sha256-76mBPaXtckI7+Ef5FujSxHwNd2rdlyNUAmp14Q2pqiE=";
        };
        aarch64-darwin = {
          target = "darwin-aarch64";
          hash = "sha256-gK/UwGm0am+o8+xSC+vHUKeEPkqNW5WD0prUNsAKNAM=";
        };
      };

      rustVersion = "1.99.0";

      # Bun 1.4.3 embeds SQLite 3.51.0. Pin the shared SQLite used by the C,
      # Zig, Go and Rust runners to the same release so they compare like with
      # like. esqlite bundles its own SQLite (3.50.4) for the Gleam runner.
      sqliteVersion = "3.51.0";
      sqliteSource = {
        url = "https://www.sqlite.org/2025/sqlite-autoconf-3510000.tar.gz";
        hash = "sha256-QuJt/dlqouaxsb5ciLCIf5lZCT9lDWk8sC65w20UbKU=";
      };

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              overlays = [ rust-overlay.overlays.default ];
            }
          )
        );
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
          gleamRelease = gleamReleases.${system};
          bunRelease = bunReleases.${system};
        in
        {
          # Built straight from SQLite's release tarball with its default
          # options. nixpkgs' sqlite carries patches for its own version.
          sqlite = pkgs.stdenv.mkDerivation {
            pname = "sqlite";
            version = sqliteVersion;
            src = pkgs.fetchurl sqliteSource;
            configureFlags = [ "--disable-static" ];
            enableParallelBuilding = true;
          };

          gleam = pkgs.stdenvNoCC.mkDerivation {
            pname = "gleam";
            version = gleamVersion;
            src = pkgs.fetchurl {
              url = "https://github.com/gleam-lang/gleam/releases/download/v${gleamVersion}/gleam-v${gleamVersion}-${gleamRelease.target}.tar.gz";
              inherit (gleamRelease) hash;
            };
            sourceRoot = ".";
            installPhase = ''
              install -Dm755 gleam $out/bin/gleam
            '';
          };

          bun = pkgs.stdenv.mkDerivation {
            pname = "bun";
            version = bunVersion;
            src = pkgs.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${bunVersion}/bun-${bunRelease.target}.zip";
              inherit (bunRelease) hash;
            };
            sourceRoot = "bun-${bunRelease.target}";
            nativeBuildInputs = [
              pkgs.unzip
            ]
            ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.autoPatchelfHook ];
            # Stripping corrupts Bun's embedded runtime.
            dontStrip = true;
            installPhase = ''
              install -Dm755 bun $out/bin/bun
            '';
          };
        }
      );

      devShells = forAllSystems (
        pkgs:
        let
          localPackages = self.packages.${pkgs.stdenv.hostPlatform.system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              localPackages.gleam
              localPackages.bun
              (pkgs.rust-bin.stable.${rustVersion}.minimal.override { extensions = [ "rustfmt" ]; })
              pkgs.beamPackages.erlang
              pkgs.beamPackages.rebar3
              # One shared SQLite for the C, Zig, Go and Rust runners. Bun embeds
              # its own copy and esqlite bundles another.
              localPackages.sqlite
              pkgs.pkg-config
              pkgs.go
              pkgs.zig
              pkgs.git
              # scripts/summarize_benchmarks.rb
              pkgs.ruby
            ];
          };
        }
      );
    };
}
