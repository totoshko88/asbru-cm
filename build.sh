#!/bin/bash

PRODUCT=${PRODUCT:-asbru-cm}

# Check build environment for GTK4 support
echo "Checking build environment for modern dependencies..."

# Check for GTK4 development packages
if pkg-config --exists gtk4; then
    echo "✓ GTK4 development packages found"
    export GTK4_AVAILABLE=1
else
    echo "⚠ GTK4 development packages not found, using GTK3 compatibility"
    export GTK4_AVAILABLE=0
fi

# Check for Wayland development support
if pkg-config --exists wayland-client; then
    echo "✓ Wayland development support found"
    export WAYLAND_AVAILABLE=1
else
    echo "⚠ Wayland development support not found"
    export WAYLAND_AVAILABLE=0
fi

# Check for Adwaita library
if pkg-config --exists libadwaita-1; then
    echo "✓ Adwaita library found"
    export ADWAITA_AVAILABLE=1
else
    echo "⚠ Adwaita library not found"
    export ADWAITA_AVAILABLE=0
fi

if [ -z "$TRAVIS_TAG" ]; then
  eval "$(egrep -o 'APPVERSION.*=.*' lib/PACUtils.pm | tr -d '[:space:]')"
  export VERSION=$APPVERSION~$(date +"%s");
  echo "No Travis Tag set. We are using a timestamp in seconds: ${VERSION}"
else
  export VERSION=$TRAVIS_TAG
  echo "Our version will be the tag ${VERSION}"
fi

cp -r dist/${PACKAGE}/* .

if [ "${SCRIPT}" == "make_debian.sh" ]; then
  mkdir build
  ./make_debian.sh
  cp *.{deb,tar.xz,dsc,build,changes} build/
else
  git clone https://github.com/packpack/packpack.git packpack
  ./packpack/packpack
fi

if [ "${PACKAGE}" == "deb" ] && [ "${REPACK_DEB}" == "yes" ] ; then
  DEBFILE=${PRODUCT}_${VERSION}-1_all.deb
  DEBFILE_OLD=$(basename ${DEBFILE} .deb).deb.old
  echo "Repacking debian file [${DEBFILE}] to have XY format."
  pushd build
  mv ${DEBFILE} ${DEBFILE_OLD}
  dpkg-deb -x ${DEBFILE_OLD} tmp
  dpkg-deb -e ${DEBFILE_OLD} tmp/DEBIAN
  dpkg-deb -b tmp ${DEBFILE}
  rm -rf tmp
  popd
fi

# Validate package dependencies if lintian is available
if command -v lintian >/dev/null 2>&1 && [ -f "build/${PRODUCT}_${VERSION}-1_all.deb" ]; then
    echo "Running lintian checks on generated package..."
    lintian build/${PRODUCT}_${VERSION}-1_all.deb || echo "⚠ Lintian found issues (non-fatal)"
fi

echo "Build completed. Package features:"
echo "  GTK4 Support: ${GTK4_AVAILABLE:-0}"
echo "  Wayland Support: ${WAYLAND_AVAILABLE:-0}"
echo "  Adwaita Support: ${ADWAITA_AVAILABLE:-0}"

