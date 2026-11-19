#!/usr/bin/env bash
# Test assemble_did_schema_set.sh on did-schema main's layout.
#
#   bash .github/scripts/test_assemble_did_schema_set.sh
#
# [schema folders by family] (Decided by Jess Haley, 2026-10-30, did-schema
# did_v2_go_forward_class_audit.md): classes in family subfolders of
# schemas/did_v2/, registries in schemas/registry/ and schemas/generated/.
# UPDATED 2026-11-19 ([retired classes leave V2] step 2, [one folder, final
# classes only]): the old tiered layout (stable/, draft/, deprecated/) is no
# longer read, and the retire classes in retiring/ are not copied. Builds a
# tree in a temp directory and checks that:
#   1. the family layout assembles every final class and every registry, and
#      no retire class (counted as NOT COPIED);
#   2. a tiered tree (stable/, draft/ or deprecated/) fails;
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
    else
        for c in base entity assertion; do put "$s/did_v2/$c.json"; done
        put "$s/did_v2/value/mass.json"; put "$s/did_v2/value/genomic_interval.json"
        put "$s/did_v2/calculation/tuning_curve_calculation.json"
        put "$s/did_v2/data_body/sampled_body.json"
        put "$s/did_v2/time_reference/clock_type.json"
        put "$s/did_v2/retiring/old_thing.json"
        put "$s/did_v2/retiring/older_thing.json"
        for r in CURIE_lookups_meta binding_registry_meta ndi_reserved_keys; do put "$s/registry/$r.json"; done
        for r in term_registry_meta class_disposition_meta; do put "$s/generated/$r.json"; done
        put "$s/generated/index.json"
        put "$s/registry/did_v2_term_registry.json"; put "$s/generated/did_v2_coverage_ledger.json"
    fi
}

classes_of() { ls "$1" | grep -v -E '_meta\.json$|^ndi_reserved_keys\.json$|^did_v2_|^V_eta_' | sort; }
regs_of() { ls "$1" | grep -E '_meta\.json$|^ndi_reserved_keys\.json$' | sort; }

n=0
build "$T/new" new
bash "$ASM" "$T/new" "$T/flat_new" > "$T/out_new" || { cat "$T/out_new"; fail "family layout did not assemble"; }

# 1. every final class and registry, no retire class
grep -q "^DENOMINATOR: 8 class file(s), 6 registry file(s)" "$T/out_new" || { cat "$T/out_new"; fail "family layout denominator"; }
grep -q "^NOT COPIED: 2 retire class file(s) in did_v2/retiring/" "$T/out_new" || { cat "$T/out_new"; fail "retire classes not counted"; }
want="assertion.json base.json clock_type.json entity.json genomic_interval.json mass.json sampled_body.json tuning_curve_calculation.json"
[ "$(classes_of "$T/flat_new" | tr '\n' ' ' | sed 's/ $//')" = "$want" ] || fail "classes: $(classes_of "$T/flat_new" | tr '\n' ' ')"
[ ! -e "$T/flat_new/old_thing.json" ] && [ ! -e "$T/flat_new/older_thing.json" ] || fail "a retire class was copied"
[ "$(regs_of "$T/flat_new" | wc -l | tr -d ' ')" = 5 ] || fail "expected 5 registries"
[ ! -e "$T/flat_new/index.json" ] || fail "index copied"
n=$((n + 1)); echo "ok   the family layout assembles the final classes and registries, no retire class"

# 2. a tiered tree fails, whichever tier
build "$T/old" old
if bash "$ASM" "$T/old" "$T/flat_old" > "$T/out_old" 2>&1; then cat "$T/out_old"; fail "a tiered tree assembled"; fi
grep -q "tier folder(s) stable/ draft/ deprecated/" "$T/out_old" || { cat "$T/out_old"; fail "tier message"; }
for t in stable draft deprecated; do
    rm -rf "$T/tier"; build "$T/tier" new; put "$T/tier/schemas/did_v2/$t/x.json"
    if bash "$ASM" "$T/tier" "$T/flat_tier" > "$T/out_tier" 2>&1; then fail "a $t/ folder did not fail"; fi
    grep -q "tier folder(s) $t/" "$T/out_tier" || { cat "$T/out_tier"; fail "$t/ message"; }
done
n=$((n + 1)); echo "ok   a tiered tree fails"

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
