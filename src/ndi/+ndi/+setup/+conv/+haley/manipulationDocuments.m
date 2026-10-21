function out = manipulationDocuments(session, S, subjectIds, options)
%MANIPULATIONDOCUMENTS Stage 8 (Haley): how one session's plates were made and its worms moved.
%
%   OUT = ndi.setup.conv.haley.manipulationDocuments(SESSION, S, SUBJECTIDS, ...)
%   builds the manipulation documents of the one-row session table SESSION
%   (from sessionList, with `session_id` assigned). S is the subject table
%   (subjectList, whose `prep` column holds each plate's and patch's times,
%   peptone, OD600 and volume); SUBJECTIDS maps each subject's
%   local_identifier to its document id. Nothing is written here. Decision
%   log #54, #56, #57. Variables are the decided terms (haleyTerm); methods
%   and the kinds of plate moved to are labels.
%
%   Plates (assay, acclimation, food deprivation, E. coli):
%     pour         dose_manipulation: 25 mL of NGM agar (or NGM agar without
%                  peptone, from the plate's `peptone`; only Matching and the
%                  E. coli study used it), formulation_id the recipe, variable
%                  the recipe's formulation type (nematode growth medium
%                  EMPTY:0000262, or without peptone EMPTY:0000263).
%                  When: E. coli `timePoured`; a C. elegans plate, which has no
%                  pour time, a relative_time_reference `intervalBefore` its
%                  seeding (an unseeded food deprivation plate: before the
%                  worms went on). No time, no pour.
%     seeding      dose_manipulation per patch at the patch's volume (assay
%                  and E. coli plates), and on each acclimation plate's one
%                  patch (200 uL); variable the strain's term (its WBStrain
%                  node; the diluent's formulation type for a patch of diluent
%                  alone), formulation_id that day's suspension
%                  (seedingSuspensions' index). When: the seeding time.
%     temperature  temperature_manipulation per move: the temperature moved
%                  INTO, approximate; variable ambient temperature
%                  (NCIT:C90380). Assay plate: cold room (`timeColdRoom`
%                  to `timeRoomTemp`), room temperature (`timeRoomTemp` to the
%                  end of filming). Acclimation plate: cold room
%                  (`growthTimeColdRoom` to `growthTimeRoomTemp`), room
%                  temperature (to the pick), incubator (the pick to the last
%                  move off it). Food deprivation plate: incubator
%                  (`starvedTime` to the last move off it). E. coli plate: cold
%                  room after pouring (to seeding, which was onto cold plates:
%                  the end is up to 5 min early), cold room after seeding (to
%                  `timeRoomTemp`), room temperature (from `timeRoomTemp` to
%                  its last image, where its patches' stay ends; decision
%                  #130).
%                  Seeding to cold room is at room temperature with no move:
%                  none. A `timeRoomTemp` the spec's corrections mark as
%                  estimated is approximate with no bound, and says so.
%   Worm cohorts (`distributive` true when the schema has it):
%     transfer           term_manipulation per move (acclimation, food
%                        deprivation, assay plate) at the time of the cohort's
%                        contained_in relation (stage 6): variable location
%                        (NCIT:C25341), value the kind of plate moved to (a
%                        label; the plate itself is
%                        the relation's parent), method the move's technique
%                        (worm picking; agar plug transfer; onto the assay
%                        plate agar plug transfer or eyelash picking, from the
%                        transfer protocol, with the cleaning step through an
%                        empty NGM plate as a method parameter).
%     droplet            dose_manipulation of the cohort, at the assay
%                        transfer's time, when the transfer's rule names a
%                        droplet (eyelash picking into S-Complete): formulation_id
%                        the droplet's formulation, no amount, variable its
%                        formulation type, no method (decision #132, option c).
%     food deprivation   term_manipulation food availability (ZECO:0000113)
%                        = fasting (ZECO:0000114) at the food deprivation
%                        window; no method.
%   Each temperature manipulation's method says how it was imposed:
%   refrigeration (cold room), ambient exposure (the bench), incubation (the
%   20 C incubator) -- the method is what tells room temperature from the
%   incubator.
%   Hand-written times are approximate, +/- the hand-written tolerance (to the
%   minute); video times (the end of filming) are exact.
%
%   Options:
%     'Preparation'  the spec's `preparation` section (required)
%     'Seeding'      the spec's `seeding` section (strain per folder)
%     'Ids'          containers.Map: dataset-level key -> document id (stage 2:
%                    recipes, strains, suspensions)
%     'Names'        containers.Map: formulation or strain key -> the term a
%                    dose of it reads as (a formulation's type, a strain's
%                    WBStrain term)
%     'Suspensions'  seedingSuspensions' index table
%     'Relations'    relationDocuments' output (timeReferenceIds, assaySpans,
%                    stayEnds)
%     'HandTolerance'  [minus plus] s for a hand-written time (default [60 60])
%
%   OUT fields: documents (cell of structs: manipulations and their time
%   references), counts (struct), skipped (cellstr: a manipulation not made,
%   and why), seedIds (containers.Map, a patch's document id -> its seeding
%   dose's id: an input of the patch's stage-12 estimates, decision #122).

arguments
    session table
    S table
    subjectIds
    options.Preparation struct
    options.Seeding struct = struct()
    options.Ids = containers.Map()
    options.Names = containers.Map()
    options.Suspensions = table()
    options.Relations = struct()
    options.HandTolerance (1,2) double = [60 60]
end
if height(session) ~= 1
    error('ndi:setup:conv:haley:oneSession', 'Give exactly one session row.');
end
sid = char(session.session_id{1});
ref = char(session.local_identifier{1});
tz = 'America/Los_Angeles';
S = S(strcmp(S.session, ref), :);
cfg = options.Preparation;
hand = options.HandTolerance;
minuteFmt = 'yyyy-MM-dd''T''HH:mm';
secondFmt = 'yyyy-MM-dd''T''HH:mm:ss';
refs = getOr(options.Relations, 'timeReferenceIds', containers.Map());
spans = getOr(options.Relations, 'assaySpans', containers.Map());
stayEnds = getOr(options.Relations, 'stayEnds', containers.Map());
eachMember = struct();
if ndi.setup.V2.schemaHasField('statement', 'distributive')
    eachMember.distributive = true;
end

docs = {};
out = struct('documents', {{}}, 'skipped', {{}}, 'counts', struct('pour', 0, ...
    'seed_patch', 0, 'seed_acclimation_patch', 0, 'temperature', 0, 'transfer', 0, ...
    'food_deprivation', 0, 'developmental_stage', 0, 'droplet', 0), 'seedIds', containers.Map());

% ---- plates ------------------------------------------------------------------
plateKinds = {'assay_plate', 'acclimation_plate', 'food_deprivation_plate', 'plate'};
for k = find(ismember(S.kind, plateKinds))'
    id = S.local_identifier{k};
    kind = S.kind{k};
    folder = S.folder{k};
    p = S.prep(k);
    roomTol = hand;
    if ~isempty(p.room_temp_note), roomTol = 'estimated'; end

    % seeding
    seedRef = '';
    if ~isnat(p.seeded) && ismember(kind, {'assay_plate', 'plate', 'acclimation_plate'})
        seedTol = hand;
        if isfield(p, 'seeded_spread_s')
            % a seeding time known only to a span (decision #75)
            seedTol = hand + p.seeded_spread_s;
        end
        seedRef = instant(p.seeded, seedTol);
        if strcmp(kind, 'acclimation_plate')
            seedAcclimation([id '_patch0001'], folder, p, seedRef);
        else
            pk = find(strcmp(S.kind, 'patch') & startsWith(S.local_identifier, [id '_patch']))';
            for j = pk
                seedPatch(S(j, :), folder, p.seeded, seedRef);
            end
        end
    end

    % temperature
    incubatorRef = '';
    switch kind
        case 'assay_plate'
            temperature(id, p.cold_room, hand, p.room_temp, roomTol, minuteFmt, ...
                cfg.temperature.cold_room_celsius, '', cfg.temperature.methods.cold_room);
            stop = NaT;
            if isKey(spans, id)
                span = spans(id);       % (a Map takes one level of indexing)
                stop = span.stop;
            end
            temperature(id, p.room_temp, roomTol, stop, [], secondFmt, ...
                cfg.temperature.room_celsius, p.room_temp_note, cfg.temperature.methods.room);
        case 'acclimation_plate'
            placed = S.worms_placed(k);
            temperature(id, p.cold_room, hand, p.room_temp, hand, minuteFmt, ...
                cfg.temperature.cold_room_celsius, '', cfg.temperature.methods.cold_room);
            % a named correction of the time (decision #70e) is its note
            temperature(id, p.room_temp, hand, placed, hand, minuteFmt, ...
                cfg.temperature.room_celsius, p.room_temp_note, cfg.temperature.methods.room);
            [stop, stopTol, stopFmt] = lastMoveOff(id);
            incubatorRef = temperature(id, placed, hand, stop, stopTol, stopFmt, ...
                cfg.temperature.incubator_celsius, '', cfg.temperature.methods.incubator);
        case 'food_deprivation_plate'
            [stop, stopTol, stopFmt] = lastMoveOff(id);
            incubatorRef = temperature(id, S.worms_placed(k), hand, stop, stopTol, stopFmt, ...
                cfg.temperature.incubator_celsius, '', cfg.temperature.methods.incubator);
        case 'plate'
            % out of the cold room shortly before seeding (seeded cold): the
            % window ends at the seeding, up to out_before_seeding_seconds earlier
            outTol = [getOr(cfg.temperature, 'out_before_seeding_seconds', 0) + hand(1), hand(2)];
            temperature(id, p.poured_cold_room, hand, p.seeded, outTol, minuteFmt, ...
                cfg.temperature.cold_room_celsius, '', cfg.temperature.methods.cold_room);
            temperature(id, p.cold_room, hand, p.room_temp, hand, minuteFmt, ...
                cfg.temperature.cold_room_celsius, '', cfg.temperature.methods.cold_room);
            % on the bench until its last image, where its patches' stay
            % ends (relationDocuments; decision #130)
            stop = NaT; stopTol = []; stopFmt = minuteFmt;
            if isKey(stayEnds, id)
                e = stayEnds(id);
                stop = e.stop; stopTol = e.tol; stopFmt = e.fmt;
            end
            temperature(id, p.room_temp, hand, stop, stopTol, stopFmt, ...
                cfg.temperature.room_celsius, '', cfg.temperature.methods.room);
    end

    % pouring: E. coli plates have its time; the others are before seeding
    % (an unseeded plate: before the worms went on)
    pourRef = '';
    if ~isnat(p.poured)
        pourRef = instant(p.poured, hand);
    else
        anchor = seedRef;
        if isempty(anchor), anchor = incubatorRef; end
        if ~isempty(anchor)
            d = did2.build.relativeTimeReference(anchor, 'Relation', 'intervalBefore', ...
                'SessionId', sid);
            docs{end+1} = d; %#ok<AGROW>
            pourRef = d.base.id;
        end
    end
    if isempty(pourRef)
        out.skipped{end+1} = sprintf('%s: no pour (no pour, seeding or worm time to place it)', id);
    else
        peptone = p.peptone;
        if ~isfield(cfg.pour.agar, peptone), peptone = cfg.pour.default_peptone; end
        notes = '';
        if isfield(cfg.pour, 'notes') && isfield(cfg.pour.notes, folder)
            notes = cfg.pour.notes.(folder);
        end
        if isfield(p, 'peptone_note') && ~isempty(p.peptone_note)
            % the plate's label was corrected (decision #111): the pour that
            % names the recipe carries the correction's note
            notes = strtrim(sprintf('%s %s.', notes, p.peptone_note));
        end
        dose(id, nameOf(cfg.pour.agar.(peptone)), cfg.pour.volume_ml, 'mL', cfg.pour.agar.(peptone), ...
            pourRef, cfg.pour.method, notes, 'pour');
    end
end

% ---- worm cohorts: the moves, and food deprivation -----------------------------
cohorts = find(strcmp(S.kind, 'cohort'))';
for k = cohorts
    cid = S.local_identifier{k};
    assay = regexprep(cid, '_worms$', '');
    if ~isempty(S.acclimation{k})
        move(cid, S.acclimation{k}, 'acclimation plate', cfg.transfer.pick_method, []);
    end
    if isfield(cfg, 'developmental_stage')
        stageAtPick(cid, k, assay);
    end
    if ~isempty(S.deprivation{k})
        key = [S.deprivation{k} '|' cid];
        move(cid, S.deprivation{k}, 'food deprivation plate', cfg.transfer.deprivation_method, []);
        if isKey(refs, key)
            statement('term_manipulation', cid, haleyTerm(cfg.food_deprivation.variable), ...
                haleyTerm(cfg.food_deprivation.value), refs(key), ...
                struct('Fields', eachMember), 'food_deprivation');
        end
    end
    method = '';
    params = [];
    dropletKey = '';
    if isKey(spans, assay)
        span = spans(assay);
        [method, params, dropletKey] = assayMethod(span.method);
    end
    move(cid, assay, 'assay plate', method, params);
    if ~isempty(dropletKey)
        droplet(cid, assay, dropletKey);
    end
end

out.documents = docs;

% =============================================================================
    function id = instant(t, tol)
        % a hand-written instant: when something was done
        d = utcReference(wallClock(t, tz), tol, fmtOf(tol), NaT, [], minuteFmt, false, tz, sid);
        docs{end+1} = d;
        id = d.base.id;
    end

    function refId = temperature(subject, t0, tol0, t1, tol1, fmt1, celsius, note, method)
        % moved INTO CELSIUS at T0, until T1 (when known); returns the window
        refId = '';
        if isnat(t0)
            return;
        end
        t0 = wallClock(t0, tz);
        hasEnd = ~isnat(t1);
        if hasEnd
            t1 = wallClock(t1, tz);
            if t1 < t0
                out.skipped{end+1} = sprintf(['%s at %g C: ends (%s) before it starts (%s); ' ...
                    'recorded with its start only'], subject, celsius, char(t1), char(t0));
                hasEnd = false;
            end
        end
        d = utcReference(t0, tol0, fmtOf(tol0), t1, tol1, fmt1, hasEnd, tz, sid);
        docs{end+1} = d;
        refId = d.base.id;
        v = did2.build.composite('temperature_manipulation', 'value', struct('celsius', celsius, ...
            'source_value', celsius, 'source_unit', ndi.setup.V2.sourceUnit('C'), 'approximate', true));
        statement('temperature_manipulation', subject, haleyTerm(cfg.temperature.variable), v, refId, ...
            struct('Notes', note, 'Method', method), 'temperature');
    end

    function seedPatch(row, folder, t, seedRef)
        pid = row.local_identifier{1};
        pp = row.prep(1);
        key = suspension(folder, t, pp.od600, 'assay');
        if ~isempty(row.bacteria{1})
            variable = nameOf(row.bacteria{1});
        elseif ~isempty(key)
            variable = nameOf(key);          % a patch of the diluent alone
        else
            variable = haleyTerm('diluent');
        end
        if isnan(pp.volume_ul)
            out.skipped{end+1} = sprintf('%s: seeding volume not recorded; no seeding dose', pid);
            return;
        end
        dose(pid, variable, pp.volume_ul, 'uL', key, seedRef, cfg.seed.method, '', 'seed_patch');
    end

    function seedAcclimation(patch, folder, p, seedRef)
        % the acclimation plate's one patch (subjectList), at the spec's volume
        strain = getOr(getOr(options.Seeding, 'strain', struct()), 'default', 'OP50');
        [key, note] = suspension(folder, p.seeded, p.od600, 'growth');
        dose(patch, nameOf(strain), cfg.seed.growth_volume_ul, 'uL', key, seedRef, ...
            cfg.seed.method, note, 'seed_acclimation_patch');
    end

    function dose(subject, variable, amount, unit, formulationKey, timeId, method, notes, counter, fields)
        % AMOUNT empty: a dose with no amount recorded (its value is left out)
        if isempty(amount)
            v = [];
        else
            scale = struct('uL', 1e-6, 'mL', 1e-3);
            v = did2.build.composite('dose_manipulation', 'value', struct('volume', ...
                struct('liters', amount * scale.(unit), 'source_value', amount, ...
                'source_unit', ndi.setup.V2.sourceUnit(unit))));
        end
        x = struct('Method', method, 'Notes', notes, 'Edges', struct());
        if nargin >= 10
            x.Fields = fields;
        end
        % a dose names what was given: did-schema requires dose.formulation_id
        % (#73 item 59), so a dose whose suspension is not known is not built
        % and is reported (a day with no measured solution gets an
        % solution of its plan alone, decisions #82 and #114, so this is now a
        % defect if it fires)
        if ~isempty(formulationKey) && isKey(options.Ids, formulationKey)
            x.Edges.formulation_id = options.Ids(formulationKey);
        elseif ~isempty(formulationKey)
            out.skipped{end+1} = sprintf('%s: formulation %s was not built; no %s dose', ...
                subject, formulationKey, counter);
            return;
        else
            out.skipped{end+1} = sprintf('%s: no formulation known (no solution recorded); no %s dose', ...
                subject, counter);
            return;
        end
        n0 = numel(docs);
        statement('dose_manipulation', subject, variable, v, timeId, x, counter);
        if numel(docs) > n0 && startsWith(counter, 'seed')
            out.seedIds(subjectIds(subject)) = docs{end}.base.id;
        end
    end

    function move(cohort, plate, value, method, params)
        moveKey = [plate '|' cohort];    % (nested: a name of its own, not the caller's `key`)
        if ~isKey(refs, moveKey)
            out.skipped{end+1} = sprintf('%s to %s: no time for the move; no transfer', cohort, plate);
            return;
        end
        x = struct('Fields', eachMember, 'Method', method, 'MethodParameters', params);
        statement('term_manipulation', cohort, haleyTerm(cfg.transfer.variable), ...
            haleyTerm(value), refs(moveKey), x, 'transfer');
    end

    function [method, params, dropletKey] = assayMethod(protocolMethod)
        % the transfer protocol's method -> the last step, plus the cleaning
        % step every assay transfer went through; and the formulation key of
        % the droplet the worms were released in, when the rule has one (it
        % is its own dose, decision #132 option c, not a method parameter)
        method = '';
        dropletKey = '';
        params = did2.build.parameter(haleyTerm('cleaning step'), 'Text', cfg.transfer.cleaning);
        rules = cfg.transfer.assay_methods;
        if isstruct(rules), rules = num2cell(rules); end
        for r = 1:numel(rules)
            if contains(protocolMethod, rules{r}.contains)
                method = rules{r}.method;
                if isfield(rules{r}, 'droplet')
                    dropletKey = rules{r}.droplet;
                end
                return;
            end
        end
    end

    function droplet(cohort, plate, formulationKey)
        % the droplet the worms were released in on the assay plate (decision
        % #132, option c, Jess Haley 2026-10-21): a dose_manipulation of the
        % cohort, at the transfer's time, formulation_id the droplet's
        % formulation (S-Complete), no amount (none was recorded). Variable:
        % what was given, the formulation's type, as for a pour (no other dose
        % in this import is given to animals); no method. A move with no time
        % has no transfer and no droplet (move reports it).
        moveKey = [plate '|' cohort];
        if ~isKey(refs, moveKey)
            return;
        end
        dose(cohort, nameOf(formulationKey), [], '', formulationKey, refs(moveKey), '', '', ...
            'droplet', eachMember);
    end

    function statement(leaf, subject, variable, value, timeId, x, counter)
        if ~isKey(subjectIds, subject)
            out.skipped{end+1} = sprintf('%s %s: not a subject of this session', subject, counter);
            return;
        end
        args = {'SessionId', sid, 'TimeReferenceIds', {timeId}};
        if isfield(x, 'Method') && ~isempty(x.Method)
            m = x.Method;
            if ischar(m) || isstring(m)
                m = haleyTerm(char(m));   % the spec names a procedure; its term (#106)
            end
            args = [args, {'Method', m}];
        end
        if isfield(x, 'MethodParameters') && ~isempty(x.MethodParameters)
            args = [args, {'MethodParameters', x.MethodParameters}];
        end
        if isfield(x, 'Notes') && ~isempty(x.Notes), args = [args, {'Notes', x.Notes}]; end
        if isfield(x, 'Fields') && ~isempty(fieldnames(x.Fields))
            args = [args, {'Fields', x.Fields}];
        end
        if isfield(x, 'Edges') && ~isempty(fieldnames(x.Edges))
            args = [args, {'Edges', x.Edges}];
        end
        docs{end+1} = did2.build.statement(leaf, subjectIds(subject), variable, value, args{:});
        out.counts.(counter) = out.counts.(counter) + 1;
    end

    function stageAtPick(cid, k, assay)
        % the worms were picked as L4 larvae (decision #69): an observation at
        % the pick, or, with no pick time, before the cohort's next move
        st = cfg.developmental_stage;
        when = '';
        pick = NaT;
        h = strcmp(S.local_identifier, S.acclimation{k});
        if any(h), pick = S.worms_placed(find(h, 1)); end
        if ~isnat(pick)
            when = instant(pick, hand);
        else
            next = {};
            if ~isempty(S.deprivation{k}), next{end+1} = [S.deprivation{k} '|' cid]; end
            next{end+1} = [assay '|' cid];
            next = next(cellfun(@(x) isKey(refs, x), next));
            if ~isempty(next)
                d = did2.build.relativeTimeReference(refs(next{1}), 'Relation', 'intervalBefore', ...
                    'SessionId', sid);
                docs{end+1} = d;
                when = d.base.id;
            end
        end
        if isempty(when)
            out.skipped{end+1} = sprintf('%s: no pick time and no later move; no developmental stage', cid);
            return;
        end
        statement('term_observation', cid, haleyTerm(st.variable), haleyTerm(st.value), when, ...
            struct('Fields', eachMember, 'Method', haleyTerm(st.method)), 'developmental_stage');
    end

    function [t, tol, fmt] = lastMoveOff(holding)
        % the latest time a cohort left HOLDING: its next plate's start (a
        % food deprivation plate's starvedTime, or the assay transfer T)
        t = NaT; tol = []; fmt = minuteFmt;
        on = find(strcmp(S.kind, 'cohort') & (strcmp(S.acclimation, holding) | ...
            strcmp(S.deprivation, holding)))';
        for c = on
            if strcmp(S.acclimation{c}, holding) && ~isempty(S.deprivation{c})
                q = S.worms_placed(strcmp(S.local_identifier, S.deprivation{c}));
                if isempty(q), continue; end
                q = wallClock(q(1), tz); qTol = hand; qFmt = minuteFmt;
            else
                a = regexprep(S.local_identifier{c}, '_worms$', '');
                if ~isKey(spans, a), continue; end
                sa = spans(a);
                q = sa.T; qTol = sa.tol; qFmt = secondFmt;
            end
            if ~isnat(q) && (isnat(t) || q > t)
                t = q; tol = qTol; fmt = qFmt;
            end
        end
    end

    function [key, note] = suspension(folder, t, od, kind)
        key = '';
        note = '';
        I = options.Suspensions;
        if isempty(I) || height(I) == 0 || isnat(t) || isnan(od)
            return;
        end
        day = char(t, 'yyyy-MM-dd');
        hit = strcmp(I.folder, folder) & strcmp(cellstr(char(I.day, 'yyyy-MM-dd')), day) & ...
            abs(I.od600 - od) < 1e-9 & strcmp(I.kind, kind);
        hit = find(hit, 1);
        if ~isempty(hit)
            key = I.key{hit};
            if ismember('note', I.Properties.VariableNames)
                note = I.note{hit};
            end
        end
    end

    function t = nameOf(key)
        % the term a dose of KEY reads as (a formulation's type, a strain's
        % term); a key with none is an error, not an unregistered label
        if isKey(options.Names, key)
            t = options.Names(key);
        else
            error('ndi:setup:conv:haley:unregisteredLabel', ...
                ['The dose of "%s" (manipulationDocuments, from the spec''s ' ...
                 'preparation/seeding sections) has no term: the spec gives "%s" no ' ...
                 'formulation type or strain term (the ''Names'' option). Give it one; ' ...
                 'its key is not written as a label.'], key, key);
        end
        if ~isstruct(t), t = did2.build.term('', t); end
    end

    function f = fmtOf(tol)
        % a time filled in by rule keeps its seconds; a hand-written one is to
        % the minute
        if ischar(tol) || isstring(tol)
            f = secondFmt;
        else
            f = minuteFmt;
        end
    end
end

function v = getOr(s, name, default)
arguments
    s
    name {mustBeText}
    default
end
if isstruct(s) && isfield(s, name)
    v = s.(name);
else
    v = default;
end
end
