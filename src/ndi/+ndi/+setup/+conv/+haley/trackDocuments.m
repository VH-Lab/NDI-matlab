function out = trackDocuments(dataParentDir, session, R, subjectIds, options)
%TRACKDOCUMENTS Stage 10 part B (Haley): each worm's tracks, per video.
%
%   OUT = ndi.setup.conv.haley.trackDocuments(DATAPARENTDIR, SESSION, R,
%   SUBJECTIDS, ...) builds, for the one-row session table SESSION, the
%   per-frame track calculations of each worm and behaviour video, from the
%   folder's <bodyPart>.mat tables (midpoint; head and tail in foragingMini),
%   which the lab's analysis package made from the WormLab exports
%   (analyzeWormLabTracks, Haley et al. 2024). Decision log #61.
%
%   Per worm and video, four calculations about the worm, each in an
%   ingested sampled_body keyed by `video frame` (0-based; the source's
%   1-based `frameNum`) and `body part` (the body parts with a table, in the
%   order midpoint, head, tail: one, the midpoint, when only it was tracked;
%   written as the points they are -- `body midpoint`, `anterior end point`,
%   `posterior end point`, the ends of the tracked body spline, not UBERON's
%   head and tail regions; decision #128).
%   The body parts of a worm share their frames; a body part whose frames
%   differ from the first one's is left out and reported in OUT.skipped.
%     position calculation  `position`, keyed [video frame x body part x
%                           coordinate] (X-coordinate, Y-coordinate) in the
%                           video's coordinate system (part A), in pixels
%                           from the image's upper-left corner (the source's
%                           1-based pixel coordinates less half a pixel).
%                           The track as the analysis package left it: gaps
%                           of at most 10 s filled by linear interpolation
%                           (method video tracking; parameters interpolation
%                           method and maximum gap filled), longer gaps and
%                           positions off the image NaN; `noTrack` is not
%                           stored (Jess, 2026-10-03: filling a gap is a
%                           curation step like WormLab's own). Input: the
%                           recording.
%     velocity calculation  `speed` (`velocitySmooth`), m/s: the moving
%                           average of the step lengths over a 4 s window,
%                           steps faster than 600 um/s left out (method
%                           parameter window).
%                           Input: the positions.
%     length calculation    `signed distance from the nearest bacterial patch
%                           edge` (`distanceLawnEdge`), m: positive inside a
%                           patch, negative outside it, as the variable
%                           (EMPTY:0000350) says (decision #119). Method
%                           distance transform. Inputs: the positions and the
%                           lawn mask.
%     item calculation      `nearest bacterial patch` (`closestLawnID`): a
%                           0-based index into the plate's patch subjects
%                           (item_id). The source reads it at pixel (1, 1) on
%                           the frames it marks `noTrack`, so those frames
%                           hold the body's fill value. Inputs: the
%                           positions and the nearest-patch map (or the lawn
%                           mask).
%   A statement holds the body parts whose table has its column. The rest of
%   each table is not stored (decision log #60/#61's keep list): identifiers,
%   times (the recording has them), and values computed from the positions by
%   a stated rule (step distance, path angle, turns, neighbour distances,
%   arena-edge distance, nearArena, outOfBounds).
%
%   Options:
%     'Geometry'             part A's OUT.byEpoch (epoch -> coordinate system,
%                            lawn mask, nearest-patch map ids, metres per pixel)
%     'RecordingStatements'  containers.Map, epoch -> recording statement id
%     'RecordingRefs'        containers.Map, epoch -> its UTC reference id
%     'SoftwareId', 'InterpreterId', 'OperatingSystemId'   as part A
%
%   OUT fields: documents (cell of structs), counts (struct: position, speed,
%   patch_edge_distance, nearest_patch, each a number of statements),
%   skipped (cellstr), byWorm (containers.Map, '<epoch>|<worm
%   local_identifier>' -> struct of the ids of that worm's position, speed,
%   patch-edge distance and nearest-patch statements in that video ('' for
%   one not made): stage 11's inputs).

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
    'speed', 0, 'patch_edge_distance', 0, 'nearest_patch', 0), 'byWorm', containers.Map());
if strcmp(folder, 'ecoli')
    return;
end
if isempty(options.OperatingSystemId)
    out.skipped{end+1} = sprintf(['%s: no operating system document (the spec''s `macos`, ' ...
        'built by the metadata stage); no track calculations'], ref);
    return;
end
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

% each body part's table, this experiment's rows only
parts = {};
tables = {};
for part = {'midpoint', 'head', 'tail'}
    file = fullfile(root, [part{1} '.mat']);
    if ~isfile(file)
        continue;
    end
    T = trackTable(file);
    parts{end+1} = part{1}; %#ok<AGROW>
    tables{end+1} = T(T.expNum == session.experiment(1), :); %#ok<AGROW>
end
if isempty(parts)
    return;
end

docs = {};
gapFill = did2.build.list( ...
    did2.build.parameter(haleyTerm('interpolation method'), 'Term', haleyTerm('linear interpolation')), ...
    did2.build.parameter(haleyTerm('maximum gap filled'), 'Value', 10, 'Unit', haleyTerm('second')));
speedParams = did2.build.list( ...
    did2.build.parameter(haleyTerm('window'), 'Value', 4, 'Unit', haleyTerm('second')));
coordinate = {haleyTerm('coordinate'), 2, ...
    'Term', haleyTerm({'X-coordinate', 'Y-coordinate'})};

for k = 1:height(R)
    epoch = R.epoch{k};
    row = find(arrayfun(@(r) strcmp(epochOf(pre, D.videoFileName{r}), epoch), 1:height(D)), 1);
    if isempty(row) || ~isKey(options.RecordingStatements, epoch) || ~isKey(options.Geometry, epoch)
        continue;
    end
    geo = options.Geometry(epoch);
    V = cellfun(@(T) T(T.plateNum == D.plateNum(row) & T.videoNum == D.videoNum(row), :), ...
        tables, 'UniformOutput', false);
    worms = unique(cell2mat(cellfun(@(t) t.wormNum(:), V(:), 'UniformOutput', false)));
    if isempty(worms)
        continue;
    end
    videoId = options.RecordingStatements(epoch);
    timeIds = {};
    if isKey(options.RecordingRefs, epoch), timeIds = {options.RecordingRefs(epoch)}; end
    calc = [{'SessionId', sid, 'TimeReferenceIds', timeIds}, env];
    plate = R.plate{k};
    for w = reshape(worms, 1, [])
        worm = sprintf('%s_worm%04d', pre, w);
        if ~isKey(subjectIds, worm)
            out.skipped{end+1} = sprintf('%s: %s is not a subject of this session', epoch, worm);
            continue;
        end

        % the body parts tracked on the same frames as the first one
        kept = {};
        W = {};
        n = [];
        for j = 1:numel(parts)
            Wj = sortrows(V{j}(V{j}.wormNum == w, :), 'frameNum');
            m = height(Wj);
            if m == 0
                continue;
            end
            if ~isequal(Wj.frameNum(:)', 1:m)
                out.skipped{end+1} = sprintf('%s: %s %s frames are not 1..%d; %s left out', ...
                    epoch, worm, parts{j}, m, parts{j});
                continue;
            end
            if isempty(n)
                n = m;
            elseif m ~= n
                out.skipped{end+1} = sprintf('%s: %s %s has %d frames, %s %d; %s left out', ...
                    epoch, worm, parts{j}, m, kept{1}, n, parts{j});
                continue;
            end
            kept{end+1} = parts{j}; %#ok<AGROW>
            W{end+1} = Wj; %#ok<AGROW>
        end
        if isempty(kept)
            continue;
        end
        frame = {haleyTerm('video frame'), n, 'Origin', 0, 'Spacing', 1, ...
            'SourceOrigin', 1, 'SourceSpacing', 1};
        wormId = subjectIds(worm);

        % positions
        xy = NaN(n, numel(kept), 2);
        for j = 1:numel(kept)
            xy(:, j, 1) = W{j}.xPosition - 0.5;
            xy(:, j, 2) = W{j}.yPosition - 0.5;
        end
        keys = haleyAxes(frame, bodyPartAxis(kept), coordinate);
        pos = did2.build.statement('calculation', wormId, ...
            haleyTerm('position'), [], 'DataBody', true, ...
            'DatumType', 'float64', keys.args{:}, ...
            'Method', haleyTerm('video tracking'), 'MethodParameters', gapFill, ...
            'InputIds', {videoId}, ...
            'Edges', struct('coordinate_system_id', geo.coordinate_system), calc{:}, 'ValueKind', 'position');
        docs = [docs, {pos, ingestedBody(pos, xy, 'float64', keys, sid, ...
            sprintf(['The track of the %s: x, y per video frame and body part, ' ...
            'pixels from the upper-left corner.'], strjoin(kept, ', ')), ...
            'NaN')}]; %#ok<AGROW>
        out.counts.position = out.counts.position + 1;
        ids = struct('position', pos.base.id, 'speed', '', 'patch_edge_distance', '', ...
            'nearest_patch', '');

        % speed
        [has, a] = column(W, 'velocitySmooth');
        if any(has)
            keys = haleyAxes(frame, bodyPartAxis(kept(has)));
            sp = did2.build.statement('calculation', wormId, ...
                haleyTerm('speed'), [], 'DataBody', true, ...
                'DatumType', 'float64', keys.args{:}, ...
                'Method', haleyTerm('moving average'), 'MethodParameters', speedParams, ...
                'InputIds', {pos.base.id}, calc{:}, 'ValueKind', 'velocity');
            docs = [docs, {sp, ingestedBody(sp, a * 1e-6, 'float64', keys, sid, ...
                'Speed per video frame and body part, m/s (the source''s velocitySmooth, um/s).', ...
                'NaN')}]; %#ok<AGROW>
            out.counts.speed = out.counts.speed + 1;
            ids.speed = sp.base.id;
        end

        % distance to the nearest patch edge
        [has, a] = column(W, 'distanceLawnEdge');
        if any(has) && ~isempty(geo.lawn_mask)
            keys = haleyAxes(frame, bodyPartAxis(kept(has)));
            de = did2.build.statement('calculation', wormId, ...
                haleyTerm('signed distance from the nearest bacterial patch edge'), [], ...
                'DataBody', true, 'DatumType', 'float64', keys.args{:}, ...
                'Method', haleyTerm('distance transform'), ...
                'InputIds', {pos.base.id, geo.lawn_mask}, calc{:}, 'ValueKind', 'length');
            docs = [docs, {de, ingestedBody(de, a * geo.pixel, 'float64', keys, sid, ...
                ['Signed distance to the nearest patch edge per video frame and body part, m ' ...
                '(the source''s distanceLawnEdge, pixels).'], 'NaN')}]; %#ok<AGROW>
            out.counts.patch_edge_distance = out.counts.patch_edge_distance + 1;
            ids.patch_edge_distance = de.base.id;
        end

        % nearest patch
        [has, id] = column(W, 'closestLawnID');
        if any(has)
            pIds = patchIds(subjectIds, plate);
            W1 = W(has);
            for j = 1:numel(W1)
                if ismember('noTrack', W1{j}.Properties.VariableNames)
                    id(logical(W1{j}.noTrack), j) = NaN;   % read at pixel (1,1): meaningless
                end
            end
            if isempty(pIds) || any(id(:) > numel(pIds) | id(:) < 1)
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
                keys = haleyAxes(frame, bodyPartAxis(kept(has)));
                np = did2.build.statement('calculation', wormId, ...
                    haleyTerm('nearest bacterial patch'), [], 'DataBody', true, 'DatumType', dt, ...
                    keys.args{:}, 'InputIds', inputs, ...
                    'Edges', struct('item_id', {pIds}), calc{:}, 'ValueKind', 'item');
                docs = [docs, {np, ingestedBody(np, v, dt, keys, sid, ...
                    sprintf(['The nearest patch per video frame and body part: a 0-based index ' ...
                    'into item_id; %d where the source did not track the worm.'], fill), ...
                    num2str(fill))}]; %#ok<AGROW>
                out.counts.nearest_patch = out.counts.nearest_patch + 1;
                ids.nearest_patch = np.base.id;
            end
        end
        out.byWorm([epoch '|' worm]) = ids;
    end
end
out.documents = docs;
end

% -----------------------------------------------------------------------------

function k = bodyPartAxis(names)
% the `body part` axis over NAMES (body part names, in order): a haleyAxes
% spec, the dimension and its term covariate
arguments
    names cell
end
% the source's part names are points of the tracked body spline: `midpoint`
% the term `body midpoint`, `head` and `tail` its ends, `anterior end point`
% and `posterior end point` (decision #128)
points = containers.Map({'midpoint', 'head', 'tail'}, ...
    {'body midpoint', 'anterior end point', 'posterior end point'});
k = {haleyTerm('body part'), numel(names), 'Term', ...
    haleyTerm(cellfun(@(n) points(n), names, 'UniformOutput', false))};
end

function [has, a] = column(W, name)
% which of the body parts' tables W have column NAME, and its values as an
% [frames x (body parts that have it)] double array
arguments
    W cell
    name {mustBeText}
end
has = cellfun(@(t) ismember(name, t.Properties.VariableNames), W);
a = zeros(0, 0);
if any(has)
    a = cell2mat(cellfun(@(t) double(t.(name)(:)), W(has), 'UniformOutput', false));
end
end

function e = epochOf(pre, name)
% a recording's epoch id from the file name the table records
arguments
    pre {mustBeText}
    name
end
e = '';
name = strtrim(char(name));
if isempty(name), return; end
[~, stem] = fileparts(name);
e = [pre '_' stem];
end
