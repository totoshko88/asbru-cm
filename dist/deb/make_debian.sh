#!/bin/bash

# Check for GTK4 development packages
echo "Checking for GTK4 development environment..."
if ! pkg-config --exists gtk4; then
    echo "Warning: GTK4 development packages not found. Falling back to GTK3 compatibility mode."
    echo "For full GTK4 support, install: libgtk-4-dev libadwaita-1-dev"
fi

# Check for VTE GTK4 support
if ! pkg-config --exists vte-2.91-gtk4; then
    echo "Warning: VTE GTK4 bindings not found. Using GTK3 VTE compatibility."
fi

if [ -z "$TRAVIS_TAG" ]; then
	eval "$(egrep -o 'APPVERSION.*=.*' lib/PACUtils.pm | tr -d '[:space:]')"
	RELEASE_DEBIAN=$APPVERSION~$(git log -1 | grep -i "^commit" | awk '{print $2}');
	echo "No Travis Tag set. We are guessing a version number from the git log: ${RELEASE_DEBIAN}"
else
	RELEASE_DEBIAN=${TRAVIS_TAG,,};
	echo "Setting version to ${RELEASE_DEBIAN}"
fi

PACKAGE_DIR=build
DEBIAN_VERSION=${RELEASE_DEBIAN/-/"~"}

echo "Building package release ${DEBIAN_VERSION}, be patient ..."

# Ensure we're in the project root directory
if [ ! -f "asbru-cm" ]; then
    if [ -f "../../asbru-cm" ]; then
        echo "Changing to project root directory..."
        cd ../..
    else
        echo "Error: Cannot find asbru-cm executable. Please run from project root or dist/deb directory."
        exit 1
    fi
fi

pwd

if ! [[ -z "$TRAVIS_TAG" ]]; then
	git checkout tags/${TRAVIS_TAG}
fi

mkdir $PACKAGE_DIR

tar -cpf "${PACKAGE_DIR}/asbru-cm_$DEBIAN_VERSION.orig.tar" --exclude ".git" --exclude "debian" --exclude "build" .
cp -r debian build/
cd ${PACKAGE_DIR}
tar -xf asbru-cm_$DEBIAN_VERSION.orig.tar
xz -9 asbru-cm_$DEBIAN_VERSION.orig.tar
mv asbru-cm_$DEBIAN_VERSION.orig.tar.xz ../

#ls -lha

if ! [[ -z "$TRAVIS_TAG" ]]; then
	dch -v "$DEBIAN_VERSION" -D "unstable" -b -m "New automatic GitHub build from snapshot"
else
	dch -v "$DEBIAN_VERSION" -D "stable" -b -m "New automatic GitHub build from tag"
fi


debuild -us -uc

#ls -lha
cd ..
#ls -lha

echo "All done. Hopefully"                   
