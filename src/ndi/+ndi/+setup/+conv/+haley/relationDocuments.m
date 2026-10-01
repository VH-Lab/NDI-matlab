function out = relationDocuments(session, S, R, subjectIds)
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
%                          recorded: the paper moves the worms "immediately
%                          prior" to recording and measures "time since
%                          transfer" as time elapsed in the recording, so T =
%                          the first behaviour video's start, marked
%                          approximate (the assay window's start, and the end
%                          of the window before it). No time where the source
%                          has none (an unfilmed plate, a missing pick time).
%                          One time reference per (plate, assay plate),
%                          shared by the plate's worms (moved together).
%
%   Wall-clock times are America/Los_Angeles, as everywhere in this import.
%
%   OUT fields: documents (cell of structs: relations and their time
%   references), counts (struct: one count per relation kind), skipped
%   (cellstr: a relation whose parent is not a subject of this session).

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
% T is not recorded: the paper's worms were moved "immediately prior" to
% recording and it measures "time since transfer" as time elapsed in the
% recording, so T = the first behaviour video's start, marked approximate.
behaviour = R(strcmp(R.kind, 'behaviour'), :);
plates = S(strcmp(S.kind, 'assay_plate'), :);
holding = S(ismember(S.kind, {'acclimation_plate', 'food_deprivation_plate'}), :);
worms = S(strcmp(S.kind, 'worm'), :);
spanOf = containers.Map();      % assay plate id -> [start end] (datetime, no zone)
for k = 1:height(plates)
    v = behaviour(strcmp(behaviour.plate, plates.local_identifier{k}), :);
    if height(v) == 0
        continue;
    end
    dur = v.duration;
    dur(isnan(dur)) = 0;
    t = wallClock(v.local_start, tz);
    spanOf(plates.local_identifier{k}) = [min(t), max(t + seconds(dur))];
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
    T = NaT; filmedEnd = NaT;
    if isKey(spanOf, plate)
        span = spanOf(plate);
        T = span(1); filmedEnd = span(2);
    end
    seq = struct('id', {}, 'start', {}, 'approx', {}, 'counter', {});
    if ~isempty(w.acclimation{1})
        seq(end+1) = struct('id', w.acclimation{1}, 'start', placed(holding, w.acclimation{1}, tz), ...
            'approx', false, 'counter', 'worm_in_acclimation_plate'); %#ok<AGROW>
    end
    if ~isempty(w.deprivation{1})
        seq(end+1) = struct('id', w.deprivation{1}, 'start', placed(holding, w.deprivation{1}, tz), ...
            'approx', false, 'counter', 'worm_in_food_deprivation_plate'); %#ok<AGROW>
    end
    seq(end+1) = struct('id', plate, 'start', T, 'approx', true, ...
        'counter', 'worm_in_assay_plate'); %#ok<AGROW>
    for i = 1:numel(seq)
        if i < numel(seq)
            stop = seq(i+1).start; stopApprox = seq(i+1).approx;
        else
            stop = filmedEnd; stopApprox = false;
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
            d = utcReference(seq(i).start, dur, seq(i).approx, stopApprox && ~isempty(dur), tz, sid);
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

function d = utcReference(localStart, dur, approximateStart, approximateEnd, tz, sid)
t = localStart;
t.TimeZone = tz;
u = t;
u.TimeZone = 'UTC';
args = {};
if approximateStart
    args = [args, {'Approximate', true}];
end
if approximateEnd
    args = [args, {'DurationApproximate', true}];
end
d = did2.build.absoluteTimeReference(char(u, 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''), ...
    'SourceValue', char(t, 'yyyy-MM-dd''T''HH:mm:ss'), 'SourceTimezone', tz, ...
    'Duration', dur, 'SessionId', sid, args{:});
end
