function out = trackDocuments(dataParentDir, session, R, subjectIds, options)
%TRACKDOCUMENTS Stage 10 part B (Haley): each worm's tracks, per video.
%
%   OUT = ndi.setup.conv.haley.trackDocuments(DATAPARENTDIR, SESSION, R,
%   SUBJECTIDS, ...) builds, for the one-row session table SESSION, the
%   per-frame track calculations of each worm, body part and behaviour video,
%   from the folder's <bodyPart>.mat tables (midpoint; head and tail in
%   foragingMini), which the lab's analysis package made from the WormLab
%   exports (analyzeWormLabTracks, Haley et al. 2024). Decision log #61.
%
%   Per worm, body part and video, all about the worm, each keyed by the
%   0-based video frame (the source's 1-based `frameNum`) and in an ingested
%   sampled_body:
%     position_calculation  `<body part> position`: x and y in the video's
%                           coordinate system (part A), in pixels from the
%                           image's upper-left corner (the source's 1-based
%                           pixel coordinates less half a pixel). The track
%                           as the analysis package left it: gaps of at most
%                           10 s filled by linear interpolation (method
%                           parameters), longer gaps and positions off the
%                           image NaN; `noTrack` is not stored (Jess,
%                           2026-10-03: filling a gap is a curation step like
%                           WormLab's own). Input: the recording.
%     velocity_calculation  `<body part> speed` (`velocitySmooth`), m/s: the
%                           4 s moving mean of the step lengths, steps faster
%                           than 600 um/s left out (method parameters).
%                           Input: the positions.
%     length_calculation    `<body part> distance to the nearest patch edge`
%                           (`distanceLawnEdge`), m, positive on a patch,
%                           negative off it. Inputs: the positions and the
%                           lawn mask.
%     item_calculation      `nearest patch` (`closestLawnID`): a 0-based index
%                           into the plate's patch subjects (item_id). The
%                           source reads it at pixel (1, 1) on the frames it
%                           marks `noTrack`, so those frames hold the body's
%                           fill value. Only when the schema has `item`
%                           (did-schema PR #87). Inputs: the positions and the
%                           nearest-patch map (or the lawn mask).
%   The rest of each table is not stored (decision log #60/#61's keep list):
%   identifiers, times (the recording has them), and values computed from
%   the positions by a stated rule (step distance, path angle, turns,
%   neighbour distances, arena-edge distance, nearArena, outOfBounds).
%
%   Options:
%     'Geometry'             part A's OUT.byEpoch (epoch -> coordinate system,
%                            lawn mask, nearest-patch map ids, metres per pixel)
%     'RecordingStatements'  containers.Map, epoch -> recording statement id
%     'RecordingRefs'        containers.Map, epoch -> its UTC reference id
%     'SoftwareId', 'InterpreterId', 'OperatingSystemId'   as part A
%
%   OUT fields: documents (cell of structs), counts (struct), skipped (cellstr).

arguments
    dataParentDir (1,:) char {mustBeFolder}
    session table
    R table
    subjectIds
    options.Geometry = containers.Map()
    options.RecordingStatements = containers.Map()
    options.RecordingRefs = containers.Map()
    options.SoftwareId (1,:) char = ''
    options.InterpreterId (1,:) char = ''
    options.OperatingSystemId (1,:) char = ''
end
if height(session) ~= 1
    error('ndi:setup:conv:haley:oneSession', 'Give exactly one session row.');
end
sid = char(session.session_id{1});
ref = char(session.local_identifier{1});
folder = char(session.folder{1});
out = struct('documents', {{}}, 'skipped', {{}}, 'counts', struct('position', 0, ...
    'speed', 0, 'patch_edge_distance', 0, 'nearest_patch', 0));
if strcmp(folder, 'ecoli')
    return;
end
if isempty(options.OperatingSystemId)
    out.skipped{end+1} = sprintf(['%s: no operating system document (the spec''s `macos`, ' ...
        'built by the metadata stage); no track calculations'], ref);
    return;
end
hasItem = ndi.setup.V2.schemaHasField('item', 'value');
env = {};
if ~isempty(options.SoftwareId), env = [env, {'SoftwareId', options.SoftwareId}]; end
if ~isempty(options.InterpreterId), env = [env, {'InterpreterId', options.InterpreterId}]; end
env = [env, {'OperatingSystemId', options.OperatingSystemId}];

pre = ndi.setup.conv.haley.idPrefix(folder);
root = fullfile(dataParentDir, 'haley', 'celegans', folder);
I = load(fullfile(root, 'experimentInfo.mat'), 'info');
D = I.info;
D = D(D.expNum == session.experiment(1), :);
R = R(strcmp(R.session, ref) & strcmp(R.kind, 'behaviour'), :);
docs = {};
gapFill = did2.build.list( ...
    did2.build.parameter('gap filling', 'Term', did2.build.term('', 'linear interpolation')), ...
    did2.build.parameter('longest gap filled', 'Value', 10, 'Unit', 'second'));

for part = {'midpoint', 'head', 'tail'}
    bodyPart = part{1};
    file = fullfile(root, [bodyPart '.mat']);
    if ~isfile(file)
        continue;
    end
    T = trackTable(file);
    T = T(T.expNum == session.experiment(1), :);
    for k = 1:height(R)
        epoch = R.epoch{k};
        row = find(arrayfun(@(r) strcmp(epochOf(pre, D.videoFileName{r}), epoch), 1:height(D)), 1);
        if isempty(row) || ~isKey(options.RecordingStatements, epoch) || ~isKey(options.Geometry, epoch)
            continue;
        end
        geo = options.Geometry(epoch);
        V = T(T.plateNum == D.plateNum(row) & T.videoNum == D.videoNum(row), :);
        if height(V) == 0
            continue;
        end
        videoId = options.RecordingStatements(epoch);
        timeIds = {};
        if isKey(options.RecordingRefs, epoch), timeIds = {options.RecordingRefs(epoch)}; end
        calc = [{'SessionId', sid, 'TimeReferenceIds', timeIds}, env];
        plate = R.plate{k};
        worms = unique(V.wormNum);
        for w = reshape(worms, 1, [])
            worm = sprintf('%s_worm%04d', pre, w);
            if ~isKey(subjectIds, worm)
                out.skipped{end+1} = sprintf('%s: %s %s is not a subject of this session', epoch, worm, bodyPart);
                continue;
            end
            W = sortrows(V(V.wormNum == w, :), 'frameNum');
            n = height(W);
            if ~isequal(W.frameNum(:)', 1:n)
                out.skipped{end+1} = sprintf('%s: %s %s frames are not 1..%d; no track', ...
                    epoch, worm, bodyPart, n);
                continue;
            end
            frame = did2.build.key('video frame', n, 'Origin', 0, 'Spacing', 1, ...
                'SourceOrigin', 1, 'SourceSpacing', 1);
            frames = did2.build.list(frame);
            wormId = subjectIds(worm);

            % positions
            xy = [W.xPosition, W.yPosition] - 0.5;
            keys = did2.build.list(frame, did2.build.key('image coordinate', 2, ...
                'Labels', {'image horizontal axis', 'image vertical axis'}));
            pos = did2.build.statement('position_calculation', wormId, ...
                did2.build.term('', [bodyPart ' position']), [], 'DataBody', true, ...
                'DatumType', 'float64', 'Keys', keys, ...
                'Method', did2.build.term('', 'tracking by WormLab'), 'MethodParameters', gapFill, ...
                'InputIds', {videoId}, ...
                'Edges', struct('coordinate_system_id', geo.coordinate_system), calc{:});
            docs = [docs, {pos, ingestedBody(pos, xy, 'float64', keys, sid, ...
                sprintf('The %s track: x, y per video frame, pixels from the upper-left corner.', bodyPart), ...
                'NaN')}]; %#ok<AGROW>
            out.counts.position = out.counts.position + 1;

            % speed
            if ismember('velocitySmooth', W.Properties.VariableNames)
                sp = did2.build.statement('velocity_calculation', wormId, ...
                    did2.build.term('', [bodyPart ' speed']), [], 'DataBody', true, ...
                    'DatumType', 'float64', 'Keys', frames, ...
                    'Method', did2.build.term('', 'moving mean of step lengths'), ...
                    'MethodParameters', did2.build.list( ...
                        did2.build.parameter('window', 'Value', 4, 'Unit', 'second'), ...
                        did2.build.parameter('fastest step kept', 'Value', 600e-6, ...
                            'Unit', 'meter per second', 'SourceValue', '600', 'SourceUnit', 'um/s')), ...
                    'InputIds', {pos.base.id}, calc{:});
                docs = [docs, {sp, ingestedBody(sp, W.velocitySmooth * 1e-6, 'float64', frames, sid, ...
                    'Speed per video frame, m/s (the source''s velocitySmooth, um/s).', 'NaN')}]; %#ok<AGROW>
                out.counts.speed = out.counts.speed + 1;
            end

            % distance to the nearest patch edge
            if ismember('distanceLawnEdge', W.Properties.VariableNames) && ~isempty(geo.lawn_mask)
                de = did2.build.statement('length_calculation', wormId, ...
                    did2.build.term('', [bodyPart ' distance to the nearest patch edge']), [], ...
                    'DataBody', true, 'DatumType', 'float64', 'Keys', frames, ...
                    'Method', did2.build.term('', 'distance transform of the lawn mask'), ...
                    'Notes', 'Positive on a patch, negative off it.', ...
                    'InputIds', {pos.base.id, geo.lawn_mask}, calc{:});
                docs = [docs, {de, ingestedBody(de, W.distanceLawnEdge * geo.pixel, 'float64', frames, sid, ...
                    'Signed distance to the nearest patch edge per video frame, m (the source''s distanceLawnEdge, pixels).', ...
                    'NaN')}]; %#ok<AGROW>
                out.counts.patch_edge_distance = out.counts.patch_edge_distance + 1;
            end

            % nearest patch
            if hasItem && ismember('closestLawnID', W.Properties.VariableNames)
                pIds = patchIds(subjectIds, plate);
                id = double(W.closestLawnID);
                if ismember('noTrack', W.Properties.VariableNames)
                    id(logical(W.noTrack)) = NaN;   % read at pixel (1,1): meaningless
                end
                if isempty(pIds) || any(id > numel(pIds) | id < 1)
                    out.skipped{end+1} = sprintf('%s: %s names patches the plate %s does not have; no nearest patch', ...
                        epoch, worm, plate);
                else
                    dt = 'uint8'; fill = 255;
                    if numel(pIds) >= 255, dt = 'uint16'; fill = 65535; end
                    v = id - 1;
                    v(isnan(v)) = fill;
                    inputs = {pos.base.id};
                    if ~isempty(geo.nearest_patch)
                        inputs{end+1} = geo.nearest_patch; %#ok<AGROW>
                    elseif ~isempty(geo.lawn_mask)
                        inputs{end+1} = geo.lawn_mask; %#ok<AGROW>
                    end
                    np = did2.build.statement('item_calculation', wormId, ...
                        did2.build.term('', 'nearest patch'), [], 'DataBody', true, 'DatumType', dt, ...
                        'Keys', frames, 'InputIds', inputs, ...
                        'Edges', struct('item_id', {pIds}), calc{:});
                    docs = [docs, {np, ingestedBody(np, v, dt, frames, sid, ...
                        sprintf(['The nearest patch per video frame: a 0-based index into item_id; ' ...
                        '%d where the source did not track the worm.'], fill), num2str(fill))}]; %#ok<AGROW>
                    out.counts.nearest_patch = out.counts.nearest_patch + 1;
                end
            end
        end
    end
end
out.documents = docs;
end

% -----------------------------------------------------------------------------
function T = trackTable(file)
% the table in FILE, loaded once per file (the tables are up to GBs and
% every session of a folder reads the same one)
persistent cacheFile cacheStamp cacheTable
info = dir(file);
if ~isempty(cacheFile) && strcmp(cacheFile, file) && isequal(cacheStamp, info.datenum)
    T = cacheTable;
    return;
end
S = load(file);
f = fieldnames(S);
T = S.(f{1});
cacheFile = file; cacheStamp = info.datenum; cacheTable = T;
end

function e = epochOf(pre, name)
% a recording's epoch id from the file name the table records
e = '';
name = strtrim(char(name));
if isempty(name), return; end
[~, stem] = fileparts(name);
e = [pre '_' stem];
end
