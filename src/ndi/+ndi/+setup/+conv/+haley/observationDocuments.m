function out = observationDocuments(session, R, subjectIds, options)
%OBSERVATIONDOCUMENTS Stage 9 (Haley): the temperature and humidity readings.
%
%   OUT = ndi.setup.conv.haley.observationDocuments(SESSION, R, SUBJECTIDS, ...)
%   builds, for the one-row session table SESSION, an observation of each
%   filmed assay plate's ambient temperature and relative humidity, from the
%   behaviour videos' `temp` and `humidity` (R rows, from recordingList).
%   Decision log #59.
%
%   The lab's temperature probe read both; the value noted is its mean over
%   the hour of recording (Jess, 2026-10-03). Every video of a plate carries
%   the same reading (profiled over the five C. elegans studies, 0 of 597
%   plates differ), so there is ONE reading per plate, over the plate's
%   recordings: the video's own UTC reference when it was filmed once, else a
%   window from the first video's start to the last one's end. A plate whose
%   videos disagree gets none (reported in OUT.skipped). No value, no
%   observation.
%
%     temperature_observation  variable `ambient temperature` (the term the
%                              manipulations move a plate into), celsius
%     humidity_observation     variable `relative humidity`,
%                              percent_relative_humidity (did-schema PR #86;
%                              only when the schema in use has `humidity`)
%
%   Both: subject = the assay plate, instrument = the probe (stage 2), notes
%   = the spec's `environment.notes`.
%
%   Options:
%     'Environment'    the spec's `environment` section (required)
%     'InstrumentId'   the probe's document id ('' leaves instrument_id empty)
%     'RecordingRefs'  containers.Map, epoch -> its UTC reference id
%                      (sessionDocuments' OUT.recordingRefs)
%
%   OUT fields: documents (cell of structs), counts (struct: temperature,
%   humidity), skipped (cellstr).

arguments
    session table
    R table
    subjectIds
    options.Environment struct
    options.InstrumentId (1,:) char = ''
    options.RecordingRefs = containers.Map()
end
if height(session) ~= 1
    error('ndi:setup:conv:haley:oneSession', 'Give exactly one session row.');
end
sid = char(session.session_id{1});
ref = char(session.local_identifier{1});
tz = 'America/Los_Angeles';
cfg = options.Environment;
secondFmt = 'yyyy-MM-dd''T''HH:mm:ss';
hasHumidity = ndi.setup.V2.schemaHasField('humidity', 'value');

docs = {};
out = struct('documents', {{}}, 'skipped', {{}}, 'counts', struct('temperature', 0, 'humidity', 0));
if ~all(ismember({'temp', 'humidity'}, R.Properties.VariableNames))
    out.documents = docs;
    return;
end
R = R(strcmp(R.session, ref) & strcmp(R.kind, 'behaviour'), :);
R = R(~isnan(R.temp) | ~isnan(R.humidity), :);
if ~hasHumidity && any(~isnan(R.humidity))
    out.skipped{end+1} = sprintf(['%s: the schema in use has no `humidity` (did-schema PR #86); ' ...
        'no humidity observations'], ref);
end

plates = unique(R.plate, 'stable');
for k = 1:numel(plates)
    plate = plates{k};
    P = sortrows(R(strcmp(R.plate, plate), :), 'local_start');
    if ~isKey(subjectIds, plate)
        out.skipped{end+1} = sprintf('%s: not a subject of this session', plate);
        continue;
    end
    temp = oneValue(P.temp);
    humidity = oneValue(P.humidity);
    if isempty(temp) || isempty(humidity)
        out.skipped{end+1} = sprintf('%s: its %d videos disagree on temp or humidity; no reading', ...
            plate, height(P));
        continue;
    end
    timeId = window(P);
    if ~isnan(temp)
        v = did2.build.composite('temperature_observation', 'value', struct('celsius', temp, ...
            'source_value', temp, 'source_unit', 'C'));
        statement('temperature_observation', plate, cfg.temperature.variable, v, timeId, 'temperature');
    end
    if ~isnan(humidity) && hasHumidity
        v = did2.build.composite('humidity_observation', 'value', ...
            struct('percent_relative_humidity', humidity));
        statement('humidity_observation', plate, cfg.humidity.variable, v, timeId, 'humidity');
    end
end
out.documents = docs;

% =============================================================================
    function id = window(P)
        % the plate's recordings: one video's own reference, else first start
        % to last end (the video times are exact)
        if height(P) == 1 && isKey(options.RecordingRefs, P.epoch{1})
            id = options.RecordingRefs(P.epoch{1});
            return;
        end
        t0 = wallClock(P.local_start(1), tz);
        t1 = wallClock(P.local_start(end), tz) + seconds(P.duration(end));
        hasEnd = ~isnan(P.duration(end));
        if ~hasEnd, t1 = NaT; end
        d = utcReference(t0, [], secondFmt, t1, [], secondFmt, hasEnd, tz, sid);
        docs{end+1} = d;
        id = d.base.id;
    end

    function statement(leaf, plate, variable, value, timeId, counter)
        args = {'SessionId', sid, 'TimeReferenceIds', {timeId}};
        if ~isempty(options.InstrumentId), args = [args, {'InstrumentId', options.InstrumentId}]; end
        if isfield(cfg, 'notes') && ~isempty(cfg.notes), args = [args, {'Notes', cfg.notes}]; end
        docs{end+1} = did2.build.statement(leaf, subjectIds(plate), ...
            did2.build.term('', variable), value, args{:});
        out.counts.(counter) = out.counts.(counter) + 1;
    end
end

function v = oneValue(x)
% the one value X holds (NaN when none); [] when its values differ
u = unique(x(~isnan(x)));
if isempty(u)
    v = NaN;
elseif numel(u) == 1
    v = u;
else
    v = [];
end
end
