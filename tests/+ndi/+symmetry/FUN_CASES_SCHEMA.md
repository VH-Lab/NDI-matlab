# `fun` symmetry artifact schema

The on-disk contract for the two `fun`-namespace symmetry artifacts:
`pathSafeNameCases.json` and `whatVariesCases.json`.

**Status: the MATLAB side of this contract was authored without a MATLAB runtime
and has never been executed.** Both sides were written in parallel by different
tasks, so the two implementations are expected to disagree in small ways on
first contact. This document is the reconciliation reference — *the integrator
adjusts one side to the other against this file*, and whichever side is changed,
this file is updated to match.

---

## 1. Where the files live

Both languages use the layout the `makeArtifacts` / `readArtifacts`
`INSTRUCTIONS.md` files already define:

```
<tempdir>/NDI/symmetryTest/<SourceType>/<namespace>/<className>/<testName>/<file>.json
```

* `<SourceType>` — `matlabArtifacts` or `pythonArtifacts`
* `<namespace>` — **`fun`** for both artifacts

| artifact | `<className>` | `<testName>` | `<file>.json` |
|---|---|---|---|
| pathSafeName | `pathSafeName` | `testPathSafeNameArtifacts` | `pathSafeNameCases.json` |
| whatVaries | `whatVaries` | `testWhatVariesArtifacts` | `whatVariesCases.json` |

The `<className>` / `<testName>` segments are **MATLAB-style names on both
sides**. That is not an oversight: the existing Python make-side tests already
hardcode MATLAB-style artifact directories (`tests/symmetry/make_artifacts/
session/test_build_session.py` writes to `.../session/buildSession/
testBuildSessionArtifacts/`) even though the pytest method is
`test_build_session_artifacts`. Keep that convention.

Files are written as **UTF-8 bytes**. The MATLAB side writes
`unicode2native(jsonencode(...), 'UTF-8')` rather than `fwrite(..., 'char')`,
because the astral pathSafeName cases put characters above U+00FF in the payload
and `'char'` truncates each to one byte.

**Non-ASCII policy: raw UTF-8, no `\uXXXX` escaping required — and both readers
must accept either form.** MATLAB's `jsonencode` emits non-ASCII characters
literally and the Python side passes `ensure_ascii=False`, so in practice both
files carry raw UTF-8; but escaping is *not* part of this contract, `jsondecode`
and `json.loads` both decode `\uXXXX` transparently, and neither side may assume
which form it will be handed. This is why the astral cases are compared as
**codepoint lists** (`inputCodepoints`,
`elementLegacyDirNameCodepoints`) rather than as raw text: a JSON text-encoding
choice can then never masquerade as a behaviour difference.

## 2. Common envelope

```json
{
  "schemaVersion": 1,
  "description": "…",
  "language": "matlab",
  "generator": "ndi.symmetry.makeArtifacts.fun.pathSafeName",
  "cases": [ { … }, { … } ]
}
```

* `language` — `"matlab"` or `"python"`.
* `generator` — free text naming the producing test; for humans only.
* `cases` — a JSON **array of objects**, one per case. Always an array, even for
  one case. Every case object carries **every** field listed below; a field that
  does not apply is `""` (text), `[]` (list), or `false`, never absent. That
  keeps `jsondecode` returning a clean struct array on the MATLAB side.

Cases are joined **by `name`**, not by position. Order is irrelevant to the
comparison, though both sides currently emit the same order.

## 3. The canonical value grammar

Every value that is compared across languages is first rendered to a string by
one small grammar, implemented in MATLAB as
`ndi.symmetry.fun.cases.render`. Comparing rendered strings avoids the usual
symmetry-test rot: MATLAB `double` vs Python `int`, MATLAB cell vs Python list,
`jsondecode` collapsing a one-element array, and so on.

| kind | rendering | examples |
|---|---|---|
| real number, scalar | `sprintf('%.12g')` | `0`, `0.5`, `180`, `-3.25` |
| non-finite | fixed tokens | `NaN`, `Inf`, `-Inf` |
| boolean, scalar | | `true`, `false` |
| text | single-quoted, no escaping | `'circle'`, `''` (empty text) |
| **sequence** | `[e1, e2, e3]` | `[0, 90, 180]`, `['r', 'g', 'b']`, `[]` |
| **mapping** | `{key: value, …}`, **keys sorted** | `{angle: 0, contrast: 1}` |
| anything else | `<classname>` | `<datetime>` |

Rules that matter:

* **The grammar does not distinguish container types.** A MATLAB cell array, a
  MATLAB struct array, a MATLAB numeric row vector, and a Python list all render
  as `[…]`. Python has one list type for all of them, so a grammar that told
  them apart could never match. The MATLAB-side input shape is recorded
  separately in each whatVaries case's `shape` field.
* **Mapping keys are sorted** so field-insertion order cannot cause a spurious
  mismatch.
* **Non-finite tokens are MATLAB's spelling.** Python must emit `NaN` / `Inf` /
  `-Inf`, not `nan` / `inf`.
* **Booleans are checked before numbers.** In Python `bool` is a subclass of
  `int`; `True` must render `true`, not `1`.
* Only **vectors** appear in this battery. A 2-D matrix would render in MATLAB's
  column-major order and Python's row-major order — do not add one.

Some fields are semantically a *list even when it has one element*.
`whatVaries`' `values` is the prime case: MATLAB collapses a single distinct
value to a bare scalar, while Python returns a one-element list. Those fields are
rendered with `renderSequence`, which always brackets: `[5]`, never `5`. The
per-field table below says which is which.

`whatIsConstantRendered` is the same kind of field and is easy to get wrong,
because the collapse happens one level up: `whatIsConstant` returns a *struct
array*, and a MATLAB **1x1** struct array is indistinguishable from a scalar
struct, so plain `render` maps a single-constant result to a **mapping**
`{parameter: 'contrast', value: 1}` while Python's one-element list gives the
**sequence** `[{parameter: 'contrast', value: 1}]`. It must therefore go through
`renderSequence` too. Empty and multi-entry results are unaffected — `render`
already delegates those to `renderSequence`.

`renderSequence` also has to special-case a bare `char`/`str`: it is **one**
element, not a sequence of characters. Iterating a MATLAB `char` row vector
would render `'circle'` as `['c', 'i', 'r', 'c', 'l', 'e']` against Python's
`['circle']`. No case in this battery reaches that today (`whatVaries` returns
non-numeric distinct values in a cell, so even a single distinct string arrives
as a one-element container on both sides), so the guard is a trap-setter, not a
behaviour change — but both ports carry it.

## 4. `pathSafeNameCases.json`

Exercises `ndi.fun.file.pathSafeName` and `ndi.fun.file.elementDirectoryName`
(Python: `ndi.fun.file.pathSafeName` / `elementDirectoryName`).

### Case object

| field | type | compared? | meaning |
|---|---|---|---|
| `name` | string | join key | stable ASCII case id |
| `status` | string | **yes** | `"ok"` or `"error"` |
| `identifier` | string | no | error id / exception class; humans only |
| `message` | string | no | error text; humans only |
| `note` | string | no | what branch of the sanitizer the case pins |
| `input` | string | no | the literal input, for reading the file |
| `inputCodepoints` | int list | **yes** | **the authoritative input**: Unicode scalar values |
| `inputUtf16Units` | int | **yes** | number of UTF-16 code units (MATLAB `numel(char(s))`) |
| `inputCodepointCount` | int | **yes** | number of Unicode scalar values (Python `len(s)`) |
| `pathSafeName` | string | **yes** | `pathSafeName(input)` |
| `elementDirName` | string | **yes** | first output of `elementDirectoryName(input)` |
| `elementLegacyDirName` | string | no | second output; recorded literally for reading |
| `elementLegacyDirNameCodepoints` | int list | **yes** | the same value as codepoints — compared instead of the literal so no JSON text-encoding difference can masquerade as a behaviour difference |

`identifier` and `message` are deliberately **never compared**: MATLAB
identifiers (`MATLAB:validators:mustBeTextScalar`) and Python exception names
(`TypeError`) can never match, and pinning them would make the symmetry test a
translation table instead of a behaviour check. Only the *fact* of an error
(`status`) is symmetric.

**The input is specified as codepoints, not as a literal.** Each side builds its
input string from `inputCodepoints` — MATLAB via UTF-8 and `native2unicode`,
Python via `chr()`. Neither side has to trust a source-file encoding, and
`readArtifacts/fun/pathSafeName.testInputsAgree` asserts the two sides really
started from the same bytes.

### Why `inputUtf16Units` and `inputCodepointCount` are both compared

MATLAB `char` holds UTF-16 code units, so a character above U+FFFF is a
surrogate **pair** and `pathSafeName` emits **two** `-` for it. Python counts
code points and a naive port emits one. For a *filename* contract that means the
two languages would disagree about which folder an element's data lives in —
exactly the bug `pathSafeName` was added to fix. Recording both counts makes the
difference visible in the artifact even when the sanitized names agree (the
current Python port deliberately reproduces the UTF-16 expansion, so they
should).

### The 22 cases

| # | name | input | expected result |
|---|---|---|---|
| 1 | `emptyString` | `''` | `x` |
| 2 | `portablePassthrough` | `ctx_1-a.dat` | unchanged |
| 3 | `elementBarSeparator` | `probe \| 1` | `probe_-_1` |
| 4 | `elementBarSeparatorUnderscored` | `ctx_\|_1` | `ctx_-_1` |
| 5 | `singleSpace` | `' '` | `_` |
| 6 | `tabAndNewline` | `a`,TAB,`b`,LF,`c` | `a_b_c` |
| 7 | `deleteControlChar` | `a`,DEL,`b` | `a_b` |
| 8 | `windowsForbiddenChars` | `a<b>c:d"e/f\g\|h?i*j` | `a-b-c-d-e-f-g-h-i-j` |
| 9 | `trailingDots` | `report...` | `report` |
| 10 | `allDots` | `...` | `x` |
| 11 | `leadingDot` | `.hidden` | `.hidden` |
| 12 | `reservedCON` | `CON` | `_CON` |
| 13 | `reservedLowerCon` | `con` | `_con` |
| 14 | `reservedCOM1` | `COM1` | `_COM1` |
| 15 | `reservedLPT9` | `LPT9` | `_LPT9` |
| 16 | `reservedWithExtension` | `CON.txt` | `_CON.txt` |
| 17 | `reservedTrailingDot` | `com1.` | `_com1` |
| 18 | `notReservedCOM0` | `COM0` | `COM0` |
| 19 | `bmpUnicodeAccent` | U+0061 U+00E9 U+0062 | `a-b`, 3 units / 3 codepoints |
| 20 | `astralUnicodeEmoji` | U+0061 U+1F600 U+0062 | `a--b`, **4 units / 3 codepoints** |
| 21 | `astralOnlyEmoji` | U+1F389 | `--`, 2 units / 1 codepoint |
| 22 | `astralThenTrailingDot` | U+1F600 U+002E | `--`, 3 units / 2 codepoints |

Cases 9/10/17 pin the ordering inside `pathSafeName`: the trailing-dot strip runs
**before** the empty check and **before** the reserved-name check. Case 11 pins
that the base name before the first dot is empty for `.hidden`, so no `_` prefix
is added. Case 18 pins that **`COM0`** is *not* reserved — **`COM0` is the only
non-reserved device name this battery exercises.** `LPT0`, along with `COM10`,
`CONS`, `CONSOLE` and `AUXX`, is covered Python-side in
`tests/test_element_directory.py`, not here; an earlier version of this line
claimed `LPT0` for the symmetry battery, which was coverage it does not have.

`elementDirName` must equal `pathSafeName` on every case: `elementDirectoryName`
maps space to `_` before delegating, and `pathSafeName` maps space to `_` too.
The MATLAB make-side test asserts that invariant. `elementLegacyDirName` is the
input with U+0020 replaced by U+005F and **nothing else** changed.

## 5. `whatVariesCases.json`

Exercises `ndi.fun.stimulus.whatVaries` and `ndi.fun.stimulus.whatIsConstant`.

### Case object

| field | type | compared? | meaning |
|---|---|---|---|
| `name` | string | join key | stable ASCII case id |
| `status` | string | **yes** | `"ok"` or `"error"` |
| `identifier` | string | no | error id / exception class; humans only |
| `message` | string | no | error text; humans only |
| `shape` | string | no | MATLAB-side input shape token (below) |
| `mirrors` | string | no | which `whatVariesTest` method(s) this case mirrors |
| `excludeBlank` | bool | **yes** | the option the case was run with |
| `inputRendered` | string | **yes** | the input, in the canonical grammar |
| `variesParameters` | string list | **yes** | varying parameter names, in output order |
| `variesValues` | string list | **yes** | parallel to `variesParameters`; each entry is the distinct-value list, rendered **as a sequence** (`[5]`, never `5`) |
| `constantParameters` | string list | **yes** | constant parameter names, in output order |
| `constantValues` | string list | **yes** | parallel to `constantParameters`; each entry is a **single value**, rendered normally (`1`, `['r', 'g', 'b']`) |
| `whatIsConstantRendered` | string | **yes** | the whole `whatIsConstant` result, rendered **via `renderSequence`** — `[{parameter: 'contrast', value: 1}, …]`, `[{…}]` for a single constant parameter (never a bare `{…}`), `[]` when empty |

`inputRendered` is compared on purpose: it is the only thing that catches the two
hand-written batteries drifting apart. Without it the suite could go green while
silently comparing two different inputs.

`whatIsConstantRendered` exists so that `whatVariesTest`'s
`testWhatIsConstantMatchesSecondOutput` is covered on *every* case rather than as
one extra case.

**The grammar's fallback tokens are language-specific and deliberately
unreachable from this battery.** MATLAB `render` emits `<missing>` for a missing
`string` scalar and `<classname>` for any class it does not know; Python emits
`<NoneType>` for `None` and `<typename>` otherwise. These can never match across
languages and no case produces one. That is the point: a fallback token showing
up in an artifact does not mean the two sides disagree, it means a case grew a
value the grammar was never given a symmetric rendering for. The fix is to add
that rendering **on both sides**, not to add a token to the table in section 3.

### `shape` tokens

Recorded, not compared — Python has one list type for several of these.

`stimuliStructArray`, `cellOfParameterStructs`,
`structArrayOfParameterStructs`, `documentProperties`,
`documentPropertiesArray`, `singleParameterStruct`, `emptyCell`, `badInput`.

### The 18 cases, and how they map onto the 17 MATLAB test methods

`tests/+ndi/+unittest/+fun/+stimulus/whatVariesTest.m` has 17 test methods and
the battery has 18 rows. The mapping is not one-to-one in *either* direction, so
here is the arithmetic in full:

* **15** methods contribute exactly one row each.
* `testWhatIsConstantMatchesSecondOutput` contributes **no row of its own**. It
  reuses `testStimuliStructArray`'s three-angle fixture (row 1), and the
  equivalence it asserts is instead checked on *every* row by the
  `whatIsConstantRendered` field.
* `testBadInputErrors` contributes **two** rows, not one: it asserts two separate
  errors, `whatVaries(42)` and `whatVaries({42})`, which are rows 17 and 18.
* **1** row, `allNaNParameter`, mirrors no method at all — it is the added
  divergence probe.

So **15 + 2 + 1 = 18**. (An earlier version of this paragraph said "two methods
do not contribute a distinct input … 17 rows plus one", which double-counted:
`testBadInputErrors` does not fail to contribute a row, it contributes an extra
one.)

| # | case name | mirrors `whatVariesTest` method |
|---|---|---|
| 1 | `stimuliStructArray` | `testStimuliStructArray` **and** `testWhatIsConstantMatchesSecondOutput` (same input; the equivalence is checked by `whatIsConstantRendered` on every case) |
| 2 | `valuesSortedAndUnique` | `testValuesSortedAndUnique` |
| 3 | `cellOfParameterStructs` | `testCellOfParameterStructs` |
| 4 | `structArrayOfParameterStructs` | `testStructArrayOfParameterStructs` |
| 5 | `documentPropertiesShapedStruct` | `testDocumentPropertiesShapedStruct` |
| 6 | `poolingAcrossPresentations` | `testPoolingAcrossPresentations` (presentation 2 carries **two** stimuli — see below) |
| 7 | `fieldPresentInSomeStimuli` | `testFieldPresentInSomeStimuli` |
| 8 | `blankStimuliExcludedByDefault` | `testBlankStimuliExcludedByDefault` |
| 9 | `blankStimuliIncludedWhenOptionFalse` | `testBlankStimuliIncludedWhenOptionFalse` (same stimuli as 8, `excludeBlank=false`) |
| 10 | `cellValuedConstantParameter` | `testCellValuedConstantParameter` — **known divergence** |
| 11 | `vectorValuedVaryingParameter` | `testVectorValuedVaryingParameter` |
| 12 | `allBlankStimuli` | `testAllBlankStimuliGivesEmpty` |
| 13 | `nonNumericValues` | `testNonNumericValuesReturnedAsCell` |
| 14 | `allConstantSingleStimulus` | `testAllConstantSingleStimulus` |
| 15 | `emptyInput` | `testEmptyInput` |
| 16 | `allNaNParameter` | *none* — added to pin the `eqlen(NaN,NaN)` divergence |
| 17 | `badInputNumeric` | `testBadInputErrors`, first assertion (`whatVaries(42)`) |
| 18 | `badCellEntry` | `testBadInputErrors`, second assertion (`whatVaries({42})`) |

The exact inputs are in `ndi.symmetry.fun.cases.whatVariesInput`; the Python side
carries an equivalent table. `inputRendered` is what keeps the two honest.

**Every nested list in a fixture must have at least two elements.** This is a
hard constraint on the case list, not a style note. MATLAB cannot tell a 1x1
struct array from a scalar struct, so a one-element nested list renders as a
**mapping** on the MATLAB side and a **sequence** on the Python side — and since
`inputRendered` is compared, the two languages would fail against each other over
a container shape rather than a behaviour. `poolingAcrossPresentations` is the
case this bites: presentation 2 therefore carries **two** stimuli (angles 270 and
315, giving the pooled `[0, 90, 180, 270, 315]`), not the one it originally had.
Top-level lists are safe — the `cases` array is a MATLAB *cell*, which
`jsonencode` never collapses — but nested `stimuli` arrays are not.

### Known divergences

`ndi.symmetry.fun.cases.knownDivergences` lists the cases where MATLAB `main` and
the Python port are believed to disagree **today**. Both trace to one line:
`local_varyingFields` in `src/ndi/+ndi/+fun/+stimulus/whatVaries.m` compares with
`vlt.data.eqlen`, which bottoms out in a bare `==`, while `local_uniqueValues` in
the same file already uses `isequaln` and the Python port uses `isequaln`
semantics throughout.

| case | predicted MATLAB | predicted Python |
|---|---|---|
| `cellValuedConstantParameter` | **errors** — `==` is undefined for two cell arrays | succeeds; `color` is constant |
| `allNaNParameter` | `angle` reported **varying** — `eqlen(NaN,NaN)` is false | `angle` reported **constant** |

**These are source-read predictions, not measurements.** No MATLAB runtime was
available when this battery was written. The first real run settles them:

* `readArtifacts/fun/whatVaries.testMatlabPythonSymmetry` reports rather than
  fails on a listed case, and fails on every other mismatch.
* `readArtifacts/fun/whatVaries.testKnownDivergencesAreStillReal` prints, for each
  listed case, whether the divergence actually showed up. **A listed case that now
  agrees means the upstream fix landed** — delete the entry from
  `knownDivergences` and clear `divergenceExpected` in `whatVariesDefs` so the
  case becomes a hard assertion again. A stale allow-list is how a symmetry suite
  goes quietly green over the bug it exists to watch.

**Settled: the auditor FAILS on a stale entry.** It previously reported and never
failed, so a stale allow-list entry landed as a line in the CI log rather than a
red build — the same failure mode as a silently skipped test, and exactly what
the paragraph above warns about. `testKnownDivergencesAreStillReal` and its
Python twin `audit_known_divergences` now both fail when a listed case starts
agreeing across languages, so the entry gets removed and the case goes back to
being a hard assertion.

A case *missing* from either artifact still only reports. That is list drift
rather than a landed fix, and the key-set check in `testMatlabPythonSymmetry`
already fails on it; failing twice for one cause is noise.

If the divergences turn out to be real, the upstream fix is to swap `eqlen` for
`isequaln` in `local_varyingFields`.

## 6. Why the whatVaries generator records errors instead of failing

`makeArtifacts/fun/whatVaries` wraps every case in try/catch **by design** and
records a throwing case as `{"status": "error", "identifier": …}`. If it failed
instead, a generator that died on the already-known cell-valued case would write
no artifact at all — costing the symmetry suite every other case's coverage to
report one bug that is already documented.

The error is not swallowed. It is printed by the make test, recorded in the
artifact, and **asserted against Python** in `readArtifacts/fun/whatVaries`. The
assertion lives at the comparison, where the two languages can actually be held
against each other.

`makeArtifacts/fun/pathSafeName` is the opposite: it asserts its expected outputs
before writing, because MATLAB is the reference side for `pathSafeName` and every
branch of it is deterministic and fully readable. This follows
`makeArtifacts/time/timeConvert`, whose earlier `assumeTrue`-based skip silently
masked a real `time_convert` bug.

## 7. `readArtifacts/session/objectTypeMarker` — a caveat worth carrying

That test asserts `ndi.session.dir.directorytype` returns `'session'` /
`'dataset'` on both languages' session and dataset artifact directories. It has a
soundness hole that the integrator should know about:

The `ndi.session.dir` **constructor** calls `updateObjectTypeMarker`
(`src/ndi/+ndi/+session/dir.m:160`), so any MATLAB test that merely *opens* a
Python-generated artifact directory writes the marker into it.
`readArtifacts/session/buildSession` does exactly that, and `buildSession` sorts
before `objectTypeMarker`. So for `pythonArtifacts` a **pass proves nothing** —
only a failure is conclusive. The test prints whether the marker file was already
present when it ran.

The sound version of this check belongs in **Python's own suite**, asserting
`directorytype` on its freshly written artifacts before any MATLAB code has run.
Worth adding on the Python side during integration.

## 8. Discovery / CI

No workflow change is needed. `.github/workflows/test-symmetry.yml` builds its
suite with

```matlab
TestSuite.fromPackage("ndi.symmetry.makeArtifacts", "IncludingSubpackages", true)
TestSuite.fromPackage("ndi.symmetry.readArtifacts", "IncludingSubpackages", true)
```

so the new `+fun` subpackages are picked up automatically, exactly as `+time`
was. `ndi.symmetry.fun.cases` is a plain `classdef` (not a `TestCase`) and sits
outside both packages, so it is a shared helper and never a discovered test —
the same arrangement as `ndi.symmetry.time.scenario`.
