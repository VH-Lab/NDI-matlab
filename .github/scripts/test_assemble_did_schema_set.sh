#!/usr/bin/env bash
# Test assemble_did_schema_set.sh on did-schema's old and new layouts.
#
#   bash .github/scripts/test_assemble_did_schema_set.sh
#
# [schema folders by family] (Decided by Jess Haley, 2026-10-30, did-schema
# V_eta_go_forward_class_audit.md): classes move into family subfolders of
# schemas/did_v2/, registries to schemas/registry/ and schemas/generated/.
# Builds the SAME classes and registries in the old layout (stable/, draft/,
# deprecated/; registries in stable/) and the new one in a temp directory, and
# checks that:
#   1. both assemble the same class files and the same registries;
#   2. the old layout assembles exactly what `cp stable/ draft/ deprecated/` did;
#   3. a class held twice, or a registry in two folders, fails;
#   4. an empty set fails.
# Exits 1 on the first failure, printing what it saw.

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ASM="$HERE/assemble_did_schema_set.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
put() { mkdir -p "$(dirname "$1")"; printf '{"file":"%s"}' "$(basename "$1")" > "$1"; }

build() {  # build <root> old|new
    local s="$1/schemas"
    if [ "$2" = old ]; then
        for c in base entity assertion mass tuning_curve_calculation sampled_body; do put "$s/did_v2/stable/$c.json"; done
        for c in clock_type genomic_interval; do put "$s/did_v2/draft/$c.json"; done
        put "$s/did_v2/deprecated/old_thing.json"
        for r in CURIE_lookups_meta binding_registry_meta ndi_reserved_keys term_registry_meta class_disposition_meta; do
            put "$s/did_v2/stable/$r.json"; done
        put "$s/did_v2/index.json"; put "$s/did_v2/topics.json"
        put "$s/V_eta_term_registry.json"; put "$s/V_eta_coverage_ledger.json"
    else
        for c in base entity assertion; do put "$s/did_v2/$c.json"; done
        put "$s/did_v2/value/mass.json"; put "$s/did_v2/value/genomic_interval.json"
        put "$s/did_v2/calculation/tuning_curve_calculation.json"
        put "$s/did_v2/data_body/sampled_body.json"
        put "$s/did_v2/time_reference/clock_type.json"
        put "$s/did_v2/retiring/old_thing.json"
        for r in CURIE_lookups_meta binding_registry_meta ndi_reserved_keys; do put "$s/registry/$r.json"; done
        for r in term_registry_meta class_disposition_meta; do put "$s/generated/$r.json"; done
        put "$s/generated/index.json"
        put "$s/registry/did_v2_term_registry.json"; put "$s/generated/did_v2_coverage_ledger.json"
    fi
}

classes_of() { ls "$1" | grep -v -E '_meta\.json$|^ndi_reserved_keys\.json$|^did_v2_|^V_eta_' | sort; }
regs_of() { ls "$1" | grep -E '_meta\.json$|^ndi_reserved_keys\.json$' | sort; }

n=0
build "$T/old" old; build "$T/new" new
bash "$ASM" "$T/old" "$T/flat_old" > "$T/out_old" || { cat "$T/out_old"; fail "old layout did not assemble"; }
bash "$ASM" "$T/new" "$T/flat_new" > "$T/out_new" || { cat "$T/out_new"; fail "new layout did not assemble"; }
grep -q "^DENOMINATOR: 9 class file(s)" "$T/out_new" || { cat "$T/out_new"; fail "new layout denominator"; }

# 1. same classes, same registries
[ "$(classes_of "$T/flat_old")" = "$(classes_of "$T/flat_new")" ] || fail "classes differ: $(diff <(classes_of "$T/flat_old") <(classes_of "$T/flat_new") | tr '\n' ' ')"
[ "$(classes_of "$T/flat_new" | wc -l | tr -d ' ')" = 9 ] || fail "expected 9 classes, got $(classes_of "$T/flat_new" | tr '\n' ' ')"
[ "$(regs_of "$T/flat_old")" = "$(regs_of "$T/flat_new")" ] || fail "registries differ"
[ "$(regs_of "$T/flat_new" | wc -l | tr -d ' ')" = 5 ] || fail "expected 5 registries"
[ ! -e "$T/flat_new/index.json" ] && [ ! -e "$T/flat_old/index.json" ] && [ ! -e "$T/flat_old/topics.json" ] || fail "index/topics copied"
n=$((n + 1)); echo "ok   both layouts assemble the same classes and registries"

# 2. old layout == old cp
mkdir -p "$T/cp"; cp "$T/old/schemas/did_v2/"{stable,draft,deprecated}/*.json "$T/cp/"
diff -r "$T/cp" "$T/flat_old" > /dev/null || fail "old layout differs from cp stable/ draft/ deprecated/"
n=$((n + 1)); echo "ok   the old layout matches the old cp"

# 3. duplicates fail
put "$T/new/schemas/did_v2/calculation/entity.json"
if bash "$ASM" "$T/new" "$T/flat_dup" > "$T/out_dup" 2>&1; then fail "a class held twice did not fail"; fi
grep -q "entity.json is held more than once" "$T/out_dup" || { cat "$T/out_dup"; fail "duplicate class message"; }
rm "$T/new/schemas/did_v2/calculation/entity.json"
put "$T/new/schemas/generated/binding_registry_meta.json"
if bash "$ASM" "$T/new" "$T/flat_dup2" > "$T/out_dup2" 2>&1; then fail "a registry held twice did not fail"; fi
n=$((n + 1)); echo "ok   a duplicate class or registry fails"

# 4. empty fails
mkdir -p "$T/empty/schemas/did_v2"
if bash "$ASM" "$T/empty" "$T/flat_empty" > "$T/out_empty" 2>&1; then fail "an empty set did not fail"; fi
grep -q "DENOMINATOR: 0 class file(s)" "$T/out_empty" || { cat "$T/out_empty"; fail "empty denominator"; }
n=$((n + 1)); echo "ok   an empty set fails"

echo
echo "$n test(s), 0 failure(s)"
