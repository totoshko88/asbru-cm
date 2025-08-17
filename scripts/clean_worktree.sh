#!/usr/bin/env bash
set -euo pipefail

echo "Cleaning build & packaging artifacts..." >&2

PATTERNS=(
  'build' 'build_production' 'dist/deb/build' 'packpack' 'pkginspect' 'deb' 'rpm' 'appimage'
  '*/*.deb' '*.deb' '*.dsc' '*.tar.xz' '*.build' '*.buildinfo' '*.changes' '*.orig.tar.*' 'build_*.log'
  'package_quality_report.txt' 'lintian_detailed_report.txt' 'current_application_test_log.md'
)

deleted=0
for p in "${PATTERNS[@]}"; do
  matches=( $(compgen -G "$p" || true) )
  for m in "${matches[@]}"; do
    if [ -e "$m" ]; then
      rm -rf -- "$m" && echo "Removed $m" && ((deleted++)) || true
    fi
  done

done

echo "Cleanup complete. Removed $deleted paths." >&2

exit 0
