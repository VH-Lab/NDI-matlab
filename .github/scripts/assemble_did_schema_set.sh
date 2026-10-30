#!/usr/bin/env bash
# Assemble did-schema's V2 schema set into ONE flat directory (DID_SCHEMA_PATH).
#
#   bash .github/scripts/assemble_did_schema_set.sh <did-schema checkout> <destination dir>
#
# Reads BOTH layouts, so nothing breaks while did-schema moves from one to the
# other:
#
#   tiered (today)  schemas/did_v2/stable/*.json, schemas/did_v2/draft/*.json,
#                   and schemas/did_v2/deprecated/*.json when it exists
#   flat            schemas/did_v2/*.json
#                   Decided by Jess Haley, 2026-10-29 [one folder, final
#                   classes only] (did-schema V_eta_go_forward_class_audit.md):
#                   "every V2 class lives in one folder, `schemas/did_v2/`, with
#                   no `stable/` / `draft/` tiers"; "the siblings that read the
#                   tiers by path ... move to the flat layout first".
#
# A tier folder that is absent is skipped, never an error (draft/ goes away in
# the flat layout). The set's root has always held two files that are not
# schemas, index.json (the class index) and topics.json; they are not copied,
# because DID-matlab's did2.schema.cache parses every *.json in the directory
# that is not a *_meta file as a class.
#
# [schema set renamed did_v2] (Jess Haley, 2026-10-25), step 1 "accept both
# names": schemas/did_v2/ when the checkout has it, else schemas/V_eta/.
#
# Fails when a file name occurs in two places (the flat copy and a tier, or two
# tiers): which copy wins would otherwise depend on copy order. Fails when
# nothing is copied. Prints the denominator: files copied, per source.

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <did-schema checkout> <destination dir>" >&2
    exit 2
fi
REPO="$1"
DEST="$2"

SET="$REPO/schemas/did_v2"
[ -d "$SET" ] || SET="$REPO/schemas/V_eta"
if [ ! -d "$SET" ]; then
    echo "::error::no schema set: neither $REPO/schemas/did_v2 nor $REPO/schemas/V_eta exists" >&2
    exit 1
fi
echo "SCHEMA SET: $SET"
mkdir -p "$DEST"

SEEN=""      # one "<file name><TAB><source>" line per file copied (bash 3 has no maps)
total=0
TAB="$(printf '\t')"

copy_from() {
    # copy_from <dir> <label> [root]: every *.json directly in <dir>
    local dir="$1" label="$2" root="${3:-}" n=0 f base prev
    if [ ! -d "$dir" ]; then
        echo "  $label: absent (skipped)"
        return 0
    fi
    shopt -s nullglob
    for f in "$dir"/*.json; do
        base="$(basename "$f")"
        if [ -n "$root" ]; then
            case "$base" in
                index.json|topics.json) continue ;;
            esac
        fi
        prev="$(printf '%s\n' "$SEEN" | awk -F'\t' -v b="$base" '$1 == b { print $2; exit }')"
        if [ -n "$prev" ]; then
            echo "::error::$base is in both $prev and $label; refusing to pick one" >&2
            exit 1
        fi
        SEEN="$SEEN$base$TAB$label
"
        cp "$f" "$DEST/"
        n=$((n + 1))
    done
    shopt -u nullglob
    echo "  $label: $n file(s)"
    total=$((total + n))
}

copy_from "$SET"            "flat ($SET/*.json)" root
copy_from "$SET/stable"     "stable/"
copy_from "$SET/draft"      "draft/"
copy_from "$SET/deprecated" "deprecated/"

if [ "$total" -eq 0 ]; then
    echo "::error::no schema file copied from $SET" >&2
    exit 1
fi
echo "DENOMINATOR: $total schema file(s) from did-schema@$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
