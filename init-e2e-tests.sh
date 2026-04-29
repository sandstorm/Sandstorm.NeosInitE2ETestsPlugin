#!/usr/bin/env bash
#
# init-e2e-tests.sh — Scaffold E2E test infrastructure into a Neos package.
#
# Standalone bash port of the `composer e2e:init` command provided by
# sandstorm/neos-init-e2e-tests-plugin. Run from the root of a Neos package:
#
#   curl -fsSL https://raw.githubusercontent.com/sandstorm/Sandstorm.NeosInitE2ETestsPlugin/main/init-e2e-tests.sh | bash
#
# Configuration via environment variables:
#   E2E_REF       — git ref to fetch (default: main)
#

set -euo pipefail

E2E_REF="${E2E_REF:-main}"
E2E_REPO_URL="https://github.com/sandstorm/Sandstorm.NeosInitE2ETestsPlugin"

PROJECT_ROOT="$(pwd)"

if [ ! -f "$PROJECT_ROOT/composer.json" ]; then
    echo "Error: no composer.json found in $PROJECT_ROOT" >&2
    echo "Run this script from the root of your Neos package." >&2
    exit 1
fi

for cmd in curl tar find sed jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: required command '$cmd' not found in PATH." >&2
        exit 1
    fi
done

PACKAGE_NAME="$(jq -r '.name // empty' composer.json)"
if [ -z "$PACKAGE_NAME" ]; then
    echo "Error: composer.json is missing a \"name\" field." >&2
    exit 1
fi

# Derive the Neos package key from the composer name, mirroring
# derivePackageKey() in src/InitCommand.php.
#
# The jq expression defines two helper functions:
#   ucfirst  — capitalises the first character of a string, leaves the rest as-is.
#   camel    — splits a string on one-or-more hyphens/underscores, ucfirsts each
#              word, and joins them into CamelCase (e.g. "my-neos-pkg" → "MyNeosPkg").
#
# The main expression:
#   1. Uses .extra.neos."package-key" verbatim when it is present in composer.json.
#   2. Otherwise splits the composer name on "/" (e.g. "sandstorm/my-neos-pkg"),
#      applies camel() to each part, and joins them with "." →
#      "Sandstorm.MyNeosPkg".
PACKAGE_KEY="$(jq -r --arg name "$PACKAGE_NAME" '
    def ucfirst: (.[0:1] | ascii_upcase) + .[1:];
    def camel: split("[-_]+"; "") | map(select(length > 0) | ucfirst) | join("");
    .extra.neos."package-key" // ($name | split("/") | map(camel) | join("."))
' composer.json)"

echo "sandstorm/neos-init-e2e-tests-plugin: Scaffolding E2E test infrastructure..."
echo "  PackageName: $PACKAGE_NAME"
echo "  PackageKey:  $PACKAGE_KEY"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ARCHIVE_URL="$E2E_REPO_URL/archive/$E2E_REF.tar.gz"
echo "  Downloading template from $ARCHIVE_URL ..."
if ! curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$TMP"; then
    echo "Error: failed to download or extract $ARCHIVE_URL" >&2
    exit 1
fi

# GitHub archives always extract into a single top-level subdirectory named
# "<RepoName>-<ref>/". We locate it with find rather than hard-coding the name
# so this works regardless of the chosen ref (branch, tag, or commit SHA).
EXTRACTED_DIR="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
TEMPLATE_DIR="$EXTRACTED_DIR/template"

if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "Error: template/ not found in archive (looked at $TEMPLATE_DIR)" >&2
    exit 1
fi

# Recursively copy the template into the project root, substituting placeholders.
# Mirrors writeTemplate() in src/InitCommand.php.
#
# The null-delimiter pattern used here safely handles filenames that contain
# spaces, newlines, or other special characters:
#   find -print0        — separates entries with NUL (\0) instead of newlines.
#   read -d ''          — reads until the next NUL byte (one entry per iteration).
#   IFS=               — disables word-splitting so the path is read verbatim.
#   read -r            — disables backslash interpretation in the path.
#   < <(find …)        — process substitution: find runs as a subshell whose
#                        stdout is fed as stdin to the while loop.
while IFS= read -r -d '' src; do
    rel="${src#$TEMPLATE_DIR/}"
    dest="$PROJECT_ROOT/$rel"

    # Explicitly create directories so that empty template directories
    # (e.g. a placeholder Tests/ folder) are preserved in the destination.
    if [ -d "$src" ]; then
        mkdir -p "$dest"
        continue
    fi

    if [ -e "$dest" ]; then
        echo "  - Skipping existing: $rel"
        continue
    fi

    mkdir -p "$(dirname "$dest")"
    # Only run sed on files that actually contain a placeholder. Running sed
    # unconditionally on binary files (images, compiled assets, etc.) would
    # corrupt them.
    if grep -qE '\{\{(PackageName|PackageKey)\}\}' "$src"; then
        sed -e "s|{{PackageName}}|$PACKAGE_NAME|g" \
            -e "s|{{PackageKey}}|$PACKAGE_KEY|g" \
            "$src" > "$dest"
    else
        cp "$src" "$dest"
    fi
    echo "  - Created: $rel"
done < <(find "$TEMPLATE_DIR" -mindepth 1 -print0)

echo "Done."
