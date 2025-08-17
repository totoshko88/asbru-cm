# Ásbrú Connection Manager - Modernized Fork

[![Travis][travis-badge]][travis-url]
[![License][license-badge]][license-url]
[![RPM Packages][rpm-badge]][rpm-url]
[![Debian Packages][deb-badge]][deb-url]
[![Liberapay][liberapay-badge]][liberapay-url]
[![Donate Bitcoins][bitcoin-badge]][bitcoin-url]

[<img src="https://www.asbru-cm.net/assets/img/asbru-logo-200.png" align="right" width="200px" height="200px" />](https://asbru-cm.net)

## A free and open-source connection manager - Modernized for GTK4 and Wayland

> **Note**: This is a modernized fork of the original [asbru-cm/asbru-cm](https://github.com/asbru-cm/asbru-cm) project, updated to work with modern Linux distributions including PopOS 24.04, GTK4, and Wayland display servers.

Modernization fork repository: https://github.com/totoshko88/asbru-cm

**Ásbrú Connection Manager** is a user interface that helps organizing remote terminal sessions and automating repetitive tasks.

### Features

- Simple GUI to manage/launch connections to remote machines
- Scripting possibilities, 'ala' SecureCRT
- Configurable pre or post connection local commands execution
- Configurable list of macros (commands) to execute locally when connected or to send to connected client
- Configurable list of conditional executions on connected machine via 'Expect':
  - forget about SSH certificates
  - chain multiple SSH connections
  - automate tunnels creation
  - with line-send delay capabilities
- [KeePassXC](https://keepassxc.org/) integration
- Ability to connect to machines through a Proxy server
- Cluster connections
- Tabbed/Windowed terminals
- Wake On LAN capabilities
- Local and global variables, eg.: write down a password once, use it ANY where, centralizing its modification for faster changes! use them for:
  - password vault
  - reusing connection strings
- Seamless Gnome/Gtk integration
- Tray icon for 'right button' quick launching of managed connections. Screenshots and statistics.
- DEB, RPM and .TAR.GZ packages available

## Modernization Project (Version 7.0.0)

This version represents a comprehensive modernization of Ásbrú Connection Manager to ensure compatibility with modern Linux distributions and desktop environments.

### What's New in 7.0.0

- **GTK4 Migration**: Complete migration from GTK3 to GTK4 for better performance and modern desktop integration
- **Wayland Support**: Full compatibility with Wayland display servers
# Ásbrú Connection Manager (Focused Fork)

Minimal fork for direct local use & packaging. For full history, documentation, issues and upstream development see the original project: https://github.com/asbru-cm/asbru-cm

## Scope
This fork keeps the core functionality and adds simplified build + packaging scripts (DEB, RPM, optional AppImage) with modern theme/icon handling tweaks. Documentation here is intentionally concise.

## Quick Start (Run From Source)
```bash
git clone https://github.com/totoshko88/asbru-cm.git
cd asbru-cm
perl asbru-cm
```
If Gtk/Perl modules are missing, install your distro packages (example Ubuntu / Debian):
```bash
sudo apt update
sudo apt install -y perl libgtk3-perl libvte-2.91-0 libvte-2.91-dev libyaml-libyaml-perl libjson-xs-perl
```

## Build a Debian Package
```bash
./make_debian.sh          # Produces asbru-cm_<version>_all.deb
sudo dpkg -i asbru-cm_*_all.deb
sudo apt -f install       # Resolve deps if needed
```

## Build an RPM (on Debian/Ubuntu host or Fedora)
```bash
bash dist/rpm/build_rpm.sh
ls dist/rpm/build/RPMS/noarch/*.rpm
```

## Optional: AppImage Build
Requires Docker or Podman (auto-detected).
```bash
bash dist/appimage/make_appimage.sh
ls dist/release/Asbru-CM*.AppImage
```
Install Podman quickly (Ubuntu/Debian): `sudo apt install -y podman`

## Download Prebuilt Packages
Check the Releases page of THIS fork for uploaded `.deb` (and possibly `.rpm`, `.AppImage`) artifacts for the current tag. After download:
```bash
sudo dpkg -i asbru-cm_*.deb || sudo rpm -i asbru-cm-*.rpm
```
Verify integrity if `SHA256SUMS` file is provided:
```bash
sha256sum -c SHA256SUMS
```

## Basic Usage
Launch from terminal:
```bash
asbru-cm
```
or (from source tree without install):
```bash
perl asbru-cm
```

## Environment Variables (Optional)
```bash
ASBRU_DEBUG=1                # Verbose debug
ASBRU_DEBUG_STACK=1          # Include stack traces in debug output
ASBRU_FORCE_ICON_RESCAN=1    # Force internal icon theme rescan
ASBRU_LARGE_ICONS=1          # Prefer larger symbolic icons
```

## License
GPL-3.0 (see `LICENSE`).

Upstream authors retain original credits. This fork only adjusts packaging & minor runtime helpers.

## Support
For feature requests & extensive help use the upstream issue tracker. This fork focuses on lightweight packaging; issues here should be specific to added scripts or minimal changes.

---
Minimal README version generated to align with request for a concise, fork-centric document.
  $ sudo apt-get install asbru-cm
  ````

- Fedora

  ````
  $ curl -s https://packagecloud.io/install/repositories/asbru-cm/v5/script.rpm.sh | sudo bash
  $ sudo dnf install asbru-cm
  ````


### Frequenty Asked Questions

- Why did you call that project "Ásbrú" ?

  In Norse mythology, [Ásbrú](https://en.wikipedia.org/wiki/Bifr%C3%B6st) refers to a burning rainbow bridge that connects Midgard (Earth) and Asgard, the realm of the gods.

- Is this a fork of PAC (Perl Auto Connector) Manager ?

  Yes, this project has a dual heritage:

  1. **Original Fork**: Ásbrú Connection Manager was originally forked from PAC Manager when [David Torrejon Vaquerizas](https://github.com/perseo22) could not continue development and was not open for external contributions ([see this](https://github.com/perseo22/pacmanager/issues/57)).

  2. **Modernization Fork**: This version (7.0.0+) is a fork of the original [asbru-cm/asbru-cm](https://github.com/asbru-cm/asbru-cm) project, created to modernize the codebase for compatibility with current Linux distributions, GTK4, and Wayland.

- Why was this modernization fork created?

  The original Ásbrú Connection Manager project has not been actively maintained since 2022 and fails to run on modern Linux distributions like PopOS 24.04 due to outdated dependencies and deprecated GTK3 components. This fork addresses these compatibility issues while maintaining full functionality.

More questions can be found on the [dedicated project wiki page](https://github.com/asbru-cm/asbru-cm/wiki/Frequently-Asked-Questions).

### Contributing

If you want to contribute to Ásbrú Connection Manager, first check out the [issues](https://github.com/asbru-cm/asbru-cm/issues) and see if your request is not listed yet.  Issues and pull requests will be triaged and responded to as quickly as possible.

Before contributing, please review our [contributing doc](https://github.com/asbru-cm/asbru-cm/blob/master/CONTRIBUTING.md) for info on how to make feature requests and bear in mind that we adhere to the [Contributor Covenant code of conduct](https://github.com/asbru-cm/asbru-cm/blob/master/CODE_OF_CONDUCT.md).

### Financial support

If you like Ásbrú Connection Manager, you may also consider supporting the project financially by donating on <a title="Donate Liberapay" href="https://liberapay.com/asbru-cm/donate">Liberapay</a> or by donating to one of <a href="https://docs.asbru-cm.net/Contributing/Financial_Contribution/">our cryptocurrency addresses</a>.

### License

Ásbrú Connection Manager is licensed under the GNU General Public License version 3 <http://www.gnu.org/licenses/gpl-3.0.html>.  A full copy of the license can be found in the [LICENSE](https://github.com/asbru-cm/asbru-cm/blob/master/LICENSE) file.

### Sponsors

<a title="Cloudflare" href="https://cloudflare.com/"><img height="105" width="230" alt="Cloudflare" src="https://www.cloudflare.com/img/logo-web-badges/cf-logo-on-white-bg.svg" /></a>

### Packages

The repositories for our RPM and DEB builds are thankfully sponsored by [packagecloud](https://packagecloud.io/) and [Cloudsmith](https://cloudsmith.io). A great thanks to them.

<a title="Private Maven, RPM, DEB, PyPi and RubyGem Repository" href="https://packagecloud.io/"><img height="46" width="158" alt="Private Maven, RPM, DEB, PyPi and RubyGem Repository" src="https://packagecloud.io/images/packagecloud-badge.png" /></a>

<a href="https://cloudsmith.com/"><img height="46" widht="158" alt="Fast, secure development and distribution. Universal, web-scale package management" src="https://www.asbru-cm.net/assets/img/misc/cloudsmith-logo-color.png" /></a>

[travis-badge]: https://api.travis-ci.com/asbru-cm/asbru-cm.svg?branch=master
[travis-url]: https://app.travis-ci.com/github/asbru-cm/asbru-cm
[license-badge]: https://img.shields.io/badge/License-GPL--3-blue.svg?style=flat
[license-url]: LICENSE
[deb-badge]: https://img.shields.io/badge/Packages-Debian-blue.svg?style=flat
[deb-url]: https://packagecloud.io/asbru-cm/asbru-cm?filter=debs
[rpm-badge]: https://img.shields.io/badge/Packages-RPM-blue.svg?style=flat
[rpm-url]: https://packagecloud.io/asbru-cm/asbru-cm?filter=rpms
[liberapay-badge]: http://img.shields.io/liberapay/patrons/asbru-cm.svg?logo=liberapay
[liberapay-url]: https://liberapay.com/asbru-cm/donate
[bitcoin-badge]: https://img.shields.io/badge/bitcoin-19ZsvCafwRCwQSPcvfzgyiHD3Viptb4F45-D28138.svg?style=flat-square
[bitcoin-url]: https://blockchain.info/address/19ZsvCafwRCwQSPcvfzgyiHD3Viptb4F45 
