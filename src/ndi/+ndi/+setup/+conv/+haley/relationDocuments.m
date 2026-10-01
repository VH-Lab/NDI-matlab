function out = relationDocuments(session, S, R, subjectIds)
%RELATIONDOCUMENTS Stage 6 (Haley): how one session's subjects are related.
%
%   OUT = ndi.setup.conv.haley.relationDocuments(SESSION, S, R, SUBJECTIDS)
%   builds the directed_relation documents among the subjects of the
%   one-row session table SESSION (from sessionList, with `session_id`
%   assigned). S and R are the subject and recording tables (subjectList,
%   recordingList); SUBJECTIDS maps each subject's local_identifier to its
%   document id (ndi.setup.conv.haley.sessionDocuments returns it). Nothing
%   is written here. Decision log #52.
%
%   Relations (child -> parent):
%     patch  part_of       its plate (assay plate, or E. coli plate). No
%                          time: a patch is part of its plate for the
%                          plate's whole life.
%     worm   contained_in  its assay plate, while it was filmed: the plate's
%                          UTC span from its first behaviour video's start
%                          to its last one's end (an absolute_time_reference).
%                          No time when the plate has no behaviour video.
%     worm   contained_in  its acclimation plate, from the pick time
%                          (`growthTimePicked`) to the start of its assay
%                          plate's first behaviour video, that end marked
%                          approximate (the worm was moved shortly before
%                          filming; the transfer time is not recorded). Only
%                          the start when the plate was not filmed; no time
%                          when the pick time is not recorded.
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
    'patch_part_of_plate', 0, 'worm_in_assay_plate', 0, 'worm_in_acclimation_plate', 0));
docs = {};

% ---- patch part_of plate --------------------------------------------------------
patches = S(strcmp(S.kind, 'patch'), :);
for k = 1:height(patches)
    child = patches.local_identifier{k};
    parent = regexprep(child, '_patch\d+$', '');   % <plate>_patchNNNN (decision #42)
    [docs, out] = relate(docs, out, subjectIds, child, parent, 'part_of', {}, sid, ...
        'patch_part_of_plate');
end

% ---- worms: the assay plate while filmed, the acclimation plate before ----------
behaviour = R(strcmp(R.kind, 'behaviour'), :);
plates = S(strcmp(S.kind, 'assay_plate'), :);
picks = S(strcmp(S.kind, 'acclimation_plate'), :);
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
assayRef = containers.Map();    % assay plate id -> time reference id (one per plate, shared)
accRef = containers.Map();      % acclimation id|assay plate id -> time reference id (shared)
for k = 1:height(worms)
    w = worms(k, :);
    plate = plates.local_identifier(plates.plate == w.plate & strcmp(plates.folder, w.folder));
    if isempty(plate)
        out.skipped{end+1} = sprintf('%s: no assay plate %d in this session', ...
            w.local_identifier{1}, w.plate); %#ok<AGROW>
        continue;
    end
    plate = plate{1};
    times = {};
    if isKey(spanOf, plate)
        if ~isKey(assayRef, plate)
            span = spanOf(plate);
            d = utcReference(span(1), seconds(span(2) - span(1)), false, tz, sid);
            docs{end+1} = d; %#ok<AGROW>
            assayRef(plate) = d.base.id;
        end
        times = {assayRef(plate)};
    end
    [docs, out] = relate(docs, out, subjectIds, w.local_identifier{1}, plate, 'contained_in', ...
        times, sid, 'worm_in_assay_plate');

    acc = w.acclimation{1};
    if isempty(acc)
        continue;
    end
    times = {};
    p = picks.pick(strcmp(picks.local_identifier, acc));
    key = [acc '|' plate];
    if isKey(accRef, key)
        times = {accRef(key)};
    elseif ~isempty(p) && ~isnat(p(1))
        p = wallClock(p(1), tz);
        if isKey(spanOf, plate)
            span = spanOf(plate);
            d = utcReference(p, seconds(span(1) - p), true, tz, sid);
        else
            d = utcReference(p, [], false, tz, sid);
        end
        docs{end+1} = d; %#ok<AGROW>
        accRef(key) = d.base.id;
        times = {d.base.id};
    end
    [docs, out] = relate(docs, out, subjectIds, w.local_identifier{1}, acc, 'contained_in', ...
        times, sid, 'worm_in_acclimation_plate');
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

function d = utcReference(localStart, dur, approximateEnd, tz, sid)
t = localStart;
t.TimeZone = tz;
u = t;
u.TimeZone = 'UTC';
args = {};
if approximateEnd
    args = {'DurationApproximate', true};
end
d = did2.build.absoluteTimeReference(char(u, 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''), ...
    'SourceValue', char(t, 'yyyy-MM-dd''T''HH:mm:ss'), 'SourceTimezone', tz, ...
    'Duration', dur, 'SessionId', sid, args{:});
end
