function [S, checks] = subjectList(dataParentDir, sessions, options)
%SUBJECTLIST Stage 4 (Haley): the subjects to create, per session.
%
%   [S, CHECKS] = ndi.setup.conv.haley.subjectList(DATAPARENTDIR, SESSIONS)
%   reads the raw data under DATAPARENTDIR/haley and returns one row per
%   subject, each assigned to a session of SESSIONS (the table from
%   ndi.setup.conv.haley.sessionList). Decision log #37-#41.
%
%   Names follow the eLife paper (decision #42): the plate an animal is
%   filmed on is an ASSAY plate, the plate L4s are picked onto the day
%   before is an ACCLIMATION plate.
%
%   C. elegans, from <folder>/experimentInfo.mat `info` (one row per
%   plate-video):
%     assay_plate      one per distinct plateNum      concentration_assayPlate0011
%                                                     "Assay Plate 0011"
%     patch            one per row of the plate's     concentration_assayPlate0011_patch0007
%                      lawnCenters (numbered in that  "Patch 0007 on Assay Plate 0011"
%                      order, which is closestLawnID's)
%     cohort           the worms of one assay plate,  concentration_assayPlate0011_worms
%                      moved together (decision #55): "Worms on Assay Plate 0011"
%                      a group subject; each worm is
%                      member_of it, and the plates
%                      and moves are stated on it
%     worm             one per distinct wormNum       concentration_worm0451  "Worm 0451"
%     acclimation_plate one per (strain, pick time)   concentration_0001_acclimationPlate0001
%                      in a session, numbered by pick "Acclimation Plate 0001"
%                      time then strain (the source
%                      has no id for it; decision #39)
%     food_deprivation_plate  one per (strain,   mutants_0001_foodDeprivationPlate0001
%                      starvedTime) in a session: the "Food Deprivation Plate 0001"
%                      unseeded plate food-deprived worms were moved to
%                      from their acclimation plate (decision #53)
%   E. coli, from ecoli/bacteria.mat `info` (one row per plate; all 126 are
%   kept, analysed or not -- decision #43):
%     plate            one per plate                  ecoli_plate0042  "Plate 0042"
%     patch            `rectangle` template: 12 (3    ecoli_plate0042_patch0012
%                      staggered rows of 4, numbered
%                      left to right, top to bottom
%                      within a column: decision
%                      #62); `none` seeded: 1 (one
%                      large patch; OD600 0 = LB
%                      alone); `none` with
%                      lawnVolume 0: none
%
%   Numbers restart in each source folder, so every local_identifier starts
%   with ndi.setup.conv.haley.idPrefix(folder) (decision #37).
%
%   Columns: session, kind, local_identifier, name, description, folder,
%   plate, patch, worm, strain, acclimation (the acclimation plate an assay
%   plate's worms came from), exclude (the source's `exclude` flag, for the
%   assertions stage), deprivation (the food deprivation plate a
%   food-deprived assay plate's worms came through; '' otherwise),
%   worms_placed (when worms were put onto this plate: an acclimation
%   plate's `growthTimePicked`, a food deprivation plate's `starvedTime`;
%   NaT for the other kinds), bacteria (a patch's strain key: OP50 on the
%   C. elegans plates, OP50-GFP on the E. coli plates; '' for a patch of LB
%   alone, OD600 0), cohort (a worm's cohort), type (subject.type, decision
%   #55: worm organism, cohort group, a patch with bacteria culture, every
%   plate and a patch of LB alone material), prep (stage 8, decisions #54,
%   #56: a struct of how a plate or patch was made -- seeded, cold_room,
%   room_temp (an assay plate's `timeSeed`/`timeColdRoom`/`timeRoomTemp`, an
%   acclimation plate's `growthTime*`, an E. coli plate's `timeSeed`/
%   `timeSeedColdRoom`/`timeRoomTemp`), poured and poured_cold_room (E. coli),
%   peptone (the label, or the spec's correction), od600 and volume_ul (a
%   patch's; an acclimation plate's `growthOD600`), room_temp_note (the
%   correction's reason when `timeRoomTemp` was estimated), room_temp_by_rule
%   (it is exactly a recording's start minus 1 h); NaT/NaN/'' where the
%   source has nothing).
%
%   Option 'Corrections': the spec's `corrections`; those naming a `plate`
%   are applied to its prep (decision #56: plate 90's peptone; #54d: an
%   estimated `timeRoomTemp`).
%
%   CHECKS (second output, also printed) report what looks wrong in the
%   source WITHOUT changing anything:
%     plateWithoutSession  a plate whose expNum has no session (no
%                          tableOfContents row); its subjects are skipped
%     plateOnTwoDays       one plateNum under two expNums (kept on the first)
%     wormOnTwoPlates      one wormNum on two plates (kept on the first)
%     wormRange            a session whose worms differ from its
%                          tableOfContents range (decision 3: the range is a
%                          check, never trusted)
%     noLawnCenters        a plate with no patch positions (no patches made)
%     patchCountDisagrees  lawnCenters and lawnRadii list different counts
%     noPickTime           a plate with no growthTimePicked (its
%                          acclimation plate is grouped by strain alone)
%     ecoliSeeding         an E. coli plate whose template and seeding
%                          disagree, or a plateNum used by two experiments
%     growthDisagrees      an acclimation plate whose assay plates give
%                          different growth times (the first is kept)
%     correctionUnmatched  a spec correction naming a plate not listed
%     roomTempLooksEstimated  an assay plate whose `timeRoomTemp` is exactly a
%                          recording's start minus 1 h (filled in by rule)
%                          that no correction lists
%
%   Nothing is written; the subjects stage of import_V2 prints S.

arguments
    dataParentDir (1,:) char {mustBeFolder}
    sessions table
    options.Corrections = {}
end

root = fullfile(dataParentDir, 'haley');
checks = struct('plateWithoutSession', {{}}, 'plateOnTwoDays', {{}}, ...
    'wormOnTwoPlates', {{}}, 'wormRange', {{}}, 'noLawnCenters', {{}}, ...
    'patchCountDisagrees', {{}}, 'noPickTime', {{}}, 'ecoliSeeding', {{}}, ...
    'growthDisagrees', {{}}, 'correctionUnmatched', {{}}, 'roomTempLooksEstimated', {{}});
rows = {};

% ---- C. elegans -------------------------------------------------------------
folders = unique(sessions.folder(~strcmp(sessions.folder, 'ecoli')));
nFiles = 0;
for f = 1:numel(folders)
    folder = folders{f};
    pre = ndi.setup.conv.haley.idPrefix(folder);
    file = fullfile(root, 'celegans', folder, 'experimentInfo.mat');
    if ~isfile(file)
        error('ndi:setup:conv:haley:noExperimentInfo', 'Missing %s.', file);
    end
    I = load(file, 'info');
    I = I.info;
    nFiles = nFiles + 1;
    need = {'expNum', 'plateNum', 'wormNum', 'strainID', 'growthTimePicked', 'lawnCenters'};
    missing = setdiff(need, I.Properties.VariableNames);
    if ~isempty(missing)
        error('ndi:setup:conv:haley:badExperimentInfo', '%s has no column(s) %s.', ...
            file, strjoin(missing, ', '));
    end
    mine = sessions(strcmp(sessions.folder, folder), :);

    % One record per assay plate, gathered first: acclimation plates are
    % numbered per session, which needs every plate of the session.
    plates = unique(I.plateNum);
    P = struct('plate', {}, 'session', {}, 'worms', {}, 'strain', {}, 'pick', {}, ...
        'nPatch', {}, 'nVideo', {}, 'exclude', {}, 'starved', {}, 'od600', {}, ...
        'prep', {}, 'growth', {});
    wormHome = containers.Map('KeyType', 'double', 'ValueType', 'double');
    for k = 1:numel(plates)
        p = double(plates(k));
        R = I(I.plateNum == plates(k), :);
        days = unique(R.expNum);
        if numel(days) > 1
            checks.plateOnTwoDays{end+1} = sprintf('%s: plate %d appears under expNum %s; kept on %d', ...
                folder, p, mat2str(double(days(:)')), days(1));
        end
        s = find(mine.experiment == double(days(1)), 1);
        if isempty(s)
            checks.plateWithoutSession{end+1} = sprintf('%s: plate %d (expNum %d) has no session', ...
                folder, p, days(1));
            continue;
        end
        w = cellfun(@(x) double(x(:)'), R.wormNum, 'UniformOutput', false);
        worms = unique([w{:}]);
        kept = [];
        for m = 1:numel(worms)
            if isKey(wormHome, worms(m)) && wormHome(worms(m)) ~= p
                checks.wormOnTwoPlates{end+1} = sprintf('%s: worm %d is on plate %d and plate %d; kept on %d', ...
                    folder, worms(m), wormHome(worms(m)), p, wormHome(worms(m)));
                continue;
            end
            wormHome(worms(m)) = p;
            kept(end+1) = worms(m); %#ok<AGROW>
        end
        % Patch positions from the plate's first video that HAS them: a failed
        % start (Mutants plate 1, 3 Nov 2023 07:35:52; decision #41) has none,
        % and its restart does.
        hasLawn = find(~cellfun(@isempty, R.lawnCenters), 1);
        nPatch = 0;
        if isempty(hasLawn)
            checks.noLawnCenters{end+1} = sprintf('%s: plate %d has no lawnCenters; no patches made', folder, p);
        else
            nPatch = size(R.lawnCenters{hasLawn}, 1);
            if ismember('lawnRadii', I.Properties.VariableNames) && numel(R.lawnRadii{hasLawn}) ~= nPatch
                checks.patchCountDisagrees{end+1} = sprintf('%s: plate %d has %d lawnCenters and %d lawnRadii', ...
                    folder, p, nPatch, numel(R.lawnRadii{hasLawn}));
            end
        end
        pick = R.growthTimePicked(1);
        if isnat(pick)
            checks.noPickTime{end+1} = sprintf('%s: plate %d has no growthTimePicked', folder, p);
        end
        ex = false;
        if ismember('exclude', I.Properties.VariableNames)
            ex = any(R.exclude);
        end
        starved = NaT;
        if ismember('starvedTime', I.Properties.VariableNames) && ~isnat(R.starvedTime(1))
            starved = R.starvedTime(1);
        end
        od = [];                    % the patches' OD600 when the source has it
        if ismember('OD600', I.Properties.VariableNames)
            od = R.OD600(1, :);
            if iscell(od), od = od{1}; end
            od = double(od(:)');
        end
        P(end+1) = struct('plate', p, 'session', mine.local_identifier{s}, 'worms', kept, ...
            'strain', char(R.strainID{1}), 'pick', pick, 'nPatch', nPatch, ...
            'nVideo', height(R), 'exclude', ex, 'starved', starved, 'od600', od, ...
            'prep', prepOf(R, 'timeSeed', 'timeColdRoom', 'timeRoomTemp', NaN), ...
            'growth', growthPrepOf(R)); %#ok<AGROW>
    end

    % Acclimation plates: one per (session, strain, pick time), numbered within the
    % session by pick time, then strain.
    growthOf = cell(1, numel(P));
    for s = 1:height(mine)
        idx = find(strcmp({P.session}, mine.local_identifier{s}));
        if isempty(idx)
            continue;
        end
        keys = cell(numel(idx), 1);
        for m = 1:numel(idx)
            keys{m} = growthKey(P(idx(m)));
        end
        [u, ~, grp] = unique(keys);
        picks = NaT(numel(u), 1);
        strains = cell(numel(u), 1);
        for g = 1:numel(u)
            first = idx(find(grp == g, 1));
            picks(g) = P(first).pick;
            strains{g} = P(first).strain;
        end
        G = table(picks, strains, (1:numel(u))', 'VariableNames', {'pick', 'strain', 'k'});
        G = sortrows(G, {'pick', 'strain'});
        for n = 1:height(G)
            g = G.k(n);
            gid = sprintf('%s_acclimationPlate%04d', mine.local_identifier{s}, n);
            members = idx(grp == g);
            for m = 1:numel(members)
                growthOf{members(m)} = gid;
            end
            if isnat(G.pick(n))
                when = 'pick time not recorded';
            else
                when = ['picked ' char(G.pick(n), 'yyyy-MM-dd HH:mm')];
            end
            r = subjRow(mine.local_identifier{s}, 'acclimation_plate', gid, ...
                sprintf('Acclimation Plate %04d', n), ...
                sprintf('Acclimation plate of %s, %s; the worms of %d assay plate(s) came from it.', ...
                G.strain{n}, when, numel(members)), folder, NaN, NaN, NaN, G.strain{n}, '', false, ...
                G.pick(n));
            % its preparation: the growth columns of the assay plates it served,
            % which should agree; the first is kept and a disagreement reported
            r.prep = P(members(1)).growth;
            for m = 2:numel(members)
                if ~samePrep(P(members(m)).growth, r.prep)
                    checks.growthDisagrees{end+1} = sprintf(['%s: assay plates %d and %d give ' ...
                        'different growth seeding/cold room/room temperature times; kept %d''s'], ...
                        gid, P(members(1)).plate, P(members(m)).plate, P(members(1)).plate);
                end
            end
            rows{end+1} = r; %#ok<AGROW>
        end
    end

    % Food deprivation plates: the unseeded plate a food-deprived plate's
    % worms were moved to from their acclimation plate (`starvedTime`, the
    % paper's "3 hr of food deprivation"); one per (session, strain, time
    % moved), numbered within the session by that time, then strain.
    deprivationOf = repmat({''}, 1, numel(P));
    deprived = arrayfun(@(q) ~isnat(q.starved), P);   % (an empty P gives logical [])
    for s = 1:height(mine)
        idx = find(strcmp({P.session}, mine.local_identifier{s}) & deprived);
        if isempty(idx)
            continue;
        end
        keys = arrayfun(@(q) [q.strain '|' char(q.starved, 'yyyyMMddHHmmss')], P(idx), ...
            'UniformOutput', false);
        [u, ~, grp] = unique(keys);
        times = NaT(numel(u), 1);
        strains = cell(numel(u), 1);
        for g = 1:numel(u)
            first = idx(find(grp == g, 1));
            times(g) = P(first).starved;
            strains{g} = P(first).strain;
        end
        G = table(times, strains, (1:numel(u))', 'VariableNames', {'starved', 'strain', 'k'});
        G = sortrows(G, {'starved', 'strain'});
        for n = 1:height(G)
            g = G.k(n);
            did = sprintf('%s_foodDeprivationPlate%04d', mine.local_identifier{s}, n);
            members = idx(grp == g);
            for m = 1:numel(members)
                deprivationOf{members(m)} = did;
            end
            rows{end+1} = subjRow(mine.local_identifier{s}, 'food_deprivation_plate', did, ...
                sprintf('Food Deprivation Plate %04d', n), ...
                sprintf(['Unseeded plate the %s worms of %d assay plate(s) were moved to from ' ...
                'their acclimation plate at %s, for food deprivation before the assay.'], ...
                G.strain{n}, numel(members), char(G.starved(n), 'yyyy-MM-dd HH:mm')), ...
                folder, NaN, NaN, NaN, G.strain{n}, '', false, G.starved(n)); %#ok<AGROW>
        end
    end

    % Assay plates, their patches and worms.
    for m = 1:numel(P)
        q = P(m);
        pid = sprintf('%s_assayPlate%04d', pre, q.plate);
        pname = sprintf('Assay Plate %04d', q.plate);
        r = subjRow(q.session, 'assay_plate', pid, pname, ...
            sprintf('Assay plate %d: %d worm(s), %d patch(es), filmed in %d video(s).', ...
            q.plate, numel(q.worms), q.nPatch, q.nVideo), folder, q.plate, NaN, NaN, ...
            q.strain, growthOf{m}, q.exclude, NaT, deprivationOf{m});
        r.prep = q.prep;
        % a timeRoomTemp of exactly a recording's start minus 1 h was filled
        % in by rule (decision #54d): the spec's corrections list each one
        if ismember('timeRecord', I.Properties.VariableNames) && ~isnat(q.prep.room_temp)
            t = I.timeRecord(I.plateNum == q.plate);
            r.prep.room_temp_by_rule = any(q.prep.room_temp == t - hours(1));
        end
        rows{end+1} = r; %#ok<AGROW>
        for k = 1:q.nPatch
            r = subjRow(q.session, 'patch', sprintf('%s_patch%04d', pid, k), ...
                sprintf('Patch %04d on %s', k, pname), ...
                sprintf('Patch %d of assay plate %d.', k, q.plate), folder, q.plate, k, NaN, ...
                '', '', false);
            % OP50 on every C. elegans plate (decision #54); a patch the source
            % gives OD600 0 is LB alone, with no bacteria.
            od = q.od600;
            if numel(od) == q.nPatch, od = od(k); end
            if ~(~isempty(od) && all(od == 0))
                r.bacteria = 'OP50';
            end
            % seeded with the plate, at its own OD600 and the plate's volume
            r.prep.seeded = q.prep.seeded;
            r.prep.volume_ul = q.prep.volume_ul;
            if isscalar(od), r.prep.od600 = od; end
            rows{end+1} = r; %#ok<AGROW>
        end
        % The plate's worms are one cohort (decision #55): moved together, so
        % the plates they were on and how they got there are stated once, on
        % the cohort, and each worm is a member of it.
        cohort = '';
        if ~isempty(q.worms)
            cohort = [pid '_worms'];
            r = subjRow(q.session, 'cohort', cohort, ['Worms on ' pname], ...
                sprintf('The %d %s worm(s) of assay plate %d, moved together.', ...
                numel(q.worms), q.strain, q.plate), folder, q.plate, NaN, NaN, ...
                q.strain, growthOf{m}, false, NaT, deprivationOf{m});
            rows{end+1} = r; %#ok<AGROW>
        end
        for k = 1:numel(q.worms)
            r = subjRow(q.session, 'worm', sprintf('%s_worm%04d', pre, q.worms(k)), ...
                sprintf('Worm %04d', q.worms(k)), ...
                sprintf('Worm %d, on assay plate %d.', q.worms(k), q.plate), folder, q.plate, ...
                NaN, q.worms(k), q.strain, growthOf{m}, false, NaT, deprivationOf{m});
            r.cohort = cohort;
            rows{end+1} = r; %#ok<AGROW>
        end
    end

    % The tableOfContents worm range, checked against the worms present.
    for s = 1:height(mine)
        a = mine.worm_first(s); b = mine.worm_last(s);
        if isnan(a) || isnan(b)
            continue;
        end
        idx = strcmp({P.session}, mine.local_identifier{s});
        present = sort([P(idx).worms]);
        if ~isequal(present, a:b)
            if isempty(present)
                got = 'no worms';
            else
                got = sprintf('%d worm(s), %d-%d', numel(present), present(1), present(end));
            end
            checks.wormRange{end+1} = sprintf('%s: tableOfContents says worms %d-%d (%d); the plates have %s', ...
                mine.local_identifier{s}, a, b, b - a + 1, got);
        end
    end
end

% ---- E. coli ----------------------------------------------------------------
mine = sessions(strcmp(sessions.folder, 'ecoli'), :);
if height(mine) > 0
    file = fullfile(root, 'ecoli', 'bacteria.mat');
    B = load(file, 'info');
    info = B.info;
    nFiles = nFiles + 1;
    need = {'expNum', 'plateNum', 'template', 'OD600', 'lawnVolume'};
    missing = setdiff(need, info.Properties.VariableNames);
    if ~isempty(missing)
        error('ndi:setup:conv:haley:badBacteriaInfo', '%s info has no column(s) %s.', ...
            file, strjoin(missing, ', '));
    end
    [u, ~, j] = unique(info.plateNum);
    for k = find(accumarray(j, 1) > 1)'
        checks.ecoliSeeding{end+1} = sprintf('ecoli: plateNum %d is used by more than one plate', u(k));
    end
    for r = 1:height(info)
        n = double(info.expNum(r));
        p = double(info.plateNum(r));
        s = find(mine.experiment == n, 1);
        if isempty(s)
            checks.plateWithoutSession{end+1} = sprintf('ecoli: plate %d (expNum %d) has no session', p, n);
            continue;
        end
        template = lower(strtrim(char(info.template{r})));
        seeded = info.lawnVolume(r) > 0;
        switch template
            case 'rectangle'
                nPatch = 12;
                if ~seeded
                    checks.ecoliSeeding{end+1} = sprintf('ecoli: plate %d has the rectangle template but lawnVolume 0', p);
                end
                what = '12 patches in a 3 x 4 grid';
            case 'none'
                % Seeded (lawnVolume > 0) = one large patch. OD600 0 is a patch
                % of LB alone, a bacteria-free patch at relative density 0 (the
                % eLife paper, Methods: "A '0' density solution was prepared
                % with just LB"), so it is still a patch. Unseeded = a blank
                % plate. Only an OD600 with no volume is inconsistent.
                nPatch = double(seeded);
                if ~seeded && info.OD600(r) > 0
                    checks.ecoliSeeding{end+1} = sprintf('ecoli: plate %d has OD600 %g but lawnVolume 0', ...
                        p, info.OD600(r));
                end
                if ~seeded
                    what = 'no bacteria';
                elseif info.OD600(r) == 0
                    what = 'one large patch of LB alone (relative density 0)';
                else
                    what = 'one large lawn';
                end
            otherwise
                nPatch = 0;
                checks.ecoliSeeding{end+1} = sprintf('ecoli: plate %d has unknown template "%s"; no patches made', ...
                    p, template);
                what = ['template ' template];
        end
        pid = sprintf('ecoli_plate%04d', p);
        pname = sprintf('Plate %04d', p);
        pl = subjRow(mine.local_identifier{s}, 'plate', pid, pname, ...
            sprintf('E. coli plate %d: %s.', p, what), 'ecoli', p, NaN, NaN, '', '', false);
        R1 = info(r, :);
        pl.prep = prepOf(R1, 'timeSeed', 'timeSeedColdRoom', 'timeRoomTemp', NaN);
        pl.prep.poured = colOr(R1, 'timePoured', NaT);
        pl.prep.poured_cold_room = colOr(R1, 'timePouredColdRoom', NaT);
        rows{end+1} = pl; %#ok<AGROW>
        for k = 1:nPatch
            pr = subjRow(mine.local_identifier{s}, 'patch', sprintf('%s_patch%04d', pid, k), ...
                sprintf('Patch %04d on %s', k, pname), ...
                sprintf('Patch %d of E. coli plate %d.', k, p), 'ecoli', p, k, NaN, '', '', false);
            if info.OD600(r) > 0            % OD600 0 is LB alone: no bacteria
                pr.bacteria = 'OP50-GFP';   % decision #54
            end
            pr.prep.seeded = pl.prep.seeded;
            pr.prep.od600 = double(info.OD600(r));
            pr.prep.volume_ul = double(info.lawnVolume(r));
            rows{end+1} = pr; %#ok<AGROW>
        end
    end
end

% ---- the spec's named corrections to a plate (decisions #54, #56) ------------
% By folder and plate: `peptone` replaces the plate's label (plate 90); a
% `timeRoomTemp` with `approximate` marks that time as estimated, keeping it
% and its reason. Corrections by seeding day are seedingSuspensions'.
corr = options.Corrections;
if isstruct(corr), corr = num2cell(corr); end
for c = 1:numel(corr)
    x = corr{c};
    if ~isfield(x, 'plate')
        continue;
    end
    hit = false;
    for k = 1:numel(rows)
        r = rows{k};
        if strcmp(r.folder, x.folder) && isequal(r.plate, double(x.plate)) && ...
                any(strcmp(r.kind, {'assay_plate', 'plate'}))
            switch x.column
                case 'peptone'
                    r.prep.peptone = char(x.value);
                case 'timeRoomTemp'
                    r.prep.room_temp_note = char(x.reason);
                otherwise
                    continue;
            end
            rows{k} = r;
            hit = true;
        end
    end
    if ~hit
        checks.correctionUnmatched{end+1} = sprintf('%s: no %s plate %d in the selected sessions', ...
            char(x.key), x.folder, double(x.plate));
    end
end

for k = 1:numel(rows)
    r = rows{k};
    if r.prep.room_temp_by_rule && isempty(r.prep.room_temp_note)
        checks.roomTempLooksEstimated{end+1} = sprintf(['%s: timeRoomTemp is exactly a ' ...
            'recording''s start minus 1 h but no correction lists it'], r.local_identifier);
    end
end

% ---- report -------------------------------------------------------------------
if isempty(rows)
    S = cell2table(cell(0, 18), 'VariableNames', {'session', 'kind', 'local_identifier', ...
        'name', 'description', 'folder', 'plate', 'patch', 'worm', 'strain', 'acclimation', ...
        'deprivation', 'exclude', 'worms_placed', 'bacteria', 'cohort', 'prep', 'type'});
else
    S = struct2table([rows{:}], 'AsArray', true);
    S.type = arrayfun(@(k) typeOf(S.kind{k}, S.bacteria{k}), (1:height(S))', ...
        'UniformOutput', false);
end
dup = {};
if height(S) > 0
    [u, ~, j] = unique(S.local_identifier);
    dup = u(accumarray(j, 1) > 1);
end
if ~isempty(dup)
    error('ndi:setup:conv:haley:duplicateSubject', ...
        'Two subjects would share local_identifier %s.', strjoin(dup, ', '));
end
kinds = {'assay_plate', 'acclimation_plate', 'food_deprivation_plate', 'plate', 'patch', ...
    'cohort', 'worm'};
counts = cellfun(@(k) sum(strcmp(S.kind, k)), kinds);
fprintf(['DENOMINATOR: %d subject(s) in %d session(s), from %d source file(s): ' ...
    '%d assay plate(s), %d acclimation plate(s), %d food deprivation plate(s), %d E. coli plate(s), ' ...
    '%d patch(es), %d worm cohort(s), %d worm(s)\n'], ...
    height(S), numel(unique(S.session)), nFiles, counts);
names = fieldnames(checks);
fprintf('CHECKS (reported, nothing changed): %d finding(s)\n', ...
    sum(cellfun(@(n) numel(checks.(n)), names)));
for k = 1:numel(names)
    for m = 1:numel(checks.(names{k}))
        fprintf('  %-20s %s\n', names{k}, checks.(names{k}){m});
    end
end
end

% =============================================================================

function s = subjRow(session, kind, id, name, desc, folder, plate, patch, worm, strain, acclimation, exclude, placed, deprivation)
if nargin < 13
    placed = NaT;
end
if nargin < 14
    deprivation = '';
end
s = struct('session', session, 'kind', kind, 'local_identifier', id, 'name', name, ...
    'description', desc, 'folder', folder, 'plate', plate, 'patch', patch, 'worm', worm, ...
    'strain', strain, 'acclimation', acclimation, 'deprivation', deprivation, ...
    'exclude', logical(exclude), 'worms_placed', placed, 'bacteria', '', 'cohort', '', ...
    'prep', blankPrep());
end

function p = blankPrep()
% What stage 8 needs to know about how a plate or patch was made (decisions
% #54, #56): NaT / NaN / '' where the source has nothing.
p = struct('seeded', NaT, 'cold_room', NaT, 'room_temp', NaT, 'room_temp_note', '', ...
    'poured', NaT, 'poured_cold_room', NaT, 'peptone', '', 'od600', NaN, 'volume_ul', NaN, ...
    'room_temp_by_rule', false);
end

function p = prepOf(R, seeded, coldRoom, roomTemp, od600)
% A plate's preparation from the first of its rows (the columns repeat per row).
p = blankPrep();
p.seeded = colOr(R, seeded, NaT);
p.cold_room = colOr(R, coldRoom, NaT);
p.room_temp = colOr(R, roomTemp, NaT);
p.od600 = double(od600);
p.volume_ul = double(colOr(R, 'lawnVolume', NaN));
v = colOr(R, 'peptone', '');
if iscell(v), v = v{1}; end
if isstring(v) && any(ismissing(v)), v = ''; end
p.peptone = lower(strtrim(char(v)));
end

function p = growthPrepOf(R)
% The acclimation plate's preparation, from its assay plates' growth
% columns. Its volume (200 uL) and agar are the spec's, not the assay plate's.
p = prepOf(R, 'growthTimeSeed', 'growthTimeColdRoom', 'growthTimeRoomTemp', ...
    colOr(R, 'growthOD600', NaN));
p.volume_ul = NaN;
p.peptone = '';
end

function v = colOr(R, name, default)
% R.(name)(1) when the table has that column, else DEFAULT.
if ismember(name, R.Properties.VariableNames) && height(R) > 0
    v = R.(name)(1, :);
    if iscell(v), v = v{1}; end
    if isnumeric(v) || islogical(v), v = double(v(1)); end
    if isdatetime(v), v = v(1); end
else
    v = default;
end
end

function tf = samePrep(a, b)
same = @(x, y) (isnat(x) && isnat(y)) || isequal(x, y);
tf = same(a.seeded, b.seeded) && same(a.cold_room, b.cold_room) && same(a.room_temp, b.room_temp);
end

function t = typeOf(kind, bacteria)
% subject.type (decision #55): plates are material; a patch with bacteria is
% a culture (a lawn: a population whose members are never subjects), one of
% LB alone is material; a worm is an organism; a cohort is a group.
switch kind
    case 'worm'
        t = 'organism';
    case 'cohort'
        t = 'group';
    case 'patch'
        if isempty(bacteria), t = 'material'; else, t = 'culture'; end
    otherwise
        t = 'material';
end
end

function k = growthKey(p)
if isnat(p.pick)
    t = 'NaT';
else
    t = char(p.pick, 'yyyyMMddHHmmss');
end
k = [p.strain '|' t];
end
