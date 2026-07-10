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
%
% See also: did2.convert.v1_to_v2, did2.convert.migrators_j,
%           did2.validate.references, did2.database.sqlitedb.
