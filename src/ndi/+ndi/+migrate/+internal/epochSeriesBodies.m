function [structs, report, added] = epochSeriesBodies(structs, ndiDir)
%EPOCHSERIESBODIES Describe each migrated spike train's .vhsb as a sampled_body,
%   with complete extents, when its bytes are on this computer.
%
%   [STRUCTS, REPORT] = ndi.migrate.internal.epochSeriesBodies(STRUCTS, NDIDIR)
%   takes the migrated document bodies (structs, did2.document/toStruct) of
%   the session whose .ndi directory is NDIDIR and returns them with every
%   spike-train body it could read REPLACED, id preserved:
%
%     opaque_body  (the v1 element_epoch's epoch_binary_data.vhsb, carried as
%                  attached by did2.convert.resolveEpochProbemap)
%       ->  sampled_body   dimensions: ONE, the action potentials (term
%                          GO:0001508), n = the number of spikes the .vhsb
%                          header counts; no covariate (a bare index
%                          [bare dimension]); format, files and locations
%                          unchanged; byte_order little (vhsb is
%                          little-endian only)
%     and its owner, the train observation, gets value.data_type from the
%     header's X series (the spike times are the value: [spike train leaf],
%     V_eta_ensemble_plan.md).
%
%   REPORT.changed_groups lists, per body handled, the ids of every document
%   replaced or ADDED for it (ADDED holds the new ones); the caller
%   re-validates each group together and reverts a group that does not come
%   back clean. REPORT.changed_ids is the same ids, flat.
%
%   NOT THE JH SERIES. The Haley worm-track split (position / distance
%   columns, pixels to metres) left the generic migration: Decided by Jess
%   Haley, 2026-10-26 [dataset-specific logic leaves the generic migration]
%   and [dataset audit batch 1 and 2] (1) (did-schema
%   V_eta_go_forward_class_audit.md); the Haley V2 import makes the tracks.
%   A .vhsb owned by anything but a spike train is left as pass 1 wrote it
%   (counted other_owner / owner_missing).
%
%   WHY HERE AND NOT IN PASS 1. Decided by Jess Haley, 2026-10-22 [epoch
%   dissolution before merge] (F1), building TEAM-SIGN-OFF [epoch]
%   2026-08-17 Q3: "the NDI second pass attaches the sampled_body with a
%   complete axis". A dimension's `n` is required and is only in the bytes;
%   pass 1 reads documents, never a disk. When the bytes are NOT here -- every
%   document-only corpus -- the body stays the opaque_body by location
%   (Jess Haley, 2026-10-21 [spike trains as epoch bodies]: "a file named but
%   absent is still recorded by location"), counted `bytes_not_here`.
%
%   ONLY SPIKE TRAINS. The .vhsb is a generic (timepoints, datapoints)
%   series (F1 AMENDMENT 1: key on the element type); the only type with a
%   decided shape is `spikes` (observation, value kind time, variable
%   GO:0001508), recognised here by the owner's variable. Any other owner is
%   left as it is, counted `other_owner`.
%
%   WHERE THE BYTES ARE, in the order ndi.migrate.internal.settleIngestedFiles
%   uses: <NDIDIR>/files/<uid> (the store), then the recorded location when
%   it is a local file.
%
%   See also did2.convert.resolveEpochProbemap, ndi.vintage.epochSeriesOf,
%            vlt.file.custom_file_formats.vhsb_readheader.

arguments
    structs cell
    ndiDir (1,:) char
end

report = struct( ...
    'documents_inspected',   numel(structs), ...
    'train_bodies_seen',     0, ...
    'bodies_described',      0, ...
    'bytes_not_here',        0, ...
    'header_unreadable',     0, ...
    'other_owner',           0, ...
    'owner_missing',         0, ...
    'changed_groups',        {{}}, ...
    'changed_ids',           {{}});
added = {};

idxById = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(structs)
    id = baseId(structs{k});
    if ~isempty(id); idxById(id) = k; end
end
storeDir = fullfile(ndiDir, 'files');

for k = 1:numel(structs)
    b = structs{k};
    if ~strcmp(className(b), 'opaque_body'); continue; end
    if ~isfield(b, 'data_body') || ~isstruct(b.data_body) ...
            || ~isfield(b.data_body, 'filename') ...
            || ~strcmp(char(b.data_body.filename), 'epoch_binary_data.vhsb')
        continue;
    end
    report.train_bodies_seen = report.train_bodies_seen + 1;
    owners = edgeValues(b, 'owner_id');
    if numel(owners) ~= 1 || ~isKey(idxById, owners{1})
        report.owner_missing = report.owner_missing + 1;
        continue;
    end
    oi = idxById(owners{1});
    o = structs{oi};
    if ~isSpikeTrain(o)
        report.other_owner = report.other_owner + 1;
        continue;
    end
    path = bytesHere(b, storeDir);
    if isempty(path)
        report.bytes_not_here = report.bytes_not_here + 1;
        continue;
    end
    try
        h = vlt.file.custom_file_formats.vhsb_readheader(path);
        n = double(h.num_samples);
        dt = xDatumType(h);
    catch
        report.header_unreadable = report.header_unreadable + 1;
        continue;
    end
    if isempty(dt) || ~isscalar(n) || ~isfinite(n) || n < 0
        report.header_unreadable = report.header_unreadable + 1;
        continue;
    end

    sid = char(did2.schema.cache.sessionIdOf(b));
    ts = '';
    if isfield(b.base, 'creation_timestamp'); ts = char(b.base.creation_timestamp); end
    if isempty(ts) && isfield(b.base, 'datestamp'); ts = char(b.base.datestamp); end
    dims = did2.build.dimension(struct('node', 'GO:0001508', ...
        'name', 'action potential'), n);
    fmt = [];
    if isfield(b.data_body, 'format'); fmt = b.data_body.format; end
    args = {'ByteOrder', 'little', 'Id', baseId(b), 'SessionId', sid, ...
        'Validate', false, ...
        'Fields', struct('filename', 'epoch_binary_data.vhsb')};
    if ~isempty(ts); args = [args, {'CreationTimestamp', ts}]; end %#ok<AGROW>
    if ~isempty(fmt) && isstruct(fmt) && isfield(fmt, 'node') && ~isempty(fmt.node)
        args = [args, {'Format', fmt}]; %#ok<AGROW>
    end
    if isfield(b.data_body, 'description') && ~isempty(b.data_body.description)
        args = [args, {'Description', char(b.data_body.description)}]; %#ok<AGROW>
    end
    nb = did2.build.sampledBody(owners{1}, dims, args{:});
    if isfield(b, 'files')
        nb.files = b.files;
    end
    o.value.data_type = dt;
    structs{k} = nb;
    structs{oi} = o;
    report.bodies_described = report.bodies_described + 1;
    report.changed_ids{end+1} = baseId(nb);
    report.changed_ids{end+1} = baseId(o);
    report.changed_groups{end+1} = {baseId(nb), baseId(o)};
end
end

% ---------------------------------------------------------------------

function tf = isSpikeTrain(o)
tf = false;
if ~strcmp(className(o), 'observation'); return; end
if ~isfield(o, 'statement') || ~isstruct(o.statement) || ~isfield(o.statement, 'variable')
    return;
end
v = o.statement.variable;
tf = isstruct(v) && isfield(v, 'node') && strcmp(char(v.node), 'GO:0001508') ...
    && isfield(o, 'time');
end

function path = bytesHere(b, storeDir)
path = '';
if ~isfield(b, 'files') || ~isstruct(b.files) || ~isfield(b.files, 'file_info')
    return;
end
infos = b.files.file_info;
if isstruct(infos); infos = num2cell(infos); end
for i = 1:numel(infos)
    fi = infos{i};
    if ~isstruct(fi) || ~isfield(fi, 'locations'); continue; end
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
end

function dt = xDatumType(h)
% the vhsb X series type: X_data_type 1 char, 2 uint, 3 int, 4 float; size in bits
dt = '';
bits = double(h.X_data_size);
switch double(h.X_data_type)
    case 1
        dt = 'uint8';
    case 2
        dt = sprintf('uint%d', bits);
    case 3
        dt = sprintf('int%d', bits);
    case 4
        dt = sprintf('float%d', bits);
end
if ~any(strcmp(dt, {'uint8', 'uint16', 'uint32', 'uint64', 'int8', 'int16', ...
        'int32', 'int64', 'float32', 'float64'}))
    dt = '';
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
    % an ndi.document writes `value`; did2.build writes `document_id`
    if isfield(d, 'value') && ~isempty(d.value)
        vals{end+1} = char(d.value); %#ok<AGROW>
    elseif isfield(d, 'document_id') && ~isempty(d.document_id)
        vals{end+1} = char(d.document_id); %#ok<AGROW>
    end
end
end
