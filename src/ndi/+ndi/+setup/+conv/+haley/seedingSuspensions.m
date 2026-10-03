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
%   needed. So, per day:
%     OD600 10 solution   ingredients: the strain at OD600Real (source unit
%                         OD600; particles_per_liter = CFU x 2e10 when the
%                         CFU was measured -- decision #57), then the diluent
%     dilution, per OD600 ingredients: the OD600 10 solution as a
%                         volume_fraction of nominal/10 (source value: the
%                         nominal OD600), then the diluent
%   OD600 10 is the solution itself and OD600 0 the diluent alone, so neither
%   is a dilution. There is no master or culture entry (decision #57, option
%   B): the master's own reading is only in the Benchling entries, and no
%   column names a culture bottle.
%
%   Studies that share a seeding day AND read identically (same OD600Real and
%   CFU) used one solution (Jess, decision #57): it is built once. If those
%   studies' diluents differ (SPEC.seeding.diluent), the solution's diluent is
%   unknown and it lists none. The spec's `corrections` with column `CFU` or
%   `OD600Real` are applied first (by folder and seed_day).
%
%   Acclimation (growth) plates were all seeded alike, 200 uL at `growthOD600`
%   (OD600 1) in SPEC.seeding.growth_diluent (LB; the paper's Methods, and Jess
%   for Matching's): a growth seeding uses that day's solution in that diluent
%   (or of unknown diluent), its own study's if it has one, else another
%   study's -- Matching's S-Complete days use Mini's LB solution. Its nominal
%   OD600 joins that solution's dilutions. A growth seeding day with no such
%   solution is reported, not invented.
%
%   S has fields:
%     entries   1xN cell of formulation entries (key, type, ingredients),
%               each solution before its dilutions
%     index     table: folder, day, od600 (nominal), key -- which formulation a
%               plate of FOLDER seeded on DAY at OD600 was pipetted from
%               ('' for OD600 0 with an unknown diluent); kind is "assay" or
%               "growth"
%   CHECKS (also printed): missingColumns (a table without the seeding
%   columns; nothing built from it), twoReadings (a study-day with more than
%   one OD600Real/CFU; the first is used), noReading (rows with no timeSeed or
%   OD600Real), growthWithoutSolution (a growth seeding day with no solution).
%
%   See also ndi.setup.V2.datasetMetadata, ndi.setup.conv.haley.import_V2.

arguments
    dataParentDir (1,:) char {mustBeFolder}
    spec struct
end

cfg = spec.seeding;
root = fullfile(dataParentDir, 'haley');
checks = struct('missingColumns', {{}}, 'twoReadings', {{}}, 'noReading', {{}}, ...
    'growthWithoutSolution', {{}});
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
    'nominal', {});
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
    T = applyCorrections(T, folder, spec);
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
        R(end+1) = struct('folder', folder, 'strain', pick(cfg.strain, folder), ...
            'diluent', pick(cfg.diluent, folder), 'day', days(k), 'od', od(r(1)), ...
            'cfu', cfu(r(1)), 'nominal', uniq(nominal)); %#ok<AGROW>
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
    'folders', {}, 'nominal', {});
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
    sol(s) = struct('key', key, 'strain', x.strain, 'day', x.day, 'od', x.od, 'cfu', x.cfu, ...
        'diluent', diluent, 'folders', {{members.folder}}, 'nominal', uniq([members.nominal]));
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
        checks.growthWithoutSolution{end+1} = sprintf(['%s %s: acclimation plates seeded, ' ...
            'no %s solution measured that day'], growth(k).folder, ...
            datestr(growth(k).day, 'yyyy-mm-dd'), gdil); %#ok<DATST>
        continue;
    end
    sol(s).nominal = uniq([sol(s).nominal, growth(k).nominal]);
    for n = growth(k).nominal
        growthRows(end+1, :) = [k, s, n]; %#ok<AGROW>
    end
end

% ---- entries and the index -------------------------------------------------
entries = {};
index = table('Size', [0 5], 'VariableTypes', {'cell', 'datetime', 'double', 'cell', 'cell'}, ...
    'VariableNames', {'folder', 'day', 'od600', 'key', 'kind'});
for s = 1:numel(sol)
    x = sol(s);
    c = struct();
    if ~isnan(x.cfu)
        c.particles_per_liter = x.cfu * 2e10;
    end
    c.source_value = x.od;
    c.source_unit = 'OD600';
    ing = {struct('ingredient', x.strain, 'concentration', c)};
    if ~isempty(x.diluent)
        ing{end+1} = struct('ingredient', x.diluent); %#ok<AGROW>
    end
    entries{end+1} = struct('key', x.key, 'type', cfg.type, 'ingredients', {ing}); %#ok<AGROW>
    for n = x.nominal(x.nominal > 0 & x.nominal ~= 10)
        ing = {struct('ingredient', x.key, 'concentration', struct('volume_fraction', n / 10, ...
            'source_value', n, 'source_unit', 'OD600'))};
        if ~isempty(x.diluent)
            ing{end+1} = struct('ingredient', x.diluent); %#ok<AGROW>
        end
        entries{end+1} = struct('key', keyFor(x.key, n, x.diluent), 'type', cfg.type, ...
            'ingredients', {ing}); %#ok<AGROW>
    end
end
for r = 1:numel(R)
    x = sol(grp(r));
    for n = R(r).nominal
        index(end+1, :) = {R(r).folder, R(r).day, n, keyFor(x.key, n, x.diluent), 'assay'}; %#ok<AGROW>
    end
end
for k = 1:size(growthRows, 1)
    g = growth(growthRows(k, 1));
    x = sol(growthRows(k, 2));
    n = growthRows(k, 3);
    index(end+1, :) = {g.folder, g.day, n, keyFor(x.key, n, x.diluent), 'growth'}; %#ok<AGROW>
end

S = struct('entries', {entries}, 'index', index);
fprintf(['DENOMINATOR: %d source table(s) with seeding columns, %d row(s); %d study-day ' ...
    'reading(s) -> %d OD600 10 solution(s), %d formulation(s) in all; %d growth seeding ' ...
    'day(s), %d matched to a solution\n'], ...
    nTables, nRows, numel(R), numel(usig), numel(entries), numel(growth), ...
    numel(unique(growthRows(:, 1))));
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

function T = applyCorrections(T, folder, spec)
% The spec's named corrections to a seeding column (decision #57).
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
    r = dateshift(T.timeSeed, 'start', 'day') == datetime(x.seed_day, 'InputFormat', 'yyyy-MM-dd');
    v = x.value;
    if isempty(v), v = NaN; end
    col = double(T.(x.column));
    col(r) = v;
    T.(x.column) = col;
end
end

function k = keyFor(key, n, diluent)
if n == 10
    k = key;
elseif n == 0
    k = diluent;
else
    k = sprintf('%s_od%s', key, strrep(sprintf('%g', n), '.', 'p'));
end
end

function v = flat(x)
if iscell(x), x = [x{:}]; end
if iscell(x), x = [x{:}]; end
v = double(x(:)');
v = v(~isnan(v));
end

function v = uniq(v)
v = unique(round(double(v(:)'), 9));
v = v(~isnan(v));
end

function v = pick(s, folder)
if isfield(s, folder)
    v = s.(folder);
else
    v = s.default;
end
end

function v = getOr(s, name, default)
if isfield(s, name), v = s.(name); else, v = default; end
end
