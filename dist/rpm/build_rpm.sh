#!/bin/bash
set -euo pipefail
VERSION=7.0.0+modern41
RELEASE=1
SPEC=dist/rpm/asbru.spec
WORK=dist/rpm
TARBALL=$WORK/asbru-cm-${VERSION}.tar.gz
if [ ! -f "$TARBALL" ]; then
  echo "Source tarball $TARBALL missing. Run tar creation step first." >&2
  exit 1
fi
RPMTOP=$(pwd)/dist/rpm/build
mkdir -p $RPMTOP/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
cp "$TARBALL" $RPMTOP/SOURCES/
cp "$SPEC" $RPMTOP/SPECS/
rpmbuild --define "_topdir $RPMTOP" --define "_version $VERSION" --define "_release $RELEASE" --define 'skip_br 1' -bb $RPMTOP/SPECS/$(basename $SPEC)
ls -1 $RPMTOP/RPMS/* || true
