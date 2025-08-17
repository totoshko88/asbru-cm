#!/bin/bash

# Production DEB Package Build Script for Ásbrú Connection Manager v7.0.0
# AI-ASSISTED MODERNIZATION: This script was created with AI assistance

set -e  # Exit on any error

PRODUCT="asbru-cm"
# Derive VERSION dynamically from lib/PACUtils.pm (APPVERSION may include +modernN)
VERSION=$(grep "our \$APPVERSION" lib/PACUtils.pm | sed "s/.*'\(.*\)'.*/\1/")
BUILD_DIR="build_production"

echo "=========================================="
echo "Building Production DEB Package for Ásbrú Connection Manager v${VERSION}"
echo "Target: PopOS 24.04 with GTK4 and Wayland support"
echo "=========================================="

# Clean previous builds
if [ -d "$BUILD_DIR" ]; then
    echo "Cleaning previous build directory..."
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"

# Check build environment
echo "Checking build environment..."

# Check for required build tools
REQUIRED_TOOLS="debuild dpkg-deb lintian"
for tool in $REQUIRED_TOOLS; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: Required tool '$tool' not found. Please install: sudo apt install devscripts lintian"
        exit 1
    fi
done

# Check for GTK4 development packages
echo "Checking for GTK4 development environment..."
if pkg-config --exists gtk4; then
    echo "✓ GTK4 development packages found"
    GTK4_VERSION=$(pkg-config --modversion gtk4)
    echo "  GTK4 version: $GTK4_VERSION"
    export GTK4_AVAILABLE=1
else
    echo "⚠ GTK4 development packages not found"
    echo "  Install with: sudo apt install libgtk-4-dev"
    export GTK4_AVAILABLE=0
fi

# Check for Adwaita library
if pkg-config --exists libadwaita-1; then
    echo "✓ Adwaita library found"
    ADWAITA_VERSION=$(pkg-config --modversion libadwaita-1)
    echo "  Adwaita version: $ADWAITA_VERSION"
    export ADWAITA_AVAILABLE=1
else
    echo "⚠ Adwaita library not found"
    echo "  Install with: sudo apt install libadwaita-1-dev"
    export ADWAITA_AVAILABLE=0
fi

# Check for VTE GTK4 support
if pkg-config --exists vte-2.91-gtk4; then
    echo "✓ VTE GTK4 bindings found"
    VTE_VERSION=$(pkg-config --modversion vte-2.91-gtk4)
    echo "  VTE version: $VTE_VERSION"
    export VTE_GTK4_AVAILABLE=1
elif pkg-config --exists vte-2.91; then
    echo "⚠ VTE GTK3 bindings found, GTK4 bindings preferred"
    VTE_VERSION=$(pkg-config --modversion vte-2.91)
    echo "  VTE version: $VTE_VERSION"
    export VTE_GTK4_AVAILABLE=0
else
    echo "⚠ VTE bindings not found"
    echo "  Install with: sudo apt install libvte-2.91-dev"
    export VTE_GTK4_AVAILABLE=0
fi

# Check for Wayland development support
if pkg-config --exists wayland-client; then
    echo "✓ Wayland development support found"
    WAYLAND_VERSION=$(pkg-config --modversion wayland-client)
    echo "  Wayland version: $WAYLAND_VERSION"
    export WAYLAND_AVAILABLE=1
else
    echo "⚠ Wayland development support not found"
    export WAYLAND_AVAILABLE=0
fi

# Verify we're in the project root
if [ ! -f "asbru-cm" ]; then
    echo "Error: Must be run from project root directory (asbru-cm executable not found)"
    exit 1
fi

if [ ! -f "lib/PACUtils.pm" ]; then
    echo "Error: lib/PACUtils.pm not found. Are you in the correct directory?"
    exit 1
fi

# Display version (already sourced from PACUtils.pm)
echo "✓ Using version from PACUtils.pm: $VERSION"

# Create source tarball
echo "Creating source tarball..."
DEBIAN_VERSION="${VERSION}"
tar -cpf "${BUILD_DIR}/${PRODUCT}_${DEBIAN_VERSION}.orig.tar" \
    --exclude ".git" \
    --exclude "debian" \
    --exclude "build*" \
    --exclude "*.deb" \
    --exclude "*.tar.xz" \
    --exclude "*.dsc" \
    --exclude "*.build" \
    --exclude "*.changes" \
    --exclude ".kiro" \
    .

# Copy debian packaging files
echo "Copying debian packaging files..."
cp -r debian "${BUILD_DIR}/"

# Enter build directory
cd "${BUILD_DIR}"

# Extract source
tar -xf "${PRODUCT}_${DEBIAN_VERSION}.orig.tar"
xz -9 "${PRODUCT}_${DEBIAN_VERSION}.orig.tar"

# Skip automatic dch modification; changelog already manually maintained.
echo "Using existing debian/changelog (top version should match $DEBIAN_VERSION)"
if ! head -1 debian/changelog | grep -q "($DEBIAN_VERSION)"; then
    echo "WARNING: Top changelog entry does not match $DEBIAN_VERSION";
fi

# Build package
echo "Building DEB package..."
debuild -us -uc

# Return to project root
cd ..

# Verify package was created (search both build dir and project root)
DEB_FILE=""
for cand in \
    "${BUILD_DIR}/${PRODUCT}_${DEBIAN_VERSION}_all.deb" \
    "${BUILD_DIR}/${PRODUCT}_${DEBIAN_VERSION}-1_all.deb" \
    "${PRODUCT}_${DEBIAN_VERSION}_all.deb" \
    "${PRODUCT}_${DEBIAN_VERSION}-1_all.deb"; do
    if [ -f "$cand" ]; then DEB_FILE="$cand"; break; fi
done

if [ -n "$DEB_FILE" ] && [ -f "$DEB_FILE" ]; then
    echo "✓ Package built successfully: $DEB_FILE"
    
    # Get package size
    PACKAGE_SIZE=$(du -h "$DEB_FILE" | cut -f1)
    echo "  Package size: $PACKAGE_SIZE"
    
    # Show package info
    echo "Package information:"
    dpkg-deb --info "$DEB_FILE" | head -20
    
else
    echo "Error: Package build failed - $DEB_FILE not found"
    exit 1
fi

# Run lintian checks
echo "Running lintian quality checks (non-fatal)..."
lintian "$DEB_FILE" 2>&1 | tee "${BUILD_DIR}/lintian_report.txt" || echo "Lintian reported issues (continuing)"

# Create package summary
echo "Creating package summary..."
cat > "${BUILD_DIR}/package_summary.txt" << EOF
Ásbrú Connection Manager v${VERSION} - Production Package Summary
================================================================

Build Date: $(date)
Package File: $(basename "$DEB_FILE")
Package Size: $PACKAGE_SIZE

Build Environment:
- GTK4 Support: ${GTK4_AVAILABLE}
- Adwaita Support: ${ADWAITA_AVAILABLE}
- VTE GTK4 Support: ${VTE_GTK4_AVAILABLE}
- Wayland Support: ${WAYLAND_AVAILABLE}

Target Platform: PopOS 24.04 LTS
Desktop Environment: Cosmic (with fallback support)
Display Server: Wayland (with X11 fallback)

Installation Command:
sudo dpkg -i $(basename "$DEB_FILE")
sudo apt-get install -f  # Fix any dependency issues

Verification Commands:
dpkg -l | grep asbru-cm
asbru-cm --version
EOF

echo "=========================================="
echo "Production package build completed!"
echo "Package: $DEB_FILE"
echo "Summary: ${BUILD_DIR}/package_summary.txt"
echo "Lintian Report: ${BUILD_DIR}/lintian_report.txt"
echo "=========================================="

# List all generated files
echo "Generated files:"
ls -la "${BUILD_DIR}"/*.deb "${BUILD_DIR}"/*.tar.xz "${BUILD_DIR}"/*.dsc 2>/dev/null || true