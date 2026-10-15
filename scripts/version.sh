#!/bin/bash
#
# version.sh — single source of truth for AnatomyApp's semantic version.
#
# Every build configuration (app + tests, Debug + Release) carries ONE version:
#   MARKETING_VERSION        = MAJOR.MINOR.PATCH (semver)
#   CURRENT_PROJECT_VERSION  = monotonically increasing build number
#
# Rules (CLAUDE.md ▸ Conventions):
#   patch — bug fixes / tuning only
#   minor — new features, anatomy models, activities, assets
#   major — breaking changes (experience structure, min OS)
# Every released version gets an annotated git tag vX.Y.Z at its commit, so
# any build can be reverted to (git checkout vX.Y.Z) or diffed against.
#
# Usage:
#   scripts/version.sh current                  print version+build (verifies alignment)
#   scripts/version.sh verify                   alignment + tag consistency report
#   scripts/version.sh bump patch|minor|major   bump semver + build number
#   scripts/version.sh set X.Y.Z                set an explicit version (ALWAYS increments
#                                               the build; use it to re-align a drifted tree)
#   scripts/version.sh tag                      create annotated tag v<version> at HEAD
#
set -euo pipefail
cd "$(dirname "$0")/.."

PBX="AnatomyApp/AnatomyApp.xcodeproj/project.pbxproj"

# Distinct values of a build setting across every configuration in the project.
values() { grep -E "^[[:space:]]*$1 = " "$PBX" | sed -E "s/.*$1 = \"?([^\";]*)\"?;.*/\1/" | sort -u; }

require_aligned() {
  local nv nb
  nv=$(values MARKETING_VERSION | wc -l | tr -d ' ')
  nb=$(values CURRENT_PROJECT_VERSION | wc -l | tr -d ' ')
  if [ "$nv" != 1 ] || [ "$nb" != 1 ]; then
    echo "MISALIGNED configurations: MARKETING_VERSION={$(values MARKETING_VERSION | paste -sd, -)}" \
         "CURRENT_PROJECT_VERSION={$(values CURRENT_PROJECT_VERSION | paste -sd, -)}" >&2
    exit 1
  fi
}

# Normalise "1.0" -> "1.0.0" so semver arithmetic always has three parts.
semver() { IFS=. read -r a b c <<< "$1"; echo "${a:-0}.${b:-0}.${c:-0}"; }

write_all() { # $1 = version, $2 = build
  sed -i '' -E "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $1;/g" "$PBX"
  sed -i '' -E "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $2;/g" "$PBX"
  # Re-read and abort loudly if the write left configurations drifted or off-target.
  if [ "$(values MARKETING_VERSION)" != "$1" ] || [ "$(values CURRENT_PROJECT_VERSION)" != "$2" ]; then
    echo "WRITE FAILED: wanted v$1 ($2), got {$(values MARKETING_VERSION | paste -sd, -)}" \
         "({$(values CURRENT_PROJECT_VERSION | paste -sd, -)})" >&2
    exit 1
  fi
  echo "all configurations -> v$1 ($2)"
}

case "${1:-current}" in
  current|verify|bump|tag) require_aligned
    VERSION=$(semver "$(values MARKETING_VERSION)")
    BUILD=$(values CURRENT_PROJECT_VERSION) ;;
esac

case "${1:-current}" in
  current)
    echo "v$VERSION ($BUILD)"
    ;;
  verify)
    echo "version:  v$VERSION (build $BUILD) — all configurations aligned"
    latest_tag=$(git tag -l 'v*' --sort=-v:refname | head -1)
    echo "last tag: ${latest_tag:-none}"
    if [ "v$VERSION" != "${latest_tag:-}" ]; then
      echo "note: working version v$VERSION is ahead of last tag ${latest_tag:-none} (tag on release)"
    fi
    ;;
  bump)
    IFS=. read -r MA MI PA <<< "$VERSION"
    case "${2:?bump needs patch|minor|major}" in
      patch) PA=$((PA+1));;
      minor) MI=$((MI+1)); PA=0;;
      major) MA=$((MA+1)); MI=0; PA=0;;
      *) echo "unknown bump kind: $2" >&2; exit 1;;
    esac
    write_all "$MA.$MI.$PA" "$((BUILD+1))"
    ;;
  set)
    # Deliberately skips require_aligned so it can RE-ALIGN a drifted tree.
    max_build=$(values CURRENT_PROJECT_VERSION | sort -n | tail -1)
    write_all "$(semver "${2:?set needs X.Y.Z}")" "$((max_build+1))"
    ;;
  tag)
    if git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then
      echo "tag v$VERSION already exists at $(git rev-parse --short "v$VERSION^{commit}")" >&2
      exit 1
    fi
    git tag -a "v$VERSION" -m "AnatomyApp v$VERSION (build $BUILD)"
    echo "tagged v$VERSION at $(git rev-parse --short HEAD)"
    ;;
  *)
    echo "usage: version.sh [current|verify|bump patch|minor|major|set X.Y.Z|tag]" >&2
    exit 1
    ;;
esac
