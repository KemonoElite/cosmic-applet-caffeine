{
  description = "Caffeine applet for the COSMIC desktop: keep the system awake on demand";

  inputs = {
    # libcosmic sets rust-version = 1.93, which is newer than the rustc in the
    # current stable NixOS release, so build against unstable.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      cargoToml = lib.importTOML ./Cargo.toml;
      appId = "com.github.codevardhan.caffeine-applet";
      binName = cargoToml.package.name; # caffeine-applet

      mkPackage =
        {
          lib,
          stdenv,
          rustPlatform,
          libcosmicAppHook,
          libxkbcommon,
        }:
        rustPlatform.buildRustPackage {
          pname = "cosmic-applet-caffeine";
          inherit (cargoToml.package) version;

          # Only what the build reads, so editing the README, CI or this flake
          # does not trigger a rebuild. tests/ is needed: src/window.rs pulls
          # its unit tests in from there with #[path].
          src = lib.fileset.toSource {
            root = ./.;
            fileset = lib.fileset.unions [
              ./Cargo.toml
              ./Cargo.lock
              ./i18n.toml
              ./i18n
              ./resources
              ./src
              ./tests
            ];
          };

          # libcosmic and friends are git dependencies. Fetching them with
          # builtins.fetchGit (pinned by the revs in Cargo.lock) means there is
          # no cargoHash to bump every time Cargo.lock changes.
          cargoLock = {
            lockFile = ./Cargo.lock;
            allowBuiltinFetchGit = true;
          };

          # Forces linking of the libraries libcosmic dlopen()s (wayland, EGL,
          # xkbcommon, ...) and wraps the binary with COSMIC's fallback
          # themes and icons on XDG_DATA_DIRS.
          nativeBuildInputs = [ libcosmicAppHook ];
          buildInputs = [ libxkbcommon ];

          # The tests that need the logind system bus or cosmic-idle skip
          # themselves when those are missing, as they are in the sandbox.
          preCheck = ''
            export HOME="$TMPDIR"
            export XDG_CONFIG_HOME="$TMPDIR/.config"
          '';

          # Same layout as the Flatpak manifest and `just install`.
          postInstall = ''
            install -Dm0644 resources/app.desktop \
              $out/share/applications/${appId}.desktop
            install -Dm0644 resources/app.metainfo.xml \
              $out/share/metainfo/${appId}.metainfo.xml

            icons=resources/icons/hicolor/scalable/apps
            dest=$out/share/icons/hicolor/scalable/apps
            install -Dm0644 $icons/icon.svg            $dest/${appId}.svg
            install -Dm0644 $icons/coffee-symbolic.svg $dest/${appId}-symbolic.svg
            install -Dm0644 $icons/coffee-full.svg     $dest/${appId}.On.svg
            install -Dm0644 $icons/coffee-empty.svg    $dest/${appId}.Off.svg
          '';

          meta = {
            description = cargoToml.package.description;
            homepage = "https://github.com/KemonoElite/cosmic-applet-caffeine";
            license = lib.licenses.mit;
            mainProgram = binName;
            platforms = lib.platforms.linux;
          };
        };
    in
    {
      overlays.default = final: _prev: {
        cosmic-applet-caffeine = final.callPackage mkPackage { };
      };

      packages = forAllSystems (pkgs: rec {
        cosmic-applet-caffeine = pkgs.callPackage mkPackage { };
        default = cosmic-applet-caffeine;
      });

      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.cosmic-applet-caffeine;
        in
        {
          options.programs.cosmic-applet-caffeine = {
            enable = lib.mkEnableOption "the Caffeine applet for the COSMIC panel";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
              defaultText = lib.literalExpression "cosmic-applet-caffeine.packages.\${pkgs.stdenv.hostPlatform.system}.default";
              description = "The cosmic-applet-caffeine package to install.";
            };
          };

          # The panel finds applets through the X-CosmicApplet desktop entry,
          # which systemPackages links into /run/current-system/sw/share.
          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
          };
        };

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          # Brings in rustc, cargo, pkg-config, libxkbcommon and the
          # libcosmicAppHook shell hook, which sets RUSTFLAGS so `cargo run`
          # links the libraries libcosmic would otherwise dlopen().
          inputsFrom = [ self.packages.${pkgs.stdenv.hostPlatform.system}.default ];

          packages = with pkgs; [
            clippy
            rustfmt
            rust-analyzer
            just
            appstream # appstreamcli, for `just check-metadata`
            imagemagick # identify, for `just check-metadata`
          ];

          RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
        };
      });

      checks = forAllSystems (pkgs: {
        package = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
