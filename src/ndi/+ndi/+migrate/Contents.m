% +migrate  Tools for migrating NDI datasets/sessions to a V2 wire format.
%
%   The +migrate subpackage holds user-facing commands that move an
%   existing NDI dataset or session from the legacy did_v1 storage
%   shape to a chosen target wire format (V_delta by default; V_epsilon,
%   V_zeta, or V_eta via TargetVersion). Each command produces a summary
%   struct the caller can inspect; nothing aborts the whole run on a
%   single bad document (see did2.convert.v1_to_v2's quarantine
%   convention). For split targets the command also runs a second pass
%   over the whole migrated body set: V_epsilon/V_zeta resolve
%   session-context deferrals (e.g. stimulus_bath -> bath); V_eta
%   promotes attributed anatomical loci to Path-S part-subjects.
%
% Files:
%   local   - migrate a local on-disk dataset/session.
%   cloud   - migrate a cloud-hosted dataset (uses the cloud write-lock
%             to quiesce other writers and the existing
%             list/bulk-fetch/bulk-upload endpoints).
%
%   +internal/  second-pass and I/O helpers (not user-facing):
%     bodyResolver       - session/element graph over the whole body set.
%     stimulusBathToBath - V_epsilon/V_zeta stimulus_bath assembler.
%     pathSPromotion     - V_eta attributed-locus -> Path-S promotion.
%     softwareDedup      - V_eta `software` merge on (session, name, version),
%                          retargeting inbound edges BY TARGET ID (one of the
%                          seven edges that must_refer to `software` is called
%                          `reader_id`, not `software_id`). Pass 1 mints one
%                          entity per consuming document because a
%                          single-document migrator cannot see the batch; this
%                          is the "deduplicated by name+version" half of the
%                          signed R1 model. Runs LAST of the V_eta sub-passes.
%     stimulusPresentationToTimedSequence
%                        - V_eta SIGNED stimulus model, and the pass that runs
%                          on stimulus_presentation since 2026-08-17: N
%                          deduped standalone `visual_grating` docs + ONE
%                          `timed_sequence_manipulation` carrying the v1
%                          presentation id and a playlist that indexes them.
%                          The two blockers this entry used to record are both
%                          cleared -- `visual_grating` stopped being abstract
%                          (team, 2026-08-17), and the id collision is gone
%                          because the two emitters are now mutually exclusive
%                          by definition.
%     hartleyBasisGratings
%                        - the half of the Hartley decomposition the
%                          presentation does not contain. Ten of the eleven
%                          20211116 presentations are a GENERATOR RECIPE (M,
%                          K_absmax, L_absmax, sfmax, fps, randState) that
%                          enumerates nothing; the basis they play is in the
%                          `hartley_calc` documents that reference them
%                          (`hartley_reverse_correlation.hartley_numbers`,
%                          3360 entries, ONE distinct value across all 210),
%                          with a `frameTimes` of the same length. Mints the
%                          basis ONCE per session and hands the playlist +
%                          frame times to the assembler above.
%     stimulusPresentationToManipulation
%                        - the FLATTENING emitter, GATED OFF. RETAINED by the
%                          2026-08-17 signature for the presentation-less
%                          single-grating case -- "not a rival model to
%                          retire, the degenerate one" -- and that case has NO
%                          v1 source, so this emitter has no caller and no
%                          reachable input. It is not retired; do not delete
%                          it, and do not re-wire it without reading the
%                          signature: both emitters preserve the presentation
%                          id, and `documents(id TEXT PRIMARY KEY)` cannot
%                          hold two claimants.
%
% NOTE the list above is a HAND-WRITTEN NARRATIVE and is NOT a census of
% +internal/. Measured 2026-08-17: 20 .m files in
% src/ndi/+ndi/+migrate/+internal/, of which 7 are named anywhere above
% (bodyResolver, hartleyBasisGratings, pathSPromotion, softwareDedup,
% stimulusBathToBath, stimulusPresentationToManipulation,
% stimulusPresentationToTimedSequence) and 13 are not. An absence here has
% never meant a helper does not exist. To ask what helpers exist, list the
% folder.
%
% See also: did2.convert.v1_to_v2, did2.convert.migrators_j,
%           did2.validate.references, did2.database.sqlitedb.
