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
%     temperature observation  variable ambient temperature (NCIT:C90380, the
%                              term the manipulations move a plate into),
%                              celsius
%     humidity observation     variable relative humidity (om:RelativeHumidity),
%                              percent_relative_humidity (did-schema PR #86)
%
%   Both: subject = the assay plate, instrument = the probe (stage 2), method
%   NCIT:C53319 Arithmetic Mean (the value is the probe's mean over the hour:
%   tenet T16, a summary is stated as its quantity with the statistic as its
%   method; decision #121, superseding #59's "no method"), notes = the spec's
%   `environment.notes`.
%
%   Options:
%     'Environment'    the spec's `environment` section (required)
%     'InstrumentId'   the probe's document id ('' leaves instrument_id empty)
%     'RecordingRefs'  containers.Map, epoch -> its UTC reference id
%                      (sessionDocuments' OUT.recordingRefs)
%
%   OUT fields: documents (cell of structs), counts (struct: temperature,
%   humidity), skipped (cellstr), windows (containers.Map, plate -> the id of
%   the time reference spanning its recordings, for stage 11), windowStarts
%   (containers.Map, plate -> that window's start, wall clock: stage 11 uses
%   the window only when it starts at the plate's first recording, decision
%   #118).

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

docs = {};
out = struct('documents', {{}}, 'skipped', {{}}, 'counts', struct('temperature', 0, 'humidity', 0), ...
    'windows', containers.Map(), 'windowStarts', containers.Map());
if ~all(ismember({'temp', 'humidity'}, R.Properties.VariableNames))
    out.documents = docs;
    return;
end
R = R(strcmp(R.session, ref) & strcmp(R.kind, 'behaviour'), :);
R = R(~isnan(R.temp) | ~isnan(R.humidity), :);

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
    out.windows(plate) = timeId;
    out.windowStarts(plate) = wallClock(P.local_start(1), tz);
    if ~isnan(temp)
        v = did2.build.composite('temperature', 'value', struct('celsius', temp, ...
            'source_value', temp, 'source_unit', ndi.setup.V2.sourceUnit('C')));
        statement('temperature', plate, cfg.temperature.variable, v, timeId, 'temperature');
    end
    if ~isnan(humidity)
        v = did2.build.composite('humidity', 'value', ...
            struct('percent_relative_humidity', humidity));
        statement('humidity', plate, cfg.humidity.variable, v, timeId, 'humidity');
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
        d = ndi.setup.V2.utcReference(t0, tz, sid, 'Format', secondFmt, 'End', t1);
        docs{end+1} = d;
        id = d.base.id;
    end

    function statement(kind, plate, variable, value, timeId, counter)
        args = {'SessionId', sid, 'TimeReferenceIds', {timeId}, 'Method', haleyTerm('mean')};
        if ~isempty(options.InstrumentId), args = [args, {'InstrumentId', options.InstrumentId}]; end
        if isfield(cfg, 'notes') && ~isempty(cfg.notes), args = [args, {'Notes', cfg.notes}]; end
        docs{end+1} = did2.build.statement('observation', subjectIds(plate), ...
            haleyTerm(variable), value, args{:}, 'ValueKind', kind);
        out.counts.(counter) = out.counts.(counter) + 1;
    end
end

function v = oneValue(x)
% the one value X holds (NaN when none); [] when its values differ
arguments
    x {mustBeNumeric}
end
u = unique(x(~isnan(x)));
if isempty(u)
    v = NaN;
elseif numel(u) == 1
    v = u;
else
    v = [];
end
end
