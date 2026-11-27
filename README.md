# Volumes

A volumes applet for the [COSMIC](https://github.com/pop-os/cosmic-epoch) desktop panel. It lists your USB sticks, SD cards, discs, external disks, Android phones, and Samba, NFS and SFTP shares, and lets you open, mount and safely remove them from the panel. It works like the macOS `/Volumes` folder, where every disk shows up in one place.

<img src="screenshots/volumes-applet.png" alt="Volumes applet listing a USB drive and two saved network shares" width="407">

> **No maintainer, no support, no warranty.** This project is not maintained. Nobody takes bug reports and nobody will fix bugs. It is provided as is and you use it entirely at your own risk. It mounts, unmounts and powers off storage devices, so don't rely on it where losing data would matter. See the [license](LICENSE) for the full disclaimer.

## Features

- **Drives**: removable drives (USB sticks, SD cards, optical discs, external disks) and any internal volume mounted under `/run/media` or `/media`, whether mounted or not
  - Click a mounted drive to open it in your default file manager. Click an unmounted drive to mount it and open it.
  - **Safe removal**: the eject button unmounts the drive. If nothing else on that drive is still mounted, it also powers the drive off or ejects the disc.
- **Android phones** and other MTP devices, listed with a phone icon and mounted the same way as drives
- **Network shares** (Samba/SMB, NFS, SFTP): shares that are already mounted, however they were mounted, plus the ones you add with **Connect to server…**
  - A login form for servers that ask for one, with an anonymous option where the server allows it
  - The SSH host-key question is shown in full, fingerprint included, so you make the trust decision yourself
- **Live updates**: the list changes as devices are plugged in, unplugged, mounted or unmounted
- **Clear errors**: failures such as "device busy" or "permission denied" appear in the popup with the system's own message
- **Native backends**: disks go through [UDisks2](https://github.com/storaged-project/udisks) over D-Bus, and phones and shares go through [GVfs](https://wiki.gnome.org/Projects/gvfs). Those are the same services COSMIC Files and GNOME Files use.

## Phones

A phone isn't a disk. It uses MTP, so two things have to be true on the phone itself, and the applet can't check or fix either of them:

1. **The USB mode is set to "File transfer".** Android switches back to "Charging only" every time you plug in, and in that mode it offers no files at all. After you connect, pull down the notification shade and change the USB mode.
2. **The phone is unlocked** when you mount it.

If mounting fails, the popup reminds you of both. "Photo transfer" (PTP) mode should also work, but only shows photos, and it hasn't been tested. iPhones aren't supported.

## Network shares

Click **Connect to server…** at the bottom of the popup and enter an address:

<img src="screenshots/volumes-connect-to-server.png" alt="Connect to server form with the Samba, NFS and SFTP address formats" width="406">

| Protocol | Example |
|---|---|
| Windows / Samba | `smb://nas/media` |
| NFS | `nfs://nas/export` |
| SSH (SFTP) | `sftp://me@nas/home/me/docs` |

Tap one of the formats under the field to start an address with that scheme. Once a share mounts, its address is saved so it stays in the list after you unmount it. While a saved share is unmounted, the button at the end of its row removes it from the list.

- **Passwords are never stored.** At most, GVfs remembers them until you log out. Addresses that contain a password (`smb://user:secret@host/…`) are refused, so a password can't end up in the saved list.
- **NFS** exports normally need no login.
- **SFTP** uses your `ssh` client, so keys in `ssh-agent` work without a prompt, and key passphrases go through the same password form. GVfs mounts the whole host, but the applet still opens the folder you entered. `sftp://alice@nas` and `sftp://bob@nas` are separate entries.
- Shares mounted elsewhere (from the file manager, with `mount`, or from `/etc/fstab`) show up while they are mounted and can be unmounted here. `fstab` entries with the `user` or `users` option are listed even while unmounted.

WebDAV, FTP and browsing the network for servers aren't supported.

## Localization

English is complete. Czech, Polish and Swedish translate only the empty-list message and fall back to English for everything else, so translation updates are welcome.

To add or finish a language, copy `cosmic-applet-volumes/i18n/en/cosmic_applet_volumes.ftl` into a locale directory under `cosmic-applet-volumes/i18n/`. Translate the text to the right of each `=` and leave the keys unchanged.

Error messages from UDisks2, GVfs and the servers themselves keep their own wording and language.

## Requirements

Volumes talks to system services rather than doing the work itself:

- **UDisks2** for drives. Almost every desktop distribution has it.
- **A polkit authentication agent** for actions that need permission. COSMIC provides one.
- **GVfs with its backends** for phones and network shares, plus the `ssh` client for SFTP. Without GVfs the applet still handles drives, and phones and shares just don't appear.

```sh
# Debian/Ubuntu/Pop!_OS
sudo apt install udisks2 gvfs-backends gvfs-fuse openssh-client

# Fedora
sudo dnf install udisks2 gvfs-mtp gvfs-smb gvfs-nfs gvfs-fuse openssh-clients

# Arch
sudo pacman -S udisks2 gvfs-mtp gvfs-smb gvfs-nfs openssh
```

On NixOS, the module below turns on everything it needs.

## Installation

### NixOS (flake)

Add the flake and enable the module. It installs the applet and enables UDisks2 and GVfs:

```nix
{
  inputs.volumes.url = "github:KemonoElite/cosmic-applet-volumes";

  # in your NixOS configuration:
  imports = [ inputs.volumes.nixosModules.default ];
  programs.cosmic-applet-volumes.enable = true;
}
```

If you prefer, apply `overlays.default` and add `pkgs.cosmic-applet-volumes` to your packages, or use `packages.<system>.default` directly. No `flake.lock` is included, so the first `nix build` or `nix flake lock` creates one.

### From source

Requires Rust (edition 2024; see `rust-toolchain.toml`), [just](https://github.com/casey/just), and the `pkg-config`, `libxkbcommon-dev`, `libwayland-dev` and `libglib2.0-dev` system dependencies.

- Install: `just build-release && sudo just install`
- Uninstall: `sudo just uninstall`

To install somewhere other than `/usr`, use `sudo just prefix=/usr/local install`.

## Usage

1. Open **COSMIC Settings → Desktop → Panel → Configure panel applets**.
2. Find **Volumes** and add it to your panel.
3. Click the panel icon to open the list:
   - Click a drive, phone or share to open it. It's mounted first if it isn't already.
   - Click the eject button to unmount it. Removable drives are also powered off.
   - Click **Connect to server…** to add a network share.

## Configuration

There are no settings. The only file the applet writes is the list of saved shares, which holds one address per line and never a password:

```
~/.config/cosmic-applet-volumes/shares
```

You can edit it by hand. Lines that aren't valid addresses are dropped.

## Troubleshooting

### My phone doesn't appear

Check that the phone is unlocked and that its USB mode is set to **File transfer**, as described in [Phones](#phones). Then check that GVfs's MTP backend is installed: `gvfs-backends` on Debian/Ubuntu, `gvfs-mtp` on Fedora and Arch.

### Phones and shares never appear at all

GVfs isn't installed or isn't running. Install the packages listed under [Requirements](#requirements), then log out and back in.

### "Drive service unavailable"

The applet can't reach UDisks2. Run `systemctl status udisks2` to check whether the service is running. The applet reconnects on its own once the service comes back.

### A Samba share fails with "Invalid argument"

GVfs's SMB backend reports several different problems this way, including a wrong host name, a wrong password and a share that doesn't exist. Check all three.

### Mounting or ejecting asks for a password, or is refused

Polkit decides what you are allowed to do, and the applet shows its answer unchanged. Make sure a polkit agent is running. On some systems, internal disks need administrator rights.

## Development

```sh
just run             # run outside the panel (needs a Wayland session)
just test            # unit tests + end-to-end test
just check           # clippy, pedantic

nix develop          # dev shell: cargo, clippy, rustfmt, rust-analyzer, just, dbus-daemon
nix flake check      # the same tests, under Nix
```

The end-to-end test (`tests/e2e.rs`) starts a private `dbus-daemon` with a fake UDisks2 service and drives the real mount, unmount and power-off calls against it. It needs no root and no real disks, and it is skipped if `dbus-daemon` isn't installed.

**What's been tested:** Samba, NFS and SFTP were tested by hand against real servers through real GVfs.

**What hasn't been tested:** real phones, kernel `cifs`/`nfs` mounts, and `fstab` network entries. For those, only the detection logic has unit tests.

### Building it inside cosmic-applets

The crate is written so it can be a member of the [cosmic-applets](https://github.com/pop-os/cosmic-applets) workspace, and it adds no new crates to that project's `Cargo.lock`:

1. Root `Cargo.toml`: add `"cosmic-applet-volumes"` to `members`.
2. `cosmic-applets/Cargo.toml`: add `cosmic-applet-volumes = { path = "../cosmic-applet-volumes" }`.
3. `cosmic-applets/src/main.rs`: add `"cosmic-applet-volumes" => cosmic_applet_volumes::run(),`.

## Packaging

Use `rootdir` to stage the install and `prefix` to set the runtime path:

```sh
just build-release
just rootdir="$pkgdir" prefix=/usr install
```

A Flatpak build would need `--system-talk-name=org.freedesktop.UDisks2` and access to the GVfs session services. No manifest is included.

## License

[GPL-3.0-only](LICENSE)

## Acknowledgments

- [cosmic-ext-applet-drives](https://github.com/cosmic-utils/cosmic-ext-applet-drives), the applet this started as a rewrite of
- [cosmic-applets](https://github.com/pop-os/cosmic-applets), whose structure and several files this follows
- [System76](https://system76.com/) / [libcosmic](https://github.com/pop-os/libcosmic), the COSMIC desktop and UI toolkit
- [UDisks2](https://github.com/storaged-project/udisks) and [GVfs](https://wiki.gnome.org/Projects/gvfs), which do the actual mounting
