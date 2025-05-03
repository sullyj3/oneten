{
  description = "Dev shell for oneten (Zig + raylib-zig)";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            zig
            pkg-config

            xorg.libX11
            xorg.libXcursor
            xorg.libXext
            xorg.libXfixes
            xorg.libXi
            xorg.libXinerama
            xorg.libXrandr
            xorg.libXrender

            wayland          # wayland-client, wayland protocols

            mesa             # provides both libGL and libEGL
            libglvnd
            libxkbcommon     # XKB common library

	    alsa-lib
	    pulseaudio
          ];

          # pkg-config setup is automatic for mkShell, but if you need
          # to tweak PKG_CONFIG_PATH you can still do it here:
          shellHook = ''
            # nothing special needed—`mesa` and friends will register .pc files
          '';
        };
      });
}

