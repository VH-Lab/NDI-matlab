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
%                        - V_eta SIGNED stimulus model: N deduped standalone
%                          `visual_grating` docs + ONE
%                          `timed_sequence_manipulation` carrying the v1
%                          presentation id and a playlist that indexes them.
%                          *** NOT WIRED INTO ANY PASS, DELIBERATELY. *** It
%                          would claim the same preserved base.id as
%                          stimulusPresentationToManipulation (which still
%                          runs, and which the 2026-08-17 signature forbids
%                          retiring first), and `visual_grating` is still
%                          declared abstract so its documents cannot be
%                          instantiated. Both are open team questions; the
%                          file's own header states them. Do not re-derive
%                          this emitter -- it exists, with tests.
%
% NOTE the list above is a HAND-WRITTEN NARRATIVE and is NOT a census of
% +internal/. Measured 2026-08-17: 19 .m files in
% src/ndi/+ndi/+migrate/+internal/, of which 6 are named anywhere above
% (bodyResolver, pathSPromotion, softwareDedup, stimulusBathToBath,
% stimulusPresentationToManipulation, stimulusPresentationToTimedSequence) and
% 13 are not. An absence here has never meant a helper does not exist. To ask
% what helpers exist, list the folder.
%
% See also: did2.convert.v1_to_v2, did2.convert.migrators_j,
%           did2.validate.references, did2.database.sqlitedb.
