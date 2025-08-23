#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Build an RPM from the current tree using dist/rpm/asbru.spec
# Output ends up under ./rpm-out

spec="dist/rpm/asbru.spec"
if [[ ! -f "$spec" ]]; then
  echo "Spec not found: $spec" >&2
  exit 1
fi

version=$(perl -ne 'print $1 if /our \$APPVERSION\s*=\s*\'([^\']+)\'/' lib/PACUtils.pm)
version=${version:-7.1.0}
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

echo "Version: $version"

# Create source tarball layout
mkdir -p "$workdir/asbru-cm-$version"
rsync -a --exclude '.git' --exclude 'rpm-out' --exclude 'dist/appimage/build' ./ "$workdir/asbru-cm-$version/"

pushd "$workdir" >/dev/null
tar -caf "asbru-cm-$version.tar.gz" "asbru-cm-$version"
popd >/dev/null

# RPM build root
rpmtop="$workdir/rpmbuild"
mkdir -p "$rpmtop/BUILD" "$rpmtop/RPMS" "$rpmtop/SOURCES" "$rpmtop/SPECS" "$rpmtop/SRPMS"
cp -a "$workdir/asbru-cm-$version.tar.gz" "$rpmtop/SOURCES/"
cp -a "$spec" "$rpmtop/SPECS/"

echo "Building RPM..."
rpmbuild \
  --define "_topdir $rpmtop" \
  --define "_version $version" \
  -ba "$rpmtop/SPECS/$(basename "$spec")"

mkdir -p rpm-out
find "$rpmtop/RPMS" -type f -name '*.rpm' -exec cp -a {} rpm-out/ \;
find "$rpmtop/SRPMS" -type f -name '*.src.rpm' -exec cp -a {} rpm-out/ \;

echo "RPM artifacts in ./rpm-out:" && ls -1 rpm-out
