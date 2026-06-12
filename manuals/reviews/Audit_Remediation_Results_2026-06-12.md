# NDI-matlab Audit Remediation — Results (2026-06-12)

This branch (`audit/ndi-matlab-2026-06`, off `origin/main` `84418b9a7`) implements the
NDI-matlab findings from the 2026-06 NDI ecosystem audit, as one consolidated set of
per-fix commits.

> **⚠️ Author-not-run.** These changes were authored without a local MATLAB/Maven
> runtime. Every commit message ends with "needs MATLAB to validate/run." Please run
> the MATLAB test suites (and the Java validator build) before merging. Each finding
> below was re-verified to still apply at `origin/main` `84418b9a7` (the audit baseline
> `2d76370` was behind).

## Findings addressed

| # | Area | Commit(s) | Summary |
|---|------|-----------|---------|
| M0 | Cloud API | `4cae5dd` | `finalize_compute_session` mapped to a nonexistent `/compute/{sessionId}/finalize` route (404 on every call). Repointed to `/compute/{sessionId}/advance` — the real backend route (verified against the cloud-node `compute.router.ts`; the `advance` controller stamps `finalizedAt` when advancing past the last stage). Matches the NDI-python cloud client. |
| M1 | Cloud sync | `42f9307` | `ndi.cloud.sync.enum.SyncMode/execute` forwarded options via `syncOptions.nvpairs()` — a method that does not exist (the accessor is `toCell()`), and without `{:}` expansion. Every sync through `ndi.cloud.syncDataset` errored at dispatch. Now `toCell(){:}`. Adds an **offline** `SyncModeDispatchTest` (the existing sync tests are live-cloud and call the sync functions directly, so they never covered this path). |
| M2 | Security — shell | `86379c7` | `ndi.fun.convertoldnsd2ndi` interpolated the caller's `PATHNAME` unquoted into ten `find`/`sed` shell commands. Added `mustBeFolder` validation (defeats metacharacter injection — an injected command string is not a real directory), a double-quote rejection, and quoting. |
| M2 | Security — secrets | `ee783d6`, `5210c69` | The AES secrets backend wrote `NDI_Cloud_Secrets.json` (encrypted passwords) and `NDI_Cloud_Profiles.json` (emails/UIDs) with default umask perms (world-readable on POSIX). Added a `restrictToOwner` helper (chmod 600 via `java.nio`, consistent with the file's existing Java crypto) that **verifies** the result and **warns** on failure instead of swallowing it. |
| M2 | Security — eval | `a030c83` | Removed `eval()` of property/name strings (code-injection vectors) from `ndi.document` (constructor + `setproperties`), `ndi.element` (the `element.direct` flag), `ndi.validate`, and `ndi.calculator`. Replaced with two safe helpers — `ndi.document.assignPropertyPath` (validates each dotted segment with `isvarname`, assigns via `subsasgn`) and `ndi.fun.getfieldpath` (same validation, reads via `getfield`). Behaviour is preserved for every legitimate dotted field path; only never-valid (injection) inputs now raise. |
| M3 | Java validator | `6ccd7fc` | `pom.xml` moved off the jitpack `com.github.everit-org.json-schema` coordinate to the Maven Central `com.github.erosb:everit-json-schema` republish (same `org.everit.json.schema.*` namespace), pinned a GA JUnit + a `jackson-bom` import, and added `maven-shade-plugin` with `finalName=ndi-validator-java`. Added a `build-validator-jar.yml` CI job that builds + tests the JAR. |
| M4 | Perf | `f85caf9`, `5210c69` | `ndi.document.readblankdefinition` re-read + `jsondecode`'d a class definition from disk on every document creation, recursing per superclass. Memoized in a persistent `containers.Map` keyed on the location string (the function is a pure function of it; structs are copy-on-write so callers can't corrupt the cache). `'--clear-cache'` resets it. The DID-path-constants init runs before the cache lookup so a cache hit cannot skip it. |
| M4 | CI hygiene | `6be5761` | SHA-pinned every GitHub Action across the 6 workflows (with `# vN` comments so Dependabot can still bump) — several run with live cloud credentials. Removed the dead `push` trigger on the nonexistent `add-cloud-api-testing` branch. |
| M5 | Dead code | `0ca82af` | Removed superseded files with zero inbound references (`authenticateOriginal.m`, `loginOriginal.m`, `logoutOriginal.m`, the `+upload/for_deletion/` directory). **Kept** the `+setup/+daq/+system/deprecating/` directory despite its name — those lab-setup functions are still actively referenced. |
| M6a | Symmetry CI | `f64c737` | Added the missing `tests/+ndi/+symmetry/requirements.txt`. The cross-language symmetry workflow (driven from NDI-python) runs `matbox.installRequirements(fullfile(pwd,'tests','+ndi','+symmetry'))`, which reads `requirements.txt` from that exact directory; with no file there, Stage 1 died before any symmetry test ran. This is the actual unblock for the long-red symmetry CI (the NDI-matlab repo's *own* `test-symmetry.yml` is a different workflow that points at `tests/`). |
| M6b | Symmetry — time | `1077381` | Added the `+time` namespace symmetry artifacts (`scenario`, `scenarioReferent`, and `+makeArtifacts/+time/timeConvert` + `+readArtifacts/+time/timeConvert`) mirroring the NDI-python `tests/symmetry/{make,read}_artifacts/time/` + `_time_scenario.py`, for full cross-language closure of the syncgraph `time_convert` contract (audit item 28). **Skip-safe by design:** makeArtifacts writes the artifact only if every case converts cleanly, otherwise it marks itself *Incomplete* (an assumption failure, not a test failure) — so an unvalidated time port cannot regress the green that M6a achieves. |
| — | Pre-existing bug | `5210c69` | `ndi.time.clocktype/ne` declared its second parameter `ndi_cock_obj_b` while the body used `ndi_clocktype_obj_b`, so `~=` on clocktypes errored on an undefined variable for every call. Fixed the name and compare via `strcmp` (the inverse of `eq`). Surfaced by the adversarial review below. |

## Verification (this branch)

An adversarial-review workflow (multiple independent reviewers → an adversarial
verification pass) examined the diff for MATLAB syntax errors, semantic regressions, and
parity correctness. It produced **three** confirmed real findings, all fixed in `5210c69`:
the memoization init ordering, the secrets-permission verification, and the pre-existing
`clocktype.ne` typo. Two findings claimed as "critical" against `assignPropertyPath` were
checked and **rejected** with proof: `struct('type',{'.','.'},'subs',{a,b})` does build a
1×N substruct array, and `subsasgn` does auto-create intermediate structs (it is the
functional form of `s.a.b = v`).

## Flagged — deliberately not done (needs coordination / a runtime I don't have)

- **JWT off environment variables.** The cloud client passes the token between functions
  via `NDI_CLOUD_TOKEN`/`NDI_CLOUD_*` env vars. Removing that is a behavioural change that
  must be coordinated with the NDI-python side (which deferred the same change "for parity
  with MATLAB"). Not changed unilaterally.
- **`requirements.txt` SHA-pinning.** The NDI-python side pins its git deps to commit SHAs
  because pip git-URLs accept SHA refs. Whether `matbox.installRequirements` resolves a
  `@<sha>` ref (vs `git clone -b`, which rejects SHAs) is unverifiable here — needs MATLAB
  + matbox to confirm before pinning, so as not to break installs.
- **GenBank vocabulary dedup / git-LFS.** The 29 MB uncompressed `GenBankControlledVocabulary.tsv`
  is referenced by `ValidatorTest.java:100`, and the two identical 5.3 MB `.tsv.gz` serve
  distinct consumers (the Java validator vs MATLAB `ndi_common`). Deduping + an LFS migration
  should be done together and validated against a real build.
- **Bulk error-identifier rewrite.** ~94 `error()` calls use bare strings (no
  `ndi:<area>:<reason>` id). High-churn and opportunistic; left for a focused pass.

## ⚠️ Rebuild the validator JAR

`M3` updates `pom.xml` + adds CI, but the **committed** `src/ndi/java/ndi-validator-java/jar/ndi-validator-java.jar`
still embeds the old jitpack everit until someone rebuilds it (`mvn -f .../source-code/pom.xml package`,
or via the new `build-validator-jar.yml`) and re-commits the artifact. The pom change alone
does not harden the runtime.
