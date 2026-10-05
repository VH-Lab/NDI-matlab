function out = densityDocuments(dataParentDir, sessions, built, options)
%DENSITYDOCUMENTS Stage 12 (Haley): the border amplitude fits, across studies.
%
%   OUT = ndi.setup.conv.haley.densityDocuments(DATAPARENTDIR, SESSIONS, BUILT,
%   ...) builds, from the sessions built in this run (SESSIONS, the session
%   table with session_id; BUILT, each session's stage outputs), the documents
%   that carry the E. coli fits over to the C. elegans patches. Decision #65.
%
%   THE FITS are the lab's (Haley et al. 2024, analysis/plotForagingGFP.m):
%   per E. coli condition (peptone, lawn volume, growth-time condition,
%   OD600), a straight line through border amplitude / exposure time
%   (a.u. per ms) against growth time (minutes), over the included patches;
%   OD600 0.05 and 0.1, which were not imaged, from ONE joint fit per lawn
%   volume, f = a*OD600 + b*t, over OD600 0.5-2. The numbers are the published
%   ones, ecoli/borderAmplitude.csv (option 'FitsFile'); each is refitted
%   here from the per-patch values under the same rules, and a fit that does
%   not reproduce is reported (OUT.checks.refitDisagrees). With no CSV the
%   refits are stored, and OUT.skipped says so.
%
%   Included patches, as plotForagingGFP excludes: image
%   20231230_101739.czi; plate 64; 0.5 uL patches with circularity < 0.75; a
%   border / centre ratio < 1 or > 35; then, per image, the lowest xPeak until
%   the image's xPeak range is at most 0.1 mm.
%
%   Dataset-level documents (OUT.datasetDocuments; written with stage 2's at
%   stage 13):
%     subject             per fit, a GROUP of E. coli patches (type `group`):
%                         the patches of that condition (joint fits: of OD600
%                         0.5-2), each `member_of` it
%     directed_relation   patch member_of group
%     model_fit_calculation  the group's `border amplitude growth`: the line,
%                         its coefficients and goodness (r2, sse, sse per
%                         point); conditions the seeding condition; inputs the
%                         INCLUDED patches' `patch border amplitude` statements
%                         (stage 10 part C), so the exclusions are the values
%                         left out; method `linear least squares`, method
%                         parameters the exclusion rules; time the span of the
%                         included images
%     absolute_time_reference  that span
%   Per C. elegans worm with encounters (OUT.sessionDocuments{k}, keyed by the
%   worm's encounter list like stage 11's values):
%     intensity_calculation  `estimated patch border amplitude`: encounter.mat
%                         borderAmplitude (a.u. per ms of exposure), from the
%                         fit for the patch's condition at its growth time;
%                         0 for a patch of LB alone; NaN where no fit matches
%     intensity_calculation  `estimated cultivation plate border amplitude`:
%                         borderAmplitudeGrowth, from the 200 uL fit at the
%                         cultivation plate's growth time
%   Each value is checked against the fit it names (OUT.checks
%   .encounterDisagrees). Relative density (modelExploit's 10 x / the OD 10
%   mean, floored at 0.01, log10) is not stored: it is computed in the model
%   script, not in any source file.
%
%   Options: 'DatasetSessionId', 'SoftwareId', 'InterpreterId',
%   'OperatingSystemId' (the run environment, as stage 10), 'FitsFile'.

arguments
    dataParentDir (1,:) char {mustBeFolder}
    sessions table
    built cell
    options.DatasetSessionId (1,:) char = ''
    options.SoftwareId (1,:) char = ''
    options.InterpreterId (1,:) char = ''
    options.OperatingSystemId (1,:) char = ''
    options.FitsFile (1,:) char = ''
end
dsid = options.DatasetSessionId;
out = struct('datasetDocuments', {{}}, 'sessionDocuments', {repmat({{}}, height(sessions), 1)}, ...
    'skipped', {{}}, 'checks', struct('refitDisagrees', {{}}, 'encounterDisagrees', {{}}), ...
    'counts', struct('fits', 0, 'groups', 0, 'members', 0, 'inputs', 0, 'refit_checked', 0, ...
    'worms', 0, 'estimates', 0, 'encounters_checked', 0), 'fits', table());
if isempty(options.OperatingSystemId)
    out.skipped{end+1} = 'no operating system document (built by the metadata stage); no fits';
    return;
end
env = {};
if ~isempty(options.SoftwareId), env = [env, {'SoftwareId', options.SoftwareId}]; end
if ~isempty(options.InterpreterId), env = [env, {'InterpreterId', options.InterpreterId}]; end
env = [env, {'OperatingSystemId', options.OperatingSystemId}];
tz = 'America/Los_Angeles';
fmt = 'yyyy-MM-dd''T''HH:mm:ss';
root = fullfile(dataParentDir, 'haley', 'ecoli');

% ---- the E. coli values this run built ---------------------------------------
values = struct('imageNum', {}, 'row', {}, 'patchId', {}, 'statementId', {});
for k = 1:numel(built)
    if ~isempty(built{k}) && isfield(built{k}, 'ecoli')
        values = [values, built{k}.ecoli.borderValues]; %#ok<AGROW>
    end
end
if isempty(values)
    out.skipped{end+1} = ['no E. coli patch values in this run (the E. coli session with ' ...
        'the calculations stage); no fits'];
    return;
end
byRow = containers.Map(arrayfun(@(v) sprintf('%d|%d', v.imageNum, v.row), values, ...
    'UniformOutput', false), num2cell(1:numel(values)));

B = load(fullfile(root, 'bacteria.mat'), 'lawnAnalysis');
L = B.lawnAnalysis;
need = {'imageNum', 'plateNum', 'fileName', 'exposureTime', 'peptone', 'OD600', 'lawnVolume', ...
    'growthTimeCondition', 'growthTimeTotal', 'borderAmplitude', 'borderCenterRatio', ...
    'circularity', 'xPeak', 'acquisitionTime'};
missing = setdiff(need, L.Properties.VariableNames);
if ~isempty(missing)
    out.skipped{end+1} = sprintf('bacteria.mat lawnAnalysis has no %s; no fits', strjoin(missing, ', '));
    return;
end
L.peptone = cellstr(L.peptone);
L.fileName = cellstr(L.fileName);
% each row's stored statement: its position among its image's rows
L.row = zeros(height(L), 1);
L.statementId = repmat({''}, height(L), 1);
L.patchId = repmat({''}, height(L), 1);
for n = unique(L.imageNum)'
    idx = find(L.imageNum == n);
    for j = 1:numel(idx)
        L.row(idx(j)) = j;
        key = sprintf('%d|%d', n, j);
        if isKey(byRow, key)
            v = values(byRow(key));
            L.statementId{idx(j)} = v.statementId;
            L.patchId{idx(j)} = v.patchId;
        end
    end
end
t = growthMinutes(L.growthTimeTotal);
f = double(L.borderAmplitude) ./ double(L.exposureTime);
L.include = included(L);

% ---- the published fits --------------------------------------------------------
file = options.FitsFile;
if isempty(file), file = fullfile(root, 'borderAmplitude.csv'); end
F = table();
if isfile(file)
    F = readtable(file, 'TextType', 'char', 'Delimiter', ',');
else
    out.skipped{end+1} = sprintf('no %s: the refitted lines are stored instead', file);
end
joint = @(T) strcmp(T.peptone, 'with') & T.growthTimeCondition == 0 & ismember(T.OD600, [0.05 0.1]);

% the fits to make: one per CSV row, the joint rows as one fit per volume
fits = struct('kind', {}, 'peptone', {}, 'volume', {}, 'growth', {}, 'od', {}, 'sel', {}, ...
    'members', {}, 'coef', {}, 'goodness', {}, 'n', {});
if height(F) > 0
    single = F(~joint(F), :);
    for r = 1:height(single)
        c = single(r, :);
        m = strcmp(L.peptone, c.peptone{1}) & L.lawnVolume == c.lawnVolume & ...
            L.growthTimeCondition == c.growthTimeCondition & L.OD600 == c.OD600;
        fits(end+1) = struct('kind', 'single', 'peptone', c.peptone{1}, 'volume', c.lawnVolume, ...
            'growth', c.growthTimeCondition, 'od', c.OD600, 'sel', m & L.include, 'members', m, ...
            'coef', [c.slope, c.intercept], 'goodness', [c.rsquare, c.sse], 'n', c.dfe + 2); %#ok<AGROW>
    end
    J = F(joint(F), :);
    for vol = unique(J.lawnVolume)'
        c = J(J.lawnVolume == vol, :);
        m = strcmp(L.peptone, 'with') & L.lawnVolume == vol & L.growthTimeCondition == 0 & ...
            L.OD600 >= 0.5 & L.OD600 <= 2;
        a = c.intercept ./ c.OD600;
        fits(end+1) = struct('kind', 'joint', 'peptone', 'with', 'volume', vol, 'growth', 0, ...
            'od', [0.5 2], 'sel', m & L.include, 'members', m, 'coef', [a(1), c.slope(1)], ...
            'goodness', [c.rsquare(1), c.sse(1)], 'n', c.dfe(1) + 2); %#ok<AGROW>
    end
else
    G = findgroups(L.peptone, L.lawnVolume, L.growthTimeCondition, L.OD600);
    for g = 1:max(G)
        m = G == g;
        r = find(m, 1);
        fits(end+1) = struct('kind', 'single', 'peptone', L.peptone{r}, 'volume', L.lawnVolume(r), ...
            'growth', L.growthTimeCondition(r), 'od', L.OD600(r), 'sel', m & L.include, ...
            'members', m, 'coef', [NaN NaN], 'goodness', [NaN NaN], 'n', NaN); %#ok<AGROW>
    end
end

% ---- refit each, and build its group and its fit ---------------------------------
fitIds = cell(1, numel(fits));
for i = 1:numel(fits)
    q = fits(i);
    sel = q.sel & ~isnan(f) & ~isnan(t);
    re = [NaN NaN];
    if strcmp(q.kind, 'single') && sum(sel) >= 2
        re = ([t(sel), ones(sum(sel), 1)] \ f(sel))';
    elseif strcmp(q.kind, 'joint') && sum(sel) >= 2
        re = ([double(L.OD600(sel)), t(sel)] \ f(sel))';
    end
    label = conditionText(q);
    if height(F) == 0
        q.coef = re;
        res = f(sel) - designOf(q, L, t, sel) * re';
        q.goodness = [1 - sum(res.^2) / sum((f(sel) - mean(f(sel))).^2), sum(res.^2)];
        q.n = sum(sel);
    elseif any(isnan(re))
        out.checks.refitDisagrees{end+1} = sprintf('%s: %d included value(s), too few to refit', ...
            label, sum(sel));
    else
        out.counts.refit_checked = out.counts.refit_checked + 1;
        if any(abs(re - q.coef) > 1e-6 * max(1, abs(q.coef)))
            out.checks.refitDisagrees{end+1} = sprintf(['%s: published [%g %g], refitted ' ...
                '[%g %g] over %d included value(s)'], label, q.coef, re, sum(sel));
        end
    end
    if sum(sel) ~= q.n && ~isnan(q.n) && height(F) > 0
        out.checks.refitDisagrees{end+1} = sprintf('%s: %d value(s) by the published dfe, %d included here', ...
            label, q.n, sum(sel));
    end

    % its time: the included images' span (none: no fit, and no group)
    times = L.acquisitionTime(q.sel);
    times = times(~isnat(times));
    if isempty(times)
        out.skipped{end+1} = sprintf('%s: no included image with an acquisition time; no fit', label);
        fits(i) = q;
        continue;
    end
    w = utcReference(wallClock(min(times), tz), [], fmt, wallClock(max(times), tz), [], fmt, ...
        true, tz, dsid);
    out.datasetDocuments{end+1} = w;
    timeIds = {w.base.id};

    % the group of patches
    grp = did2.build.document('subject', groupFields(q, label), 'SessionId', dsid);
    out.datasetDocuments{end+1} = grp;
    out.counts.groups = out.counts.groups + 1;
    pats = unique(L.patchId(q.members & ~cellfun(@isempty, L.patchId)));
    for p = 1:numel(pats)
        out.datasetDocuments{end+1} = did2.build.directedRelation(pats{p}, grp.base.id, ...
            'member_of', 'SessionId', dsid);
        out.counts.members = out.counts.members + 1;
    end
    lost = sum(q.sel & cellfun(@isempty, L.statementId));
    if lost > 0
        out.skipped{end+1} = sprintf(['%s: %d included value(s) are not stored (their image ' ...
            'was not matched to its patches), so not among the fit''s inputs'], label, lost);
    end

    inputs = L.statementId(q.sel & ~cellfun(@isempty, L.statementId))';
    fit = did2.build.statement('model_fit_calculation', grp.base.id, ...
        did2.build.term('', 'border amplitude growth'), fitValue(q), ...
        'Conditions', conditionsOf(q), 'Method', did2.build.term('', 'linear least squares'), ...
        'MethodParameters', rules(), 'InputIds', inputs, 'TimeReferenceIds', timeIds, ...
        'SessionId', dsid, env{:}, 'Notes', ['Border amplitude divided by exposure time ' ...
        '(a.u. per ms) against growth time (min), as plotForagingGFP fits it.']);
    out.datasetDocuments{end+1} = fit;
    fitIds{i} = fit.base.id;
    fits(i) = q;
    out.counts.fits = out.counts.fits + 1;
    out.counts.inputs = out.counts.inputs + numel(inputs);
end
out.fits = struct2table(rmfield(fits, {'sel', 'members'}), 'AsArray', true);
out.fits.id = fitIds(:);

% ---- the C. elegans estimates ---------------------------------------------------
for k = 1:numel(built)
    if isempty(built{k}) || ~isfield(built{k}, 'encounters')
        continue;
    end
    sid = char(sessions.session_id{k});
    worms = built{k}.encounters.byWorm;
    names = keys(worms);
    docs = {};
    for w = 1:numel(names)
        x = worms(names{w});
        E = x.rows;
        need = {'lawnOD600', 'lawnVolume', 'growthCondition', 'peptone', 'lawnGrowth', ...
            'borderAmplitude'};
        if ~all(ismember(need, E.Properties.VariableNames)) || height(E) == 0
            continue;
        end
        [ids, pred] = patchFits(E, fits, fitIds);
        check(names{w}, 'patch', double(E.borderAmplitude), pred);
        in = reshape(unique(ids(~cellfun(@isempty, ids)), 'stable'), 1, []);
        docs{end+1} = did2.build.statement('intensity_calculation', x.wormId, ...
            did2.build.term('', 'estimated patch border amplitude'), ...
            did2.build.valueCell('intensity', reshape(double(E.borderAmplitude), 1, [])), ...
            'Method', did2.build.term('', 'calibration from the E. coli border amplitude fits'), ...
            x.keyed{:}, 'InputIds', [{x.listId}, in], x.calc{:}, 'Notes', ...
            ['Per ms of exposure, from the fit for the patch''s seeding condition at its growth ' ...
            'time (encounter.mat lawnGrowth, min); 0 for a patch of LB alone; NaN where no fit ' ...
            'matches (labelEncounters).']); %#ok<AGROW>
        out.counts.estimates = out.counts.estimates + 1;
        if all(ismember({'growthLawnGrowth', 'borderAmplitudeGrowth'}, E.Properties.VariableNames))
            g = find(arrayfun(@(q) strcmp(q.kind, 'single') && q.volume == 200, fits), 1);
            gIn = {};
            gPred = NaN(height(E), 1);
            if ~isempty(g)
                if ~isempty(fitIds{g}), gIn = fitIds(g); end
                gPred = fits(g).coef(2) + fits(g).coef(1) * growthMinutes(E.growthLawnGrowth);
            end
            check(names{w}, 'cultivation plate', double(E.borderAmplitudeGrowth), gPred);
            docs{end+1} = did2.build.statement('intensity_calculation', x.wormId, ...
                did2.build.term('', 'estimated cultivation plate border amplitude'), ...
                did2.build.valueCell('intensity', reshape(double(E.borderAmplitudeGrowth), 1, [])), ...
                'Method', did2.build.term('', 'calibration from the E. coli border amplitude fits'), ...
                x.keyed{:}, 'InputIds', [{x.listId}, gIn], x.calc{:}, 'Notes', ...
                ['Per ms of exposure, from the 200 uL fit at the cultivation plate''s growth time ' ...
                '(encounter.mat growthLawnGrowth).']); %#ok<AGROW>
            out.counts.estimates = out.counts.estimates + 1;
        end
        out.counts.worms = out.counts.worms + 1;
    end
    out.sessionDocuments{k} = docs;
end

    function check(worm, what, got, want)
        ok = isnan(got) & isnan(want) | abs(got - want) <= 1e-6 * max(1, abs(want));
        out.counts.encounters_checked = out.counts.encounters_checked + numel(got);
        if ~all(ok)
            out.checks.encounterDisagrees{end+1} = sprintf(['%s: %d of %d %s value(s) differ ' ...
                'from the fit (first: %g, fit %g)'], worm, sum(~ok), numel(ok), what, ...
                got(find(~ok, 1)), want(find(~ok, 1)));
        end
    end
end

% -----------------------------------------------------------------------------
function inc = included(L)
% plotForagingGFP's exclusions, in its order
inc = ~strcmp(L.fileName, '20231230_101739.czi') & L.plateNum ~= 64;
inc = inc & ~((L.circularity < 0.75 & L.lawnVolume == 0.5) | ...
    L.borderCenterRatio < 1 | L.borderCenterRatio > 35);
for n = unique(L.imageNum)'
    while true
        idx = find(L.imageNum == n & inc);
        if isempty(idx) || max(L.xPeak(idx)) - min(L.xPeak(idx)) <= 0.1
            break;
        end
        [~, worst] = min(L.xPeak(idx));
        inc(idx(worst)) = false;
    end
end
end

function m = growthMinutes(x)
if isduration(x)
    m = minutes(x);
else
    m = double(x);
end
m = m(:);
end

function X = designOf(q, L, t, sel)
if strcmp(q.kind, 'joint')
    X = [double(L.OD600(sel)), t(sel)];
else
    X = [t(sel), ones(sum(sel), 1)];
end
end

function [ids, pred] = patchFits(E, fits, fitIds)
% the fit each encounter's patch takes (labelEncounters' match) and its value
n = height(E);
ids = repmat({''}, n, 1);
pred = NaN(n, 1);
pep = cellstr(E.peptone);
growth = double(E.growthCondition);
growth(growth == 60) = 48;              % labelEncounters: foragingMini's 60 is 48
lg = growthMinutes(E.lawnGrowth);
for i = 1:n
    od = double(E.lawnOD600(i));
    if isnan(od)
        continue;
    end
    if od <= 1e-10
        pred(i) = 0;                    % a patch of LB alone
        continue;
    end
    for j = 1:numel(fits)
        q = fits(j);
        if ~strcmp(q.peptone, pep{i}) || q.volume ~= double(E.lawnVolume(i)) || q.growth ~= growth(i)
            continue;
        end
        if strcmp(q.kind, 'single') && q.od == od
            ids{i} = fitIds{j};
            pred(i) = q.coef(2) + q.coef(1) * lg(i);
        elseif strcmp(q.kind, 'joint') && ismember(od, [0.05 0.1])
            ids{i} = fitIds{j};
            pred(i) = q.coef(1) * od + q.coef(2) * lg(i);
        else
            continue;
        end
        break;
    end
end
end

function s = conditionText(q)
pep = 'with peptone';
if ~strcmp(q.peptone, 'with'), pep = 'without peptone'; end
if strcmp(q.kind, 'joint')
    s = sprintf('E. coli patches, %s, %g uL, %g h, OD600 0.5-2', pep, q.volume, q.growth);
else
    s = sprintf('E. coli patches, %s, %g uL, %g h, OD600 %g', pep, q.volume, q.growth, q.od);
end
end

function f = groupFields(q, label)
id = regexprep(lower(label), '[^a-z0-9.]+', '_');
f = struct('local_identifier', ['ecoli_fit_group_' regexprep(id, '^e._coli_patches_', '')], ...
    'name', label, 'description', ['The E. coli patches seeded this way, whose border ' ...
    'amplitude the lab fitted as one line (decision #65).']);
if ndi.setup.V2.schemaHasField('subject', 'type')
    f.type = did2.build.term('', 'group');
end
end

function c = conditionsOf(q)
pep = 'with peptone';
if ~strcmp(q.peptone, 'with'), pep = 'without peptone'; end
parts = {did2.build.condition('peptone', 'Term', did2.build.term('', pep)), ...
    did2.build.condition('seeding volume', 'Quantity', q.volume * 1e-6, 'Unit', 'liter', ...
        'SourceValue', q.volume, 'SourceUnit', 'uL'), ...
    did2.build.condition('growth time condition', 'Quantity', q.growth * 3600, 'Unit', 'second', ...
        'SourceValue', q.growth, 'SourceUnit', 'h')};
if strcmp(q.kind, 'single')
    parts{end+1} = did2.build.condition('OD600', 'Quantity', q.od);
end
c = did2.build.list(parts{:});
end

function v = fitValue(q)
t = struct('variable', did2.build.term('', 'growth time'), 'unit', did2.build.term('', 'minute'));
y = struct('variable', did2.build.term('', 'border amplitude per exposure time'), ...
    'unit', did2.build.term('', 'arbitrary unit per millisecond'));
if strcmp(q.kind, 'joint')
    eq = 'f = a*OD600 + b*t';
    x = did2.build.list(struct('variable', did2.build.term('', 'OD600')), t);
    co = did2.build.list(struct('variable', did2.build.term('', 'a'), 'value', q.coef(1)), ...
        struct('variable', did2.build.term('', 'b'), 'value', q.coef(2)));
else
    eq = 'f = slope*t + intercept';
    x = did2.build.list(t);
    co = did2.build.list(struct('variable', did2.build.term('', 'slope'), 'value', q.coef(1)), ...
        struct('variable', did2.build.term('', 'intercept'), 'value', q.coef(2)));
end
v = struct('model', did2.build.term('', 'linear'), 'equation', eq, ...
    'independent_variables', x, 'dependent_variable', y, 'coefficients', co, ...
    'goodness', struct('r2', q.goodness(1), 'sse', q.goodness(2), ...
        'sse_per_point', q.goodness(2) / q.n));
end

function p = rules()
p = did2.build.list( ...
    did2.build.parameter('excluded image', 'Text', '20231230_101739.czi'), ...
    did2.build.parameter('excluded plate', 'Text', 'E. coli plate 64'), ...
    did2.build.parameter('minimum circularity of a 0.5 uL patch', 'Value', 0.75), ...
    did2.build.parameter('minimum border to centre ratio', 'Value', 1), ...
    did2.build.parameter('maximum border to centre ratio', 'Value', 35), ...
    did2.build.parameter('maximum spread of the intensity peak distance within an image', ...
        'Value', 1e-4, 'Unit', 'meter', 'SourceValue', '0.1', 'SourceUnit', 'mm'));
end
