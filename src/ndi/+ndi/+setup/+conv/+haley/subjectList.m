function [S, checks] = subjectList(dataParentDir, sessions)
%SUBJECTLIST Stage 4 (Haley): the subjects to create, per session.
%
%   [S, CHECKS] = ndi.setup.conv.haley.subjectList(DATAPARENTDIR, SESSIONS)
%   reads the raw data under DATAPARENTDIR/haley and returns one row per
%   subject, each assigned to a session of SESSIONS (the table from
%   ndi.setup.conv.haley.sessionList). Decision log #37-#41.
%
%   C. elegans, from <folder>/experimentInfo.mat `info` (one row per
%   plate-video):
%     behaviour_plate  one per distinct plateNum      concentration_plate0011
%     patch            one per row of the plate's     concentration_plate0011_patch0007
%                      lawnCenters (numbered in that
%                      order, which is closestLawnID's)
%     worm             one per distinct wormNum       concentration_worm0451
%     growth_plate     one per (strain, pick time) in concentration_0001_growth0001
%                      a session, numbered by pick time
%                      then strain (the source has no
%                      id for it; decision #39)
%   E. coli, from ecoli/bacteria.mat `info` (one row per plate):
%     behaviour_plate  one per plate                  ecoli_plate0042
%     patch            `rectangle` template: 12 (a    ecoli_plate0042_patch0012
%                      3 x 4 grid, numbered row by
%                      row); `none` seeded: 1 (one
%                      large patch; OD600 0 = LB
%                      alone); `none` with
%                      lawnVolume 0: none
%
%   Numbers restart in each source folder, so every local_identifier starts
%   with ndi.setup.conv.haley.idPrefix(folder) (decision #37).
%
%   Columns: session, kind, local_identifier, description, folder, plate,
%   patch, worm, strain, growth (the growth plate a behaviour plate's worms
%   came from), exclude (the source's `exclude` flag, for the assertions
%   stage).
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
%     noPickTime           a plate with no growthTimePicked (its growth
%                          plate is grouped by strain alone)
%     ecoliSeeding         an E. coli plate whose template and seeding
%                          disagree, or a plateNum used by two experiments
%
%   Nothing is written; the subjects stage of import_V2 prints S.

arguments
    dataParentDir (1,:) char {mustBeFolder}
    sessions table
end

root = fullfile(dataParentDir, 'haley');
checks = struct('plateWithoutSession', {{}}, 'plateOnTwoDays', {{}}, ...
    'wormOnTwoPlates', {{}}, 'wormRange', {{}}, 'noLawnCenters', {{}}, ...
    'patchCountDisagrees', {{}}, 'noPickTime', {{}}, 'ecoliSeeding', {{}});
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

    % One record per behaviour plate, gathered first: growth plates are
    % numbered per session, which needs every plate of the session.
    plates = unique(I.plateNum);
    P = struct('plate', {}, 'session', {}, 'worms', {}, 'strain', {}, 'pick', {}, ...
        'nPatch', {}, 'nVideo', {}, 'exclude', {});
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
        P(end+1) = struct('plate', p, 'session', mine.local_identifier{s}, 'worms', kept, ...
            'strain', char(R.strainID{1}), 'pick', pick, 'nPatch', nPatch, ...
            'nVideo', height(R), 'exclude', ex); %#ok<AGROW>
    end

    % Growth plates: one per (session, strain, pick time), numbered within the
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
            gid = sprintf('%s_growth%04d', mine.local_identifier{s}, n);
            members = idx(grp == g);
            for m = 1:numel(members)
                growthOf{members(m)} = gid;
            end
            if isnat(G.pick(n))
                when = 'pick time not recorded';
            else
                when = ['picked ' char(G.pick(n), 'yyyy-MM-dd HH:mm')];
            end
            rows{end+1} = subjRow(mine.local_identifier{s}, 'growth_plate', gid, ...
                sprintf('Growth (cultivation) plate of %s, %s; the worms of %d behaviour plate(s) came from it.', ...
                G.strain{n}, when, numel(members)), folder, NaN, NaN, NaN, G.strain{n}, '', false); %#ok<AGROW>
        end
    end

    % Behaviour plates, their patches and worms.
    for m = 1:numel(P)
        q = P(m);
        pid = sprintf('%s_plate%04d', pre, q.plate);
        rows{end+1} = subjRow(q.session, 'behaviour_plate', pid, ...
            sprintf('Behaviour plate %d: %d worm(s), %d patch(es), filmed in %d video(s).', ...
            q.plate, numel(q.worms), q.nPatch, q.nVideo), folder, q.plate, NaN, NaN, ...
            q.strain, growthOf{m}, q.exclude); %#ok<AGROW>
        for k = 1:q.nPatch
            rows{end+1} = subjRow(q.session, 'patch', sprintf('%s_patch%04d', pid, k), ...
                sprintf('Patch %d of behaviour plate %d.', k, q.plate), folder, q.plate, k, NaN, ...
                '', '', false); %#ok<AGROW>
        end
        for k = 1:numel(q.worms)
            rows{end+1} = subjRow(q.session, 'worm', sprintf('%s_worm%04d', pre, q.worms(k)), ...
                sprintf('Worm %d, on behaviour plate %d.', q.worms(k), q.plate), folder, q.plate, ...
                NaN, q.worms(k), q.strain, growthOf{m}, false); %#ok<AGROW>
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
        rows{end+1} = subjRow(mine.local_identifier{s}, 'behaviour_plate', pid, ...
            sprintf('E. coli plate %d: %s.', p, what), 'ecoli', p, NaN, NaN, '', '', false); %#ok<AGROW>
        for k = 1:nPatch
            rows{end+1} = subjRow(mine.local_identifier{s}, 'patch', sprintf('%s_patch%04d', pid, k), ...
                sprintf('Patch %d of E. coli plate %d.', k, p), 'ecoli', p, k, NaN, '', '', false); %#ok<AGROW>
        end
    end
end

% ---- report -------------------------------------------------------------------
if isempty(rows)
    S = cell2table(cell(0, 11), 'VariableNames', {'session', 'kind', 'local_identifier', ...
        'description', 'folder', 'plate', 'patch', 'worm', 'strain', 'growth', 'exclude'});
else
    S = struct2table([rows{:}], 'AsArray', true);
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
kinds = {'behaviour_plate', 'patch', 'worm', 'growth_plate'};
counts = cellfun(@(k) sum(strcmp(S.kind, k)), kinds);
fprintf(['DENOMINATOR: %d subject(s) in %d session(s), from %d source file(s): ' ...
    '%d behaviour plate(s), %d patch(es), %d worm(s), %d growth plate(s)\n'], ...
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

function s = subjRow(session, kind, id, desc, folder, plate, patch, worm, strain, growth, exclude)
s = struct('session', session, 'kind', kind, 'local_identifier', id, 'description', desc, ...
    'folder', folder, 'plate', plate, 'patch', patch, 'worm', worm, 'strain', strain, ...
    'growth', growth, 'exclude', logical(exclude));
end

function k = growthKey(p)
if isnat(p.pick)
    t = 'NaT';
else
    t = char(p.pick, 'yyyyMMddHHmmss');
end
k = [p.strain '|' t];
end
