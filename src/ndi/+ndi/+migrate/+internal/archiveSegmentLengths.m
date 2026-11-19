function report = archiveSegmentLengths(docs, v1Bodies, ndiDir)
%ARCHIVESEGMENTLENGTHS Compare each v1 ingested archive's segment lengths with the ones its v2 bodies rebuild.
%
%   REPORT = ndi.migrate.internal.archiveSegmentLengths(DOCS, V1BODIES, NDIDIR)
%   reads the migrated documents DOCS (a cell of did2.document objects or
%   body structs, as the second pass leaves them) and the session's v1
%   bodies V1BODIES (structs or JSON text; only the v1
%   `daqreader_mfdaq_epochdata_ingested` documents are read), and, for every
%   v1 archive, rebuilds its two segment lengths from the v2 data bodies and
%   compares them with the v1 values. It writes nothing and changes nothing.
%
%   WHY. Decided by Jess Haley, 2026-11-12 [archive segment lengths measured
%   after the second pass] (did-schema did_v2_go_forward_class_audit.md):
%   "Lossless for these two fields is measured after NDI's second pass, not
%   at the DID stage; the DID-stage round trip names them as filled by the
%   second pass rather than lost." DID-matlab's whole-batch round trip
%   (did2.convert.roundtrip.wholeBatch, `deferred_to_second_pass`) lists
%   `daqreader_mfdaq_epochdata_ingested.parameters.sample_analog_segment` and
%   `.sample_digital_segment` as deferred; this is the second-pass half
%   ([whole-batch round trip], Build pending: NDI-matlab).
%
%   THE REBUILD. [segment length is the time chunk] (Jess Haley, 2026-10-29):
%   a segment length is the time dimension's `chunk` on the sampled_body
%   (`data.dimensions[k].chunk`, the dimension whose term is om:Time), as
%   ndi.migrate.internal.ingestedArchiveBodies writes it and
%   ndi.vintage.ingestedSegmentLength reads it. A body belongs to the v1
%   archive whose `files` hold the uid of one of its members (pass 1 and the
%   second pass keep the uids). The v1 ingest
%   (ndi.daq.reader.mfdaq/ingest_epochfiles) cuts:
%     ai, ao, ax, ti groups   at sample_analog_segment
%     di, do groups           at sample_digital_segment
%   so the rebuilt sample_analog_segment is the chunk of the archive's ai,
%   ao, ax and ti sampled bodies, and sample_digital_segment that of its di
%   and do bodies. Bodies of one kind that disagree, or a body of the kind
%   with no chunk, rebuild no single value: counted `differ`, with the reason.
%
%   NOT MEASURED is a third state, never equal and never differ. An archive
%   none of whose bodies is a sampled_body was not converted by the second
%   pass, and holds its segment lengths only in its (opaque) segment files:
%     bytes_absent   some file of the archive is neither at
%                    <NDIDIR>/files/<uid> nor at its recorded location (a
%                    document-only corpus: the corpus zips carry no binary
%                    files, NDI-matlab #785)
%     not_converted  the bytes are here, but the archive is still pass 1's
%                    opaque bodies (unconvertible or reverted; see
%                    REPORT.ingestedArchiveBodies of ndi.migrate.local)
%     no_v2_body     no v2 data body names any of the archive's files
%
%   REPORT (denominators first, unconditionally):
%     archives_inspected     v1 daqreader_mfdaq_epochdata_ingested documents
%                            read (THE denominator)
%     bodies_inspected       v2 sampled_body / opaque_body documents read
%     archives_measured      archives with at least one sampled_body
%     archives_not_measured  archives_inspected - archives_measured, split:
%     not_measured_bytes_absent, not_measured_not_converted,
%     not_measured_no_v2_body
%     state                  'measured' when archives_measured > 0, else
%                            'not measured'
%     analog, digital        per field, over the measured archives:
%       field                the v1 path
%       v1_stated            measured archives whose v1 document states a
%                            finite value
%       compared             of those, the ones the bodies rebuild a value
%                            for (a body of that kind is there)
%       equal, differ        of the compared
%       no_v2_home           v1_stated - compared: the v1 value is stated but
%                            the archive has no converted body of that kind
%                            (the v1 ingest writes both values for every
%                            archive, so an archive with no digital channel
%                            has a sample_digital_segment no body holds)
%       v2_without_v1        rebuilt where the v1 document states none
%     differences            struct array {archive_id, field, v1, v2, why},
%                            the first DIFFERENCE_CAP (20) differ entries in
%                            archive order (the counts are exact)
%     unreadable_documents   documents that could not be read as a struct
%
%   See also ndi.migrate.internal.ingestedArchiveBodies,
%            ndi.vintage.ingestedSegmentLength, ndi.migrate.local.

arguments
    docs cell
    v1Bodies cell
    ndiDir (1,:) char = ''
end

DIFFERENCE_CAP = 20;
fields = struct('analog', 'sample_analog_segment', 'digital', 'sample_digital_segment');
report = struct( ...
    'archives_inspected',          0, ...
    'bodies_inspected',            0, ...
    'archives_measured',           0, ...
    'archives_not_measured',       0, ...
    'not_measured_bytes_absent',   0, ...
    'not_measured_not_converted',  0, ...
    'not_measured_no_v2_body',     0, ...
    'state',                       'not measured', ...
    'analog',                      fieldCounts(fields.analog), ...
    'digital',                     fieldCounts(fields.digital), ...
    'differences',                 struct('archive_id', {}, 'field', {}, 'v1', {}, ...
                                       'v2', {}, 'why', {}), ...
    'unreadable_documents',        0);

% ---- the v1 archives, and which archive each file uid belongs to -----------
[archives, uidToArchive] = v1Archives(v1Bodies);
report.archives_inspected = numel(archives);
if isempty(archives)
    return;
end

% ---- the v2 bodies, by archive --------------------------------------------
nA = numel(archives);
sampled = cell(1, nA);    % per archive: struct array {kind, chunk, has_chunk, filename}
opaque = zeros(1, nA);    % per archive: opaque bodies naming its files
for k = 1:numel(docs)
    d = docs{k};
    try
        cls = classOf(d);
        if ~any(strcmp(cls, {'sampled_body', 'opaque_body'})); continue; end
        if ~isstruct(d); d = d.toStruct(); end
    catch
        report.unreadable_documents = report.unreadable_documents + 1;
        continue;
    end
    report.bodies_inspected = report.bodies_inspected + 1;
    a = archiveOfBody(d, uidToArchive);
    if a == 0; continue; end
    if strcmp(cls, 'opaque_body')
        opaque(a) = opaque(a) + 1;
        continue;
    end
    fn = bodyFilename(d);
    kind = kindOf(fn);
    [chunk, has] = timeChunk(d);
    sampled{a} = [sampled{a}, struct('kind', kind, 'chunk', chunk, ...
        'has_chunk', has, 'filename', fn)];
end

% ---- compare ----------------------------------------------------------------
for a = 1:nA
    arch = archives{a};
    if isempty(sampled{a})
        report.archives_not_measured = report.archives_not_measured + 1;
        if opaque(a) == 0
            report.not_measured_no_v2_body = report.not_measured_no_v2_body + 1;
        elseif ~bytesHere(arch, ndiDir)
            report.not_measured_bytes_absent = report.not_measured_bytes_absent + 1;
        else
            report.not_measured_not_converted = report.not_measured_not_converted + 1;
        end
        continue;
    end
    report.archives_measured = report.archives_measured + 1;
    for which = {'analog', 'digital'}
        w = which{1};
        f = fields.(w);
        v1 = paramOf(arch, f);
        bodies = sampled{a}(strcmp({sampled{a}.kind}, w));
        c = report.(w);
        if isfinite(v1); c.v1_stated = c.v1_stated + 1; end
        if isempty(bodies)
            if isfinite(v1); c.no_v2_home = c.no_v2_home + 1; end
            report.(w) = c;
            continue;
        end
        [v2, why] = rebuilt(bodies);
        if ~isfinite(v1)
            c.v2_without_v1 = c.v2_without_v1 + 1;
            report.(w) = c;
            continue;
        end
        c.compared = c.compared + 1;
        if isempty(why) && v2 == v1
            c.equal = c.equal + 1;
        else
            c.differ = c.differ + 1;
            if isempty(why)
                why = sprintf('the bodies'' time chunk is %g, the v1 %s %g', v2, f, v1);
            end
            if numel(report.differences) < DIFFERENCE_CAP
                report.differences(end+1) = struct('archive_id', baseId(arch), ...
                    'field', ['daqreader_mfdaq_epochdata_ingested.parameters.' f], ...
                    'v1', v1, 'v2', v2, 'why', why);
            end
        end
        report.(w) = c;
    end
end
if report.archives_measured > 0
    report.state = 'measured';
end
end

% =====================================================================

function c = fieldCounts(f)
c = struct('field', ['daqreader_mfdaq_epochdata_ingested.parameters.' f], ...
    'v1_stated', 0, 'compared', 0, 'equal', 0, 'differ', 0, ...
    'no_v2_home', 0, 'v2_without_v1', 0);
end

function [v, why] = rebuilt(bodies)
% the one chunk every body of a kind states; NaN and the reason otherwise
v = NaN;
why = '';
noChunk = ~[bodies.has_chunk];
if any(noChunk)
    why = sprintf('the sampled_body %s has no time chunk', bodies(find(noChunk, 1)).filename);
    return;
end
u = unique([bodies.chunk]);
if ~isscalar(u)
    why = sprintf('the bodies'' time chunks disagree (%s)', ...
        strjoin(arrayfun(@(x) sprintf('%g', x), u, 'UniformOutput', false), ', '));
    return;
end
v = u;
end

function kind = kindOf(fn)
% which v1 segment length the v1 ingest cuts this series at
kind = '';
tok = regexp(fn, '^(ai|ao|ax|ti|di|do)_group\d+_seg\.nbf_#$', 'tokens', 'once');
if isempty(tok); return; end
switch tok{1}
    case {'ai', 'ao', 'ax', 'ti'}, kind = 'analog';
    case {'di', 'do'},             kind = 'digital';
end
end

function [chunk, has] = timeChunk(b)
% the chunk of the body's time dimension (term om:Time)
chunk = NaN;
has = false;
if ~isfield(b, 'data') || ~isstruct(b.data) || ~isfield(b.data, 'dimensions'); return; end
dims = b.data.dimensions;
if isstruct(dims); dims = num2cell(dims); end
if ~iscell(dims); return; end
for k = 1:numel(dims)
    dk = dims{k};
    if ~isstruct(dk) || ~isfield(dk, 'term') || ~isstruct(dk.term) ...
            || ~isfield(dk.term, 'node') || ~strcmp(char(dk.term.node), 'om:Time')
        continue;
    end
    if isfield(dk, 'chunk') && ~isempty(dk.chunk) && isnumeric(dk.chunk) ...
            && isfinite(double(dk.chunk(1)))
        chunk = double(dk.chunk(1));
        has = true;
    end
    return;
end
end

function [archives, uidToArchive] = v1Archives(v1Bodies)
% every v1 daqreader_mfdaq_epochdata_ingested (decoded), and file uid -> its index
archives = {};
uidToArchive = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(v1Bodies)
    b = v1Bodies{k};
    if ischar(b) || (isstring(b) && isscalar(b))
        if ~contains(b, 'daqreader_mfdaq_epochdata_ingested'); continue; end
        try
            b = jsondecode(char(b));
        catch
            continue;
        end
    end
    % as ndi.migrate.internal.ingestedArchiveBodies reads them
    if ~isstruct(b) || ~isscalar(b) || ~isfield(b, 'daqreader_mfdaq_epochdata_ingested')
        continue;
    end
    archives{end+1} = b; %#ok<AGROW>
    for u = fileUids(b)
        uidToArchive(u{1}) = numel(archives);
    end
end
end

function a = archiveOfBody(b, uidToArchive)
a = 0;
for u = fileUids(b)
    if isKey(uidToArchive, u{1})
        a = uidToArchive(u{1});
        return;
    end
end
end

function uids = fileUids(b)
uids = {};
if ~isfield(b, 'files') || ~isstruct(b.files) || ~isfield(b.files, 'file_info'); return; end
infos = b.files.file_info;
if isstruct(infos); infos = num2cell(infos); end
for i = 1:numel(infos)
    if ~isstruct(infos{i}) || ~isfield(infos{i}, 'locations'); continue; end
    locs = infos{i}.locations;
    if isstruct(locs); locs = num2cell(locs); end
    for j = 1:numel(locs)
        if isstruct(locs{j}) && isfield(locs{j}, 'uid') && ~isempty(locs{j}.uid)
            uids{end+1} = char(locs{j}.uid); %#ok<AGROW>
        end
    end
end
end

function tf = bytesHere(arch, ndiDir)
% every file of the v1 archive is here: at <NDIDIR>/files/<uid>, or at its
% recorded location when that is a local file (as
% ndi.migrate.internal.ingestedArchiveBodies looks)
tf = false;
if ~isfield(arch, 'files') || ~isstruct(arch.files) || ~isfield(arch.files, 'file_info')
    return;
end
infos = arch.files.file_info;
if isstruct(infos); infos = num2cell(infos); end
if isempty(infos); return; end
for i = 1:numel(infos)
    if ~isstruct(infos{i}) || ~isfield(infos{i}, 'locations'); return; end
    locs = infos{i}.locations;
    if isstruct(locs); locs = num2cell(locs); end
    found = false;
    for j = 1:numel(locs)
        L = locs{j};
        if ~isstruct(L); continue; end
        if ~isempty(ndiDir) && isfield(L, 'uid') && ~isempty(L.uid) ...
                && isfile(fullfile(ndiDir, 'files', char(L.uid)))
            found = true;
            break;
        end
        if isfield(L, 'location') && ~isempty(L.location) && isfile(char(L.location))
            found = true;
            break;
        end
    end
    if ~found; return; end
end
tf = true;
end

function v = paramOf(arch, name)
v = NaN;
try
    p = arch.daqreader_mfdaq_epochdata_ingested.parameters;
    if isfield(p, name) && ~isempty(p.(name)) && isnumeric(p.(name))
        v = double(p.(name)(1));
    end
catch
end
end

function c = classOf(d)
c = '';
if isstruct(d)
    if isfield(d, 'document_class') && isstruct(d.document_class) ...
            && isfield(d.document_class, 'class_name')
        c = char(d.document_class.class_name);
    end
else
    c = char(d.className());
end
end

function fn = bodyFilename(b)
fn = '';
if isfield(b, 'data_body') && isstruct(b.data_body) && isfield(b.data_body, 'filename')
    fn = char(b.data_body.filename);
end
end

function id = baseId(b)
id = '';
if isstruct(b) && isfield(b, 'base') && isstruct(b.base) && isfield(b.base, 'id')
    id = char(b.base.id);
end
end
