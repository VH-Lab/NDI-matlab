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
%   THE JH SERIES (Decided by Jess Haley, 2026-10-22 [JH position and
%   distance]: "NDI's second pass splits the columns where the bytes are
%   present"). The .vhsb of a v1 `position` epoch is (time, [x y]) per frame
%   and of a `distance` epoch (time, [distanceLawnEdge 1 closestLawnID]).
%   Where the bytes are here they are split into the arrays
%   ndi.setup.conv.haley.trackDocuments writes, as INGESTED gzip'd binary
%   bodies (its ingestedBody):
%     position  float64 [video frame x body part x coordinate], the source's
%               1-based pixel positions less half a pixel; the position
%               calculation gets the dimensions + covariates (frame, the body
%               part named by the element, X/Y) and data_type float64; the
%               opaque_body is REPLACED, id kept
%     distance  column 3 -> the nearest-patch item calculation's own body,
%               uint8 [video frame x body part] (0-based patch index, 255 =
%               untracked/NaN; uint16 / 65535 past 254 patches); column 2
%               (a constant 1) is not kept; column 1 (pixels) is NOT split:
%               trackDocuments' length is in metres and v1 records no pixel
%               scale, so the length calculation keeps the .vhsb as its body
%               (counted length_not_split_no_scale)
%   Each frame dimension also carries the v1 frame TIMES as a `time`
%   covariate (origin + spacing, seconds) when they are regular -- the
%   migrated session has no recording to take them from; irregular times
%   refuse the split (split_refused_irregular_times), the .vhsb stays.
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
    'jh_bodies_seen',        0, ...
    'position_split',        0, ...
    'nearest_patch_split',   0, ...
    'length_not_split_no_scale', 0, ...
    'split_refused_irregular_times', 0, ...
    'split_refused_unreadable', 0, ...
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
    jh = jhOwners(owners, idxById, structs);
    if ~isempty(jh)
        report.jh_bodies_seen = report.jh_bodies_seen + 1;
        path = bytesHere(b, storeDir);
        if isempty(path)
            report.bytes_not_here = report.bytes_not_here + 1;
            continue;
        end
        [structs, newDocs, ids, report] = splitJH(structs, k, jh, path, idxById, report);
        added = [added, newDocs]; %#ok<AGROW>
        if ~isempty(ids)
            report.changed_groups{end+1} = ids;
            report.changed_ids = [report.changed_ids, ids];
        end
        continue;
    end
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

% ===================== the JH split ====================================

function jh = jhOwners(owners, idxById, structs)
% the JH calculations owning a body, by role ('position' / 'distance' /
% 'item'), recognised by their variable node; [] when not a JH series
jh = [];
roles = struct('position', 0, 'distance', 0, 'item', 0);
found = false;
for i = 1:numel(owners)
    if ~isKey(idxById, owners{i}); return; end
    o = structs{idxById(owners{i})};
    if ~isfield(o, 'statement') || ~isfield(o.statement, 'variable'); return; end
    switch char(o.statement.variable.node)
        case 'PATO:0000140'; roles.position = idxById(owners{i}); found = true;
        case 'EMPTY:0000384'; roles.distance = idxById(owners{i}); found = true;
        case 'EMPTY:0000297'; roles.item = idxById(owners{i}); found = true;
        otherwise; return;
    end
end
if found; jh = roles; end
end

function [structs, added, ids, report] = splitJH(structs, k, jh, path, idxById, report)
added = {}; ids = {};
b = structs{k};
try
    [y, x] = vlt.file.custom_file_formats.vhsb_read(path, -Inf, Inf);
catch
    report.split_refused_unreadable = report.split_refused_unreadable + 1;
    return;
end
x = double(x(:));
n = numel(x);
[tcov, regular] = timeCovariate(x);
if ~regular
    report.split_refused_irregular_times = report.split_refused_irregular_times + 1;
    return;
end
sid = char(did2.schema.cache.sessionIdOf(b));
if jh.position > 0
    o = structs{jh.position};
    if size(y, 2) < 2; report.split_refused_unreadable = report.split_refused_unreadable + 1; return; end
    part = bodyPartOf(o, idxById, structs);
    xy = reshape(double(y(:, 1:2)) - 0.5, n, 1, 2);
    [dims, covs] = axes3(n, part, tcov);
    o.data.dimensions = dims;
    o.data.covariates = covs;
    o.value.data_type = 'float64';
    nb = ingested(baseId(o), xy, 'float64', dims, sid, ...
        ['The track of the ' char(part.name) ': x, y per video frame, pixels ' ...
         'from the upper-left corner (v1 element_epoch epoch_binary_data.vhsb, split).'], ...
        'NaN', baseId(b));
    structs{jh.position} = o;
    structs{k} = nb;
    ids = {baseId(nb), baseId(o)};
    report.position_split = report.position_split + 1;
    return;
end
if jh.distance > 0
    report.length_not_split_no_scale = report.length_not_split_no_scale + 1;
end
if jh.item > 0
    if size(y, 2) < 3; report.split_refused_unreadable = report.split_refused_unreadable + 1; return; end
    it = structs{jh.item};
    o2 = struct();
    if jh.distance > 0; o2 = structs{jh.distance}; end
    part = bodyPartOf(it, idxById, structs);
    v = double(y(:, 3)) - 1;
    nItems = numel(edgeValues(it, 'item_id'));
    dt = 'uint8'; fill = 255;
    if nItems >= 255; dt = 'uint16'; fill = 65535; end
    v(~isfinite(v) | v < 0) = fill;
    [dims, covs] = axes2(n, part, tcov);
    it.data.dimensions = dims;
    it.data.covariates = covs;
    it.value.data_type = dt;
    nb = ingested(baseId(it), reshape(v, n, 1), dt, dims, sid, ...
        sprintf(['The nearest patch per video frame: a 0-based index into item_id; %d ' ...
        'where the source did not track the worm (v1 closestLawnID, split).'], fill), ...
        num2str(fill), '');
    structs{jh.item} = it;
    added{end+1} = nb;
    % the .vhsb stays, owned by the length calculation alone
    if jh.distance > 0
        b.depends_on = keepOwner(b.depends_on, baseId(o2));
        structs{k} = b;
        ids = {baseId(b), baseId(it), baseId(nb)};
    else
        ids = {baseId(it), baseId(nb)};
    end
    report.nearest_patch_split = report.nearest_patch_split + 1;
end
end

function [c, regular] = timeCovariate(x)
% the frame times as an origin + spacing `time` covariate (seconds), when regular
c = []; regular = false;
n = numel(x);
if n == 0; return; end
if n == 1
    regular = true;
    c = {'Origin', x(1), 'Spacing', 0};
    return;
end
d = diff(x);
sp = median(d);
if ~(sp > 0) || any(abs(d - sp) > 1e-6 * max(1, abs(sp)) + 1e-9); return; end
regular = true;
c = {'Origin', x(1), 'Spacing', sp};
end

function [dims, covs] = axes3(n, part, tcov)
frame = struct('node', 'EMPTY:0000309', 'name', 'video frame');
bp = struct('node', 'NCIT:C32221', 'name', 'Body Part');
co = struct('node', 'NCIT:C44465', 'name', 'Coordinate');
dims = did2.build.list(did2.build.dimension(frame, n), did2.build.dimension(bp, 1), ...
    did2.build.dimension(co, 2));
covs = did2.build.list( ...
    did2.build.covariate(frame, 0, 'Origin', 0, 'Spacing', 1, 'SourceOrigin', 1, 'SourceSpacing', 1), ...
    did2.build.covariate(struct('node', 'om:Time', 'name', 'time'), 0, tcov{:}, ...
        'Unit', struct('node', 'om:second-Time', 'name', 'second')), ...
    did2.build.covariate(bp, 1, 'Term', part), ...
    did2.build.covariate(co, 2, 'Term', [struct('node', 'NCIT:C44477', 'name', 'X-Coordinate'), ...
        struct('node', 'NCIT:C44478', 'name', 'Y-Coordinate')]));
end

function [dims, covs] = axes2(n, part, tcov)
frame = struct('node', 'EMPTY:0000309', 'name', 'video frame');
bp = struct('node', 'NCIT:C32221', 'name', 'Body Part');
dims = did2.build.list(did2.build.dimension(frame, n), did2.build.dimension(bp, 1));
covs = did2.build.list( ...
    did2.build.covariate(frame, 0, 'Origin', 0, 'Spacing', 1, 'SourceOrigin', 1, 'SourceSpacing', 1), ...
    did2.build.covariate(struct('node', 'om:Time', 'name', 'time'), 0, tcov{:}, ...
        'Unit', struct('node', 'om:second-Time', 'name', 'second')), ...
    did2.build.covariate(bp, 1, 'Term', part));
end

function t = bodyPartOf(o, idxById, structs)
% the body part the v1 element named (<stem>_<midpoint|head|tail>_<kind>),
% as trackDocuments' terms (decision #128): the instrument is the element
t = struct('node', 'EMPTY:0000137', 'name', 'body midpoint');
ins = edgeValues(o, 'instrument_id');
if isempty(ins) || ~isKey(idxById, ins{1}); return; end
e = structs{idxById(ins{1})};
lid = '';
if isfield(e, 'entity') && isfield(e.entity, 'local_identifier'); lid = char(e.entity.local_identifier); end
if contains(lid, '_head_')
    t = struct('node', 'EMPTY:0000352', 'name', 'anterior end point');
elseif contains(lid, '_tail_')
    t = struct('node', 'EMPTY:0000353', 'name', 'posterior end point');
end
end

function nb = ingested(ownerId, a, datumType, dims, sid, description, fillValue, id)
% ndi.setup.conv.haley ingestedBody: raw little-endian, column-major, gzip'd,
% ingested on write
raw = [tempname '.bin'];
fid = fopen(raw, 'w', 'ieee-le');
switch datumType
    case 'float64', fwrite(fid, double(a), 'double');
    otherwise,      fwrite(fid, cast(a, datumType), datumType);
end
fclose(fid);
gz = gzip(raw);
gz = gz{1};
delete(raw);
info = dir(gz);
byteOrder = '';
if ~any(strcmp(datumType, {'uint8', 'int8'})); byteOrder = 'little'; end
args = {'DatumOrder', 'F', 'ByteOrder', byteOrder, 'FillValue', fillValue, ...
    'Format', struct('node', 'EDAM:format_2333', 'name', 'Binary format'), ...
    'Compression', 'gzip', 'ContentHash', ndi.fun.file.MD5(gz), 'HashAlgorithm', 'MD5', ...
    'Description', description, 'Fields', struct('size_bytes', info.bytes), ...
    'SessionId', sid, 'Validate', false};
if ~isempty(id); args = [args, {'Id', id}]; end
nb = did2.build.sampledBody(ownerId, dims, args{:});
nb.files.file_info = struct('name', 'body_data_0', 'locations', struct( ...
    'delete_original', 1, 'uid', ndi.ido.unique_id(), 'location', gz, ...
    'parameters', '', 'location_type', 'file', 'ingest', 1));
end

function deps = keepOwner(deps, ownerId)
% the owner_id entries reduced to OWNERID
if isstruct(deps); deps = num2cell(deps); end
keep = true(1, numel(deps));
for i = 1:numel(deps)
    d = deps{i};
    if isstruct(d) && strcmp(char(d.name), 'owner_id')
        v = '';
        if isfield(d, 'value') && ~isempty(d.value); v = char(d.value); end
        if isfield(d, 'document_id') && ~isempty(d.document_id); v = char(d.document_id); end
        keep(i) = strcmp(v, ownerId);
    end
end
deps = [deps{keep}];
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
