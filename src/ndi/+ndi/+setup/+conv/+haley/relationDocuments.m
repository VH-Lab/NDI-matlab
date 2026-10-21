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
%     patch  contained_in  its plate (assay plate, acclimation plate, or
%                          E. coli plate; decision #107, replacing #52's
%                          part_of): a patch is a population of bacteria on
%                          the plate's agar, not a piece of the plate, so the
%                          plate's assertions (its kind, its target spacing,
%                          its exclusion) are not the patch's (tenet T17), and
%                          the plate's manipulations (cold room, room
%                          temperature, incubator) reach it as context while
%                          it is there. From the plate's seeding (hand-written,
%                          its bound plus any spread, decision #75) to the
%                          plate's last recording: the end of filming on an
%                          assay plate, the last image on an E. coli plate
%                          (exact). An acclimation plate has no recording: its
%                          patch's stay ends with the last move of worms off
%                          the plate (their food deprivation plate's start or
%                          the transfer T, with its bound), the latest time
%                          the source shows the patch there (decision #130); a
%                          plate with no seeding time gives a stay with no
%                          time.
%     worm   member_of     its cohort (the worms of its assay plate, moved
%                          together; decision #55). No time.
%     cohort contained_in  each plate its worms were on, in turn: its acclimation
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
%                          Stated once, on the cohort, with `distributive`
%                          true (it holds of each worm) when the schema has
%                          the field (did-schema #84).
%
%   Wall-clock times are America/Los_Angeles, as everywhere in this import.
%
%   Option 'Protocol': the spec's `transfer_protocol` section (default: none,
%   so T is the first behaviour video's start everywhere).
%
%   OUT fields: documents (cell of structs: relations and their time
%   references), counts (struct: one count per relation kind), skipped
%   (cellstr: a relation whose parent is not a subject of this session),
%   timeReferenceIds (containers.Map: '<plate>|<cohort>' -> the id of that
%   window's time reference, for the moves stage 8 states at the same times),
%   assaySpans (containers.Map: assay plate -> struct T, tol, stop, method:
%   the transfer time with its bound, the end of filming (wall clock) and the
%   protocol's transfer method, for the moves and windows of stage 8),
%   stayEnds (containers.Map: plate -> struct stop, tol, fmt: where its
%   patches' stay ends, for the windows of stage 8; decision #130).

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
    'patch_in_plate', 0, 'worm_member_of_cohort', 0, 'cohort_in_assay_plate', 0, ...
    'cohort_in_acclimation_plate', 0, 'cohort_in_food_deprivation_plate', 0), ...
    'timeReferenceIds', containers.Map(), 'assaySpans', containers.Map(), ...
    'stayEnds', containers.Map());
docs = {};
eachMember = struct('distributive', true);   % did-schema #84

% ---- worm member_of its cohort --------------------------------------------------
worms = S(strcmp(S.kind, 'worm'), :);
for k = 1:height(worms)
    if isempty(worms.cohort{k})
        continue;
    end
    [docs, out] = relate(docs, out, subjectIds, worms.local_identifier{k}, worms.cohort{k}, ...
        'member_of', {}, sid, 'worm_member_of_cohort', struct());
end

% ---- cohorts: each plate the worms were on, in turn ----------------------------
% acclimation plate (from the pick) -> [food deprivation plate (from
% starvedTime)] -> assay plate (from the transfer T). Each window runs from
% its plate's start to the next one's; the assay window ends with filming.
% T is not recorded: ndi.setup.conv.haley.transferTime reads it off the
% plate's videos with the spec's transfer protocol (approximate either way).
behaviour = R(strcmp(R.kind, 'behaviour'), :);
plates = S(strcmp(S.kind, 'assay_plate'), :);
holding = S(ismember(S.kind, {'acclimation_plate', 'food_deprivation_plate'}), :);
cohorts = S(strcmp(S.kind, 'cohort'), :);
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
    spanOf(id) = struct('T', T, 'tol', rule.tolerance, 'stop', max(t + seconds(dur)), ...
        'method', rule.method);
end
% ---- patch contained_in its plate (decision #107) ------------------------------
images = R(strcmp(R.kind, 'image'), :);
patches = S(strcmp(S.kind, 'patch'), :);
stayOf = containers.Map();      % plate id -> the time reference its patches share
for k = 1:height(patches)
    child = patches.local_identifier{k};
    parent = regexprep(child, '_patch\d+$', '');   % <plate>_patchNNNN (decision #42)
    if ~isKey(stayOf, parent)
        stayOf(parent) = patchStay(parent);
    end
    times = {};
    if ~isempty(stayOf(parent))
        times = {stayOf(parent)};
    end
    [docs, out] = relate(docs, out, subjectIds, child, parent, 'contained_in', times, sid, ...
        'patch_in_plate', struct());
end

refOf = containers.Map();       % plate id|cohort id -> time reference id
for k = 1:height(cohorts)
    w = cohorts(k, :);
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
            'tol', handTol, 'fmt', minuteFmt, 'counter', 'cohort_in_acclimation_plate'); %#ok<AGROW>
    end
    if ~isempty(w.deprivation{1})                % starvedTime: read off a clock
        seq(end+1) = struct('id', w.deprivation{1}, 'start', placed(holding, w.deprivation{1}, tz), ...
            'tol', handTol, 'fmt', minuteFmt, 'counter', 'cohort_in_food_deprivation_plate'); %#ok<AGROW>
    end
    seq(end+1) = struct('id', plate, 'start', T, 'tol', Ttol, 'fmt', secondFmt, ...
        'counter', 'cohort_in_assay_plate'); %#ok<AGROW>   % T: read off a video, early only
    for i = 1:numel(seq)
        if i < numel(seq)                        % ends when the next move starts
            stop = seq(i+1).start; stopTol = seq(i+1).tol; stopFmt = seq(i+1).fmt;
        else                                     % the end of filming: exact
            stop = filmedEnd; stopTol = []; stopFmt = secondFmt;
        end
        times = {};
        key = [seq(i).id '|' w.local_identifier{1}];
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
            'contained_in', times, sid, seq(i).counter, eachMember);
    end
end
out.documents = docs;
out.timeReferenceIds = refOf;
out.assaySpans = spanOf;

    function id = patchStay(plate)
        % a plate's patches: from its seeding to its last recording (the id of
        % the time reference, '' with no seeding time)
        id = '';
        h = find(strcmp(S.local_identifier, plate), 1);
        if isempty(h) || ~ismember('prep', S.Properties.VariableNames)
            return;
        end
        p = S.prep(h);
        if ~isstruct(p) || ~isfield(p, 'seeded') || isnat(p.seeded)
            return;
        end
        t0 = wallClock(p.seeded, tz);
        tol = handTol;
        if isfield(p, 'seeded_spread_s') && ~isempty(p.seeded_spread_s) && ~isnan(p.seeded_spread_s)
            tol = tol + p.seeded_spread_s;      % a seeding known only to a span (#75)
        end
        stop = NaT; stopTol = []; stopFmt = secondFmt;
        if isKey(spanOf, plate)                 % an assay plate: the end of filming
            stop = spanOf(plate).stop;
        elseif strcmp(S.kind{h}, 'acclimation_plate')
            % no recording: the last move of worms off it (decision #130)
            [stop, stopTol, stopFmt] = lastMoveOff(plate);
        else                                    % an E. coli plate: its last image
            im = images(strcmp(images.plate, plate), :);
            if height(im) > 0
                stop = max(wallClock(im.local_start, tz));
            end
        end
        hasEnd = ~isnat(stop);
        if hasEnd && stop < t0
            out.skipped{end+1} = sprintf(['%s patches: the last recording (%s) is before ' ...
                'the seeding (%s); the stay is recorded with its start only'], plate, ...
                char(stop), char(t0));
            hasEnd = false;
        end
        if hasEnd
            out.stayEnds(plate) = struct('stop', stop, 'tol', stopTol, 'fmt', stopFmt);
        end
        d = utcReference(t0, tol, minuteFmt, stop, stopTol, stopFmt, hasEnd, tz, sid);
        docs{end+1} = d;
        id = d.base.id;
    end

    function [t, tol, fmt] = lastMoveOff(accId)
        % the latest time a cohort left acclimation plate ACCID: its food
        % deprivation plate's start, or else its assay plate's transfer T
        t = NaT; tol = []; fmt = minuteFmt;
        for ci = find(strcmp(cohorts.acclimation, accId))'
            if ~isempty(cohorts.deprivation{ci})
                when = placed(holding, cohorts.deprivation{ci}, tz);
                whenTol = handTol; whenFmt = minuteFmt;
            else
                ap = plates.local_identifier(plates.plate == cohorts.plate(ci) & ...
                    strcmp(plates.folder, cohorts.folder{ci}));
                if isempty(ap) || ~isKey(spanOf, ap{1}), continue; end
                sp = spanOf(ap{1});
                when = sp.T; whenTol = sp.tol; whenFmt = secondFmt;
            end
            if ~isnat(when) && (isnat(t) || when > t)
                t = when; tol = whenTol; fmt = whenFmt;
            end
        end
    end
end

% -----------------------------------------------------------------------------
function [docs, out] = relate(docs, out, ids, child, parent, relation, times, sid, counter, fields)
arguments
    docs cell
    out (1,1) struct
    ids
    child {mustBeText}
    parent {mustBeText}
    relation {mustBeText}
    times cell
    sid {mustBeText}
    counter {mustBeText}
    fields struct
end
if ~isKey(ids, child) || ~isKey(ids, parent)
    out.skipped{end+1} = sprintf('%s %s %s: not both subjects of this session', ...
        child, relation, parent);
    return;
end
docs{end+1} = did2.build.directedRelation(ids(child), ids(parent), relation, ...
    'TimeReferenceIds', times, 'SessionId', sid, 'Fields', fields);
out.counts.(counter) = out.counts.(counter) + 1;
end

function t = placed(holding, id, tz)
% when the worms were put onto an acclimation / food deprivation plate
arguments
    holding table
    id {mustBeText}
    tz {mustBeText}
end
t = holding.worms_placed(strcmp(holding.local_identifier, id));
if isempty(t)
    t = NaT;
else
    t = wallClock(t(1), tz);
end
end
