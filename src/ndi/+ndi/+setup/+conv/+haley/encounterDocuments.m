function out = encounterDocuments(dataParentDir, session, R, subjectIds, options)
%ENCOUNTERDOCUMENTS Stage 11 (Haley): each worm's patch encounters.
%
%   OUT = ndi.setup.conv.haley.encounterDocuments(DATAPARENTDIR, SESSION, R,
%   SUBJECTIDS, ...) builds, for the one-row C. elegans session SESSION, the
%   encounters celegans/encounter.mat records for its worms: the visits each
%   worm made to a patch, found and measured by the lab's analysis package
%   (analyzeEncounters, labelEncounters; Haley et al. 2024). Decision log #63.
%
%   ONE WORM ON ONE PLATE. analyzeEncounters finds a worm's encounters over its
%   whole track on the plate, its videos joined in order, so `enter`/`exit` are
%   row numbers in that joined track (an encounter can start in one video and
%   end in the next). The documents are timed by the plate's recording window
%   (stage 9's, else the video's own reference) and each time is in seconds
%   from that window's start: the video's start plus (frame - 1) / frame rate.
%
%   Per worm with encounters (V_eta_study_plan.md, "Repeated events", T2):
%     time_calculation  `encounter onset`: THE ENCOUNTER LIST, one entry per
%                       encounter (id >= 1). Every other per-encounter document
%                       takes its `encounter` key's positions from it
%                       (`key_id` / `positions_from`, T14)
%     item_calculation  `patch in contact`: each encounter's patch subject (the
%                       source's lawnID = its lawnCenters row, #38) and, as
%                       `offset`, when it ended (`exit`); when the schema has
%                       `item`
%     velocity_calculation  `median speed on patch` (velocityOn), `minimum
%                       speed on patch` (velocityOnMin), `peak speed before
%                       entry` (velocityBeforeEnter), `minimum speed after
%                       entry` (velocityAfterEnter), `median speed off patch
%                       after the encounter` (velocityOff), um/s -> m/s
%     acceleration_calculation  `deceleration on entry` (decelerate,
%                       um/s^2 -> m/s^2; a linear fit from -1.5 to +6.5 s)
%     time_calculation  `time to slow down` (timeSlowDown, s)
%     length_calculation  `furthest distance off patch during the encounter`
%                       (distanceOnMax), `furthest distance from the patch edge
%                       after the encounter` (distanceOffMax), mm -> m
%     score_calculation  `probability of exploitation` (exploitPosterior),
%                       `probability of sensing` (sensePosterior), 0-1
%     label_calculation  `encounter type` (label: exploit, sample, searchOn,
%                       searchOff; `unlabelled` where the source left it blank)
%   and, for the gap before the first encounter (the source's id 0 row), one
%   `median speed off patch before the first encounter` and one `furthest
%   distance from the patch edge before the first encounter`.
%   Inputs: the worm's midpoint speed and patch-edge distance tracks (stage 10
%   part B) for each of the plate's videos; the per-encounter values also take
%   the encounter list.
%   Not stored: duration, timeEnter/timeExit, censorEnter/censorExit (from the
%   times and the videos' lengths), the plate/strain/growth columns (stages
%   4-8), borderAmplitude* (stage 12).
%
%   Options:
%     'Tracks'               trackDocuments' OUT.byWorm
%     'PlateWindows'         observationDocuments' OUT.windows
%     'RecordingRefs'        containers.Map, epoch -> its UTC reference id
%     'SoftwareId', 'InterpreterId', 'OperatingSystemId'   as stage 10
%
%   OUT fields: documents, counts (struct), skipped (cellstr).

arguments
    dataParentDir (1,:) char {mustBeFolder}
    session table
    R table
    subjectIds
    options.Tracks = containers.Map()
    options.PlateWindows = containers.Map()
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
out = struct('documents', {{}}, 'skipped', {{}}, 'counts', struct('worms', 0, ...
    'encounters', 0, 'documents', 0));
file = fullfile(dataParentDir, 'haley', 'celegans', 'encounter.mat');
if strcmp(folder, 'ecoli') || ~isfile(file)
    return;
end
if ~ndi.setup.V2.schemaHasField('time', 'value') || ~isfile(fullfile(getenv('DID_SCHEMA_PATH'), 'time_calculation.json'))
    out.skipped{end+1} = sprintf(['%s: the schema in use has no time_calculation ' ...
        '(did-schema PR #87); no encounters'], ref);
    return;
end
if isempty(options.OperatingSystemId)
    out.skipped{end+1} = sprintf(['%s: no operating system document (the spec''s `macos`, ' ...
        'built by the metadata stage); no encounters'], ref);
    return;
end
env = {};
if ~isempty(options.SoftwareId), env = [env, {'SoftwareId', options.SoftwareId}]; end
if ~isempty(options.InterpreterId), env = [env, {'InterpreterId', options.InterpreterId}]; end
env = [env, {'OperatingSystemId', options.OperatingSystemId}];
hasItem = ndi.setup.V2.schemaHasField('item', 'value');
byRef = keyByReference();
tz = 'America/Los_Angeles';
secondFmt = 'yyyy-MM-dd''T''HH:mm:ss';

pre = ndi.setup.conv.haley.idPrefix(folder);
root = fullfile(dataParentDir, 'haley', 'celegans', folder);
I = load(fullfile(root, 'experimentInfo.mat'), 'info');
D = I.info;
D = D(D.expNum == session.experiment(1), :);
E = load(file, 'encounter');
E = E.encounter;
E = E(strcmp(E.expName, folder) & E.expNum == session.experiment(1), :);
if height(E) == 0
    return;
end
if ~isfile(fullfile(root, 'midpoint.mat'))
    out.skipped{end+1} = sprintf('%s: no midpoint.mat to place the encounters on; none', ref);
    return;
end
T = trackTable(fullfile(root, 'midpoint.mat'));
T = T(T.expNum == session.experiment(1), :);
R = R(strcmp(R.session, ref) & strcmp(R.kind, 'behaviour'), :);
docs = {};

[G, plates, worms] = findgroups(E.plateNum, E.wormNum);
for g = 1:max(G)
    rows = E(G == g, :);
    rows = sortrows(rows, 'id');
    plate = sprintf('%s_assayPlate%04d', pre, plates(g));
    worm = sprintf('%s_worm%04d', pre, worms(g));
    if ~isKey(subjectIds, worm) || ~isKey(subjectIds, plate)
        continue;
    end
    % the worm's joined track: its rows of the track table, in table order
    W = T(T.plateNum == plates(g) & T.wormNum == worms(g), :);
    % the plate's videos: epoch, start, frame rate, by videoNum
    vids = D(D.plateNum == plates(g), :);
    epochs = arrayfun(@(r) epochOf(pre, vids.videoFileName{r}), (1:height(vids))', 'UniformOutput', false);
    [onR, where] = ismember(epochs, R.epoch);
    if ~all(onR)
        out.skipped{end+1} = sprintf('%s: a video of %s is not a recording of this session', worm, plate);
        continue;
    end
    start = R.local_start(where);
    rate = R.frame_rate(where);
    t0 = min(start);
    % the plate's window: stage 9's, else the one video's own reference
    timeId = '';
    if isKey(options.PlateWindows, plate)
        timeId = options.PlateWindows(plate);
    elseif height(vids) == 1 && isKey(options.RecordingRefs, epochs{1})
        timeId = options.RecordingRefs(epochs{1});
    else
        dur = R.duration(where);
        [t1, k1] = max(start + seconds(dur));
        w = utcReference(wallClock(t0, tz), [], secondFmt, wallClock(t1, tz), [], secondFmt, ...
            ~isnan(dur(k1)), tz, sid);
        docs{end+1} = w; %#ok<AGROW>
        timeId = w.base.id;
    end
    secondsAt = @(idx) arrayfun(@(i) rowSeconds(W, i, vids, start, rate, t0), idx);

    % inputs: the worm's midpoint speed and patch-edge distance in each video
    inputs = {};
    for v = 1:numel(epochs)
        key = [epochs{v} '|' worm];
        if isKey(options.Tracks, key)
            t = options.Tracks(key);
            inputs = [inputs, {t.speed, t.patch_edge_distance}]; %#ok<AGROW>
        end
    end
    inputs = inputs(~cellfun(@isempty, inputs));
    calc = [{'SessionId', sid, 'TimeReferenceIds', {timeId}}, env];
    wormId = subjectIds(worm);
    method = did2.build.term('', 'patch encounter detection');

    enc = rows(rows.id >= 1 & ~isnan(rows.enter), :);
    gap0 = rows(rows.id == 0, :);
    n = height(enc);
    out.counts.worms = out.counts.worms + 1;

    % the gap before the first encounter
    if height(gap0) == 1
        if ~isnan(gap0.velocityOff)
            docs{end+1} = did2.build.statement('velocity_calculation', wormId, ...
                did2.build.term('', 'median speed off patch before the first encounter'), ...
                speed(gap0.velocityOff), 'Method', method, 'InputIds', inputs, calc{:}); %#ok<AGROW>
        end
        if ~isnan(gap0.distanceOffMax)
            docs{end+1} = did2.build.statement('length_calculation', wormId, ...
                did2.build.term('', 'furthest distance from the patch edge before the first encounter'), ...
                mm(gap0.distanceOffMax), 'Method', method, 'InputIds', inputs, calc{:}); %#ok<AGROW>
        end
    end
    if n == 0
        continue;
    end
    out.counts.encounters = out.counts.encounters + n;

    % the encounter list
    onset = secondsAt(enc.enter);
    list = did2.build.statement('time_calculation', wormId, ...
        did2.build.term('', 'encounter onset'), did2.build.valueCell('time', onset), ...
        'Keys', did2.build.list(did2.build.key('encounter', n, 'Origin', 0, 'Spacing', 1)), ...
        'Method', method, 'InputIds', inputs, ...
        'Notes', ['Seconds from the start of the plate''s first recording; the source''s ' ...
        '`enter`, a row of the worm''s track over the plate''s videos joined in order.'], calc{:});
    docs{end+1} = list; %#ok<AGROW>
    if byRef
        keyed = {'Keys', did2.build.list(did2.build.key('encounter', n, 'PositionsFrom', 0)), ...
            'KeyIds', {list.base.id}};
    else                                    % the builder or schema predates key_id
        keyed = {'Keys', did2.build.list(did2.build.key('encounter', n, 'Origin', 0, 'Spacing', 1))};
    end
    per = [keyed, {'InputIds', [{list.base.id}, inputs]}, calc];

    % which patch
    pIds = patchIds(subjectIds, plate);
    if hasItem && all(enc.lawnID >= 1 & enc.lawnID <= numel(pIds))
        v = struct('item', enc.lawnID(:)' - 1, 'offset', secondsAt(enc.exit)');
        docs{end+1} = did2.build.statement('item_calculation', wormId, ...
            did2.build.term('', 'patch in contact'), v, 'Edges', struct('item_id', {pIds}), ...
            'Method', method, per{:}); %#ok<AGROW>
    elseif hasItem
        out.skipped{end+1} = sprintf('%s: an encounter names a patch %s does not have; no patch list', ...
            worm, plate);
    end

    % the per-encounter values
    q = {
        'velocity_calculation', 'median speed on patch', 'velocityOn', @speed
        'velocity_calculation', 'minimum speed on patch', 'velocityOnMin', @speed
        'velocity_calculation', 'peak speed before entry', 'velocityBeforeEnter', @speed
        'velocity_calculation', 'minimum speed after entry', 'velocityAfterEnter', @speed
        'velocity_calculation', 'median speed off patch after the encounter', 'velocityOff', @speed
        'acceleration_calculation', 'deceleration on entry', 'decelerate', @accel
        'time_calculation', 'time to slow down', 'timeSlowDown', @secs
        'length_calculation', 'furthest distance off patch during the encounter', 'distanceOnMax', @mm
        'length_calculation', 'furthest distance from the patch edge after the encounter', 'distanceOffMax', @mm
        'score_calculation', 'probability of exploitation', 'exploitPosterior', @prob
        'score_calculation', 'probability of sensing', 'sensePosterior', @prob};
    for j = 1:size(q, 1)
        if ~ismember(q{j, 3}, enc.Properties.VariableNames), continue; end
        x = double(enc.(q{j, 3}));
        docs{end+1} = did2.build.statement(q{j, 1}, wormId, did2.build.term('', q{j, 2}), ...
            q{j, 4}(x), 'Method', method, per{:}); %#ok<AGROW>
    end
    if ismember('label', enc.Properties.VariableNames)
        names = cellstr(enc.label);
        names(cellfun(@isempty, names)) = {'unlabelled'};
        docs{end+1} = did2.build.statement('label_calculation', wormId, ...
            did2.build.term('', 'encounter type'), struct('name', reshape(names, 1, [])), ...
            'Method', did2.build.term('', 'thresholds on the encounter probabilities'), ...
            'MethodParameters', did2.build.list( ...
                did2.build.parameter('exploit at or above probability of exploitation', 'Value', 0.5), ...
                did2.build.parameter('sample at or above probability of sensing', 'Value', 0.5), ...
                did2.build.parameter('searchOff below probability of sensing', 'Value', 0.05)), ...
            per{:}); %#ok<AGROW>
    end
end
out.documents = docs;
out.counts.documents = numel(docs);
end

% -----------------------------------------------------------------------------
function s = rowSeconds(W, i, vids, start, rate, t0)
% seconds from T0 of row I of the worm's joined track
if isnan(i) || i < 1 || i > height(W)
    s = NaN;
    return;
end
v = find(vids.videoNum == W.videoNum(i), 1);
s = seconds(start(v) - t0) + (double(W.frameNum(i)) - 1) / rate(v);
end

function tf = keyByReference()
% key_id needs both the schema (did-schema PR #87) and the builder (DID-matlab
% PR #217); before both, the per-encounter documents list the same positions
tf = false;
f = fullfile(getenv('DID_SCHEMA_PATH'), 'data.json');
if ~isfile(f), return; end
d = jsondecode(fileread(f));
if ~isfield(d, 'depends_on') || ~any(strcmp({d.depends_on.name}, 'key_id')), return; end
try
    did2.build.key('encounter', 1, 'PositionsFrom', 0);
    tf = true;
catch
end
end

function v = speed(x), v = did2.build.valueCell('velocity', x(:)' * 1e-6, 'SourceValue', x(:)', 'SourceUnit', 'um/s'); end
function v = accel(x), v = did2.build.valueCell('acceleration', x(:)' * 1e-6, 'SourceValue', x(:)', 'SourceUnit', 'um/s^2'); end
function v = secs(x), v = did2.build.valueCell('time', x(:)'); end
function v = mm(x), v = did2.build.valueCell('length', x(:)' * 1e-3, 'SourceValue', x(:)', 'SourceUnit', 'mm'); end
function v = prob(x), v = did2.build.valueCell('score', x(:)', 'Fields', struct( ...
    'scale', did2.build.term('', 'probability'), 'scale_min', 0, 'scale_max', 1)); end

function e = epochOf(pre, name)
e = '';
name = strtrim(char(name));
if isempty(name), return; end
[~, stem] = fileparts(name);
e = [pre '_' stem];
end
