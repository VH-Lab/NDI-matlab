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
%   border / center ratio < 1 or > 35; then, per image, the lowest xPeak until
%   the image's xPeak range is at most 0.1 mm.
%
%   A plate's `peptone` is corrected by the spec's named corrections (option
%   'Corrections'; folder `ecoli`, by plate) through applyCorrection BEFORE
%   the patches are grouped (decision #131): plate 90, labelled with peptone,
%   joins the without-peptone fits, which therefore differ from the paper's
%   (the refits are reported in OUT.checks.refitDisagrees). Applied and
%   refused corrections are listed in OUT.checks.corrected /
%   correctionNotApplied.
%
%   Dataset-level documents (OUT.datasetDocuments; written with stage 2's at
%   stage 13):
%     subject             per fit, a GROUP of E. coli patches (type `group`):
%                         the patches of that condition (joint fits: of OD600
%                         0.5-2), each `member_of` it
%     directed_relation   patch member_of group
%     model_fit_calculation  about the group, variable `fluorescence intensity`
%                         (unit `arbitrary unit per millisecond`): the line
%                         (model `linear`, a label), its independent variables
%                         (`bacteria growth duration after seeding`, min; and
%                         `target seeding OD600` for a joint fit, #110), coefficients (`slope` /
%                         `intercept`; the joint fit's `a` / `b`, labels) and
%                         goodness (r2, sse, sse per point); conditions the
%                         seeding condition (`culture medium` = `nematode
%                         growth medium` [without peptone], `bacterial patch
%                         volume`, `bacteria growth duration after seeding` =
%                         the planned growth group, `target bacteria growth
%                         duration after seeding` = 0 / 12 / 48 h, exact
%                         (EMPTY:0000351, decision #125), and for a one-OD600
%                         fit `target seeding OD600`, decision #110);
%                         inputs the INCLUDED patches' border amplitude
%                         statements (stage 10 part C), so the exclusions are
%                         the values left out; method `ordinary least squares
%                         estimation` (no method parameters: the groups are
%                         the planned growth groups, not bins, #125); time the
%                         span of the included images
%     absolute_time_reference  that span
%   In each C. elegans session (OUT.sessionDocuments{k}), the estimates
%   labelEncounters made from the fits, about the PATCHES (method `prediction
%   from a fitted model`, variable `fluorescence intensity`, a.u. per ms):
%     intensity_calculation  per assay-plate patch a worm encountered:
%                         encounter.mat borderAmplitude at each encounter on
%                         it, keyed `encounter onset time` (the onsets of the
%                         worms' encounter lists, counted from the start of
%                         the statement's time reference, the plate's window,
%                         #118); inputs the fit for the patch's condition (none
%                         for a patch of LB alone, estimated 0; NaN where no
%                         fit matches), the worms' encounter lists and the
%                         patch's seeding dose (#122); condition the planned
%                         growth group
%     intensity_calculation  per acclimation-plate patch (`<plate>_patch0001`,
%                         skipped when the subject list has none): the
%                         estimate at the pick (encounter.mat
%                         borderAmplitudeGrowth), from the 200 uL fit at the
%                         plate's growth time then, and the patch's seeding
%                         dose; timed by the pick (absolute_time_reference, to
%                         the minute)
%   Each value is checked against the fit it names (OUT.checks
%   .encounterDisagrees). Beside each estimate, its RELATIVE DENSITY
%   (decision #99; modelExploit and fig3_single):
%     concentration_calculation  `relative cell density`, in OD600
%                         equivalents (concentration's `od600` canonical,
%                         and the source pair, source unit OD600; a schema
%                         before od600 gets the source pair alone): 10 x the estimate / the
%                         reference, the mean encounter.mat borderAmplitude
%                         over the foragingConcentration encounters on OD600
%                         10, 0.5 uL patches; same keys and time as the
%                         estimate, whose statement is its input; method
%                         `normalization data transformation`, method
%                         parameters the reference, its target seeding OD600
%                         (10; #110) and, at
%                         the assay plates only, the lower limit 0.01 that a
%                         patch of LB alone (estimate 0) is given, as the
%                         model does. An estimate of NaN (no fit matched)
%                         stays NaN. The model works with its log10.
%   With no reference (encounter.mat lacks the columns, or not exactly one
%   OD600 10 group matches) or no `concentration_calculation` leaf, none is
%   written and OUT.skipped says why.
%
%   Options: 'DatasetSessionId', 'SoftwareId', 'InterpreterId',
%   'OperatingSystemId' (the run environment, as stage 10), 'FitsFile',
%   'Subjects' (subjectList's table: each assay plate's acclimation plate and
%   its pick time), 'Corrections' (the spec's `corrections`).

arguments
    dataParentDir (1,:) char {mustBeFolder}
    sessions table
    built cell
    options.DatasetSessionId (1,:) char = ''
    options.SoftwareId (1,:) char = ''
    options.InterpreterId (1,:) char = ''
    options.OperatingSystemId (1,:) char = ''
    options.FitsFile (1,:) char = ''
    options.Subjects table = table()
    options.Corrections = struct([])
end
dsid = options.DatasetSessionId;
out = struct('datasetDocuments', {{}}, 'sessionDocuments', {repmat({{}}, height(sessions), 1)}, ...
    'skipped', {{}}, 'checks', struct('refitDisagrees', {{}}, 'encounterDisagrees', {{}}, ...
    'corrected', {{}}, 'correctionNotApplied', {{}}), ...
    'counts', struct('fits', 0, 'groups', 0, 'members', 0, 'inputs', 0, 'refit_checked', 0, ...
    'worms', 0, 'patches', 0, 'acclimation_patches', 0, 'estimates', 0, 'relative_density', 0, ...
    'encounters_checked', 0), 'fits', table());
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
% a plate's peptone label, as the spec corrects it (plate 90, decision #131),
% before anything is grouped by it
[L, out.checks] = correctPeptone(L, options.Corrections, out.checks);
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
    grp = ndi.setup.V2.entityDocuments('subject', groupFields(q, label), struct(), ...
        'SessionId', dsid, 'Type', 'group');
    grp = grp{1};
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
        haleyTerm('fluorescence intensity'), fitValue(q), ...
        'Conditions', conditionsOf(q), 'Method', haleyTerm('ordinary least squares estimation'), ...
        'InputIds', inputs, 'TimeReferenceIds', timeIds, ...
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

% ---- the estimates, on the C. elegans patches ------------------------------------
prediction = haleyTerm('prediction from a fitted model');
fluorescence = haleyTerm('fluorescence intensity');
S = options.Subjects;
% the relative density's reference (decision #99)
[rd, why] = densityReference(dataParentDir);
if isempty(why) && ~ndi.setup.V2.schemaHasLeaf('concentration_calculation')
    why = 'the schema in use has no concentration_calculation';
end
if ~isempty(why)
    out.skipped{end+1} = ['no relative density: ' why];
    rd = [];
end
for k = 1:numel(built)
    if isempty(built{k}) || ~isfield(built{k}, 'encounters')
        continue;
    end
    sid = char(sessions.session_id{k});
    subjectIds = built{k}.subjectIds;
    worms = built{k}.encounters.byWorm;
    % each patch's seeding dose (stage 8), an input of its estimates (#122)
    seeds = containers.Map();
    if isfield(built{k}, 'manipulations') && isfield(built{k}.manipulations, 'seedIds')
        seeds = built{k}.manipulations.seedIds;
    end
    names = keys(worms);
    docs = {};
    % every encounter of every worm: its patch, onset, estimate, fit and bin
    at = struct('patchId', {}, 'timeId', {}, 'bin', {}, 'onset', {}, 'value', {}, ...
        'fitId', {}, 'listId', {});
    picked = containers.Map();   % acclimation plate -> its estimate at the pick
    for w = 1:numel(names)
        x = worms(names{w});
        E = x.rows;
        need = {'lawnID', 'lawnOD600', 'lawnVolume', 'growthCondition', 'peptone', ...
            'lawnGrowth', 'borderAmplitude'};
        if ~all(ismember(need, E.Properties.VariableNames)) || height(E) == 0
            continue;
        end
        out.counts.worms = out.counts.worms + 1;
        [ids, pred] = patchFits(E, fits, fitIds);
        check(names{w}, 'patch', double(E.borderAmplitude), pred);
        pIds = patchIds(subjectIds, x.plate);
        lawn = double(E.lawnID);
        bin = growthBin(E.growthCondition);
        for i = 1:height(E)
            if ~(lawn(i) >= 1 && lawn(i) <= numel(pIds))
                out.skipped{end+1} = sprintf('%s: encounter %d names a patch %s does not have; no estimate', ...
                    names{w}, i, x.plate); %#ok<AGROW>
                continue;
            end
            at(end+1) = struct('patchId', pIds{lawn(i)}, 'timeId', x.timeId, 'bin', bin(i), ...
                'onset', x.onset(i), 'value', double(E.borderAmplitude(i)), 'fitId', ids{i}, ...
                'listId', x.listId); %#ok<AGROW>
        end

        % the acclimation plate the worm came from, at the pick
        if ~all(ismember({'growthLawnGrowth', 'borderAmplitudeGrowth'}, E.Properties.VariableNames))
            continue;
        end
        g = find(arrayfun(@(q) strcmp(q.kind, 'single') && q.volume == 200, fits), 1);
        gPred = NaN(height(E), 1);
        if ~isempty(g)
            gPred = fits(g).coef(2) + fits(g).coef(1) * growthMinutes(E.growthLawnGrowth);
        end
        check(names{w}, 'acclimation plate', double(E.borderAmplitudeGrowth), gPred);
        acc = acclimationOf(S, x.plate);
        if isempty(acc)
            out.skipped{end+1} = sprintf('%s: no acclimation plate known for %s; no estimate at the pick', ...
                names{w}, x.plate);
            continue;
        end
        v = double(E.borderAmplitudeGrowth(1));
        if isKey(picked, acc)
            p = picked(acc);
            if ~(isnan(p.value) && isnan(v)) && abs(p.value - v) > 1e-6 * max(1, abs(v))
                out.checks.encounterDisagrees{end+1} = sprintf(['%s: its acclimation plate %s ' ...
                    'is estimated at %g, %s''s rows at %g'], names{w}, acc, v, p.worm, p.value);
            end
        else
            picked(acc) = struct('value', v, 'worm', names{w}, 'fit', g);
        end
    end

    % one estimate per assay-plate patch (and time reference and planned
    % growth group), keyed by the onsets of its encounters
    if ~isempty(at)
        bins = [at.bin];
        bins(isnan(bins)) = -1;
        [G, ~] = findgroups({at.patchId}', {at.timeId}', bins');
        for gi = 1:max(G)
            a = at(G == gi);
            [onsets, order] = sort([a.onset]);
            a = a(order);
            in = {a.fitId};
            in = [reshape(unique(in(~cellfun(@isempty, in)), 'stable'), 1, []), ...
                reshape(unique({a.listId}, 'stable'), 1, [])];
            if isKey(seeds, a(1).patchId)
                in{end+1} = seeds(a(1).patchId); %#ok<AGROW>
            end
            extra = {};
            if ~isnan(a(1).bin)
                extra = {'Conditions', did2.build.list(growthGroupCondition(a(1).bin))};
            end
            onsetKeys = did2.build.list(did2.build.key(haleyTerm('encounter onset time'), ...
                numel(a), 'Values', onsets, 'Unit', haleyTerm('second')));
            docs{end+1} = did2.build.statement('intensity_calculation', a(1).patchId, fluorescence, ...
                did2.build.valueCell('intensity', [a.value]), 'Keys', onsetKeys, ...
                'Method', prediction, extra{:}, 'InputIds', in, 'SessionId', sid, ...
                'TimeReferenceIds', {a(1).timeId}, env{:}, 'Notes', ...
                ['Border amplitude per ms of exposure at each encounter''s onset, ' ...
                'from the fit for the patch''s seeding condition at its growth time ' ...
                '(encounter.mat lawnGrowth, min); 0 for a patch of LB alone; NaN where no fit ' ...
                'matches (labelEncounters).']); %#ok<AGROW>
            out.counts.patches = out.counts.patches + 1;
            out.counts.estimates = out.counts.estimates + 1;
            if ~isempty(rd)
                docs{end+1} = relativeDensity(rd, a(1).patchId, docs{end}, [a.value], true, ...
                    {'Keys', onsetKeys}, a(1).timeId, sid, env); %#ok<AGROW>
                out.counts.relative_density = out.counts.relative_density + 1;
            end
        end
    end

    % one estimate per acclimation-plate patch, at the pick, from the 200 uL fit
    accs = keys(picked);
    for j = 1:numel(accs)
        p = picked(accs{j});
        accPatch = [accs{j} '_patch0001'];
        if ~isKey(subjectIds, accPatch)
            out.skipped{end+1} = sprintf('%s: no patch subject %s; no estimate at the pick', ...
                accs{j}, accPatch);
            continue;
        end
        when = pickTime(S, accs{j});
        if isnat(when)
            out.skipped{end+1} = sprintf('%s: no pick time; no estimate at the pick', accs{j});
            continue;
        end
        ref = utcReference(wallClock(when, tz), [60 60], 'yyyy-MM-dd''T''HH:mm', [], [], '', ...
            false, tz, sid);
        gIn = {};
        if ~isempty(p.fit) && ~isempty(fitIds{p.fit}), gIn = fitIds(p.fit); end
        if isKey(seeds, subjectIds(accPatch))
            gIn{end+1} = seeds(subjectIds(accPatch)); %#ok<AGROW>
        end
        docs = [docs, {ref, did2.build.statement('intensity_calculation', subjectIds(accPatch), ...
            fluorescence, did2.build.valueCell('intensity', p.value), 'Method', prediction, ...
            'InputIds', gIn, 'SessionId', sid, 'TimeReferenceIds', {ref.base.id}, env{:}, ...
            'Notes', ['Border amplitude per ms of exposure when the worms were picked from ' ...
            'this plate, from the 200 uL fit at the plate''s growth time then (encounter.mat ' ...
            'growthLawnGrowth).'])}]; %#ok<AGROW>
        out.counts.acclimation_patches = out.counts.acclimation_patches + 1;
        out.counts.estimates = out.counts.estimates + 1;
        if ~isempty(rd)
            docs{end+1} = relativeDensity(rd, subjectIds(accPatch), docs{end}, p.value, false, ...
                {}, ref.base.id, sid, env); %#ok<AGROW>
            out.counts.relative_density = out.counts.relative_density + 1;
        end
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
arguments
    L table
end
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
arguments
    x
end
if isduration(x)
    m = minutes(x);
else
    m = double(x);
end
m = m(:);
end

function X = designOf(q, L, t, sel)
arguments
    q (1,1) struct
    L table
    t {mustBeNumeric}
    sel
end
if strcmp(q.kind, 'joint')
    X = [double(L.OD600(sel)), t(sel)];
else
    X = [t(sel), ones(sum(sel), 1)];
end
end

function [ids, pred] = patchFits(E, fits, fitIds)
% the fit each encounter's patch takes (labelEncounters' match) and its value
arguments
    E table
    fits struct
    fitIds cell
end
n = height(E);
ids = repmat({''}, n, 1);
pred = NaN(n, 1);
pep = cellstr(E.peptone);
growth = growthBin(E.growthCondition);
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
arguments
    q (1,1) struct
end
pep = 'with peptone';
if ~strcmp(q.peptone, 'with'), pep = 'without peptone'; end
if strcmp(q.kind, 'joint')
    s = sprintf('E. coli patches, %s, %g uL, %g h, OD600 0.5-2', pep, q.volume, q.growth);
else
    s = sprintf('E. coli patches, %s, %g uL, %g h, OD600 %g', pep, q.volume, q.growth, q.od);
end
end

function f = groupFields(q, label)
arguments
    q (1,1) struct %#ok<INUSA> the group's fields come from its label alone
    label {mustBeText}
end
id = regexprep(lower(label), '[^a-z0-9.]+', '_');
f = struct('local_identifier', ['ecoli_fit_group_' regexprep(id, '^e._coli_patches_', '')], ...
    'name', label, 'description', ['The E. coli patches seeded this way, whose border ' ...
    'amplitude the lab fitted as one line (decision #65).']);
if ndi.setup.V2.schemaHasField('subject', 'type')
    f.type = did2.build.term('', 'group');
end
end

function c = conditionsOf(q)
% the seeding condition the fit is for: culture medium, patch volume, growth
% duration bin and, for a one-OD600 fit, the target OD600
arguments
    q (1,1) struct
end
medium = 'nematode growth medium';
if ~strcmp(q.peptone, 'with'), medium = 'nematode growth medium without peptone'; end
parts = {did2.build.condition(haleyTerm('culture medium'), 'Term', haleyTerm(medium)), ...
    did2.build.condition(haleyTerm('bacterial patch volume'), 'Quantity', q.volume * 1e-6, ...
        'Unit', haleyTerm('liter'), 'SourceValue', q.volume, 'SourceUnit', ndi.setup.V2.sourceUnit('uL')), ...
    growthGroupCondition(q.growth)};
if strcmp(q.kind, 'single')
    % the OD600 the patches were seeded at: the planned value, named so by its
    % term because the data also holds the measured OD600 (decision #110, T19)
    parts{end+1} = did2.build.condition(haleyTerm('target seeding OD600'), ...
        'Quantity', q.od);
end
c = did2.build.list(parts{:});
end

function c = growthGroupCondition(h)
% the condition `target bacteria growth duration after seeding` = H hours:
% the growth group the assay was planned for, exact (decision #125;
% getExperimentInfo derives it by rounding the measured growth to 12 h)
arguments
    h (1,1) double
end
c = did2.build.condition(haleyTerm('target bacteria growth duration after seeding'), ...
    'Quantity', h * 3600, 'Unit', haleyTerm('second'), 'SourceValue', h, 'SourceUnit', ndi.setup.V2.sourceUnit('h'));
end

function [L, checks] = correctPeptone(L, corrections, checks)
% the spec's named corrections to an E. coli plate's `peptone` (folder
% `ecoli`, by plate; plate 90, decision #131), each applied to the plate's
% lawnAnalysis rows only while every one still reads its `was` (decision
% #111, applyCorrection); listed in CHECKS
arguments
    L table
    corrections
    checks (1,1) struct
end
if isstruct(corrections), corrections = num2cell(corrections); end
for c = 1:numel(corrections)
    x = corrections{c};
    if ~isfield(x, 'plate') || ~isfield(x, 'column') || ~strcmp(x.column, 'peptone') ...
            || ~isfield(x, 'folder') || ~strcmp(x.folder, 'ecoli')
        continue;
    end
    r = find(L.plateNum == double(x.plate));
    if isempty(r)
        continue;                       % not among the analysed images
    end
    where = sprintf('ecoli plate %d', double(x.plate));
    ok = true;
    for j = r(:)'
        [v, applied, ~, line] = applyCorrection(x, L.peptone{j}, where);
        if ~applied
            ok = false;
            break;
        end
    end
    if ~ok
        checks.correctionNotApplied{end+1} = line;
        continue;
    end
    L.peptone(r) = {lower(v)};
    checks.corrected{end+1} = sprintf('%s (%d lawnAnalysis row(s))', line, numel(r));
end
end

function b = growthBin(x)
% each growth condition, hours: labelEncounters reads foragingMini's 60 as 48
arguments
    x
end
b = double(x(:));
b(b == 60) = 48;
end

function a = acclimationOf(S, plate)
% the acclimation plate an assay plate's worms came from ('' when not known)
arguments
    S table
    plate {mustBeText}
end
a = '';
if ~all(ismember({'local_identifier', 'acclimation'}, S.Properties.VariableNames))
    return;
end
r = find(strcmp(S.local_identifier, plate), 1);
if isempty(r), return; end
a = S.acclimation(r);
if iscell(a), a = a{1}; end
a = char(a);
end

function t = pickTime(S, acc)
% when the worms were picked from acclimation plate ACC (NaT when not known)
arguments
    S table
    acc {mustBeText}
end
t = NaT;
if ~all(ismember({'local_identifier', 'worms_placed'}, S.Properties.VariableNames))
    return;
end
r = find(strcmp(S.local_identifier, acc), 1);
if ~isempty(r), t = S.worms_placed(r); end
end

function v = fitValue(q)
arguments
    q (1,1) struct
end
t = struct('variable', haleyTerm('bacteria growth duration after seeding'), ...
    'unit', haleyTerm('minute'));
y = struct('variable', haleyTerm('fluorescence intensity'), ...
    'unit', haleyTerm('arbitrary unit per millisecond'));
if strcmp(q.kind, 'joint')
    eq = 'f = a*OD600 + b*t';
    % the planned OD600 the patches were seeded at (decision #110, T19)
    x = did2.build.list(struct('variable', haleyTerm('target seeding OD600')), t);
    % each coefficient named by its symbol in the equation
    co = did2.build.list(struct('variable', coefficient('a'), 'value', q.coef(1)), ...
        struct('variable', coefficient('b'), 'value', q.coef(2)));
else
    eq = 'f = slope*t + intercept';
    x = did2.build.list(t);
    co = did2.build.list(struct('variable', haleyTerm('slope'), 'value', q.coef(1)), ...
        struct('variable', haleyTerm('intercept'), 'value', q.coef(2)));
end
v = struct('model', haleyTerm('linear regression'), 'equation', eq, ...
    'independent_variables', x, 'dependent_variable', y, 'coefficients', co, ...
    'goodness', struct('r2', q.goodness(1), 'sse', q.goodness(2), ...
        'sse_per_point', q.goodness(2) / q.n));
end

function t = coefficient(symbol)
% a regression coefficient (STATO:0000565), named by its symbol in the equation
arguments
    symbol {mustBeText}
end
r = haleyTerm('regression coefficient');
t = did2.build.term(r.node, symbol);
end

function [rd, why] = densityReference(dataParentDir)
% the relative density's reference (decision #99; modelExploit): the mean
% encounter.mat borderAmplitude over the encounters of the one
% (expName, lawnVolume, growthCondition, OD600Label, strainName, strainID)
% group that is foragingConcentration, OD600 10, 0.5 uL. WHY is '' when found.
arguments
    dataParentDir (1,:) char
end
rd = struct('value', NaN, 'n', 0);
why = '';
file = fullfile(dataParentDir, 'haley', 'celegans', 'encounter.mat');
if ~isfile(file)
    why = 'no celegans/encounter.mat';
    return;
end
E = load(file, 'encounter');
E = E.encounter;
by = {'expName', 'lawnVolume', 'growthCondition', 'OD600Label', 'strainName', 'strainID'};
missing = setdiff([by, {'borderAmplitude'}], E.Properties.VariableNames);
if ~isempty(missing)
    why = sprintf('encounter.mat has no %s', strjoin(missing, ', '));
    return;
end
[G, GID] = findgroups(E(:, by));
ref = find(string(GID.expName) == "foragingConcentration" & ...
    string(GID.OD600Label) == "10.00" & GID.lawnVolume == 0.5);
if numel(ref) ~= 1
    why = sprintf(['%d encounter.mat group(s) are foragingConcentration, OD600 10, 0.5 uL; ' ...
        'the reference needs exactly one'], numel(ref));
    return;
end
x = double(E.borderAmplitude(G == ref));
x = x(~isnan(x));
if isempty(x) || mean(x) <= 0
    why = 'the OD600 10 reference encounters have no positive border amplitude';
    return;
end
rd = struct('value', mean(x), 'n', numel(x));
end

function d = relativeDensity(rd, entityId, estimate, v, floored, keys, timeId, sid, env)
% the relative density, about ENTITYID (the patch), of ESTIMATE's values V
% (decision #99): 10 x V / the
% reference, in OD600 equivalents; FLOORED (the assay plates) sets a value
% below 0.01 to 0.01, as the model does for a patch of LB alone. NaN stays NaN.
arguments
    rd (1,1) struct
    entityId {mustBeText}
    estimate (1,1) struct
    v double
    floored (1,1) logical
    keys cell
    timeId {mustBeText}
    sid {mustBeText}
    env cell
end
x = 10 * v(:)' / rd.value;
params = {did2.build.parameter(haleyTerm('normalization reference value'), 'Value', rd.value, ...
        'Unit', haleyTerm('arbitrary unit per millisecond')), ...
    did2.build.parameter(haleyTerm('target seeding OD600'), 'Value', 10)};   % #110
note = '';
if floored
    x(x < 0.01) = 0.01;
    params{end+1} = did2.build.parameter(haleyTerm('lower limit of reported value'), 'Value', 0.01);
    note = ' A value below 0.01 (a patch of LB alone, estimated 0) is given 0.01, as the model does.';
end
d = did2.build.statement('concentration_calculation', entityId, ...
    haleyTerm('relative cell density'), ...
    densityCell(x), ...
    keys{:}, 'Method', haleyTerm('normalization data transformation'), ...
    'MethodParameters', did2.build.list(params{:}), 'InputIds', {estimate.base.id}, ...
    'SessionId', sid, 'TimeReferenceIds', {timeId}, env{:}, 'Notes', ...
    [sprintf(['Relative bacterial density in OD600 equivalents: 10 x the border amplitude ' ...
    'estimate / %.6g, the mean over %d foragingConcentration encounters on OD600 10, 0.5 uL ' ...
    'patches (modelExploit, fig3_single). NaN where the estimate is NaN.'], rd.value, rd.n), ...
    note, ' The model works with its log10.']);
end

function v = densityCell(x)
% the relative density as concentration cells: in the `od600` canonical when
% the schema has it (did-schema, Jess 2026-10-20), the same number as the
% source value in source unit OD600; before that, the source pair alone
arguments
    x double
end
if ndi.setup.V2.schemaHasField('concentration', 'value.od600')
    v = did2.build.valueCell('concentration', x, 'Canonical', 'od600', 'SourceValue', x, ...
        'SourceUnit', ndi.setup.V2.sourceUnit('OD600'));
else
    v = did2.build.valueCell('concentration', x, 'Canonical', 'source_value', 'SourceUnit', ndi.setup.V2.sourceUnit('OD600'));
end
end
