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
%   Per worm with encounters (V_eta_study_plan.md, "Repeated events", T2),
%   each statement's variable, method and conditions a decided term
%   (haleyTerm) unless named as a label:
%     time_calculation  `encounter onset time`: THE ENCOUNTER LIST, one entry
%                       per encounter (id >= 1), keyed `encounter`; method
%                       `patch encounter detection`, method parameter `body
%                       part` = `midpoint` (the track it reads). Every other
%                       per-encounter document takes its `encounter` key's
%                       positions from it (`key_id` / `positions_from`, T14)
%     item_calculation  `bacterial patch in contact`: each encounter's patch
%                       subject (the source's lawnID = its lawnCenters row, #38)
%                       and, as `offset`, when it ended (`exit`); when the
%                       schema has `item`
%     velocity_calculation  `speed`, method `median`, keyed [encounter x
%                       `patch encounter period`] (`during the patch
%                       encounter`: velocityOn; `after the patch encounter`:
%                       velocityOff, NaN after the last encounter when the
%                       track ends first); um/s -> m/s throughout
%     velocity_calculation  `speed`, method `minimum`, condition `patch
%                       encounter period` = during (velocityOnMin)
%     velocity_calculation  `speed`, method `peak speed before an event`
%                       (velocityBeforeEnter), conditions `reference
%                       time point` = `encounter onset time`, `analysis window
%                       start` -10 s, `analysis window end` 0 s
%     velocity_calculation  `speed`, method `minimum speed after an event`
%                       (velocityAfterEnter), the same anchor, window 0..+10 s
%     acceleration_calculation  `acceleration`, method `ordinary least squares
%                       estimation` (decelerate, um/s^2 -> m/s^2), the same
%                       anchor, window -1.5..+6.5 s
%     length_calculation  `distance`, method `maximum`, conditions `reference
%                       point` = `nearest bacterial patch edge` and the period:
%                       during (distanceOnMax: the largest signed distance from
%                       the patch edge, positive inside, so negative when the
%                       midpoint never crossed it; analyzeEncounters line 273,
%                       whose own header misnames it) and after (distanceOffMax,
%                       outside the patch, unsigned); mm -> m
%     score_calculation  `posterior probability`, keyed by encounter, one per
%                       state: condition `behavioral state` = `exploitation`
%                       (exploitPosterior, method `Gaussian mixture model
%                       clustering`) and = `sensing` (sensePosterior, method
%                       `quadratic discriminant analysis`); scale `probability`,
%                       0-1. timeSlowDown is not kept: no figure uses it
%     term_calculation  `encounter type`, method `classification`: `exploit`,
%                       `sample`, `search on patch` (source searchOn), `search
%                       off patch` (searchOff); `Cannot Be Determined` where the
%                       source left it blank; its method parameters (labels)
%                       the three posterior thresholds and search off patch's
%                       distance rule (0 m into the patch). A label_calculation of
%                       the same names on a schema with no term_calculation
%   A two-key value is stored in column-major order, the encounter fastest
%   (the notes say so). For the gap before the first encounter (the source's
%   id 0 row): one `speed`, method `median`, and one `distance`, method
%   `maximum` (reference point the nearest patch edge), each with condition
%   `patch encounter period` = `before the first patch encounter`.
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
%   OUT fields: documents, counts (struct), skipped (cellstr), byWorm
%   (containers.Map, worm local_identifier -> struct of wormId, listId,
%   plate (its assay plate's local_identifier), onset (each encounter's onset,
%   seconds, as in the list), timeId (the time reference those seconds are
%   from), calc (the session, time reference and run
%   environment options its documents are built with) and rows, its
%   encounter.mat rows in list order; for stage 12, decision #65).

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
    'encounters', 0, 'documents', 0), 'byWorm', containers.Map());
file = fullfile(dataParentDir, 'haley', 'celegans', 'encounter.mat');
if strcmp(folder, 'ecoli') || ~isfile(file)
    return;
end
if ~ndi.setup.V2.schemaHasField('time', 'value') || ~ndi.setup.V2.schemaHasLeaf('time_calculation')
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

% what the per-encounter documents share
before = periodCondition('before the first patch encounter');
during = periodCondition('during the patch encounter');
after = periodCondition('after the patch encounter');
signedNote = ['Signed distance of the midpoint from the patch edge, positive inside ' ...
    'the patch: negative when the midpoint never crossed the edge during the encounter.'];
offPatchNote = 'Distance of the midpoint outside the patch, unsigned.';
columnMajor = ['Values in column-major order: every encounter''s value for the first ' ...
    'position of the second key, then for the second.'];
detection = {'Method', haleyTerm('patch encounter detection'), 'MethodParameters', ...
    did2.build.list(did2.build.parameter(haleyTerm('body part'), 'Term', haleyTerm('midpoint')))};
hasTerm = ndi.setup.V2.schemaHasLeaf('term_calculation');

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
    % A video that is not a recording (a failed start with no file, which
    % stage 5 reports as rowWithoutFile) holds none of the worm's track; the
    % worm is skipped only when a row of its track is on such a video.
    if ~any(onR) || ~all(ismember(unique(W.videoNum), vids.videoNum(onR)))
        out.skipped{end+1} = sprintf('%s: its track is on a video of %s that is not a recording of this session', ...
            worm, plate);
        continue;
    end
    vids = vids(onR, :);
    epochs = epochs(onR);
    where = where(onR);
    start = R.local_start(where);
    rate = R.frame_rate(where);
    % each video's measured frame times when it was decoded (decision #87),
    % else frame k is taken at (k-1)/frame rate
    ft = arrayfun(@(w) {frameTimesOf(R, w)}, where);
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
    secondsAt = @(idx) arrayfun(@(i) rowSeconds(W, i, vids, start, rate, t0, ft), idx);

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

    enc = rows(rows.id >= 1 & ~isnan(rows.enter), :);
    gap0 = rows(rows.id == 0, :);
    n = height(enc);
    out.counts.worms = out.counts.worms + 1;

    % the gap before the first encounter
    if height(gap0) == 1
        if ~isnan(gap0.velocityOff)
            docs{end+1} = did2.build.statement('velocity_calculation', wormId, haleyTerm('speed'), ...
                speed(gap0.velocityOff), 'Method', haleyTerm('median'), ...
                'Conditions', did2.build.list(before), 'InputIds', inputs, calc{:}); %#ok<AGROW>
        end
        if ~isnan(gap0.distanceOffMax)
            docs{end+1} = did2.build.statement('length_calculation', wormId, haleyTerm('distance'), ...
                mm(gap0.distanceOffMax), 'Method', haleyTerm('maximum'), ...
                'Conditions', did2.build.list(edgeCondition(), before), ...
                'Notes', offPatchNote, 'InputIds', inputs, calc{:}); %#ok<AGROW>
        end
    end
    if n == 0
        continue;
    end
    out.counts.encounters = out.counts.encounters + n;

    % the encounter list
    onset = secondsAt(enc.enter);
    list = did2.build.statement('time_calculation', wormId, ...
        haleyTerm('encounter onset time'), did2.build.valueCell('time', onset), ...
        'Keys', did2.build.list(did2.build.key(haleyTerm('encounter'), n, 'Origin', 0, 'Spacing', 1)), ...
        detection{:}, 'InputIds', inputs, ...
        'Notes', ['Seconds from the start of the plate''s first recording; the source''s ' ...
        '`enter`, a row of the worm''s track over the plate''s videos joined in order.'], calc{:});
    docs{end+1} = list; %#ok<AGROW>
    if byRef
        encKey = did2.build.key(haleyTerm('encounter'), n, 'PositionsFrom', 0);
        keyIds = {'KeyIds', {list.base.id}};
    else                                    % the builder or schema predates key_id
        encKey = did2.build.key(haleyTerm('encounter'), n, 'Origin', 0, 'Spacing', 1);
        keyIds = {};
    end
    % the keys of a per-encounter value: the encounter, then any other
    % dimension (its values in column-major order, the encounter fastest)
    keysWith = @(varargin) [{'Keys', did2.build.list(encKey, varargin{:})}, keyIds];
    keyed = keysWith();
    per = [{'InputIds', [{list.base.id}, inputs]}, calc];
    out.byWorm(worm) = struct('wormId', wormId, 'listId', list.base.id, 'plate', plate, ...
        'onset', onset(:), 'timeId', timeId, 'calc', {calc}, 'rows', enc);

    % which patch
    pIds = patchIds(subjectIds, plate);
    if hasItem && all(enc.lawnID >= 1 & enc.lawnID <= numel(pIds))
        v = struct('item', enc.lawnID(:)' - 1, 'offset', secondsAt(enc.exit)');
        docs{end+1} = did2.build.statement('item_calculation', wormId, ...
            haleyTerm('bacterial patch in contact'), v, 'Edges', struct('item_id', {pIds}), ...
            detection{:}, keyed{:}, per{:}); %#ok<AGROW>
    elseif hasItem
        out.skipped{end+1} = sprintf('%s: an encounter names a patch %s does not have; no patch list', ...
            worm, plate);
    end

    % median speed during and after each encounter: one array, keyed by period
    if all(ismember({'velocityOn', 'velocityOff'}, enc.Properties.VariableNames))
        x = [double(enc.velocityOn), double(enc.velocityOff)];
        byPeriod = keysWith(did2.build.key(haleyTerm('patch encounter period'), 2, 'Labels', ...
            haleyTerm({'during the patch encounter', 'after the patch encounter'})));
        docs{end+1} = did2.build.statement('velocity_calculation', wormId, haleyTerm('speed'), ...
            speed(x), 'Method', haleyTerm('median'), byPeriod{:}, ...
            'Notes', [columnMajor ' After the last encounter: NaN when the track ends first.'], ...
            per{:}); %#ok<AGROW>
    elseif any(ismember({'velocityOn', 'velocityOff'}, enc.Properties.VariableNames))
        out.skipped{end+1} = sprintf('%s: encounter.mat has only one of velocityOn / velocityOff; no median speeds', ...
            worm);
    end

    % the other per-encounter values, each with its own method and conditions
    q = {
        'velocity_calculation', 'speed', 'velocityOnMin', @speed, ...
            {'Method', haleyTerm('minimum')}, {during}, ''
        'velocity_calculation', 'speed', 'velocityBeforeEnter', @speed, ...
            {'Method', haleyTerm('peak speed before an event')}, ...
            eventWindow(-10, 0), ''
        'velocity_calculation', 'speed', 'velocityAfterEnter', @speed, ...
            {'Method', haleyTerm('minimum speed after an event')}, eventWindow(0, 10), ''
        'acceleration_calculation', 'acceleration', 'decelerate', @accel, ...
            {'Method', haleyTerm('ordinary least squares estimation')}, eventWindow(-1.5, 6.5), ''
        'length_calculation', 'distance', 'distanceOnMax', @mm, ...
            {'Method', haleyTerm('maximum')}, {edgeCondition(), during}, signedNote
        'length_calculation', 'distance', 'distanceOffMax', @mm, ...
            {'Method', haleyTerm('maximum')}, {edgeCondition(), after}, offPatchNote};
    for j = 1:size(q, 1)
        if ~ismember(q{j, 3}, enc.Properties.VariableNames), continue; end
        x = double(enc.(q{j, 3}));
        note = {};
        if ~isempty(q{j, 7}), note = {'Notes', q{j, 7}}; end
        docs{end+1} = did2.build.statement(q{j, 1}, wormId, haleyTerm(q{j, 2}), ...
            q{j, 4}(x), q{j, 5}{:}, 'Conditions', did2.build.list(q{j, 6}{:}), ...
            keyed{:}, note{:}, per{:}); %#ok<AGROW>
    end

    % the posterior probabilities of exploitation and sensing: two statements,
    % because two models made them (labelEncounters: a Gaussian mixture model
    % of log duration and log on-patch speed; a semi-supervised quadratic
    % discriminant analysis of three speed features), each with the state as
    % its condition (T16)
    posteriors = {
        'exploitPosterior', 'exploitation', 'Gaussian mixture model clustering'
        'sensePosterior',   'sensing',      'quadratic discriminant analysis'};
    for j = 1:size(posteriors, 1)
        if ~ismember(posteriors{j, 1}, enc.Properties.VariableNames), continue; end
        docs{end+1} = did2.build.statement('score_calculation', wormId, ...
            haleyTerm('posterior probability'), prob(double(enc.(posteriors{j, 1}))), ...
            'Method', haleyTerm(posteriors{j, 3}), ...
            'Conditions', did2.build.list(did2.build.condition(haleyTerm('behavioral state'), ...
                'Term', haleyTerm(posteriors{j, 2}))), ...
            keyed{:}, per{:}); %#ok<AGROW>
    end

    % the encounter type, from thresholds on the posteriors
    if ismember('label', enc.Properties.VariableNames)
        names = reshape(cellstr(enc.label), 1, []);
        typeArgs = {'Method', haleyTerm('classification'), 'MethodParameters', did2.build.list( ...
                did2.build.parameter(did2.build.term('', 'exploit: minimum probability of exploitation'), 'Value', 0.5), ...
                did2.build.parameter(did2.build.term('', 'sample: minimum probability of sensing'), 'Value', 0.5), ...
                did2.build.parameter(did2.build.term('', 'search off patch: probability of sensing below'), 'Value', 0.05), ...
                did2.build.parameter(did2.build.term('', 'search off patch: maximum distance into the patch'), ...
                    'Value', 0, 'Unit', haleyTerm('meter'))), ...
            'Notes', ['Each encounter''s type from its two posteriors (labelEncounters lines 379-384). ' ...
                'Search off patch also needs the midpoint never to have crossed the patch edge ' ...
                '(distanceOnMax < 0). Cannot Be Determined marks an encounter with a missing ' ...
                'posterior, which the source leaves unlabeled.'], ...
            keyed{:}, per{:}};
        if hasTerm
            docs{end+1} = did2.build.statement('term_calculation', wormId, ...
                haleyTerm('encounter type'), encounterTypes(names), typeArgs{:}); %#ok<AGROW>
        else                                % a schema with no term_calculation
            t = encounterTypes(names);
            docs{end+1} = did2.build.statement('label_calculation', wormId, ...
                haleyTerm('encounter type'), struct('name', {t.name}), typeArgs{:}); %#ok<AGROW>
        end
    end
end
out.documents = docs;
out.counts.documents = numel(docs);
end

% -----------------------------------------------------------------------------
function s = rowSeconds(W, i, vids, start, rate, t0, ft)
% seconds from T0 of row I of the worm's joined track: the frame's measured
% time in its video (decision #87) when the video was decoded, else
% (frame - 1) / frame rate
arguments
    W table
    i (1,1) {mustBeNumeric}
    vids table
    start
    rate
    t0
    ft cell
end
if isnan(i) || i < 1 || i > height(W)
    s = NaN;
    return;
end
v = find(vids.videoNum == W.videoNum(i), 1);
f = double(W.frameNum(i));
if f >= 1 && f <= numel(ft{v}) && f == round(f)
    s = seconds(start(v) - t0) + ft{v}(f);
else
    s = seconds(start(v) - t0) + (f - 1) / rate(v);
end
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

function v = speed(x)
arguments
    x
end
v = did2.build.valueCell('velocity', x(:)' * 1e-6, 'SourceValue', x(:)', 'SourceUnit', 'um/s');
end

function v = accel(x)
arguments
    x
end
v = did2.build.valueCell('acceleration', x(:)' * 1e-6, 'SourceValue', x(:)', 'SourceUnit', 'um/s^2');
end

function v = mm(x)
arguments
    x
end
v = did2.build.valueCell('length', x(:)' * 1e-3, 'SourceValue', x(:)', 'SourceUnit', 'mm');
end

function v = prob(x)
arguments
    x
end
v = did2.build.valueCell('score', x(:)', 'Fields', struct( ...
    'scale', haleyTerm('probability'), 'scale_min', 0, 'scale_max', 1));
end

function e = epochOf(pre, name)
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

function c = periodCondition(period)
% the condition `patch encounter period` = PERIOD (a decided term's name)
arguments
    period {mustBeText}
end
c = did2.build.condition(haleyTerm('patch encounter period'), 'Term', haleyTerm(period));
end

function c = edgeCondition()
% the condition `reference point` = the nearest bacterial patch edge
c = did2.build.condition(haleyTerm('reference point'), 'Term', ...
    haleyTerm('nearest bacterial patch edge'));
end

function c = eventWindow(t0, t1)
% the conditions of a value computed over a window around each encounter's
% onset: from T0 to T1 seconds after it
arguments
    t0 (1,1) double
    t1 (1,1) double
end
c = {did2.build.condition(haleyTerm('reference time point'), 'Term', haleyTerm('encounter onset time')), ...
    did2.build.condition(haleyTerm('analysis window start'), 'Quantity', t0, 'Unit', haleyTerm('second')), ...
    did2.build.condition(haleyTerm('analysis window end'), 'Quantity', t1, 'Unit', haleyTerm('second'))};
end

function t = encounterTypes(names)
% each encounter's type as a term: labelEncounters' labels are the decided
% types (searchOn / searchOff the search on / off patch ones); a blank label is
% `Cannot Be Determined` (a posterior is missing, so no rule applies; Jess,
% 2026-10-20), and any other label is kept as written
arguments
    names cell
end
source = {'exploit', 'sample', 'searchOn', 'searchOff'};
decided = {'exploit', 'sample', 'search on patch', 'search off patch'};
t = cell(1, numel(names));
for k = 1:numel(names)
    [hit, at] = ismember(names{k}, source);
    if hit
        t{k} = haleyTerm(decided{at});
    elseif isempty(strtrim(names{k}))
        t{k} = haleyTerm('cannot be determined');
    else
        t{k} = did2.build.term('', names{k});
    end
end
t = [t{:}];
end
