function [bodies, consumed, report] = ingestedStimulusBodies(structs, presentations, v1Bodies)
%INGESTEDSTIMULUSBODIES A v1 daqmetadatareader_epochdata_ingested as an
%   `opaque_body` of its epoch's stimulus-presentation manipulation.
%
%   [BODIES, CONSUMED, REPORT] = ndi.migrate.internal.ingestedStimulusBodies( ...
%       STRUCTS, PRESENTATIONS, V1BODIES)
%
%   Decided by Jess Haley, 2026-10-26 [ingested stimulus file is a body of
%   the presentation] (did-schema V_eta_go_forward_class_audit.md): the v1
%   document is the stored copy of an epoch's stimulus file (NDI main
%   +daq/metadatareader.m ingest_epochfiles: the reader's metadata, written by
%   ndi.compress.compress_metadata as a gzip'd .nbf.tgz, attached as
%   `data.bin`, with the epoch id and a `daqmetadatareader_id` edge). It is the
%   raw source the presentation's playlist was decoded from, so it becomes an
%   `opaque_body` owned by that epoch's stimulus-presentation `manipulation`,
%   joined by SESSION and EPOCH ID. With no matching manipulation -- or more
%   than one -- it is left as it is (pass 1 carries it as v1).
%
%   STRUCTS        the migrated documents (did2.document/toStruct); the v1
%                  documents of this class are read from it (pass 1 passes
%                  them through)
%   PRESENTATIONS  struct array (session_id, epoch_id, id): the manipulations
%                  the stimulus pass built (a standalone item is not one)
%   V1BODIES       the v1 bodies, to name the metadata reader's class
%
%   Each body: base.id = THE V1 DOCUMENT'S id (inbound edges keep
%   resolving), owner_id = the manipulation, filename 'data.bin', format
%   EMPTY:0000367 "NDI binary format" and compression 'gzip' (Jess Haley,
%   2026-10-22 [NDI binary format]: the file is NDI's .nbf.tgz), the bytes
%   carried as attached -- the one member body_data_0 with data.bin's v1
%   locations verbatim, as DID-matlab resolveEpochProbemap's
%   mkMetadataArchiveBodies carries the same file (locations settled later
%   with every other migrated document's, by
%   ndi.migrate.internal.settleIngestedFiles) -- and a description naming
%   the epoch, the metadata reader (its id and NDI class) and the source
%   class, so the v1 document can be rebuilt ([lossless means round trip]).
%   The description opens with ndi.vintage.ingestedStimulusKey (epoch and
%   reader), which ndi.daq.metadatareader/get_ingested_document finds the
%   body by ([ingested stimulus reader finds the body], Jess Haley,
%   2026-10-26).
%   CONSUMED lists the v1 ids converted; the caller drops those documents.

arguments
    structs cell
    presentations struct
    v1Bodies cell = {}
end

bodies = {};
consumed = {};
report = struct( ...
    'documents_inspected',       numel(structs), ...
    'ingested_seen',             0, ...
    'converted',                 0, ...
    'left_no_presentation',      0, ...
    'left_several_presentations', 0, ...
    'left_unplaced',             0, ...
    'left_reasons',              {{}});

byKey = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(presentations)
    key = joinKey(presentations(k).session_id, presentations(k).epoch_id);
    if isempty(key); continue; end
    held = {};
    if isKey(byKey, key); held = byKey(key); end
    held{end+1} = char(presentations(k).id); %#ok<AGROW>
    byKey(key) = held;
end
readerClass = containers.Map('KeyType', 'char', 'ValueType', 'char');
for k = 1:numel(v1Bodies)
    b = v1Bodies{k};
    if ~isstruct(b) || ~isfield(b, 'daqmetadatareader') || ~isstruct(b.daqmetadatareader) ...
            || ~isfield(b.daqmetadatareader, 'ndi_daqmetadatareader_class') ...
            || ~isfield(b, 'base') || ~isfield(b.base, 'id')
        continue;
    end
    readerClass(char(b.base.id)) = char(b.daqmetadatareader.ndi_daqmetadatareader_class);
end

for k = 1:numel(structs)
    s = structs{k};
    if ~strcmp(ndi.migrate.internal.etaShape.className(s), ...
            'daqmetadatareader_epochdata_ingested')
        continue;
    end
    report.ingested_seen = report.ingested_seen + 1;
    id = baseField(s, 'id');
    sid = char(ndi.v2.sessionIdOf(s));
    epochId = '';
    if isfield(s, 'epochid') && isstruct(s.epochid) && isfield(s.epochid, 'epochid')
        epochId = char(s.epochid.epochid);
    end
    why = unplaced(s, id, sid, epochId);
    if ~isempty(why)
        report = leave(report, 'left_unplaced', id, why);
        continue;
    end
    key = joinKey(sid, epochId);
    if ~isKey(byKey, key)
        report = leave(report, 'left_no_presentation', id, ...
            'no stimulus-presentation manipulation for its session and epoch');
        continue;
    end
    owners = unique(byKey(key));
    if numel(owners) > 1
        report = leave(report, 'left_several_presentations', id, sprintf( ...
            '%d stimulus-presentation manipulations share its session and epoch', ...
            numel(owners)));
        continue;
    end
    readerId = ndi.migrate.internal.etaShape.edge(s, 'daqmetadatareader_id');
    cls = '';
    if ~isempty(readerId) && isKey(readerClass, readerId)
        cls = readerClass(readerId);
    end
    % the opening names the epoch and the reader, and is what
    % ndi.daq.metadatareader finds the body by ([ingested stimulus reader
    % finds the body]): one function builds it for both
    desc = [ndi.vintage.ingestedStimulusKey(epochId, char(readerId)), classPart(cls), ...
        ' read from the epoch''s files, stored by NDI as a gzip''d .nbf.tgz ' ...
        '(ndi.compress.compress_metadata). Migrated from a v1 ' ...
        'daqmetadatareader_epochdata_ingested.'];
    ts = baseField(s, 'datestamp');
    args = {'Fields', struct('filename', 'data.bin'), 'Compression', 'gzip', ...
        'Description', desc, 'Id', id, 'SessionId', sid, 'Validate', false};
    if ~isempty(ts); args = [args, {'CreationTimestamp', ts}]; end %#ok<AGROW>
    restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
    body = did2.build.opaqueBody(owners(1), ...
        struct('node', 'EMPTY:0000367', 'name', 'NDI binary format'), args{:});
    clear restore
    body.files.file_info = struct('name', 'body_data_0', 'locations', {dataBinLocations(s)});
    bodies{end+1} = body; %#ok<AGROW>
    consumed{end+1} = id; %#ok<AGROW>
    report.converted = report.converted + 1;
end
end

function why = unplaced(s, id, sid, epochId)
%UNPLACED Why this document cannot be written whole as the body; '' if it can.
why = '';
if isempty(id) || isempty(sid)
    why = 'no base.id / session';
elseif isempty(epochId)
    why = 'no epoch id';
elseif ~isfield(s, 'files') || ~isstruct(s.files) || ~isfield(s.files, 'file_list') ...
        || ~isequal(cellstr(s.files.file_list), {'data.bin'}) ...
        || isempty(dataBinLocations(s))
    why = 'its files are not the one data.bin with a location';
else
    blk = struct();
    if isfield(s, 'daqmetadatareader_epochdata_ingested')
        blk = s.daqmetadatareader_epochdata_ingested;
    end
    if isstruct(blk) && ~isempty(fieldnames(blk))
        fn = fieldnames(blk);
        for k = 1:numel(fn)
            if ~isempty(blk.(fn{k}))
                why = ['a field the body does not write: ' fn{k}];
                return;
            end
        end
    end
    deps = {};
    if isfield(s, 'depends_on') && ~isempty(s.depends_on)
        deps = s.depends_on;
        if isstruct(deps); deps = num2cell(deps); end
    end
    for k = 1:numel(deps)
        d = deps{k};
        if ~isstruct(d) || ~isfield(d, 'name'); continue; end
        if any(strcmp(char(d.name), {'daqmetadatareader_id', 'session_id'})); continue; end
        v = ndi.migrate.internal.etaShape.entryValue(d);
        if ~isempty(v)
            why = ['an edge the body does not write: ' char(d.name)];
            return;
        end
    end
end
end

function loc = dataBinLocations(s)
% data.bin's v1 `locations`, verbatim; [] when there is none
loc = [];
if ~isfield(s.files, 'file_info'); return; end
infos = s.files.file_info;
if isstruct(infos); infos = num2cell(infos); end
if ~iscell(infos); return; end
for k = 1:numel(infos)
    fi = infos{k};
    if isstruct(fi) && isfield(fi, 'name') && strcmp(char(fi.name), 'data.bin') ...
            && isfield(fi, 'locations') && ~isempty(fi.locations)
        loc = fi.locations;
        return;
    end
end
end

function report = leave(report, bucket, id, why)
report.(bucket) = report.(bucket) + 1;
if numel(report.left_reasons) < 20
    report.left_reasons{end+1} = struct('id', id, 'reason', why);
end
end

function key = joinKey(sid, epochId)
key = '';
if isempty(sid) || isempty(epochId); return; end
key = [char(sid) '|' char(epochId)];
end

function t = classPart(cls)
t = '';
if ~isempty(cls); t = [' (' cls ')']; end
end

function v = baseField(s, name)
v = '';
if isfield(s, 'base') && isstruct(s.base) && isfield(s.base, name) && ~isempty(s.base.(name))
    v = char(s.base.(name));
end
end
