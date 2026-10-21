function [S, checks] = seedingSuspensions(dataParentDir, spec)
%SEEDINGSUSPENSIONS Stage 8 part B (Haley): the bacterial suspensions plates were seeded with.
%
%   [S, CHECKS] = ndi.setup.conv.haley.seedingSuspensions(DATAPARENTDIR, SPEC)
%   reads the seeding columns of every source table under DATAPARENTDIR/haley
%   and returns the suspensions as spec-shaped `formulations` entries, for
%   ndi.setup.V2.datasetMetadata to build with the spec's own (decisions #56,
%   #57). They are dataset-level: one day's suspensions served plates filmed on
%   later days and in other sessions.
%
%   Per seeding day the lab pelleted a culture, resuspended it (the master),
%   made an OD600 10 solution from it, measured that solution (`OD600Real`)
%   and, on most days, its CFU (`CFU`), then diluted it to each OD600 the day
%   needed. Each solution actually pipetted is a material ENTITY (decision
%   #114, tenet T19's "a planned value is said by its term"; built by
%   ndi.setup.conv.haley.seedingDocuments) whose formulation is its PLAN:
%     OD600 10 solution   formulation: the strain at its target OD600 10
%                         (`od600` and the source pair, source unit OD600),
%                         then the diluent. Its measured OD600 (`OD600Real`)
%                         and CFU (`CFU`) are observations of the solution
%                         entity (seedingDocuments), not values of the
%                         formulation (decisions #114, #129).
%     dilution, per OD600 formulation: the OD600 10 solution as a
%                         volume_fraction of target/10 (source value: the
%                         target OD600), then the diluent
%   OD600 10 is the solution itself and OD600 0 the diluent alone, so neither
%   is a dilution. There is no master or culture entry (decision #57, option
%   B): the master's own reading is only in the Benchling entries, and no
%   column names a culture bottle.
%
%   Studies that share a seeding day AND read identically (same OD600Real and
%   CFU) used one solution (Jess, decision #57): it is built once. If those
%   studies' diluents differ (SPEC.seeding.diluent), the solution's diluent is
%   unknown and it lists none. The spec's `corrections` with column `CFU` or
%   `OD600Real` are applied first (by folder and seed_day), each only while
%   every row of that day still reads its `was` (decision #111); an applied
%   one's note is the stock solution's (its entity's description).
%
%   Acclimation (growth) plates were all seeded alike, 200 uL at `growthOD600`
%   (OD600 1) in SPEC.seeding.growth_diluent (LB; the paper's Methods, and Jess
%   for Matching's): a growth seeding uses that day's solution in that diluent
%   (or of unknown diluent), its own study's if it has one, else another
%   study's -- Matching's S-Complete days use Mini's LB solution. Its target
%   OD600 joins that solution's dilutions. A growth seeding day with no such
%   solution (no assay plate seeded that day, so no OD600Real or CFU read:
%   foragingMutants 2023-11-09) has only its plan (decision #82, as revised
%   by #114): one solution per target OD600, the strain at that OD600 in the
%   growth diluent, and NO observation (tenet T14, "missing is not a value");
%   it is named like any other (no `unmeasured`), and carries no note, since
%   the source says nothing about it. The run's checks report the day.
%
%   S has fields:
%     entries   1xN cell of formulation entries, the plans (key, ingredients;
%               no `type`: a day's one-off mixture is no standard recipe --
%               the signed formulation.value.type rule, did-schema #84),
%               each solution before its dilutions
%     solutions struct array, one per entry: key (the entity's spec key,
%               <formulation>#solution), formulation, strain, diluent, day,
%               kind ('stock', 'dilution', or 'suspension' for an unmeasured
%               day's), target (its target OD600), stock (a dilution's stock
%               formulation), od and cfu (measured; NaN when not), note (a
%               correction's), folders
%     index     table: folder, day, od600 (nominal), key -- which formulation a
%               plate of FOLDER seeded on DAY at OD600 was pipetted from
%               (for OD600 0, FOLDER's own diluent, even on a day whose
%               solution was shared by studies with different diluents --
%               decision #94); kind is "assay" or "growth"; note ('')
%   CHECKS (also printed): missingColumns (a table without the seeding
%   columns; nothing built from it), twoReadings (a study-day with more than
%   one OD600Real/CFU; the first is used), noReading (rows with no timeSeed or
%   OD600Real), growthWithoutSolution (a growth seeding day with no measured
%   solution; its plan alone is made, decision #82), corrected and
%   correctionNotApplied (decision #111).
%
%   See also ndi.setup.V2.datasetMetadata, ndi.setup.conv.haley.import_V2.

arguments
    dataParentDir (1,:) char {mustBeFolder}
    spec struct
end

cfg = spec.seeding;
root = fullfile(dataParentDir, 'haley');
checks = struct('missingColumns', {{}}, 'twoReadings', {{}}, 'noReading', {{}}, ...
    'growthWithoutSolution', {{}}, 'corrected', {{}}, 'correctionNotApplied', {{}});
need = {'timeSeed', 'OD600Real', 'CFU', 'OD600'};

% ---- every source table: (folder, table) ------------------------------------
tables = {};
d = dir(fullfile(root, 'celegans', '*', 'experimentInfo.mat'));
for k = 1:numel(d)
    I = load(fullfile(d(k).folder, d(k).name), 'info');
    [~, folder] = fileparts(d(k).folder);
    tables(end+1, :) = {folder, I.info}; %#ok<AGROW>
end
f = fullfile(root, 'ecoli', 'bacteria.mat');
if isfile(f)
    B = load(f, 'info');
    tables(end+1, :) = {'ecoli', B.info};
end

% ---- one reading per study and seeding day ---------------------------------
R = struct('folder', {}, 'strain', {}, 'diluent', {}, 'day', {}, 'od', {}, 'cfu', {}, ...
    'nominal', {}, 'note', {});
growth = struct('folder', {}, 'day', {}, 'nominal', {});
nTables = 0;
nRows = 0;
for t = 1:size(tables, 1)
    folder = tables{t, 1};
    T = tables{t, 2};
    missing = setdiff(need, T.Properties.VariableNames);
    if ~isempty(missing)
        checks.missingColumns{end+1} = sprintf('%s: no column(s) %s', folder, strjoin(missing, ', '));
        continue;
    end
    nTables = nTables + 1;
    nRows = nRows + height(T);
    [T, checks, fixNotes] = applyCorrections(T, folder, spec, checks);
    day = dateshift(T.timeSeed, 'start', 'day');
    od = double(T.OD600Real);
    cfu = double(T.CFU);
    bad = isnat(day) | isnan(od);
    if any(bad)
        checks.noReading{end+1} = sprintf('%s: %d row(s) with no timeSeed or OD600Real', folder, nnz(bad));
    end
    days = unique(day(~bad));
    for k = 1:numel(days)
        r = find(~bad & day == days(k));
        % a missing CFU is a value here (-1), so two NaN rows are one reading
        readings = unique(fillmissing([od(r), cfu(r)], 'constant', -1), 'rows');
        if size(readings, 1) > 1
            checks.twoReadings{end+1} = sprintf('%s %s: %d readings; the first is used', ...
                folder, datestr(days(k), 'yyyy-mm-dd'), size(readings, 1)); %#ok<DATST>
        end
        nominal = [];
        for j = r(:)'
            nominal = [nominal, flat(T.OD600(j, :))]; %#ok<AGROW>
        end
        note = '';              % a correction applied to the day (decision #111)
        dayKey = datestr(days(k), 'yyyy-mm-dd'); %#ok<DATST>
        if isKey(fixNotes, dayKey), note = fixNotes(dayKey); end
        R(end+1) = struct('folder', folder, 'strain', pick(cfg.strain, folder), ...
            'diluent', pick(cfg.diluent, folder), 'day', days(k), 'od', od(r(1)), ...
            'cfu', cfu(r(1)), 'nominal', uniq(nominal), 'note', note); %#ok<AGROW>
    end
    if all(ismember({'growthTimeSeed', 'growthOD600'}, T.Properties.VariableNames))
        g = dateshift(T.growthTimeSeed, 'start', 'day');
        ok = ~isnat(g);
        gd = unique(g(ok));
        for k = 1:numel(gd)
            growth(end+1) = struct('folder', folder, 'day', gd(k), ...
                'nominal', uniq(double(T.growthOD600(ok & g == gd(k))))); %#ok<AGROW>
        end
    end
end

% ---- solutions: identical same-day readings are one solution ---------------
sig = arrayfun(@(x) sprintf('%s|%s|%.6g|%.6g', x.strain, datestr(x.day, 'yyyymmdd'), x.od, x.cfu), ...
    R, 'UniformOutput', false); %#ok<DATST>
[usig, ~, grp] = unique(sig, 'stable');
sol = struct('key', {}, 'strain', {}, 'day', {}, 'od', {}, 'cfu', {}, 'diluent', {}, ...
    'folders', {}, 'nominal', {}, 'note', {});
for s = 1:numel(usig)
    members = R(grp == s);
    x = members(1);
    dils = unique({members.diluent});
    diluent = '';               % studies with different diluents shared it: unknown
    if isscalar(dils)
        diluent = dils{1};
    end
    sameDay = find(cellfun(@(q) startsWith(q, sprintf('%s|%s|', x.strain, ...
        datestr(x.day, 'yyyymmdd'))), usig)); %#ok<DATST>
    key = sprintf('suspension_%s_%s', lower(regexprep(x.strain, '\W', '')), ...
        datestr(x.day, 'yyyymmdd')); %#ok<DATST>
    if numel(sameDay) > 1
        key = sprintf('%s_%c', key, 'a' + find(sameDay == s) - 1);
    end
    notes = unique({members.note}, 'stable');
    notes = notes(~cellfun(@isempty, notes));
    sol(s) = struct('key', key, 'strain', x.strain, 'day', x.day, 'od', x.od, 'cfu', x.cfu, ...
        'diluent', diluent, 'folders', {{members.folder}}, 'nominal', uniq([members.nominal]), ...
        'note', strjoin(notes, ' '));
end

% ---- growth seedings: that day's solution in the growth diluent ------------
% Every acclimation plate was seeded alike (SPEC.seeding.growth_diluent): from
% its own study's solution of the day when that is in the growth diluent (or
% of unknown diluent), else from another study's that is.
growthRows = zeros(0, 3);       % [growth k, solution s, nominal]
gdil = getOr(cfg, 'growth_diluent', '');
for k = 1:numel(growth)
    strain = pick(cfg.strain, growth(k).folder);
    cand = [];
    if ~isempty(sol)            % [sol.day] of no solutions is a double, not a datetime
        cand = find(strcmp({sol.strain}, strain) & [sol.day] == growth(k).day & ...
            (strcmp({sol.diluent}, gdil) | strcmp({sol.diluent}, '')));
    end
    own = cand(arrayfun(@(c) any(strcmp(sol(c).folders, growth(k).folder)), cand));
    if ~isempty(own)
        s = own(1);
    elseif ~isempty(cand)
        s = cand(1);
    else
        % no reading that day: the seeding happened, and only its plan is
        % known -- the strain at its target OD600 (decision #82; #114: no
        % observation, since nothing was measured, and no `unmeasured` name)
        checks.growthWithoutSolution{end+1} = sprintf(['%s %s: acclimation plates seeded, ' ...
            'no %s solution measured that day; recorded as its plan, with no measurement'], ...
            growth(k).folder, datestr(growth(k).day, 'yyyy-mm-dd'), gdil); %#ok<DATST>
        key = sprintf('suspension_%s_%s', lower(regexprep(strain, '\W', '')), ...
            datestr(growth(k).day, 'yyyymmdd')); %#ok<DATST>
        s = [];
        if ~isempty(sol)
            s = find(strcmp({sol.key}, key) & isnan([sol.od]), 1);
            if isempty(s) && any(strcmp({sol.key}, key))
                % a measured solution of another diluent has that day's name
                key = sprintf('%s_%s', key, lower(regexprep(gdil, '\W', '')));
            end
        end
        if isempty(s)
            sol(end + 1) = struct('key', key, 'strain', strain, 'day', growth(k).day, 'od', NaN, ...
                'cfu', NaN, 'diluent', gdil, 'folders', {{growth(k).folder}}, 'nominal', [], ...
                'note', '');
            s = numel(sol);
        end
    end
    sol(s).nominal = uniq([sol(s).nominal, growth(k).nominal]);
    for n = growth(k).nominal
        growthRows(end+1, :) = [k, s, n]; %#ok<AGROW>
    end
end

% ---- entries (the plans), the solutions, and the index -----------------------
% Each solution pipetted is a material entity (built by seedingDocuments), and
% its formulation is its PLAN (decision #114): the stock is the strain at its
% target OD600 10 in the diluent, a dilution the stock at its target fraction.
% What was MEASURED of the stock (`OD600Real`) is an observation of the stock
% entity, not a value of its formulation. An OD600 is concentration's `od600`
% canonical (did-schema, Jess 2026-10-20), with the source pair beside it.
entries = {};
solutions = struct('key', {}, 'formulation', {}, 'strain', {}, 'diluent', {}, 'day', {}, ...
    'kind', {}, 'target', {}, 'stock', {}, 'od', {}, 'cfu', {}, 'note', {}, 'folders', {});
index = table('Size', [0 6], 'VariableTypes', {'cell', 'datetime', 'double', 'cell', 'cell', 'cell'}, ...
    'VariableNames', {'folder', 'day', 'od600', 'key', 'kind', 'note'});
for s = 1:numel(sol)
    x = sol(s);
    if isnan(x.od)
        % unmeasured (decision #82): no stock is known; each target OD600 is
        % its own solution, the strain at that OD600 (its plan alone)
        for n = x.nominal
            ing = {struct('ingredient', x.strain, 'concentration', target(n))};
            if ~isempty(x.diluent)
                ing{end+1} = struct('ingredient', x.diluent); %#ok<AGROW>
            end
            fk = keyFor(x.key, n, x.diluent);
            entries{end+1} = struct('key', fk, 'ingredients', {ing}); %#ok<AGROW>
            solutions(end+1) = solution(fk, x, 'suspension', n, '', NaN, NaN, ''); %#ok<AGROW>
        end
        continue;
    end
    % the stock's plan: the strain at OD600 10. What was measured of it (its
    % OD600 and CFU) is an observation of the solution (decisions #114, #129)
    c = target(10);
    ing = {struct('ingredient', x.strain, 'concentration', c)};
    if ~isempty(x.diluent)
        ing{end+1} = struct('ingredient', x.diluent); %#ok<AGROW>
    end
    entries{end+1} = struct('key', x.key, 'ingredients', {ing}); %#ok<AGROW>
    solutions(end+1) = solution(x.key, x, 'stock', 10, '', x.od, x.cfu, x.note); %#ok<AGROW>
    for n = x.nominal(x.nominal > 0 & x.nominal ~= 10)
        ing = {struct('ingredient', x.key, 'concentration', struct('volume_fraction', n / 10, ...
            'source_value', n, 'source_unit', ndi.setup.V2.sourceUnit('OD600')))};
        if ~isempty(x.diluent)
            ing{end+1} = struct('ingredient', x.diluent); %#ok<AGROW>
        end
        fk = keyFor(x.key, n, x.diluent);
        entries{end+1} = struct('key', fk, 'ingredients', {ing}); %#ok<AGROW>
        solutions(end+1) = solution(fk, x, 'dilution', n, x.key, NaN, NaN, ''); %#ok<AGROW>
    end
end
for r = 1:numel(R)
    x = sol(grp(r));
    for n = R(r).nominal
        % an OD600 0 patch is its own study's diluent alone, whatever the
        % day's shared solution was made in (Jess, decision #94)
        dil = x.diluent;
        if n == 0, dil = R(r).diluent; end
        index(end+1, :) = {R(r).folder, R(r).day, n, keyFor(x.key, n, dil), 'assay', ''}; %#ok<AGROW>
    end
end
for k = 1:size(growthRows, 1)
    g = growth(growthRows(k, 1));
    x = sol(growthRows(k, 2));
    n = growthRows(k, 3);
    % no note for an unmeasured day: the source says nothing about it, and a
    % missing measurement is absent, not described (tenet T14, decision #114)
    index(end+1, :) = {g.folder, g.day, n, keyFor(x.key, n, x.diluent), 'growth', ''}; %#ok<AGROW>
end

S = struct('entries', {entries}, 'index', index, 'solutions', solutions);
fprintf(['DENOMINATOR: %d source table(s) with seeding columns, %d row(s); %d study-day ' ...
    'reading(s) -> %d OD600 10 solution(s), %d solution(s) and formulation(s) in all ' ...
    '(%d measured stock(s), %d dilution(s), %d unmeasured); %d growth seeding ' ...
    'day(s), %d matched to a solution\n'], ...
    nTables, nRows, numel(R), numel(usig), numel(entries), sum(strcmp({solutions.kind}, 'stock')), ...
    sum(strcmp({solutions.kind}, 'dilution')), sum(strcmp({solutions.kind}, 'suspension')), ...
    numel(growth), numel(unique(growthRows(:, 1))));
names = fieldnames(checks);
n = sum(cellfun(@(q) numel(checks.(q)), names));
if n > 0
    fprintf('CHECKS (reported, nothing changed): %d finding(s)\n', n);
    for k = 1:numel(names)
        for j = 1:numel(checks.(names{k}))
            fprintf('  %-22s %s\n', names{k}, checks.(names{k}){j});
        end
    end
end
end

function [T, checks, notes] = applyCorrections(T, folder, spec, checks)
% The spec's named corrections to a seeding column (decision #57), by folder
% and seed_day, each applied only while every row of that day still reads
% its `was` (decision #111, applyCorrection). NOTES maps a day
% ('yyyy-MM-dd') to the standard note of the correction(s) applied to it.
arguments
    T table
    folder {mustBeText}
    spec struct
    checks (1,1) struct
end
notes = containers.Map('KeyType', 'char', 'ValueType', 'any');
if ~isfield(spec, 'corrections')
    return;
end
c = spec.corrections;
if isstruct(c), c = num2cell(c); end
for k = 1:numel(c)
    x = c{k};
    if ~strcmp(x.folder, folder) || ~any(strcmp(x.column, {'CFU', 'OD600Real'})) ...
            || ~isfield(x, 'seed_day')
        continue;
    end
    r = find(dateshift(T.timeSeed, 'start', 'day') == datetime(x.seed_day, 'InputFormat', 'yyyy-MM-dd'));
    where = sprintf('%s seeding day %s', folder, char(x.seed_day));
    if isempty(r)
        checks.correctionNotApplied{end+1} = sprintf('%s: %s has no rows; nothing to correct', ...
            char(x.key), where);
        continue;
    end
    col = double(T.(x.column));
    ok = true;
    for j = r(:)'
        [v, applied, note, line] = applyCorrection(x, col(j), where);
        if ~applied
            ok = false;
            break;
        end
    end
    if ~ok
        checks.correctionNotApplied{end+1} = line;
        continue;
    end
    col(r) = v;
    T.(x.column) = col;
    checks.corrected{end+1} = sprintf('%s (%d row(s))', line, numel(r));
    d = char(x.seed_day);
    if isKey(notes, d), notes(d) = [notes(d) ' ' note]; else, notes(d) = note; end
end
end

function c = target(n)
% a planned OD600, as a concentration: `od600`, and the source pair (the plan
% is stated in OD600)
arguments
    n (1,1) double
end
c = struct('od600', n);
c.source_value = n;
c.source_unit = ndi.setup.V2.sourceUnit('OD600');
end

function x = solution(fk, s, kind, target, stock, od, cfu, note)
% one solution pipetted (decision #114): the material entity seedingDocuments
% builds, made to formulation FK; OD and CFU what was measured of it (NaN: not)
arguments
    fk {mustBeText}
    s (1,1) struct
    kind {mustBeText}
    target (1,1) double
    stock {mustBeText}
    od (1,1) double
    cfu (1,1) double
    note {mustBeText}
end
x = struct('key', [fk '#solution'], 'formulation', fk, 'strain', s.strain, 'diluent', s.diluent, ...
    'day', s.day, 'kind', kind, 'target', target, 'stock', stock, 'od', od, 'cfu', cfu, ...
    'note', note, 'folders', {s.folders});
end

function k = keyFor(key, n, diluent)
arguments
    key {mustBeText}
    n (1,1) {mustBeNumeric}
    diluent {mustBeText}
end
if n == 10
    k = key;
elseif n == 0
    k = diluent;
else
    k = sprintf('%s_od%s', key, strrep(sprintf('%g', n), '.', 'p'));
end
end

function v = flat(x)
arguments
    x
end
if iscell(x), x = [x{:}]; end
if iscell(x), x = [x{:}]; end
v = double(x(:)');
v = v(~isnan(v));
end

function v = uniq(v)
arguments
    v
end
v = unique(round(double(v(:)'), 9));
v = v(~isnan(v));
end

function v = pick(s, folder)
arguments
    s struct
    folder {mustBeText}
end
if isfield(s, folder)
    v = s.(folder);
else
    v = s.default;
end
end

function v = getOr(s, name, default)
arguments
    s struct
    name {mustBeText}
    default
end
if isfield(s, name), v = s.(name); else, v = default; end
end
