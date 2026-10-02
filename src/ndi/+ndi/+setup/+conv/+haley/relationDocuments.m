function out = relationDocuments(session, S, R, subjectIds, options)
%RELATIONDOCUMENTS Stage 6 (Haley): how one session's subjects are related.
%
%   OUT = ndi.setup.conv.haley.relationDocuments(SESSION, S, R, SUBJECTIDS)
%   builds the directed_relation documents among the subjects of the
%   one-row session table SESSION (from sessionList, with `session_id`
%   assigned). S and R are the subject and recording tables (subjectList,
%   recordingList); SUBJECTIDS maps each subject's local_identifier to its
%   document id (ndi.setup.conv.haley.sessionDocuments returns it). Nothing
%   is written here. Decision log #52, #53.
%
%   Relations (child -> parent):
%     patch  part_of       its plate (assay plate, or E. coli plate). No
%                          time: a patch is part of its plate for the
%                          plate's whole life.
%     worm   contained_in  each plate it was on, in turn: its acclimation
%                          plate from the pick (`growthTimePicked`), its
%                          food deprivation plate if it has one from the move
%                          to it (`starvedTime`), its assay plate from the
%                          transfer T; each window ends when the next starts,
%                          the assay window when filming ends. T is not
%                          recorded: it is read off the plate's videos with
%                          the spec's `transfer_protocol`
%                          (ndi.setup.conv.haley.transferTime) -- the lawn
%                          clip's start where the contrast video was filmed
%                          after the worms went on, else the first behaviour
%                          video's start -- marked approximate (the assay
%                          window's start, and the end of the window before it). No time where the source
%                          has none (an unfilmed plate, a missing pick time).
%                          Each time carries its own bound (`tolerance`
%                          [minus plus] s, CHANGE 7; decisions #52, #53):
%                          the pick and starvedTime, read off a clock and
%                          written to the minute, the spec's
%                          `hand_written_tolerance_seconds` (+/- 60) and a
%                          minute-resolution source_value; T [max_before 0]
%                          or tighter (transferTime) -- it is only ever early;
%                          a window's duration the sum of its ends' bounds.
%                          Exact (no tolerance): video times -- the end of
%                          filming here; each epoch's own reference states
%                          them exactly.
%                          One time reference per (plate, assay plate),
%                          shared by the plate's worms (moved together).
%
%   Wall-clock times are America/Los_Angeles, as everywhere in this import.
%
%   Option 'Protocol': the spec's `transfer_protocol` section (default: none,
%   so T is the first behaviour video's start everywhere).
%
%   OUT fields: documents (cell of structs: relations and their time
%   references), counts (struct: one count per relation kind), skipped
%   (cellstr: a relation whose parent is not a subject of this session).

arguments
    session table
    S table
    R table
    subjectIds
    options.Protocol = struct()
end
if height(session) ~= 1
    error('ndi:setup:conv:haley:oneSession', 'Give exactly one session row.');
end
sid = char(session.session_id{1});
ref = char(session.local_identifier{1});
tz = 'America/Los_Angeles';
S = S(strcmp(S.session, ref), :);
R = R(strcmp(R.session, ref), :);

out = struct('documents', {{}}, 'skipped', {{}}, 'counts', struct( ...
    'patch_part_of_plate', 0, 'worm_in_assay_plate', 0, 'worm_in_acclimation_plate', 0, ...
    'worm_in_food_deprivation_plate', 0));
docs = {};

% ---- patch part_of plate --------------------------------------------------------
patches = S(strcmp(S.kind, 'patch'), :);
for k = 1:height(patches)
    child = patches.local_identifier{k};
    parent = regexprep(child, '_patch\d+$', '');   % <plate>_patchNNNN (decision #42)
    [docs, out] = relate(docs, out, subjectIds, child, parent, 'part_of', {}, sid, ...
        'patch_part_of_plate');
end

% ---- worms: each plate the worm was on, in turn --------------------------------
% acclimation plate (from the pick) -> [food deprivation plate (from
% starvedTime)] -> assay plate (from the transfer T). Each window runs from
% its plate's start to the next one's; the assay window ends with filming.
% T is not recorded: ndi.setup.conv.haley.transferTime reads it off the
% plate's videos with the spec's transfer protocol (approximate either way).
behaviour = R(strcmp(R.kind, 'behaviour'), :);
plates = S(strcmp(S.kind, 'assay_plate'), :);
holding = S(ismember(S.kind, {'acclimation_plate', 'food_deprivation_plate'}), :);
worms = S(strcmp(S.kind, 'worm'), :);
lawns = R(strcmp(R.kind, 'lawn'), :);
spanOf = containers.Map();      % assay plate id -> struct T, tol, stop (no zone)
handTol = [60 60];              % a time read off a clock and written to the minute
if isfield(options.Protocol, 'hand_written_tolerance_seconds')
    handTol = reshape(double(options.Protocol.hand_written_tolerance_seconds), 1, 2);
end
minuteFmt = 'yyyy-MM-dd''T''HH:mm';     % written to the minute: source_value says so
secondFmt = 'yyyy-MM-dd''T''HH:mm:ss';  % read off a video's timestamp
for k = 1:height(plates)
    id = plates.local_identifier{k};
    v = behaviour(strcmp(behaviour.plate, id), :);
    if height(v) == 0
        continue;
    end
    dur = v.duration;
    dur(isnan(dur)) = 0;
    t = wallClock(v.local_start, tz);
    [t0, first] = min(t);
    [~, stem] = fileparts(v.file{first});
    l = lawns(strcmp(lawns.plate, id), :);
    lawnStart = NaT; lawnEnd = NaT;
    stems = {stem};
    if height(l) > 0
        [lawnStart, li] = min(wallClock(l.local_start, tz));
        [~, stems{2}] = fileparts(l.file{li});   % an exception may name the lawn clip
        if ~isnan(l.duration(li))                % known with 'ReadVideos'
            lawnEnd = lawnStart + seconds(l.duration(li));
        end
    end
    [T, rule] = ndi.setup.conv.haley.transferTime(options.Protocol, plates.folder{k}, ...
        t0, lawnStart, stems, lawnEnd);
    spanOf(id) = struct('T', T, 'tol', rule.tolerance, 'stop', max(t + seconds(dur)));
end
refOf = containers.Map();       % plate id|assay plate id -> time reference id (shared)
for k = 1:height(worms)
    w = worms(k, :);
    plate = plates.local_identifier(plates.plate == w.plate & strcmp(plates.folder, w.folder));
    if isempty(plate)
        out.skipped{end+1} = sprintf('%s: no assay plate %d in this session', ...
            w.local_identifier{1}, w.plate); %#ok<AGROW>
        continue;
    end
    plate = plate{1};
    T = NaT; Ttol = []; filmedEnd = NaT;
    if isKey(spanOf, plate)
        span = spanOf(plate);
        T = span.T; Ttol = span.tol; filmedEnd = span.stop;
    end
    % each move: when (wall clock), its bound [minus plus] s, how it was written
    seq = struct('id', {}, 'start', {}, 'tol', {}, 'fmt', {}, 'counter', {});
    if ~isempty(w.acclimation{1})                % the pick: read off a clock
        seq(end+1) = struct('id', w.acclimation{1}, 'start', placed(holding, w.acclimation{1}, tz), ...
            'tol', handTol, 'fmt', minuteFmt, 'counter', 'worm_in_acclimation_plate'); %#ok<AGROW>
    end
    if ~isempty(w.deprivation{1})                % starvedTime: read off a clock
        seq(end+1) = struct('id', w.deprivation{1}, 'start', placed(holding, w.deprivation{1}, tz), ...
            'tol', handTol, 'fmt', minuteFmt, 'counter', 'worm_in_food_deprivation_plate'); %#ok<AGROW>
    end
    seq(end+1) = struct('id', plate, 'start', T, 'tol', Ttol, 'fmt', secondFmt, ...
        'counter', 'worm_in_assay_plate'); %#ok<AGROW>   % T: read off a video, early only
    for i = 1:numel(seq)
        if i < numel(seq)                        % ends when the next move starts
            stop = seq(i+1).start; stopTol = seq(i+1).tol; stopFmt = seq(i+1).fmt;
        else                                     % the end of filming: exact
            stop = filmedEnd; stopTol = []; stopFmt = secondFmt;
        end
        times = {};
        key = [seq(i).id '|' plate];
        if isKey(refOf, key)
            times = {refOf(key)};
        elseif ~isnat(seq(i).start)
            dur = [];
            if ~isnat(stop)
                dur = seconds(stop - seq(i).start);
                if dur < 0
                    out.skipped{end+1} = sprintf(['%s on %s: ends (%s) before it starts (%s); ' ...
                        'recorded with its start only'], w.local_identifier{1}, seq(i).id, ...
                        char(stop), char(seq(i).start)); %#ok<AGROW>
                    dur = [];
                end
            end
            d = utcReference(seq(i).start, seq(i).tol, seq(i).fmt, ...
                stop, stopTol, stopFmt, ~isempty(dur), tz, sid);
            docs{end+1} = d; %#ok<AGROW>
            refOf(key) = d.base.id;
            times = {d.base.id};
        end
        [docs, out] = relate(docs, out, subjectIds, w.local_identifier{1}, seq(i).id, ...
            'contained_in', times, sid, seq(i).counter);
    end
end
out.documents = docs;
end

% -----------------------------------------------------------------------------
function [docs, out] = relate(docs, out, ids, child, parent, relation, times, sid, counter)
if ~isKey(ids, child) || ~isKey(ids, parent)
    out.skipped{end+1} = sprintf('%s %s %s: not both subjects of this session', ...
        child, relation, parent);
    return;
end
docs{end+1} = did2.build.directedRelation(ids(child), ids(parent), relation, ...
    'TimeReferenceIds', times, 'SessionId', sid);
out.counts.(counter) = out.counts.(counter) + 1;
end

function t = wallClock(t, tz)
% The source's wall-clock time with no zone attached: a value that already
% carries a zone is first expressed in TZ.
if ~isempty(t.TimeZone)
    t.TimeZone = tz;
    t.TimeZone = '';
end
end

function t = placed(holding, id, tz)
% when the worms were put onto an acclimation / food deprivation plate
t = holding.worms_placed(strcmp(holding.local_identifier, id));
if isempty(t)
    t = NaT;
else
    t = wallClock(t(1), tz);
end
end

function d = utcReference(t0, tol0, fmt0, t1, tol1, fmt1, hasEnd, tz, sid)
% A window from T0 (wall clock) to T1 (when HASEND), each with its bound
% [minus plus] seconds ([] = exact) and the precision it was written at (FMT,
% so source_value does not invent seconds a hand-written time never had). The
% duration's bound follows: it is shortest when the start is late and the end
% early (minus = start.plus + end.minus), longest the other way round.
args = {'SourceValue', char(t0, fmt0), 'SourceTimezone', tz, ...
    'Approximate', ~isempty(tol0), 'Tolerance', tol0};
if hasEnd
    s0 = tol0; if isempty(s0), s0 = [0 0]; end
    e1 = tol1; if isempty(e1), e1 = [0 0]; end
    durTol = [s0(2) + e1(1), s0(1) + e1(2)];
    if all(durTol == 0), durTol = []; end
    args = [args, {'Duration', seconds(t1 - t0), ...
        'DurationApproximate', ~isempty(durTol), 'DurationTolerance', durTol, ...
        'End', utcText(t1, tz), 'EndSourceValue', char(t1, fmt1), 'EndSourceTimezone', tz, ...
        'EndApproximate', ~isempty(tol1), 'EndTolerance', tol1}];
end
d = did2.build.absoluteTimeReference(utcText(t0, tz), 'SessionId', sid, args{:});
end

function s = utcText(t, tz)
t.TimeZone = tz;
t.TimeZone = 'UTC';
s = char(t, 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''');
end
