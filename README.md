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
- **Cosmic Desktop Integration**: Native support for PopOS 24.04's Cosmic desktop environment
- **Updated Dependencies**: All Perl modules and system dependencies updated to latest stable versions
- **Enhanced Security**: Modern cryptographic standards and secure password storage
- **Improved Performance**: Better memory usage and faster startup times
- **Modern Icon Set**: Migration to Adwaita symbolic icons with automatic Hi-DPI scaling (GDK_SCALE) and optional `ASBRU_LARGE_ICONS=1` override

### AI Assistance Disclosure

**Important**: This modernization project was developed with significant assistance from artificial intelligence tools. All AI-assisted modifications have been:
- Thoroughly reviewed and tested by human developers
- Documented with clear rationale for each change
- Validated against the original functionality requirements
- Tested on target platforms (PopOS 24.04, Ubuntu 24.04, Fedora 40+)

The AI assistance was used primarily for:
- Dependency analysis and updates
- GTK3 to GTK4 API migration
- Wayland compatibility implementation
- Code modernization and security enhancements
- Documentation and testing framework creation

### Copyright and Attribution

Original Ásbrú Connection Manager:
 Copyright © 2025 Anton Isaiev <totoshko88@gmail.com>
 Copyright © 2017-2022 Ásbrú Connection Manager team
 Copyright © 2010-2016 David Torrejón Vaquerizas
Modernization Fork:
- Copyright (C) 2025 Anton Isaiev <totoshko88@gmail.com>

This fork maintains full compatibility with the original project while adding modern platform support.

### Installation

We recommend installing Ásbrú Connection Manager using our latest pre-built packages hosted on [cloudsmith.io](https://cloudsmith.io/).

To do so, execute the following commands:

- Debian / Ubuntu

  ````
  curl -1sLf 'https://dl.cloudsmith.io/public/asbru-cm/release/cfg/setup/bash.deb.sh' | sudo -E bash
  sudo apt-get install asbru-cm
  ````

- Fedora

  ````
  curl -1sLf 'https://dl.cloudsmith.io/public/asbru-cm/release/cfg/setup/bash.rpm.sh' | sudo -E bash
  sudo dnf install asbru-cm
  ````

- Pacman-based (e.g. Arch Linux, Manjaro)

  ````
  git clone https://aur.archlinux.org/asbru-cm-git.git && cd asbru-cm-git
  makepkg -si
  ````
  
- MX Linux

  Ásbrú Connection Manager can be installed through the MX Package Installer under the Test Repo tab
  or by enabling the Test Repo and running
  ````
  sudo apt-get install asbru-cm
  ````
  
- Windows

  - Windows 10 Build 19044 and later, or Windows 11
 
    See https://learn.microsoft.com/en-us/windows/wsl/tutorials/gui-apps

    tl;dr:
    
    1. Install or update WSL.
    2. Follow the installation instructions for Ubuntu above.
    3. Ásbrú Connection Manager will then be available in the start menu.

  - Windows 10 before Build 19044, or running older WSL

    It is possible to run Asbru-CM on Windows 10 by enabling WSL and using the application [Asbru-CM Runner](https://github.com/SegiH/Asbru-CM-Runner). If you do not have [WSLG](https://github.com/microsoft/wslg) support, you will need to install [Xming](http://www.straightrunning.com/XmingNotes/). The GitHub page for [Asbru-CM Runner](https://github.com/SegiH/Asbru-CM-Runner) has detailed instructions on how to do this and allows you to run Asbru-CM on Windows 10 without a console window open in the background.
  
Once installed on your system, type ````asbru-cm```` in your terminal.

#### Optional: Build Your Own AppImage

If you want to produce the standalone AppImage locally, install either Docker or Podman, then run:

````bash
git clone https://github.com/totoshko88/asbru-cm.git
cd asbru-cm
# Build (auto-detects docker then podman)
bash dist/appimage/make_appimage.sh
ls dist/release/Asbru-CM*.AppImage
````

Container engine install examples (choose one):

````bash
# Docker (Ubuntu / Debian)
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $(. /etc/os-release; echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# OR Podman (Ubuntu / Debian 24.04+)
sudo apt-get update
sudo apt-get install -y podman
````

If both are present, the build script prefers Docker. To force Podman:

````bash
command -v docker && sudo systemctl stop docker || true
bash dist/appimage/make_appimage.sh
````

### Migration from Version 6.x

If you're upgrading from Ásbrú Connection Manager 6.x, please note:

1. **Configuration Compatibility**: Your existing configuration files will be automatically migrated to the new format
2. **Password Migration**: Encrypted passwords will be migrated to use modern AES-256-GCM encryption
3. **Theme Changes**: Some visual elements may appear different due to GTK4 theming changes

### Troubleshooting Common Issues

#### Installation Issues

**Problem**: Package dependency conflicts on modern distributions
```
Solution: Ensure you're using the correct package repository for your distribution version.
For PopOS 24.04: Use the updated DEB package specifically built for GTK4.
```

**Problem**: Application fails to start with GTK-related errors
```
Solution: Verify GTK4 libraries are installed:
sudo apt install libgtk-4-1 libadwaita-1-0 gir1.2-gtk-4.0
```

#### Display Issues

**Problem**: System tray icon not appearing in Cosmic desktop
```
Solution: This is expected behavior. Use the application menu or create a desktop shortcut.
Cosmic desktop uses a different panel system that doesn't support traditional system tray icons.
```

**Problem**: Blurry or incorrectly scaled interface on high-DPI displays
```
Solution: GTK4 should handle scaling automatically. If issues persist, try:
export GDK_SCALE=2  # Adjust value as needed
asbru-cm
```

#### Connection Issues

**Problem**: SSH connections fail after upgrade
```
Solution: Check if your SSH keys are still accessible and verify connection settings.
The modernized version uses updated SSH libraries that may have stricter security requirements.
```

**Problem**: VNC/RDP connections not working
```
Solution: Ensure the required viewer applications are installed:
sudo apt install remmina tigervnc-viewer  # or your preferred viewers
```

#### Performance Issues

**Problem**: Slower startup compared to version 6.x
```
Solution: This is normal for the first startup as GTK4 initializes new components.
Subsequent startups should be faster due to improved caching.
```

For additional support, please check the [Issues](https://github.com/your-username/asbru-cm-modernized/issues) section or refer to the migration guide in the documentation.

### Testing new features

Our master and the snapshots are being kept as stable as possible. New features for new major releases are being developed inside the "loki" branch.

Beware that [Loki](https://en.wikipedia.org/wiki/Loki) can sometimes behave in an unexpected manner to you.  This is somehow the same concept as the "[Debian sid](https://www.debian.org/releases/sid/)" release.

You are welcome to contribute and test by checking out "loki" or by installing our builds.

If you do not wish to run third party scripts on your systems, you can always access manual install instructions at https://cloudsmith.io/~asbru-cm/repos/loki/setup/

- Debian / Ubuntu

  ````
   curl -1sLf 'https://dl.cloudsmith.io/public/asbru-cm/loki/cfg/setup/bash.deb.sh' | sudo -E bash
  ````

- Fedora

  ````
   curl -1sLf 'https://dl.cloudsmith.io/public/asbru-cm/loki/cfg/setup/bash.rpm.sh' | sudo -E bash
  ````


### Installation of legacy 5.x

- Debian / Ubuntu

  ````
  $ curl -s https://packagecloud.io/install/repositories/asbru-cm/v5/script.deb.sh | sudo bash
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
