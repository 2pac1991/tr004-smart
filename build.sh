#!/bin/bash
# Baut das Unraid-Paket dist/tr004-smart-<version>.txz und plugin/tr004-smart.plg
#   ./build.sh                 Version = heutiges Datum (JJJJ.MM.TT)
#   ./build.sh 2026.11.15a     eigene Version
#   ./build.sh --release [v]   zusaetzlich GitHub-Release mit dem Paket anlegen (Downloads werden gezaehlt)
set -euo pipefail
cd "$(dirname "$0")"
RELEASE=0; [ "${1:-}" = "--release" ] && { RELEASE=1; shift; }
VERSION="${1:-$(date +%Y.%m.%d)}"
NAME=tr004-smart
P=usr/local/emhttp/plugins/$NAME
STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT

bash tests/run-tests.sh >/dev/null || { echo "Tests fehlgeschlagen - kein Paket gebaut" >&2; exit 1; }

cp -R src/ "$STAGE/"
install -m 755 tr004-smart            "$STAGE/$P/tr004-smart"
install -m 755 unraid/smartctl-wrapper "$STAGE/$P/smartctl-wrapper"
chmod 755 "$STAGE/$P/scripts/"*.sh
sed -i.bak "s/^VERSION=\".*\"/VERSION=\"$VERSION\"/" "$STAGE/$P/tr004-smart" && rm -f "$STAGE/$P/tr004-smart.bak"
find "$STAGE" -name .DS_Store -delete

mkdir -p dist
OUT="dist/$NAME-$VERSION.txz"
# Slackware-Paket: tar.xz, Besitzer root
if tar --version 2>/dev/null | grep -q bsdtar; then
  (cd "$STAGE" && tar --uid 0 --gid 0 --uname root --gname root -cJf - usr) > "$OUT"
else
  (cd "$STAGE" && tar --owner=0 --group=0 -cJf - usr) > "$OUT"
fi
MD5=$(md5sum "$OUT" 2>/dev/null | cut -d' ' -f1 || md5 -q "$OUT")
[ -n "$MD5" ] || MD5=$(md5 -q "$OUT")
sed -e "s/@VERSION@/$VERSION/g" -e "s/@MD5@/$MD5/g" plugin/$NAME.plg.in > plugin/$NAME.plg
echo "gebaut: $OUT ($MD5)"
echo "        plugin/$NAME.plg (Version $VERSION)"

if [ $RELEASE = 1 ]; then
  gh release create "$VERSION" "$OUT" --title "$NAME $VERSION" --notes "Unraid-Plugin $NAME $VERSION (Beta). Installation: Plugins > Install Plugin > https://raw.githubusercontent.com/2pac1991/tr004-smart/main/plugin/tr004-smart.plg" --prerelease
  echo "Release $VERSION angelegt - jetzt plugin/$NAME.plg committen und pushen"
fi
