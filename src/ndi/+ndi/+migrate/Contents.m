% +migrate  Tools for migrating NDI datasets/sessions to a V2 wire format.
%
%   The +migrate subpackage holds user-facing commands that move an
%   existing NDI dataset or session from the legacy did_v1 storage
%   shape to the V_eta wire format, the only target. Each command produces
%   a summary
%   struct the caller can inspect; nothing aborts the whole run on a
%   single bad document (see did2.convert.v1_to_v2's quarantine
%   convention). For V_eta the command also runs a second pass
%   over the whole migrated body set: it resolves session-context
%   deferrals (e.g. stimulus_bath -> dose_manipulation) and promotes
%   attributed anatomical loci to Path-S part-subjects.
%
% Files:
%   local   - migrate a local on-disk dataset/session.
%   cloud   - pass 1 over a cloud-hosted dataset, as a DryRun report only:
%             it refuses to upload (NDI:migrate:cloudIncomplete) until it
%             runs the full pipeline ndi.migrate.local runs.
%
%   +internal/  second-pass and I/O helpers (not user-facing):
%     bodyResolver       - session/element graph over the whole body set.
%     withSessionId      - a minted body's session id as the schema in use keeps
%                          it: the base.session_id field, or a `session_id`
%                          edge (did-schema V_eta_relation_inheritance_plan.md).
%     stimulusBathToBath - stimulus_bath assembler (V_eta: dose_manipulation).
%     pathSPromotion     - V_eta region parts: a statement about a region targets its part entity.
%     softwareDedup      - V_eta `software` merge on (session, name, version),
%                          retargeting inbound edges BY TARGET ID (one of the
%                          seven edges that must_refer to `software` is called
%                          `reader_id`, not `software_id`). Pass 1 mints one
%                          entity per consuming document because a
%                          single-document migrator cannot see the batch; this
%                          is the "deduplicated by name+version" half of the
%                          signed R1 model. Runs right after pass 1 and
%                          again LAST of the V_eta sub-passes ([software
%                          dedup after pass one], Jess Haley 2026-10-22).
%     v1AttachedFile     - where a v1 document's attached file is on this
%                          computer (<.ndi>/files/<uid>, else the recorded
%                          location); the stimulus fold reads
%                          presentation_time.bin through it.
%     dimensionTermCensus
%                        - counts the dimensions written whose term has no
%                          node, against the dimensions written ([covariate
%                          details] 5.4, Jess Haley 2026-10-22).
%     stimulusPresentationToItem
%                        - the stimulus fold in the did-schema #88 shape
%                          (V_eta_method_plan.md, TEAM-SIGN-OFF [method]
%                          2026-10-21): one standalone `method` document per
%                          distinct stimulus (stimulusRecipe + stimulusMethod;
%                          every recognised NewStim kind -- grating, blank,
%                          uniform field / bars, dense noise, sparse noise,
%                          shape movie -- per [non-grating stimuli as methods],
%                          Jess Haley 2026-10-21)
%                          + ONE `manipulation` (value kind `item`) carrying the v1
%                          presentation id and a 0-based playlist into them.
%                          Several animals: one manipulation of the session's
%                          cohort, `distributive` (sessionCohort).
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
%                          frame times to the assembler above. The generator
%                          keys the basis does not read are the presentation
%                          manipulation's inline method parameters
%                          ([Hartley settings on the inline method], Jess
%                          Haley 2026-10-30; recipeParameterList).
%     (stimulusPresentationToManipulation, stimulusPresentationToTimedSequence
%      and gratingValueFromParameters were deleted 2026-10-21 with the
%      `visual_grating`, `visual_grating_manipulation` and `timed_sequence`
%      classes they wrote; did-schema #88 has none of them.)
%
% NOTE the list above is a HAND-WRITTEN NARRATIVE and is NOT a census of
% +internal/. (The 2026-08-17 count of 20 files, 7 named, is stale: three of
% the named files are deleted and several helpers were added since.) An absence here has
% never meant a helper does not exist. To ask what helpers exist, list the
% folder.
%
% See also: did2.convert.v1_to_v2, did2.convert.migrators_j,
%           did2.validate.references, did2.database.sqlitedb.
