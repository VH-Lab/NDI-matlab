function out = ecoliDocuments(dataParentDir, session, R, subjectIds, options)
%ECOLIDOCUMENTS Stage 10 part C (Haley): the E. coli patch profiles.
%
%   OUT = ndi.setup.conv.haley.ecoliDocuments(DATAPARENTDIR, SESSION, R,
%   SUBJECTIDS, ...) builds, for the E. coli session SESSION, the calculations
%   the lab's analysis package (analyzeGFP / analyzeLawnProfiles, Haley et al.
%   2024) made from each analysed fluorescence image: ecoli/bacteria.mat
%   `lawnAnalysis` (one row per patch detected in an image) and the image's
%   patch mask, ecoli/mask/<image>.png. Decision log #62.
%
%   WHICH PATCH IS WHICH. An image's lawnAnalysis rows are its detected
%   patches in the order bwlabel numbers its mask (checked over all 1,521
%   analysed images: region count = row count in every one; Jess,
%   2026-10-05; numbered here the same way without the Image Processing
%   Toolbox, private/labelRegions). They are matched to the plate's patch
%   SUBJECTS by position:
%     `rectangle` plate (12 patches, 3 staggered rows of 4)   the 12 detected
%         patches are numbered as bwlabel numbers an ideal grid -- left to
%         right, patches sharing a column top to bottom -- and detected patch
%         number k is patch subject k
%     one-patch plate   its one detected patch is the one patch subject
%   An image with any other count is not matched: its per-patch values are
%   left out and reported (OUT.skipped), and its mask is still stored.
%
%   Per analysed image, all from the image's recording statement (input):
%     coordinate_system   the image's pixel grid, as part A's (only when
%                         bacteria.mat metaData gives the image's `scale`)
%     label_calculation   the plate's `bacterial lawn region`: the mask, a
%                         bool per pixel (ingested body), method parameter the
%                         0.5 mm margin the analysis adds around each patch
%     item_calculation    the plate's `nearest patch` (ecoli/closest/<image>
%                         .png), a 0-based index into the patch subjects --
%                         only for a matched image, and only when the schema
%                         has `item` (did-schema PR #87)
%   and per matched detected patch, about its patch subject, from the image
%   and the mask:
%     intensity_calculation  `patch border amplitude` (borderAmplitude, the
%                            basis of the paper's relative density), `patch
%                            centre amplitude` (centerAmplitude), `patch peak
%                            intensity` (yPeak), `patch edge intensity`
%                            (yOuterEdge); background-normalised intensity
%     length_calculation     `patch edge to intensity peak` (xPeak, mm -> m)
%     score_calculation      `patch circularity` (0-1)
%   Not stored: borderCenterRatio (border / centre amplitude), meanAmplitude,
%   FWHM, xHalfMax*, yHalfMax, lawnRadius (decision #60's keep list). The
%   profile curves and fitted background images are not in bacteria.mat;
%   they come in a later pass (decision #62).
%
%   Options: 'RecordingStatements', 'RecordingRefs', 'SoftwareId',
%   'InterpreterId', 'OperatingSystemId' as part A.
%
%   OUT fields: documents, counts (struct), skipped (cellstr).

arguments
    dataParentDir (1,:) char {mustBeFolder}
    session table
    R table
    subjectIds
    options.RecordingStatements = containers.Map()
    options.RecordingRefs = containers.Map()
    options.SoftwareId (1,:) char = ''
    options.InterpreterId (1,:) char = ''
    options.OperatingSystemId (1,:) char = ''
end
if height(session) ~= 1
    error('ndi:setup:conv:haley:oneSession', 'Give exactly one session row.');
end
sid = char(session.session_id{1});
ref = char(session.local_identifier{1});
out = struct('documents', {{}}, 'skipped', {{}}, 'counts', struct('coordinate_system', 0, ...
    'mask', 0, 'nearest_patch', 0, 'matched_images', 0, 'unmatched_images', 0, ...
    'patch_values', 0));
if ~strcmp(char(session.folder{1}), 'ecoli')
    return;
end
if isempty(options.OperatingSystemId)
    out.skipped{end+1} = sprintf(['%s: no operating system document (the spec''s `macos`, ' ...
        'built by the metadata stage); no calculations'], ref);
    return;
end
env = {};
if ~isempty(options.SoftwareId), env = [env, {'SoftwareId', options.SoftwareId}]; end
if ~isempty(options.InterpreterId), env = [env, {'InterpreterId', options.InterpreterId}]; end
env = [env, {'OperatingSystemId', options.OperatingSystemId}];
hasItem = ndi.setup.V2.schemaHasField('item', 'value');

root = fullfile(dataParentDir, 'haley', 'ecoli');
B = load(fullfile(root, 'bacteria.mat'));
if ~isfield(B, 'lawnAnalysis')
    out.skipped{end+1} = sprintf('%s: bacteria.mat has no lawnAnalysis', ref);
    return;
end
L = B.lawnAnalysis;
M = table();
if isfield(B, 'metaData'), M = B.metaData; end
R = R(strcmp(R.session, ref) & strcmp(R.kind, 'image'), :);
docs = {};

for k = 1:height(R)
    epoch = R.epoch{k};
    n = str2double(regexp(epoch, '(\d+)$', 'tokens', 'once'));
    rows = L(L.imageNum == n, :);
    if height(rows) == 0 || ~isKey(options.RecordingStatements, epoch)
        continue;                                % not analysed (or not written)
    end
    plate = R.plate{k};
    if ~isKey(subjectIds, plate)
        out.skipped{end+1} = sprintf('%s: plate %s is not a subject of this session', epoch, plate);
        continue;
    end
    maskFile = fullfile(root, 'mask', sprintf('%04d.png', n));
    if ~isfile(maskFile)
        out.skipped{end+1} = sprintf('%s: no mask/%04d.png', epoch, n);
        continue;
    end
    imageId = options.RecordingStatements(epoch);
    timeIds = {};
    if isKey(options.RecordingRefs, epoch), timeIds = {options.RecordingRefs(epoch)}; end
    calc = [{'SessionId', sid, 'TimeReferenceIds', timeIds}, env];

    % the image's scale, when the source gives it
    scale = NaN;
    if height(M) > 0 && ismember('scale', M.Properties.VariableNames)
        s = M.scale(M.imageNum == n);
        if ~isempty(s), scale = double(s(1)); end
    end
    pixel = NaN;
    if scale > 0
        pixel = 1e-3 / scale;
        step = did2.build.valueCell('length', pixel, 'SourceValue', 1 / scale, ...
            'SourceUnit', 'mm', 'Approximate', true);
        cs = did2.build.document('coordinate_system', struct( ...
            'origin', did2.build.term('', 'image upper-left corner'), ...
            'dimensions', did2.build.list( ...
                struct('axis', did2.build.term('', 'image horizontal axis'), ...
                    'positive_direction', did2.build.term('', 'image right'), 'spacing', step), ...
                struct('axis', did2.build.term('', 'image vertical axis'), ...
                    'positive_direction', did2.build.term('', 'image down'), 'spacing', step))), ...
            'SessionId', sid, 'Edges', struct('referent_id', imageId));
        docs{end+1} = cs; %#ok<AGROW>
        out.counts.coordinate_system = out.counts.coordinate_system + 1;
    end

    % the mask
    mask = logical(imread(maskFile));
    keys = pixelKeys(mask, pixel);
    inputs = {imageId};
    if height(M) > 0 && ismember('backgroundImageNum', M.Properties.VariableNames)
        bg = M.backgroundImageNum(M.imageNum == n);
        if ~isempty(bg) && ~isnan(bg(1))
            bgEpoch = sprintf('ecoli_image%04d', bg(1));
            if isKey(options.RecordingStatements, bgEpoch)
                inputs{end+1} = options.RecordingStatements(bgEpoch); %#ok<AGROW>
            end
        end
    end
    ms = did2.build.statement('label_calculation', subjectIds(plate), ...
        did2.build.term('', 'bacterial lawn region'), [], 'DataBody', true, 'DatumType', 'bool', ...
        'Keys', keys, 'Method', did2.build.term('', 'patch detection by threshold'), ...
        'MethodParameters', did2.build.list(did2.build.parameter('margin around each patch', ...
            'Value', 0.5e-3, 'Unit', 'meter', 'SourceValue', '0.5', 'SourceUnit', 'mm')), ...
        'InputIds', inputs, calc{:});
    docs = [docs, {ms, ingestedBody(ms, mask, 'bool', keys, sid, ...
        sprintf('The patch mask (1 = within 0.5 mm of a detected patch), from mask/%04d.png.', n))}]; %#ok<AGROW>
    out.counts.mask = out.counts.mask + 1;

    % which detected patch is which patch subject
    [~, nDetected, centroids] = labelRegions(mask);
    if nDetected ~= height(rows)
        out.skipped{end+1} = sprintf('%s: %d regions in the mask, %d lawnAnalysis rows; not matched', ...
            epoch, nDetected, height(rows));
        out.counts.unmatched_images = out.counts.unmatched_images + 1;
        continue;
    end
    pIds = patchIds(subjectIds, plate);
    slot = matchPatches(centroids, nDetected, numel(pIds));
    if isempty(slot)
        out.skipped{end+1} = sprintf(['%s: %d detected patch(es) on %s, which has %d patch ' ...
            'subject(s); not matched'], epoch, nDetected, plate, numel(pIds));
        out.counts.unmatched_images = out.counts.unmatched_images + 1;
        continue;
    end
    out.counts.matched_images = out.counts.matched_images + 1;
    match = {'Notes', 'Detected patch matched to its grid patch by position (decision #62).'};

    % the nearest-patch map
    closestFile = fullfile(root, 'closest', sprintf('%04d.png', n));
    if hasItem && isfile(closestFile)
        c = double(imread(closestFile));
        if all(c(:) >= 1 & c(:) <= nDetected)
            v = slot(c) - 1;
            dt = 'uint8';
            if numel(pIds) > 255, dt = 'uint16'; end
            np = did2.build.statement('item_calculation', subjectIds(plate), ...
                did2.build.term('', 'nearest patch'), [], 'DataBody', true, 'DatumType', dt, ...
                'Keys', keys, 'InputIds', {ms.base.id}, ...
                'Edges', struct('item_id', {pIds}), calc{:}, match{:});
            docs = [docs, {np, ingestedBody(np, v, dt, keys, sid, ...
                'Each pixel''s nearest patch: a 0-based index into item_id.')}]; %#ok<AGROW>
            out.counts.nearest_patch = out.counts.nearest_patch + 1;
        else
            out.skipped{end+1} = sprintf('%s: closest/%04d.png holds values outside 1..%d; no map', ...
                epoch, n, nDetected);
        end
    end

    % the per-patch values
    in = {'InputIds', {imageId, ms.base.id}};
    for j = 1:nDetected
        patch = pIds{slot(j)};
        r = rows(j, :);
        for q = {{'borderAmplitude', 'patch border amplitude'}, ...
                 {'centerAmplitude', 'patch centre amplitude'}, ...
                 {'yPeak', 'patch peak intensity'}, ...
                 {'yOuterEdge', 'patch edge intensity'}}
            col = q{1}{1};
            if ~ismember(col, r.Properties.VariableNames) || isnan(r.(col)), continue; end
            v = did2.build.valueCell('intensity', double(r.(col)));
            docs{end+1} = did2.build.statement('intensity_calculation', patch, ...
                did2.build.term('', q{1}{2}), v, ...
                'Method', did2.build.term('', 'fluorescence profile from the patch edge'), ...
                in{:}, calc{:}, match{:}); %#ok<AGROW>
            out.counts.patch_values = out.counts.patch_values + 1;
        end
        if ismember('xPeak', r.Properties.VariableNames) && ~isnan(r.xPeak)
            v = did2.build.valueCell('length', r.xPeak * 1e-3, 'SourceValue', r.xPeak, 'SourceUnit', 'mm');
            docs{end+1} = did2.build.statement('length_calculation', patch, ...
                did2.build.term('', 'patch edge to intensity peak'), v, ...
                'Method', did2.build.term('', 'fluorescence profile from the patch edge'), ...
                in{:}, calc{:}, match{:}); %#ok<AGROW>
            out.counts.patch_values = out.counts.patch_values + 1;
        end
        if ismember('circularity', r.Properties.VariableNames) && ~isnan(r.circularity)
            v = did2.build.valueCell('score', r.circularity, 'Fields', struct( ...
                'scale', did2.build.term('', 'circularity'), 'scale_min', 0, 'scale_max', 1));
            docs{end+1} = did2.build.statement('score_calculation', patch, ...
                did2.build.term('', 'patch circularity'), v, in{:}, calc{:}, match{:}); %#ok<AGROW>
            out.counts.patch_values = out.counts.patch_values + 1;
        end
    end
end
out.documents = docs;
end

% -----------------------------------------------------------------------------
function slot = matchPatches(c, nDetected, nSubjects)
% SLOT(j) = the patch subject number of detected patch j, or [] when the
% image cannot be matched. 12: number as bwlabel numbers an ideal staggered
% grid (left to right; patches sharing a column, top to bottom). 1: itself.
slot = [];
if nDetected == 1 && nSubjects == 1
    slot = 1;
    return;
end
if nDetected ~= 12 || nSubjects ~= 12
    return;
end
% C: the detected patches' centroids, x and y in label order
% three rows of four, by y
[~, byY] = sort(c(:, 2));
rowOf = zeros(12, 1);
rowOf(byY) = repelem(1:3, 4);
gapY = diff(c(byY, 2));
if min(gapY([4 8])) <= max(gapY([1:3 5:7 9:11]))
    return;                                % the rows are not cleanly apart
end
% within each row, the step between neighbours
steps = [];
for r = 1:3
    steps = [steps; diff(sort(c(rowOf == r, 1)))]; %#ok<AGROW>
end
tol = median(steps) / 4;
% columns: patches whose x differ by less than a quarter step share one
[~, byX] = sort(c(:, 1));
col = zeros(12, 1);
col(byX(1)) = 1;
for i = 2:12
    col(byX(i)) = col(byX(i - 1)) + (c(byX(i), 1) - c(byX(i - 1), 1) >= tol);
end
if max(col) ~= 8
    return;                                % not the staggered 8-column layout
end
[~, order] = sortrows([col, c(:, 2)]);     % left to right, then top to bottom
slot = zeros(12, 1);
slot(order) = 1:12;
end

function keys = pixelKeys(a, pixel)
% as part A: pixel centres from the upper-left corner, in metres when the
% scale is known, else in pixels
if isnan(pixel)
    keys = did2.build.list( ...
        did2.build.key('image vertical position', size(a, 1), 'Unit', 'pixel', ...
            'Origin', 0.5, 'Spacing', 1), ...
        did2.build.key('image horizontal position', size(a, 2), 'Unit', 'pixel', ...
            'Origin', 0.5, 'Spacing', 1));
    return;
end
keys = did2.build.list( ...
    did2.build.key('image vertical position', size(a, 1), 'Unit', 'meter', ...
        'Origin', pixel / 2, 'Spacing', pixel, 'SourceUnit', 'pixel', 'SourceOrigin', 0.5, 'SourceSpacing', 1), ...
    did2.build.key('image horizontal position', size(a, 2), 'Unit', 'meter', ...
        'Origin', pixel / 2, 'Spacing', pixel, 'SourceUnit', 'pixel', 'SourceOrigin', 0.5, 'SourceSpacing', 1));
end
