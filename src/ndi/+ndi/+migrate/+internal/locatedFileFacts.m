function [structs, report] = locatedFileFacts(structs)
%LOCATEDFILEFACTS Size and MD5 for the data bodies recorded by location whose file is on this computer.
%
%   [STRUCTS, REPORT] = ndi.migrate.internal.locatedFileFacts(STRUCTS) takes
%   migrated document bodies (structs) and, for every `opaque_body` whose ONE
%   member `body_data_0` is recorded BY LOCATION (location_type 'file',
%   ingest 0) at a path that exists here, fills `size_bytes`, `content_hash`
%   and `hash_algorithm` 'MD5' -- what ndi.setup.V2.recordingDocuments records
%   for a native recording file. REPORT.changed_ids names the bodies it changed.
%
%   Decided by Jess Haley, 2026-10-21 (did-schema
%   V_eta_recording_observation_plan.md): an opaque_body per epoch file by
%   location; a file named but absent is still recorded by location. The DID
%   batch pass that writes those bodies (did2.convert.resolveEpochProbemap)
%   reads documents only, so it omits size and checksum; this is the half that
%   needs the disk. An absent file is COUNTED (`files_absent`) and left as it
%   is, never an error.

arguments
    structs cell
end

report = struct('bodies_by_location', 0, 'files_present', 0, 'files_absent', 0, ...
    'multi_member_skipped', 0, 'already_described', 0, 'changed_ids', {{}});
for k = 1:numel(structs)
    b = structs{k};
    if ~isstruct(b) || ~isfield(b, 'document_class') ...
            || ~strcmp(char(b.document_class.class_name), 'opaque_body') ...
            || ~isfield(b, 'files') || ~isfield(b.files, 'file_info') ...
            || isempty(b.files.file_info)
        continue;
    end
    fi = b.files.file_info;
    if iscell(fi); fi = [fi{:}]; end
    loc = fi(1).locations;
    if ~isstruct(loc) || ~isscalar(loc) || ~isfield(loc, 'location_type') ...
            || ~strcmp(char(loc.location_type), 'file') || logical(loc.ingest)
        continue;
    end
    report.bodies_by_location = report.bodies_by_location + 1;
    if numel(fi) ~= 1
        report.multi_member_skipped = report.multi_member_skipped + 1;
        continue;
    end
    if isfield(b, 'data_body') && isfield(b.data_body, 'content_hash') ...
            && ~isempty(b.data_body.content_hash)
        report.already_described = report.already_described + 1;
        continue;
    end
    p = char(loc.location);
    if ~isfile(p)
        report.files_absent = report.files_absent + 1;
        continue;
    end
    info = dir(p);
    b.data_body.size_bytes = info.bytes;
    b.data_body.content_hash = ndi.fun.file.MD5(p);
    b.data_body.hash_algorithm = 'MD5';
    structs{k} = b;
    report.files_present = report.files_present + 1;
    report.changed_ids{end+1} = char(b.base.id);
end
end
