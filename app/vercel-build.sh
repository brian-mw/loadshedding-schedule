#!/usr/bin/env bash
set -euo pipefail

readonly FLUTTER_VERSION="3.41.5"
readonly APP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SDK_DIR="${HOME}/.cache/flutter-${FLUTTER_VERSION}"

API_BASE_URL="${API_BASE_URL:-/api}"
case "$API_BASE_URL" in
  https://*) ;;
  /*) ;;
  *)
    echo "API_BASE_URL must be an absolute path or an HTTPS URL." >&2
    exit 1
    ;;
esac
API_BASE_URL="${API_BASE_URL%/}"

if command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter)"
else
  FLUTTER_BIN="${SDK_DIR}/bin/flutter"
  if [[ ! -x "$FLUTTER_BIN" ]]; then
    mkdir -p "$SDK_DIR"
    archive="$(mktemp)"
    trap 'rm -f "$archive"' EXIT
    curl --fail --location --silent --show-error \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      --output "$archive"
    tar -xf "$archive" -C "$SDK_DIR" --strip-components=1
  fi
fi

if [[ -e "$SDK_DIR/.git" ]] &&
  ! git config --global --get-all safe.directory | grep -Fxq "$SDK_DIR"; then
  git config --global --add safe.directory "$SDK_DIR"
fi

cd "$APP_DIR"
"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" build web \
  --release \
  --dart-define="API_BASE_URL=${API_BASE_URL}"
