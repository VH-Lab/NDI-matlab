function [structs, report, added] = epochSeriesBodies(structs, ndiDir, options)
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
%               (a constant 1) is not kept; column 1 (the signed distance in
%               pixels) -> the length calculation's own body, float64 [video
%               frame x body part] in METRES (NaN stays NaN), REPLACING the
%               .vhsb (id kept) -- see THE JH DISTANCE IN METRES below
%   Each frame dimension also carries the v1 frame TIMES as a `time`
%   covariate (origin + spacing, seconds) when they are regular -- the
%   migrated session has no recording to take them from; irregular times
%   refuse the split (split_refused_irregular_times), the .vhsb stays.
%
%   THE JH DISTANCE IN METRES (Decided by Jess Haley, 2026-10-23 [JH signed
%   distance in metres], did-schema V_eta_epoch_plan.md). Converted the way
%   the Haley V2 import does it: metres per pixel = 1e-3 / scale
%   (ndi.setup.conv.haley.geometryDocuments, `pixel = 1e-3 / scale`), the
%   distance times that (trackDocuments, `a * geo.pixel`), no half-pixel
%   offset (a distance is a difference of positions). `scale` is the one the
%   v1 writer stored on the epoch video's imageStack (doImport.m
%   `dimension_scale`, [scale scale 1/frameRate]), which is PIXELS PER MM:
%   the analysis package computes it as sqrt(arena area in pixels / arena
%   area in mm^2), commented "pixels/mm" (shreklab/Haley-et-al-2024
%   helper_functions/getAcetateArena.m, `arena.scale`, stored by
%   analysis/getForagingInfo.m as `info.scale`), and its own distances are
%   converted with (1000/scale) um per pixel (analysis/analyzeWormLabTracks.m).
%   doImport's `dimension_scale_units` 'micrometer' is a mislabel of that
%   number. The video is reached in the migrated set as
%   did2.convert's +migrators_j/image_stack makes it: an `observation` about
%   the worm or about a group the worm is `member_of` (the v1 subject_group;
%   +migrators_j/subject_group), whose sampled_body has a time dimension and
%   carries the v1 dimension_scale as the Y and X covariates' spacing
%   `source_value`, source unit micrometre (the v1 label). Exactly one
%   distinct positive scale must be reachable from the length calculation's
%   worm: none -> the .vhsb stays (counted length_not_split_no_scale); more
%   than one (a worm listed on two videos of its plate with different
%   scales) -> the .vhsb stays (counted length_not_split_scale_ambiguous).
%   A scale is never invented. The conversion is stated in the body's
%   description, as trackDocuments states its own (source pixels -> m), with
%   the scale and the video it came from.
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
    options.SplitJH (1,1) logical = false
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
    'jh_split_withheld',     0, ...
    'position_split',        0, ...
    'nearest_patch_split',   0, ...
    'length_split_metres',   0, ...
    'length_not_split_no_scale', 0, ...
    'length_not_split_scale_ambiguous', 0, ...
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
videoIdx = [];   % built on the first JH body (the scale lookup)

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
        if ~options.SplitJH
            % [generic stage is lossless] and [partly placed is carried as v1]
            % (Jess Haley, 2026-10-25, did-schema
            % V_eta_go_forward_class_audit.md, audit item 5): the JH split
            % drops column 2 and rewrites the values (minus 0.5 / minus 1,
            % pixels to metres), so the generic stage does not run it: the
            % opaque body is left as pass 1 wrote it, bytes unchanged. The
            % split stays for the JH dataset map ('SplitJH', true).
            report.jh_split_withheld = report.jh_split_withheld + 1;
            continue;
        end
        path = bytesHere(b, storeDir);
        if isempty(path)
            report.bytes_not_here = report.bytes_not_here + 1;
            continue;
        end
        if isempty(videoIdx)
            videoIdx = videoScaleIndex(structs, idxById);
        end
        [structs, newDocs, ids, report] = splitJH(structs, k, jh, path, idxById, report, videoIdx);
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

function [structs, added, ids, report] = splitJH(structs, k, jh, path, idxById, report, videoIdx)
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
% the distance: column 1 (pixels) in metres, when one scale is reachable
mpp = [];
lengthDesc = '';
why = '';
if (jh.item > 0 && size(y, 2) < 3) || size(y, 2) < 1
    report.split_refused_unreadable = report.split_refused_unreadable + 1;
    return;
end
if jh.distance > 0
    [scale, videoId, why] = scaleOf(structs{jh.distance}, videoIdx);
    switch why
        case 'none'
            report.length_not_split_no_scale = report.length_not_split_no_scale + 1;
        case 'ambiguous'
            report.length_not_split_scale_ambiguous = report.length_not_split_scale_ambiguous + 1;
        otherwise
            mpp = 1e-3 / scale;                    % metres per pixel
            lengthDesc = sprintf(['Signed distance to the nearest patch edge per video ' ...
                'frame and body part, m (the source''s distanceLawnEdge, pixels; v1 ' ...
                'element_epoch epoch_binary_data.vhsb column 1, split), times 1e-3 / ' ...
                'scale metres per pixel: scale %.17g pixels per mm, approximate (from ' ...
                'the arena mask''s area and the arena''s nominal size), from the video ' ...
                '%s (v1 imageStack dimension_scale, labelled micrometer).'], scale, videoId);
    end
end
if jh.item > 0
    it = structs{jh.item};
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
    ids = [ids, {baseId(it), baseId(nb)}];
    report.nearest_patch_split = report.nearest_patch_split + 1;
end
if jh.distance > 0 && ~isempty(mpp)
    % the length calculation's own body REPLACES the .vhsb, id kept
    o2 = structs{jh.distance};
    part = bodyPartOf(o2, idxById, structs);
    a = double(y(:, 1)) * mpp;                     % NaN stays NaN
    [dims, covs] = axes2(n, part, tcov);
    o2.data.dimensions = dims;
    o2.data.covariates = covs;
    o2.value.data_type = 'float64';
    lb = ingested(baseId(o2), reshape(a, n, 1), 'float64', dims, sid, lengthDesc, ...
        'NaN', baseId(b));
    structs{jh.distance} = o2;
    structs{k} = lb;
    ids = [{baseId(lb), baseId(o2)}, ids];
    report.length_split_metres = report.length_split_metres + 1;
elseif jh.distance > 0 && jh.item > 0
    % the .vhsb stays, owned by the length calculation alone
    b.depends_on = keepOwner(b.depends_on, baseId(structs{jh.distance}));
    structs{k} = b;
    ids = [{baseId(b)}, ids];
end
end

% ===================== the JH video scale ==============================

function idx = videoScaleIndex(structs, idxById)
% IDX.scales: entity id -> {[scale, videoId], ...} for each migrated video
% (an observation whose sampled_body has a time dimension and Y/X covariates
% carrying the v1 dimension_scale, source unit micrometre); IDX.groups:
% entity id -> the ids of the groups it is `member_of`
idx = struct('scales', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'groups', containers.Map('KeyType', 'char', 'ValueType', 'any'));
for k = 1:numel(structs)
    b = structs{k};
    switch className(b)
        case 'directed_relation'
            if ~isMemberOf(b); continue; end
            c = edgeValues(b, 'child_id'); p = edgeValues(b, 'parent_id');
            if isempty(c) || isempty(p); continue; end
            if isKey(idx.groups, c{1})
                idx.groups(c{1}) = [idx.groups(c{1}), p(1)];
            else
                idx.groups(c{1}) = p(1);
            end
        case 'sampled_body'
            owners = edgeValues(b, 'owner_id');
            if numel(owners) ~= 1 || ~isKey(idxById, owners{1}); continue; end
            o = structs{idxById(owners{1})};
            if ~strcmp(className(o), 'observation'); continue; end
            ent = edgeValues(o, 'entity_id');
            if isempty(ent); continue; end
            s = videoScale(b);
            if isempty(s); continue; end
            entry = {s, owners{1}};
            if isKey(idx.scales, ent{1})
                idx.scales(ent{1}) = [idx.scales(ent{1}), {entry}];
            else
                idx.scales(ent{1}) = {entry};
            end
    end
end
end

function [scale, videoId, why] = scaleOf(o, idx)
% the one positive scale reachable from the calculation's entity: its own
% videos and those of every group it is member_of
scale = []; videoId = ''; why = 'none';
ent = edgeValues(o, 'entity_id');
if isempty(ent); return; end
cands = ent(1);
if isKey(idx.groups, ent{1}); cands = [cands, idx.groups(ent{1})]; end
vals = []; vids = {};
for i = 1:numel(cands)
    if ~isKey(idx.scales, cands{i}); continue; end
    e = idx.scales(cands{i});
    for j = 1:numel(e)
        vals(end+1) = e{j}{1}; %#ok<AGROW>
        vids{end+1} = e{j}{2}; %#ok<AGROW>
    end
end
if isempty(vals); return; end
u = unique(vals);
if numel(u) > 1; why = 'ambiguous'; return; end
scale = u;
videoId = strjoin(unique(vids), ', ');
why = 'one';
end

function s = videoScale(b)
% the v1 dimension_scale (pixels per mm) a migrated video's body carries as
% the spacing source_value of its first two covariates (Y, X), when both
% agree, are positive and are in the v1 label's unit (micrometre); [] else
s = [];
if ~isfield(b, 'data') || ~isstruct(b.data) || ~isfield(b.data, 'dimensions') ...
        || ~isfield(b.data, 'covariates'); return; end
dims = b.data.dimensions; covs = b.data.covariates;
if isstruct(dims); dims = num2cell(dims); end
if isstruct(covs); covs = num2cell(covs); end
if numel(dims) < 3; return; end
hasTime = false;
for i = 1:numel(dims)
    d = dims{i};
    if isstruct(d) && isfield(d, 'term') && isstruct(d.term) && isfield(d.term, 'node') ...
            && strcmp(char(d.term.node), 'om:Time')
        hasTime = true;
    end
end
if ~hasTime; return; end
sp = NaN(1, 2);
for i = 1:numel(covs)
    c = covs{i};
    if ~isstruct(c) || ~isfield(c, 'along') || ~isfield(c, 'spacing') ...
            || ~isfield(c, 'source_unit'); continue; end
    a = double(c.along);
    if ~isscalar(a) || a < 0 || a > 1; continue; end
    u = c.source_unit;
    if ~isstruct(u) || ~isfield(u, 'node') || ~strcmp(char(u.node), 'om:micrometre'); continue; end
    if ~isstruct(c.spacing) || ~isfield(c.spacing, 'source_value'); continue; end
    v = c.spacing.source_value;
    if ischar(v) || isstring(v); v = str2double(v); end
    if isnumeric(v) && isscalar(v); sp(a + 1) = double(v); end
end
if all(isfinite(sp)) && sp(1) > 0 && sp(1) == sp(2)
    s = sp(1);
end
end

function tf = isMemberOf(b)
tf = false;
if ~isfield(b, 'directed_relation') || ~isstruct(b.directed_relation) ...
        || ~isfield(b.directed_relation, 'relation'); return; end
r = b.directed_relation.relation;
if isstruct(r)
    tf = (isfield(r, 'node') && strcmp(char(r.node), 'RO:0002350')) ...
        || (isfield(r, 'name') && any(strcmp(char(r.name), {'member of', 'member_of'})));
elseif ischar(r) || isstring(r)
    tf = any(strcmp(char(r), {'member of', 'member_of'}));
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
