#!/bin/bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/ ;)
set -euo pipefail
IFS=$'\n\t'

# Too much output can't hurt, it's Bash.
set -x

USE_APPSTREAM="${USE_APPSTREAM-0}"

ln -s ./opt/asbru-cm/res/asbru-cm.desktop /var/appimage-dir/asbru-cm.desktop
ln -s ./opt/asbru-cm/res/asbru-logo.svg /var/appimage-dir/asbru-cm.svg
ln -s ./opt/asbru-cm/res/asbru-logo-256.png /var/appimage-dir/.DirIcon
ln -s ./opt/asbru-cm/dist/appimage/AppRun /var/appimage-dir/AppRun

chmod a+x /var/appimage-dir/AppRun

dos2unix /var/appimage-dir/opt/asbru-cm/res/asbru-cm.desktop /var/appimage-dir/opt/asbru-cm/res/asbru-logo.svg /var/appimage-dir/opt/asbru-cm/dist/appimage/AppRun

if [[ "${USE_APPSTREAM}" -eq 1 ]]; then

    dos2unix /var/appimage-dir/opt/asbru-cm/res/org.asbru.cm.appdata.xml

    mkdir -p /var/appimage-dir/usr/share/metainfo/

    cp -a /var/appimage-dir/opt/asbru-cm/res/org.asbru.cm.appdata.xml /var/appimage-dir/usr/share/metainfo/org.asbru.cm.appdata.xml
    cp -a /var/appimage-dir/opt/asbru-cm/res/org.asbru.cm.appdata.xml /usr/share/metainfo/org.asbru.cm.appdata.xml

fi

for binfile in /var/appimage-dir/usr/bin/*; do
    filequery="$(file "${binfile}")"
    if [[ "${filequery}" == *"ld-musl-x86_64.so.1"* ]]; then
        echo "patching ELF header for file ${binfile}"
        # ELF PT_INTERP must be absolute; point to loader shipped inside the AppImage
        patchelf "${binfile}" --set-interpreter "/lib/ld-musl-x86_64.so.1"
    fi
done

# Rebuild GTK input method modules cache and patch to relative paths
/usr/bin/gtk-query-immodules-3.0 > /var/appimage-dir/usr/lib/gtk-3.0/3.0.0/immodules.cache
sed -i 's@/usr/lib/@./usr/lib/@g' /var/appimage-dir/usr/lib/gtk-3.0/3.0.0/immodules.cache

# Ensure gdk-pixbuf loaders include librsvg svg loader and cache references local path
if [ -x /usr/bin/gdk-pixbuf-query-loaders ]; then
    /usr/bin/gdk-pixbuf-query-loaders > /var/appimage-dir/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache
fi
sed -i 's@/usr/lib/@./usr/lib/@g' /var/appimage-dir/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache || true

# Refresh icon caches if available (improves lookup speed inside AppImage)
if [ -x /usr/bin/gtk-update-icon-cache ]; then
    for d in /var/appimage-dir/usr/share/icons/hicolor /var/appimage-dir/usr/share/icons/Adwaita; do
        [ -d "$d" ] && /usr/bin/gtk-update-icon-cache -f -q "$d" || true
    done
fi

ARCH=x86_64 LD_LIBRARY_PATH="/usr/glibc-compat/lib64:/usr/glibc-compat/lib" /appimagetool-x86_64.AppImage /var/appimage-dir Asbru-CM.AppImage
