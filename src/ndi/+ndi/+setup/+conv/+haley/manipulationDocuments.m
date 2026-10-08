function out = manipulationDocuments(session, S, subjectIds, options)
%MANIPULATIONDOCUMENTS Stage 8 (Haley): how one session's plates were made and its worms moved.
%
%   OUT = ndi.setup.conv.haley.manipulationDocuments(SESSION, S, SUBJECTIDS, ...)
%   builds the manipulation documents of the one-row session table SESSION
%   (from sessionList, with `session_id` assigned). S is the subject table
%   (subjectList, whose `prep` column holds each plate's and patch's times,
%   peptone, OD600 and volume); SUBJECTIDS maps each subject's
%   local_identifier to its document id. Nothing is written here. Decision
%   log #54, #56, #57; every term is a name until the ontology lookup.
%
%   Plates (assay, acclimation, food deprivation, E. coli):
%     pour         dose_manipulation: 25 mL of NGM agar (or NGM agar without
%                  peptone, from the plate's `peptone`; only Matching and the
%                  E. coli study used it), formulation_id the recipe.
%                  When: E. coli `timePoured`; a C. elegans plate, which has no
%                  pour time, a relative_time_reference `intervalBefore` its
%                  seeding (an unseeded food deprivation plate: before the
%                  worms went on). No time, no pour.
%     seeding      dose_manipulation per patch (assay and E. coli plates) at
%                  the patch's volume, and per acclimation plate (200 uL);
%                  variable the strain (the diluent's name for a patch of
%                  diluent alone), formulation_id that day's suspension
%                  (seedingSuspensions' index). When: the seeding time.
%     temperature  temperature_manipulation per move: the temperature moved
%                  INTO, approximate. Assay plate: cold room (`timeColdRoom`
%                  to `timeRoomTemp`), room temperature (`timeRoomTemp` to the
%                  end of filming). Acclimation plate: cold room
%                  (`growthTimeColdRoom` to `growthTimeRoomTemp`), room
%                  temperature (to the pick), incubator (the pick to the last
%                  move off it). Food deprivation plate: incubator
%                  (`starvedTime` to the last move off it). E. coli plate: cold
%                  room after pouring (to seeding, which was onto cold plates:
%                  the end is up to 5 min early), cold room after seeding (to
%                  `timeRoomTemp`), room temperature (from `timeRoomTemp`).
%                  Seeding to cold room is at room temperature with no move:
%                  none. A `timeRoomTemp` the spec's corrections mark as
%                  estimated is approximate with no bound, and says so.
%   Worm cohorts (`distributive` true when the schema has it):
%     transfer           term_manipulation per move (acclimation, food
%                        deprivation, assay plate) at the time of the cohort's
%                        contained_in relation (stage 6): variable `location`,
%                        value the kind of plate moved to (the plate itself is
%                        the relation's parent), method the move's technique
%                        (worm picking; agar plug transfer; onto the assay
%                        plate agar plug transfer or eyelash picking, from the
%                        transfer protocol, with the cleaning step through an
%                        empty NGM plate and any S-Complete droplet as method
%                        parameters).
%     food deprivation   term_manipulation `food availability` = `none` at
%                        the food deprivation window.
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
%     'Names'        containers.Map: formulation or strain key -> its name
%     'Suspensions'  seedingSuspensions' index table
%     'Relations'    relationDocuments' output (timeReferenceIds, assaySpans)
%     'HandTolerance'  [minus plus] s for a hand-written time (default [60 60])
%
%   OUT fields: documents (cell of structs: manipulations and their time
%   references), counts (struct), skipped (cellstr: a manipulation not made,
%   and why).

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
eachMember = struct();
if ndi.setup.V2.schemaHasField('statement', 'distributive')
    eachMember.distributive = true;
end

docs = {};
out = struct('documents', {{}}, 'skipped', {{}}, 'counts', struct('pour', 0, ...
    'seed_patch', 0, 'seed_acclimation_plate', 0, 'temperature', 0, 'transfer', 0, ...
    'food_deprivation', 0, 'developmental_stage', 0));

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
        seedRef = instant(p.seeded, hand);
        if strcmp(kind, 'acclimation_plate')
            seedAcclimation(id, folder, p, seedRef);
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
            temperature(id, p.room_temp, hand, NaT, [], minuteFmt, ...
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
        dose(id, cfg.pour.variable.(peptone), cfg.pour.volume_ml, 'mL', cfg.pour.agar.(peptone), ...
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
            statement('term_manipulation', cid, cfg.food_deprivation.variable, ...
                did2.build.term('', cfg.food_deprivation.value), refs(key), ...
                struct('Fields', eachMember), 'food_deprivation');
        end
    end
    method = '';
    params = [];
    if isKey(spans, assay)
        span = spans(assay);
        [method, params] = assayMethod(span.method);
    end
    move(cid, assay, 'assay plate', method, params);
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
            'source_value', celsius, 'source_unit', 'C', 'approximate', true));
        statement('temperature_manipulation', subject, cfg.temperature.variable, v, refId, ...
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
            variable = 'diluent';
        end
        if isnan(pp.volume_ul)
            out.skipped{end+1} = sprintf('%s: seeding volume not recorded; no seeding dose', pid);
            return;
        end
        dose(pid, variable, pp.volume_ul, 'uL', key, seedRef, cfg.seed.method, '', 'seed_patch');
    end

    function seedAcclimation(id, folder, p, seedRef)
        strain = getOr(getOr(options.Seeding, 'strain', struct()), 'default', 'OP50');
        key = suspension(folder, p.seeded, p.od600, 'growth');
        dose(id, nameOf(strain), cfg.seed.growth_volume_ul, 'uL', key, seedRef, ...
            cfg.seed.method, '', 'seed_acclimation_plate');
    end

    function dose(subject, variable, amount, unit, formulationKey, timeId, method, notes, counter)
        scale = struct('uL', 1e-6, 'mL', 1e-3);
        v = did2.build.composite('dose_manipulation', 'value', struct('volume', ...
            struct('liters', amount * scale.(unit), 'source_value', amount, 'source_unit', unit)));
        x = struct('Method', method, 'Notes', notes, 'Edges', struct());
        % a dose names what was given: did-schema requires dose.formulation_id
        % (#73 item 59), so a dose whose suspension is not known is not built
        % and is reported (e.g. Mutants 2023-11-09: no solution measured)
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
        statement('dose_manipulation', subject, variable, v, timeId, x, counter);
    end

    function move(cohort, plate, value, method, params)
        moveKey = [plate '|' cohort];    % (nested: a name of its own, not the caller's `key`)
        if ~isKey(refs, moveKey)
            out.skipped{end+1} = sprintf('%s to %s: no time for the move; no transfer', cohort, plate);
            return;
        end
        x = struct('Fields', eachMember, 'Method', method, 'MethodParameters', params);
        statement('term_manipulation', cohort, cfg.transfer.variable, ...
            did2.build.term('', value), refs(moveKey), x, 'transfer');
    end

    function [method, params] = assayMethod(protocolMethod)
        % the transfer protocol's method -> the last step, plus the cleaning
        % step every assay transfer went through
        method = '';
        params = did2.build.parameter('cleaning step', 'Text', cfg.transfer.cleaning);
        rules = cfg.transfer.assay_methods;
        if isstruct(rules), rules = num2cell(rules); end
        for r = 1:numel(rules)
            if contains(protocolMethod, rules{r}.contains)
                method = rules{r}.method;
                if isfield(rules{r}, 'droplet')
                    params = did2.build.list(params, ...
                        did2.build.parameter('droplet', 'Term', rules{r}.droplet));
                end
                return;
            end
        end
    end

    function statement(leaf, subject, variable, value, timeId, x, counter)
        if ~isKey(subjectIds, subject)
            out.skipped{end+1} = sprintf('%s %s: not a subject of this session', subject, counter);
            return;
        end
        args = {'SessionId', sid, 'TimeReferenceIds', {timeId}};
        if isfield(x, 'Method') && ~isempty(x.Method), args = [args, {'Method', x.Method}]; end
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
        statement('term_observation', cid, st.variable, did2.build.term('', st.value), when, ...
            struct('Fields', eachMember, 'Method', did2.build.term('', st.method)), 'developmental_stage');
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

    function key = suspension(folder, t, od, kind)
        key = '';
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
        end
    end

    function n = nameOf(key)
        if isKey(options.Names, key)
            n = options.Names(key);
        else
            n = key;
        end
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
if isstruct(s) && isfield(s, name)
    v = s.(name);
else
    v = default;
end
end
