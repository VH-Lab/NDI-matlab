function [structs, report, removed] = ingestedArchiveBodies(structs, ndiDir, v1Bodies)
%INGESTEDARCHIVEBODIES Turn each migrated v1 ingested mfdaq channel group into
%   one sampled_body whose channel list is covariates, when the bytes are on
%   this computer.
%
%   [STRUCTS, REPORT, REMOVED] = ndi.migrate.internal.ingestedArchiveBodies( ...
%       STRUCTS, NDIDIR, V1BODIES)
%   takes the migrated document bodies (structs, did2.document/toStruct) of
%   the session whose .ndi directory is NDIDIR, and the session's v1 bodies
%   V1BODIES (structs or JSON text; only the v1
%   `daqreader_mfdaq_epochdata_ingested` documents are read, for their
%   segment lengths and epoch start). It returns STRUCTS with every channel
%   group it could read REPLACED, id preserved, and REMOVED, the ids of the
%   bodies whose content is now carried elsewhere (the caller drops them).
%
%   Decided by Jess Haley, 2026-11-01 [ingested archives are sampled bodies]
%   (did-schema did_v2_go_forward_class_audit.md): "a v1 ingested channel
%   group (`ai/ao/ax/di/do/ti_group<g>_seg.nbf_<s>`) becomes one
%   `sampled_body` per group, the same shape NDI V2's ingest writes ([V2
%   ingest is one sampled body per channel group]); its channel list (channel
%   numbers, offset, scale; the sample rate as the time axis's spacing) is
%   covariates on that body, not the `channel_list.bin` file." Pass 1
%   (did2.convert.resolveEpochProbemap, "One opaque_body per attached
%   series") carries each series as an opaque_body; this second-pass step,
%   which can read NDI's files, converts them:
%
%     opaque_body  `<p>_group<g>_seg.nbf_#`, p in ai ao ax di do, members
%                  body_data_0..N-1 = v1 segments 1..N
%       ->  sampled_body
%             dimensions  0  time     (om:Time), n = the samples in the
%                                     group, chunk = the v1 segment length
%                                     (the archive's sample_analog_segment
%                                     or sample_digital_segment; [segment
%                                     length is the time chunk])
%                         1  channel  (NCIT:C44170), n = the group's channels
%             covariates  time along 0: origin 0, spacing 1/sample rate,
%                         second ([evenly spaced time is a covariate]; v1
%                         reads sample s at t0 + (s-1)/rate, so origin 0 is
%                         the epoch's start: [clock only on the time
%                         reference], no clock on the body)
%                         channel number along 1: count (v1 `number`)
%                         offset along 1: quantity (v1 `offset`)
%                         scale along 1: quantity (v1 `scale`)
%             conditions  Channel (NCIT:C44170) = the group's channel type
%                         term ([channel types]; ndi.vintage.channelTypes)
%             datum_order 'F' (time fastest, as NDI's compressors take a
%                         samples-by-channels array)
%             format, compression, filename, files: unchanged
%
%     The time group `ti_group<g>_seg.nbf_#`: when every time sample is
%     t0 + (k-1)/rate (to a millionth of a sample), it adds nothing the
%     groups' time covariate does not say ([evenly spaced time is a
%     covariate]: "stores no body for it") and its body is REMOVED. When it is
%     not evenly spaced the whole archive is LEFT as pass 1 wrote it, counted
%     `time_not_evenly_spaced`: the decided shape (a sampled_body of its own,
%     owned by a time observation, the groups' time a `key` to it) needs a
%     time observation whose entity and variable are not decided.
%
%     `channel_list.bin` is REMOVED only when every one of its rows is
%     carried by a converted body: a row of a converted channel group, named
%     by its v1 abbreviation and number (`ai3`), with no time channel. A row
%     of another kind (a time channel, an event, marker or text channel) or a
%     time-channel link has no home on a sampled body yet, so the file is
%     KEPT as the opaque_body pass 1 wrote, and nothing is lost (counted
%     `channel_list_kept`).
%
%     `evmktx_group<g>_seg.nbf_#` (events) stays the opaque_body it is.
%
%   NOT HERE YET. The `compression` block ([ingested compression settings]:
%   NDI's compressor as the term, the stored integer format and bit size as
%   parameters) waits on did-schema declaring `data_body.compression` as a
%   {term, parameters} block; until then the body keeps pass 1's
%   `compression`. The data file names stay as pass 1 wrote them.
%
%   WHERE THE BYTES ARE, as ndi.migrate.internal.epochSeriesBodies looks:
%   <NDIDIR>/files/<uid>, then the recorded location when it is a local
%   file. Every member of every series the archive converts must be here;
%   otherwise the archive is left (`bytes_not_here`). A document-only corpus
%   has no bytes: nothing changes.
%
%   REPORT.changed_groups lists, per archive converted, the ids of every
%   body replaced or removed for it; the caller re-validates each group and
%   reverts a group that does not come back clean.
%
%   See also did2.convert.resolveEpochProbemap,
%            ndi.migrate.internal.epochSeriesBodies,
%            ndi.file.type.mfdaq_epoch_channel, ndi.daq.reader.mfdaq.

arguments
    structs cell
    ndiDir (1,:) char
    v1Bodies cell = {}
end

report = struct( ...
    'documents_inspected',        numel(structs), ...
    'archives_seen',              0, ...
    'archives_converted',         0, ...
    'group_bodies_seen',          0, ...
    'group_bodies_described',     0, ...
    'time_bodies_removed',        0, ...
    'channel_list_removed',       0, ...
    'channel_list_kept',          0, ...
    'event_bodies_left',          0, ...
    'bytes_not_here',             0, ...
    'channel_list_missing',       0, ...
    'channel_list_unreadable',    0, ...
    'v1_archive_not_found',       0, ...
    'time_not_evenly_spaced',     0, ...
    'unconvertible',              0, ...
    'first_unconvertible_reason', '', ...
    'changed_groups',             {{}}, ...
    'changed_ids',                {{}});
removed = {};
storeDir = fullfile(ndiDir, 'files');

% ---- the pass-1 archive bodies, grouped by archive (same owners, session
% and epoch note) ---------------------------------------------------------
groupKeys = {};
groupMembers = {};
for k = 1:numel(structs)
    b = structs{k};
    if ~strcmp(className(b), 'opaque_body'); continue; end
    fn = bodyFilename(b);
    if isempty(seriesKind(fn)); continue; end
    key = archiveKeyOf(b);
    i = find(strcmp(groupKeys, key), 1);
    if isempty(i)
        groupKeys{end+1} = key; %#ok<AGROW>
        groupMembers{end+1} = k; %#ok<AGROW>
    else
        groupMembers{i}(end+1) = k;
    end
end
if isempty(groupKeys); return; end

archives = [];   % decoded lazily: only when some archive has its bytes here

for a = 1:numel(groupKeys)
    idx = groupMembers{a};
    kinds = cellfun(@(k) seriesKind(bodyFilename(structs{k})), num2cell(idx), ...
        'UniformOutput', false);
    if ~any(ismember(kinds, {'group', 'time'})); continue; end
    report.archives_seen = report.archives_seen + 1;
    report.group_bodies_seen = report.group_bodies_seen + sum(strcmp(kinds, 'group'));
    report.event_bodies_left = report.event_bodies_left + sum(strcmp(kinds, 'event'));

    clIdx = idx(strcmp(kinds, 'channel_list'));
    if numel(clIdx) ~= 1
        report.channel_list_missing = report.channel_list_missing + 1;
        continue;
    end
    clPath = memberPaths(structs{clIdx}, storeDir);
    if isempty(clPath)
        report.bytes_not_here = report.bytes_not_here + 1;
        continue;
    end
    try
        ci = ndi.file.type.mfdaq_epoch_channel(clPath{1}).channel_information;
    catch
        report.channel_list_unreadable = report.channel_list_unreadable + 1;
        continue;
    end

    if isempty(archives)
        archives = v1ArchivesByUid(v1Bodies);
    end
    arch = archiveOf(structs(idx), archives);
    if isempty(arch)
        report.v1_archive_not_found = report.v1_archive_not_found + 1;
        continue;
    end

    try
        [made, gone, why] = convertArchive(structs, idx, kinds, clIdx, ci, arch, storeDir);
    catch err
        made = {}; gone = {};
        why = sprintf('%s: %s', err.identifier, err.message);
    end
    if strcmp(why, 'bytes_not_here')
        report.bytes_not_here = report.bytes_not_here + 1;
        continue;
    elseif strcmp(why, 'time_not_evenly_spaced')
        report.time_not_evenly_spaced = report.time_not_evenly_spaced + 1;
        continue;
    elseif ~isempty(why)
        report.unconvertible = report.unconvertible + 1;
        if isempty(report.first_unconvertible_reason)
            report.first_unconvertible_reason = why;
        end
        continue;
    end

    ids = {};
    for m = 1:numel(made)
        structs{made{m}.k} = made{m}.body;
        ids{end+1} = baseId(made{m}.body); %#ok<AGROW>
    end
    for g = 1:numel(gone)
        ids{end+1} = gone{g}; %#ok<AGROW>
        removed{end+1} = gone{g}; %#ok<AGROW>
        if strcmp(gone{g}, baseId(structs{clIdx}))
            report.channel_list_removed = report.channel_list_removed + 1;
        else
            report.time_bodies_removed = report.time_bodies_removed + 1;
        end
    end
    if ~any(strcmp(gone, baseId(structs{clIdx})))
        report.channel_list_kept = report.channel_list_kept + 1;
    end
    report.archives_converted = report.archives_converted + 1;
    report.group_bodies_described = report.group_bodies_described + numel(made);
    report.changed_groups{end+1} = ids;
    report.changed_ids = [report.changed_ids, ids];
end
end

% =====================================================================

function [made, gone, why] = convertArchive(structs, idx, kinds, clIdx, ci, arch, storeDir)
%CONVERTARCHIVE The sampled bodies of one archive, or why it is left.
made = {};
gone = {};
why = '';
[types, abbrev] = ndi.daq.reader.mfdaq.channel_types();
ciType = cellfun(@char, {ci.type}, 'UniformOutput', false);
ciGroup = double([ci.group]);
params = struct();
if isfield(arch, 'daqreader_mfdaq_epochdata_ingested') ...
        && isfield(arch.daqreader_mfdaq_epochdata_ingested, 'parameters')
    params = arch.daqreader_mfdaq_epochdata_ingested.parameters;
end
t0 = epochStart(arch);
carriedRows = false(1, numel(ci));

% the time groups first: each must be evenly spaced from the epoch's start
for j = 1:numel(idx)
    if ~strcmp(kinds{j}, 'time'); continue; end
    b = structs{idx(j)};
    [~, g] = prefixAndGroup(bodyFilename(b));
    rows = find(strcmp(ciType, 'time') & ciGroup == g);
    if isempty(rows); why = sprintf('no channel_list row for %s', bodyFilename(b)); return; end
    paths = memberPaths(b, storeDir);
    if isempty(paths); why = 'bytes_not_here'; return; end
    if ~isfinite(t0); why = 'the v1 archive names no epoch start (t0_t1)'; return; end
    t = [];
    for m = 1:numel(paths)
        t = [t; expandSegment(paths{m}, 'time')]; %#ok<AGROW>
    end
    if size(t, 2) ~= numel(rows)
        why = sprintf('%s holds %d column(s), the channel list %d', ...
            bodyFilename(b), size(t, 2), numel(rows));
        return;
    end
    for r = 1:numel(rows)
        sr = double(ci(rows(r)).sample_rate);
        if ~(isfinite(sr) && sr > 0); why = 'time_not_evenly_spaced'; return; end
        ideal = t0 + (0:size(t, 1)-1)' / sr;
        if any(abs(double(t(:, r)) - ideal) > max(1e-9, 1e-6 / sr))
            why = 'time_not_evenly_spaced';
            return;
        end
    end
    gone{end+1} = baseId(b); %#ok<AGROW>
end

for j = 1:numel(idx)
    if ~strcmp(kinds{j}, 'group'); continue; end
    k = idx(j);
    b = structs{k};
    fn = bodyFilename(b);
    [prefix, g] = prefixAndGroup(fn);
    switch prefix
        case 'ai', want = {'analog_in'};
        case 'ao', want = {'analog_out'};
        case 'ax', want = {'auxiliary_in'};
        case 'di', want = {'digital_in', 'digital_out'};  % v1 mfdaq writes digital_out as di
        case 'do', want = {'digital_out'};
    end
    rows = find(ismember(ciType, want) & ciGroup == g);
    if isempty(rows); why = sprintf('no channel_list row for %s', fn); return; end
    if numel(unique(ciType(rows))) ~= 1
        why = sprintf('%s mixes channel types %s', fn, strjoin(unique(ciType(rows)), ', '));
        return;
    end
    type = ciType{rows(1)};
    sr = unique(double([ci(rows).sample_rate]));
    if ~isscalar(sr) || ~isfinite(sr) || sr <= 0
        why = sprintf('%s has no single sample rate', fn);
        return;
    end
    dataclass = char(ci(rows(1)).dataclass);
    switch dataclass
        case 'ephys',   seg = paramOf(params, 'sample_analog_segment');
        case 'digital', seg = paramOf(params, 'sample_digital_segment');
        otherwise
            why = sprintf('%s has data class %s', fn, dataclass);
            return;
    end
    paths = memberPaths(b, storeDir);
    if isempty(paths); why = 'bytes_not_here'; return; end
    last = expandSegment(paths{end}, dataclass);
    if ~isfinite(seg)
        if isscalar(paths); seg = size(last, 1);
        else; seg = size(expandSegment(paths{1}, dataclass), 1); end
    end
    if size(last, 2) ~= numel(rows) || size(last, 1) > seg
        why = sprintf('%s: last segment %dx%d, %d channel(s), segment length %d', ...
            fn, size(last, 1), size(last, 2), numel(rows), seg);
        return;
    end
    n = (numel(paths) - 1) * seg + size(last, 1);

    body = sampledFromOpaque(b, rows, ci, type, types, abbrev, sr, n, seg);
    made{end+1} = struct('k', k, 'body', body); %#ok<AGROW>
    % a row is carried when everything in it is on the body or derived
    for r = rows(:)'
        ab = abbrev{strcmp(types, type)};
        nm = char(ci(r).name);
        tc = double(ci(r).time_channel);
        carriedRows(r) = strcmp(nm, sprintf('%s%d', ab, double(ci(r).number))) ...
            && (isempty(tc) || all(isnan(tc)));
    end
end
if isempty(made); why = 'no channel group to convert'; return; end
if all(carriedRows)
    gone{end+1} = baseId(structs{clIdx});
end
end

function body = sampledFromOpaque(b, rows, ci, type, types, abbrev, sr, n, seg)
% the channel number variable is a label no registry row carries yet, as the
% other second-pass builders' labels (ndi.migrate.internal.termRegistryOff)
restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
ab = abbrev{strcmp(types, type)};
[node, label] = channelTypeTerm(ab);
timeTerm = struct('node', 'om:Time', 'name', 'time');
channelTerm = struct('node', 'NCIT:C44170', 'name', 'Channel');
dims = did2.build.list( ...
    did2.build.dimension(timeTerm, n, 'Chunk', seg), ...
    did2.build.dimension(channelTerm, numel(rows)));
covs = did2.build.list( ...
    did2.build.covariate(timeTerm, 0, 'Origin', 0, 'Spacing', 1 / sr, ...
        'Unit', struct('node', 'om:second-Time', 'name', 'second')), ...
    did2.build.covariate(CHANNEL_NUMBER(), 1, 'Count', double([ci(rows).number])), ...
    did2.build.covariate(OFFSET(), 1, 'Value', double([ci(rows).offset])), ...
    did2.build.covariate(SCALE(), 1, 'Value', double([ci(rows).scale])));
conds = did2.build.condition(channelTerm, 'Term', struct('node', node, 'name', label));

db = b.data_body;
sid = char(did2.schema.cache.sessionIdOf(b));
ts = '';
if isfield(b.base, 'creation_timestamp'); ts = char(b.base.creation_timestamp); end
args = {'Covariates', covs, 'Conditions', conds, 'DatumOrder', 'F', ...
    'Id', baseId(b), 'SessionId', sid, 'Validate', false, ...
    'Fields', struct('filename', bodyFilename(b)), ...
    'Notes', sprintf(['%s The NDI second pass read it as one sampled body ' ...
        '(channel group of %d %s channel(s), %d sample(s)); the v1 ' ...
        'channel_list.bin rows are its covariates.'], ...
        strtrim(ndi.v2.notesOf(db)), numel(rows), type, n)};
if ~isempty(ts); args = [args, {'CreationTimestamp', ts}]; end
if isfield(db, 'format') && isstruct(db.format) && isfield(db.format, 'node') ...
        && ~isempty(db.format.node)
    args = [args, {'Format', db.format}];
end
if isfield(db, 'compression') && ~isempty(db.compression)
    args = [args, {'Compression', db.compression}];
end
body = did2.build.sampledBody(edgeValues(b, 'owner_id'), dims, args{:});
body.files = b.files;
end

% ---- terms ----------------------------------------------------------

function t = CHANNEL_NUMBER()
% No existing ontology term found (OLS4, 2026-11-01); a label until one is
% registered (T19: report candidates rather than mint).
t = struct('node', '', 'name', 'channel number');
end

function t = OFFSET()
% v1 `offset`: the stored value is (raw + offset) * scale, so the offset is
% in the stored integer's units (Intan: 32768). AFO "signal offset
% configuration": "adds/subtracts a fixed amount of magnitude to the signal
% strength or amplitude to move the zero reference".
t = struct('node', 'AFO:AFQ_0000202', 'name', 'signal offset configuration');
end

function t = SCALE()
% v1 `scale`: what one stored unit is worth in the reader's output unit
% (Intan analog: 0.195, microvolts per count). NCIT "Unit Conversion
% Factor": "An operator used to convert units from one scale to another."
t = struct('node', 'NCIT:C70774', 'name', 'Unit Conversion Factor');
end

function [node, label] = channelTypeTerm(ab)
T = ndi.vintage.channelTypes();
node = T{strcmp(T(:, 1), ab), 2};
labels = {'ai', 'analog input channel'; 'ao', 'analog output channel'; ...
    'di', 'digital input channel'; 'do', 'digital output channel'; ...
    't', 'time channel'; 'ax', 'auxiliary input channel'};
label = labels{strcmp(labels(:, 1), ab), 2};
end

% ---- the files ------------------------------------------------------

function kind = seriesKind(fn)
% 'group' (ai ao ax di do), 'time' (ti), 'event' (evmktx), 'channel_list', or ''
kind = '';
if strcmp(fn, 'channel_list.bin'); kind = 'channel_list'; return; end
tok = regexp(fn, '^(ai|ao|ax|di|do|ti|evmktx)_group\d+_seg\.nbf_#$', 'tokens', 'once');
if isempty(tok); return; end
switch tok{1}
    case 'ti', kind = 'time';
    case 'evmktx', kind = 'event';
    otherwise, kind = 'group';
end
end

function [prefix, g] = prefixAndGroup(fn)
tok = regexp(fn, '^([a-z]+)_group(\d+)_seg', 'tokens', 'once');
prefix = tok{1};
g = str2double(tok{2});
end

function data = expandSegment(path, dataclass)
% NDI's compressed segment, read with NDI's own expander (the file must end
% .nbf.tgz, as ndi.daq.reader.mfdaq's copydocfile2temp names it)
stem = ndi.file.temp_name();
tmp = [stem '.nbf.tgz'];
copyfile(path, tmp);
c = onCleanup(@() deleteIfThere(tmp));
switch dataclass
    case 'ephys',   data = ndi.compress.expand_ephys(stem);
    case 'digital', data = ndi.compress.expand_digital(stem);
    case 'time',    data = ndi.compress.expand_time(stem);
end
end

function deleteIfThere(f)
if isfile(f); delete(f); end
end

function paths = memberPaths(b, storeDir)
% the local path of every member body_data_0..N-1, in order; {} if any is
% not here
paths = {};
if ~isfield(b, 'files') || ~isstruct(b.files) || ~isfield(b.files, 'file_info')
    return;
end
infos = b.files.file_info;
if isstruct(infos); infos = num2cell(infos); end
names = cellfun(@(f) char(f.name), infos, 'UniformOutput', false);
out = cell(1, numel(infos));
for m = 1:numel(infos)
    i = find(strcmp(names, sprintf('body_data_%d', m - 1)), 1);
    if isempty(i); paths = {}; return; end
    p = locatedHere(infos{i}, storeDir);
    if isempty(p); paths = {}; return; end
    out{m} = p;
end
paths = out;
end

function path = locatedHere(fi, storeDir)
path = '';
if ~isstruct(fi) || ~isfield(fi, 'locations'); return; end
locs = fi.locations;
if isstruct(locs); locs = num2cell(locs); end
for j = 1:numel(locs)
    L = locs{j};
    if isstruct(L) && isfield(L, 'uid') && ~isempty(L.uid) ...
            && did.file.isSafeUid(char(L.uid)) ...
            && isfile(fullfile(storeDir, char(L.uid)))
        path = fullfile(storeDir, char(L.uid));
        return;
    end
end
for j = 1:numel(locs)
    L = locs{j};
    if ~isstruct(L) || ~isfield(L, 'location') || isempty(L.location); continue; end
    type = 'file';
    if isfield(L, 'location_type') && ~isempty(L.location_type)
        type = lower(strtrim(char(L.location_type)));
    end
    if strcmp(type, 'file') && isfile(char(L.location))
        path = char(L.location);
        return;
    end
end
end

% ---- the v1 archive -------------------------------------------------

function m = v1ArchivesByUid(v1Bodies)
% file uid -> the v1 daqreader_mfdaq_epochdata_ingested struct holding it
m = containers.Map('KeyType', 'char', 'ValueType', 'any');
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
    if ~isstruct(b) || ~isscalar(b) || ~isfield(b, 'daqreader_mfdaq_epochdata_ingested')
        continue;
    end
    if ~isfield(b, 'files') || ~isstruct(b.files) || ~isfield(b.files, 'file_info')
        continue;
    end
    infos = b.files.file_info;
    if isstruct(infos); infos = num2cell(infos); end
    for i = 1:numel(infos)
        if ~isstruct(infos{i}) || ~isfield(infos{i}, 'locations'); continue; end
        locs = infos{i}.locations;
        if isstruct(locs); locs = num2cell(locs); end
        for j = 1:numel(locs)
            if isstruct(locs{j}) && isfield(locs{j}, 'uid') && ~isempty(locs{j}.uid)
                m(char(locs{j}.uid)) = b;
            end
        end
    end
end
end

function arch = archiveOf(bodies, archives)
% the one v1 archive every member of these bodies came from; [] otherwise
arch = [];
archId = '';
for k = 1:numel(bodies)
    b = bodies{k};
    if ~isfield(b, 'files') || ~isfield(b.files, 'file_info'); continue; end
    infos = b.files.file_info;
    if isstruct(infos); infos = num2cell(infos); end
    for i = 1:numel(infos)
        if ~isfield(infos{i}, 'locations'); continue; end
        locs = infos{i}.locations;
        if isstruct(locs); locs = num2cell(locs); end
        for j = 1:numel(locs)
            if ~isfield(locs{j}, 'uid') || isempty(locs{j}.uid) ...
                    || ~isKey(archives, char(locs{j}.uid))
                arch = [];
                return;
            end
            a = archives(char(locs{j}.uid));
            if isempty(archId)
                archId = baseId(a);
                arch = a;
            elseif ~strcmp(archId, baseId(a))
                arch = [];
                return;
            end
        end
    end
end
end

function t0 = epochStart(arch)
t0 = NaN;
try
    tt = double(arch.daqreader_epochdata_ingested.epochtable.t0_t1);
    if ~isempty(tt); t0 = tt(1); end
catch
end
end

function v = paramOf(params, name)
v = NaN;
if isstruct(params) && isfield(params, name) && ~isempty(params.(name))
    v = double(params.(name));
end
end

% ---- document fields ------------------------------------------------

function key = archiveKeyOf(b)
% pass 1 makes one archive's bodies together: the same owners, session and
% epoch note ("The ingested recording of epoch <e>: ...")
owners = sort(edgeValues(b, 'owner_id'));
sid = char(did2.schema.cache.sessionIdOf(b));
note = '';
if isfield(b, 'data_body'); note = ndi.v2.notesOf(b.data_body); end
tok = regexp(note, 'recording of epoch (.*?): v1 attached', 'tokens', 'once');
ep = '';
if ~isempty(tok); ep = tok{1}; end
key = strjoin([{sid, ep}, owners], '|');
end

function fn = bodyFilename(b)
fn = '';
if isfield(b, 'data_body') && isstruct(b.data_body) && isfield(b.data_body, 'filename')
    fn = char(b.data_body.filename);
end
end

function c = className(b)
c = '';
if isstruct(b) && isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    c = char(b.document_class.class_name);
end
end

function id = baseId(b)
id = '';
if isstruct(b) && isfield(b, 'base') && isstruct(b.base) && isfield(b.base, 'id')
    id = char(b.base.id);
end
end

function vals = edgeValues(b, name)
vals = {};
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
if isstruct(deps); deps = num2cell(deps); end
for k = 1:numel(deps)
    d = deps{k};
    if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), name)
        continue;
    end
    if isfield(d, 'value') && ~isempty(d.value)
        vals{end+1} = char(d.value); %#ok<AGROW>
    elseif isfield(d, 'document_id') && ~isempty(d.document_id)
        vals{end+1} = char(d.document_id); %#ok<AGROW>
    end
end
end
