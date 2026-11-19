#!/usr/bin/env bash
# Assemble did-schema's v2 schema set into ONE flat directory (DID_SCHEMA_PATH).
#
#   bash .github/scripts/assemble_did_schema_set.sh <did-schema checkout> <destination dir>
#
# Reads did-schema main's layout, and only that one (Decided by Jess Haley,
# 2026-10-30 [schema folders by family] and 2026-10-29 [one folder, final
# classes only], did-schema did_v2_go_forward_class_audit.md): schemas/did_v2/
# holds class files only, core classes at the top and family subfolders
# (value/, calculation/, data_body/, time_reference/, relation/, acquisition/),
# plus retiring/ for the retire classes not yet deleted; the registries are in
# schemas/registry/ and the tool-written files in schemas/generated/.
#
# NO TIERS. There is no stable/, draft/ or deprecated/ tier any more, and the
# workflows stop copying deprecated/*.json ([retired classes leave V2] step 2,
# Jess Haley, 2026-10-25). A tier folder directly under schemas/did_v2/ FAILS
# the step: a checkout that has one is not did-schema main.
#
# FINAL CLASSES ONLY. The retire classes in schemas/did_v2/retiring/ are NOT
# copied ([one folder, final classes only]: "stop passing documents through
# under retire classes"; [retired classes leave V2]: "retired v1 types are not
# V2 classes, and a did_v1 document is not read against the V2 set"). Their
# count is printed. Measured safe before this was made the default: NDI-matlab
# PR for VH-Lab/NDI-matlab#1268 (its body lists the runs).
#
# What is copied, FLAT, into <destination dir>:
#
#   class files     every *.json under schemas/did_v2/ (else schemas/V_eta/,
#                   [schema set renamed did_v2] step 1) at any depth, except in
#                   folders named registry, generated or retiring, hidden
#                   folders, and names that are not classes: *_meta.json,
#                   ndi_reserved_keys.json, index.json, topics.json, did_v2_*,
#                   V_eta_* (DID-matlab's did2.schema.cache.isClassFileName).
#   registries      every *_meta.json and ndi_reserved_keys.json anywhere under
#                   schemas/, and every *.json under schemas/registry/.
#
# Fails when one file name occurs twice (class names are unique across the
# tree, and a registry is read by its name: which copy wins would otherwise
# depend on copy order), when a tier folder is found, and when no class file
# is found. Prints the denominator first: class files per folder, registries,
# retire class files not copied.

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

tiers=""
for t in stable draft deprecated; do
    if [ -d "$SET/$t" ]; then tiers="$tiers $t/"; fi
done
if [ -n "$tiers" ]; then
    echo "::error::tier folder(s)$tiers under $SET: did-schema has no stable/ draft/ deprecated/ tiers ([one folder, final classes only]; [retired classes leave V2] step 2), so this is not did-schema main's layout" >&2
    exit 1
fi

is_class() {
    case "$1" in
        *_meta.json|ndi_reserved_keys.json|index.json|topics.json|did_v2_*|V_eta_*) return 1 ;;
        *.json) return 0 ;;
        *) return 1 ;;
    esac
}

LIST="$(mktemp)"
trap 'rm -f "$LIST"' EXIT

# class files: any depth, registry/ generated/ retiring/ and hidden folders pruned
while IFS= read -r f; do
    if is_class "$(basename "$f")"; then printf 'class\t%s\n' "$f" >> "$LIST"; fi
done < <(find "$SET" -mindepth 1 -type d \( -name registry -o -name generated -o -name retiring -o -name '.*' \) -prune \
              -o -type f -name '*.json' -print | LC_ALL=C sort)
# the retire classes, counted and not copied
nretire=0
if [ -d "$SET/retiring" ]; then
    nretire=$(find "$SET/retiring" -type f -name '*.json' | wc -l | tr -d ' ')
fi

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
echo "NOT COPIED: $nretire retire class file(s) in ${SET#"$SCHEMAS/"}/retiring/ ([one folder, final classes only])"
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
# SCRATCH PROBE (not for merge): V2 base.name deleted, as did-schema will, to
# list the NDI tests that still build or read it
if [ -f "$DEST/base.json" ]; then
    python3 - "$DEST/base.json" <<'PY'
import json, sys
p = sys.argv[1]
with open(p) as fh:
    base = json.load(fh)
n = len(base.get("fields", []))
base["fields"] = [f for f in base.get("fields", []) if f.get("name") != "name"]
with open(p, "w") as fh:
    json.dump(base, fh, indent=4)
print("SCRATCH PROBE: base.name removed from %s (%d -> %d fields)" % (p, n, len(base["fields"])))
PY
fi
