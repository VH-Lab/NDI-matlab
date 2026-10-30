#!/usr/bin/env bash
# Assemble did-schema's V2 schema set into ONE flat directory (DID_SCHEMA_PATH).
#
#   bash .github/scripts/assemble_did_schema_set.sh <did-schema checkout> <destination dir>
#
# Reads EVERY layout did-schema has had or is moving to, so nothing breaks while
# it moves:
#
#   tiered          schemas/did_v2/{stable,draft,deprecated}/*.json, the
#                   registries (*_meta.json, ndi_reserved_keys.json) in stable/
#   flat            schemas/did_v2/*.json ([one folder, final classes only],
#                   Jess Haley, 2026-10-29)
#   by family       Decided by Jess Haley, 2026-10-30 [schema folders by family]
#                   (did-schema V_eta_go_forward_class_audit.md): schemas/did_v2/
#                   holds class files only, in family subfolders (core at the
#                   top; value/, calculation/, data_body/, time_reference/,
#                   retiring/); the registries move to schemas/registry/ and the
#                   tool-written files to schemas/generated/. Exact folders are
#                   not final, so nothing below names them.
#
# What is copied, FLAT, into <destination dir>:
#
#   class files     every *.json under schemas/did_v2/ (else schemas/V_eta/,
#                   [schema set renamed did_v2] step 1) at any depth, except in
#                   folders named registry or generated, hidden folders, and
#                   names that are not classes: *_meta.json,
#                   ndi_reserved_keys.json, index.json, topics.json, did_v2_*,
#                   V_eta_* (DID-matlab's did2.schema.cache.isClassFileName).
#   registries      every *_meta.json and ndi_reserved_keys.json anywhere under
#                   schemas/, and every *.json under schemas/registry/.
#
# Fails when one file name occurs twice (class names are unique across the
# tree, and a registry is read by its name: which copy wins would otherwise
# depend on copy order), and when no class file is found. Prints the
# denominator first: class files per folder, registries.

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <did-schema checkout> <destination dir>" >&2
    exit 2
fi
REPO="$1"
DEST="$2"
SCHEMAS="$REPO/schemas"

SET="$SCHEMAS/did_v2"
[ -d "$SET" ] || SET="$SCHEMAS/V_eta"
if [ ! -d "$SET" ]; then
    echo "::error::no schema set: neither $SCHEMAS/did_v2 nor $SCHEMAS/V_eta exists" >&2
    exit 1
fi
echo "SCHEMA SET: $SET"

is_class() {
    case "$1" in
        *_meta.json|ndi_reserved_keys.json|index.json|topics.json|did_v2_*|V_eta_*) return 1 ;;
        *.json) return 0 ;;
        *) return 1 ;;
    esac
}

LIST="$(mktemp)"
trap 'rm -f "$LIST"' EXIT

# class files: any depth, registry/ generated/ and hidden folders pruned
while IFS= read -r f; do
    if is_class "$(basename "$f")"; then printf 'class\t%s\n' "$f" >> "$LIST"; fi
done < <(find "$SET" -mindepth 1 -type d \( -name registry -o -name generated -o -name '.*' \) -prune \
              -o -type f -name '*.json' -print | LC_ALL=C sort)

# registries: by name anywhere under schemas/, plus everything in registry/
while IFS= read -r f; do
    printf 'registry\t%s\n' "$f" >> "$LIST"
done < <( { find "$SCHEMAS" -mindepth 1 -type d -name '.*' -prune \
                 -o -type f \( -name '*_meta.json' -o -name 'ndi_reserved_keys.json' \) -print
            if [ -d "$SCHEMAS/registry" ]; then
                find "$SCHEMAS/registry" -type f -name '*.json' -print
            fi; } | LC_ALL=C sort -u)

nclass=$(awk -F'\t' '$1 == "class"' "$LIST" | wc -l | tr -d ' ')
nreg=$(awk -F'\t' '$1 == "registry"' "$LIST" | wc -l | tr -d ' ')
echo "DENOMINATOR: $nclass class file(s), $nreg registry file(s), from did-schema@$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
awk -F'\t' '$1 == "class"' "$LIST" | cut -f2 | while IFS= read -r f; do dirname "$f"; done \
    | LC_ALL=C sort | uniq -c | sed "s|$SCHEMAS/||; s|^|  class files in |"

if [ "$nclass" -eq 0 ]; then
    echo "::error::no class file found under $SET" >&2
    exit 1
fi

dups="$(cut -f2 "$LIST" | while IFS= read -r f; do basename "$f"; done | LC_ALL=C sort | uniq -d)"
if [ -n "$dups" ]; then
    for d in $dups; do
        echo "::error::$d is held more than once: $(cut -f2 "$LIST" | grep "/$d\$" | tr '\n' ' ')-- refusing to pick one" >&2
    done
    exit 1
fi

mkdir -p "$DEST"
cut -f2 "$LIST" | while IFS= read -r f; do cp "$f" "$DEST/"; done
echo "copied $((nclass + nreg)) file(s) into $DEST"
