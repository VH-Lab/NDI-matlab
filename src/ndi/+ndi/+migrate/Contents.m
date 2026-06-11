% +migrate  Tools for migrating NDI datasets/sessions to V_epsilon on disk.
%
%   The +migrate subpackage holds user-facing commands that move an
%   existing NDI dataset or session from the legacy did_v1 storage
%   shape to the V_epsilon wire format. Each command produces a
%   summary struct the caller can inspect; nothing aborts the whole
%   run on a single bad document (see did2.convert.v1_to_v2's
%   quarantine convention).
%
% Files:
%   local   - migrate a local on-disk dataset/session to V_epsilon.
%   cloud   - migrate a cloud-hosted dataset to V_epsilon (uses the
%             cloud write-lock to quiesce other writers and the
%             existing list/bulk-fetch/bulk-upload endpoints).
%
% See also: did2.convert.v1_to_v2, did2.validate.references,
%           did2.database.sqlitedb, docs/v2/PLAN.md.
