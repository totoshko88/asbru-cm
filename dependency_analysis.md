# Ásbrú Connection Manager - Dependency Analysis

## Current Dependencies Analysis

### Core Perl Modules (Standard Library)
- `strict` - Core Perl pragma
- `warnings` - Core Perl pragma  
- `utf8` - Core Perl pragma
- `FindBin` - Core module for finding script directory
- `File::Copy` - Core file operations
- `File::Basename` - Core file path operations
- `File::stat` - Core file statistics
- `File::Temp` - Core temporary file handling
- `Encode` - Core text encoding
- `Config` - Core Perl configuration
- `POSIX` - Core POSIX functions
- `Socket` - Core socket operations
- `Sys::Hostname` - Core hostname functions
- `Time::HiRes` - Core high-resolution time
- `IPC::Open2` - Core inter-process communication
- `IPC::Open3` - Core inter-process communication
- `Getopt::Long` - Core command-line parsing
- `List::Util` - Core list utilities
- `DynaLoader` - Core dynamic loading

### External Perl Modules (CPAN/System Packages)
#### GUI Framework
- `Gtk3` - **NEEDS UPDATE TO GTK4** - Current GTK3 bindings
- `Gtk3::SimpleList` - **NEEDS UPDATE** - Simple list widget for GTK3
- `Gtk3::Gdk` - **NEEDS UPDATE** - GTK3 GDK bindings

#### Terminal Emulation
- `Vte` (via Glib::Object::Introspection) - **NEEDS UPDATE** - Currently using VTE 2.91, needs 3.0+ for GTK4

#### Window Management
- `Wnck` (via Glib::Object::Introspection) - **NEEDS REPLACEMENT** - X11-specific, not Wayland compatible

#### Data Storage and Serialization
- `YAML` - Configuration file handling - **UPDATE RECOMMENDED**
- `Storable` - Binary data serialization - **UPDATE RECOMMENDED**

#### Cryptography and Security
- `Crypt::CBC` - **NEEDS UPDATE** - Cipher Block Chaining mode
- `Crypt::Rijndael` - **NEEDS REPLACEMENT** - Old AES implementation, replace with modern alternative
- `Digest::SHA` - SHA hashing - **UPDATE RECOMMENDED**

#### Networking
- `Socket6` - **UPDATE RECOMMENDED** - IPv6 socket support
- `Net::ARP` - ARP table access - **UPDATE RECOMMENDED**
- `Net::Ping` - Network ping functionality - **UPDATE RECOMMENDED**
- `IO::Socket::INET` - Internet socket operations - **UPDATE RECOMMENDED**

#### System Integration
- `OSSP::uuid` - UUID generation - **UPDATE RECOMMENDED**
- `Glib::IO` - GSettings integration - **COMPATIBLE**
- `Glib::Object::Introspection` - GObject bindings - **COMPATIBLE**

### System Dependencies (from debian/control)
#### Current GTK3 Dependencies (NEED REPLACEMENT)
- `libgtk3-perl` → **REPLACE WITH** `libgtk4-perl`
- `libvte-2.91-0` → **UPDATE TO** GTK4-compatible VTE
- `gir1.2-vte-2.91` → **UPDATE TO** `gir1.2-vte-3.0` or newer
- `gir1.2-wnck-3.0` → **REMOVE/REPLACE** (X11-specific, not Wayland compatible)

#### Graphics and Display
- `libcairo-perl` - **COMPATIBLE** - Cairo graphics
- `libglib-perl` - **COMPATIBLE** - GLib bindings  
- `libpango-perl` - **COMPATIBLE** - Pango text rendering
- `dbus-x11` → **UPDATE TO** `dbus` (remove X11 dependency)

#### Cryptography (NEED UPDATES)
- `libcrypt-cbc-perl` - **UPDATE RECOMMENDED**
- `libcrypt-blowfish-perl` → **REPLACE WITH** modern AES implementation
- `libcrypt-rijndael-perl` → **REPLACE WITH** `Crypt::Cipher::AES` or similar

#### Networking and Protocols
- `libsocket6-perl` - **UPDATE RECOMMENDED**
- `libnet-arp-perl` - **UPDATE RECOMMENDED**
- `openssh-client` - **COMPATIBLE**
- `ncat | nmap` - **COMPATIBLE**

#### Data Handling
- `libyaml-perl` - **UPDATE RECOMMENDED**
- `libxml-parser-perl` - **UPDATE RECOMMENDED**
- `libexpect-perl` - **UPDATE RECOMMENDED**

#### System Integration
- `libossp-uuid-perl` - **UPDATE RECOMMENDED**
- `libcanberra-gtk-module` - **COMPATIBLE**
- `libgtk3-simplelist-perl` → **REPLACE WITH** GTK4 equivalent

### New Dependencies Needed for GTK4/Wayland

#### GTK4 Framework
- `libgtk4-perl` - GTK4 Perl bindings (if available)
- `libadwaita-1-dev` - Modern GTK4 theming
- `libgtk-4-dev` - GTK4 development libraries

#### Wayland Support
- `xdg-desktop-portal` - Portal integration for Wayland
- `libwayland-dev` - Wayland development libraries

#### Modern Security
- `Crypt::Cipher::AES` - Modern AES implementation
- `Crypt::PBKDF2` - Secure key derivation
- `Crypt::AuthEnc::GCM` - Authenticated encryption

### Deprecated/Problematic Dependencies

#### High Priority (Breaking on Modern Systems)
1. **GTK3 → GTK4 Migration**
   - `Gtk3` → `Gtk4`
   - `libgtk3-perl` → `libgtk4-perl`
   - All GTK3-specific widgets and APIs

2. **VTE Terminal Emulation**
   - VTE 2.91 → VTE 3.0+ for GTK4 compatibility

3. **X11-Specific Components**
   - `Wnck` - Window management (X11-only)
   - `dbus-x11` - X11-specific D-Bus

#### Medium Priority (Security/Compatibility)
1. **Cryptography Updates**
   - `Crypt::Blowfish` → Modern AES
   - `Crypt::Rijndael` → `Crypt::Cipher::AES`

2. **Network Module Updates**
   - `Socket6` - Update for modern IPv6 support
   - Various Net::* modules

#### Low Priority (Maintenance)
1. **Data Handling**
   - `YAML` - Update to latest version
   - `Storable` - Update to latest version

## Compatibility Matrix

| Component | Current Version | Target Version | Compatibility | Priority |
|-----------|----------------|----------------|---------------|----------|
| GTK Framework | GTK3 | GTK4 | Breaking | Critical |
| VTE Terminal | 2.91 | 3.0+ | Breaking | Critical |
| Window Management | Wnck (X11) | Portal/Native | Breaking | High |
| Cryptography | Blowfish/Old AES | Modern AES-GCM | Breaking | High |
| Perl Modules | Mixed versions | Latest stable | Compatible | Medium |
| System Integration | X11-focused | Wayland-ready | Partial | Medium |

## Migration Strategy

### Phase 1: Critical Dependencies
1. Update GTK3 → GTK4 bindings
2. Update VTE 2.91 → 3.0+
3. Replace X11-specific window management

### Phase 2: Security Updates  
1. Replace Blowfish with AES-256-GCM
2. Update all cryptographic modules
3. Implement secure key derivation

### Phase 3: System Integration
1. Add Wayland portal support
2. Update networking modules
3. Enhance desktop environment detection

### Phase 4: Maintenance Updates
1. Update all remaining Perl modules
2. Optimize for modern systems
3. Add new features enabled by updates

## Testing Requirements

### Compatibility Testing
- Test on PopOS 24.04 with Cosmic desktop
- Test on Ubuntu 24.04 with GNOME/Wayland
- Test fallback to X11 where needed

### Functionality Testing
- All connection protocols (SSH, RDP, VNC, etc.)
- GUI rendering and interaction
- System integration features
- Security and encryption features

## Risk Assessment

### High Risk
- GTK4 migration may require significant code changes
- VTE update may affect terminal functionality
- Wayland compatibility may require architecture changes

### Medium Risk
- Cryptography updates may affect existing encrypted data
- Network module updates may affect connection handling

### Low Risk
- Standard Perl module updates
- System package updates