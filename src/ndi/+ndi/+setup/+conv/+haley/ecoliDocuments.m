function out = ecoliDocuments(dataParentDir, session, R, subjectIds, options)
%ECOLIDOCUMENTS Stage 10 part C (Haley): the E. coli patch profiles.
%
%   OUT = ndi.setup.conv.haley.ecoliDocuments(DATAPARENTDIR, SESSION, R,
%   SUBJECTIDS, ...) builds, for the E. coli session SESSION, the calculations
%   the lab's analysis package (analyzeGFP / analyzeLawnProfiles, Haley et al.
%   2024) made from each analysed fluorescence image: ecoli/bacteria.mat
%   `lawnAnalysis` (one row per patch detected in an image) and the image's
%   patch mask, ecoli/mask/<image>.png. Decision log #62; the images and
%   profile curves, #64.
%
%   WHAT THE TIFFS ARE (decision #64). ecoli/images/<n>.tiff is NOT the image
%   as acquired: it is analyzeLawnProfiles' `imageNormalized` rounded to
%   uint16 -- the raw image (saturated pixels filled by linear
%   interpolation) times max(B) divided by B, B the empty-plate background
%   image smoothed by getFluorescenceBackground (outliers against a 400 px
%   moving median replaced, then a 20 px average filter). Checked exactly
%   on three images (Jess, 2026-10-05). The raw images, and the background
%   images, are ecoli/raw/<n>.tiff (the recordings, recordingList); every
%   calculation below takes the NORMALIZED image as its input, the pixels
%   the analysis actually used. With no raw/ folder the recordings are the
%   normalized TIFFs themselves and no normalized-image calculation is made.
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
%     fewer than 12 detected on a `rectangle` plate   each goes to the
%         nearest of the 12 patch positions of the acetate template
%         registered on the image's brightfield image (metaData
%         brightfieldImageNum -> the extract's `template`; the positions are
%         the spec's `ecoli_patch_layout`; ndi.setup.conv.haley.
%         matchTemplatePatches, decision #80), when every patch is within
%         its max_distance_mm and no two claim one position
%   An image matched no way is reported (OUT.skipped, with why) and its
%   per-patch values are left out; its mask is still stored.
%
%   Per image with an ecoli/images TIFF (when raw/ exists):
%     intensity calculation  the plate's `fluorescence intensity`, method
%                         `normalization to background illumination`: the
%                         TIFF, by location (opaque_body, not ingested), from
%                         the raw image's recording and its background image's
%                         recording (inputs). The analysis's window sizes
%                         are not stated: they are the code's (cited as the
%                         software), not part of what the value means
%
%   Per analysed image, all from the normalized image (input):
%     coordinate_system   the image's pixel grid, as part A's (only when
%                         bacteria.mat metaData gives the image's `scale`)
%     label calculation   the plate's patch mask, variable `Imaging Region of
%                         Interest` with the condition `Location` = bacterial
%                         patch (decision #113): a bool per pixel
%                         (ingested body) keyed [Y-coordinate, X-coordinate],
%                         method `image segmentation`; the mask reaches
%                         0.5 mm beyond each patch (in its body's description)
%     item calculation    the plate's `nearest bacterial patch` map
%                         (ecoli/closest/<image>.png), a 0-based index into
%                         the patch subjects -- only for a matched image
%   and per matched detected patch, about its patch subject, from the image
%   and the mask, each `fluorescence intensity` in background-normalized
%   arbitrary units, told apart by method and conditions:
%     intensity calculation  yPeak: method `maximum`
%                            yOuterEdge: condition `location` = `bacterial
%                            patch edge`
%                            centerAmplitude: method `mean`, condition
%                            `location` = `bacterial patch center`
%                            borderAmplitude (the basis of the paper's
%                            relative density; yPeak - yOuterEdge): method
%                            `peak amplitude` (EMPTY:0000349), method
%                            parameter `reference point` = `bacterial patch
%                            edge` (decision #123)
%     length calculation     xPeak, `distance` (mm -> m), conditions
%                            `reference point` = `bacterial patch edge` and
%                            `distance end point` = `bacterial patch
%                            fluorescence peak`
%     score calculation      `circularity` (0-1)
%     intensity calculation  the patch's profile curve, method `mean`
%                            (analyzeGFP lawnProfiles.pixelValuesNormalized,
%                            its row for this patch) in an ingested float64
%                            body keyed by `distance` (regular, 1 um steps,
%                            negative outside the patch; NaN where the patch
%                            has no pixels at that distance), condition
%                            `reference point` = `bacterial patch edge`,
%                            method parameter the 1 um `bin width`
%   The per-patch intensities and xPeak are read off the profile curve
%   (analyzeLawnProfiles), so the curve's statement is among their inputs
%   when it is stored (decision #122).
%   Not stored: borderCenterRatio (border / center amplitude), meanAmplitude,
%   FWHM, xHalfMax*, yHalfMax, lawnRadius (decision #60's keep list): each
%   is computed from the stored curve. The fitted background images are not
%   stored (decision #64): each is reproducible from its raw image.
%
%   Options: 'RecordingStatements', 'RecordingRefs', 'SoftwareId',
%   'InterpreterId', 'OperatingSystemId' as part A. 'ProfilesFile': the
%   analyzeGFP workspace holding lawnProfiles and backgroundInfo, default
%   ecoli/analyzeGFP_24-04-04.mat; read without loading its images
%   (private/lawnProfileReader); its `template` (extractTemplates), when
%   present, places partly detected images. Without the file there are no
%   curves, and OUT.skipped says so. 'PatchLayout': the spec's
%   `ecoli_patch_layout` (decision #80).
%
%   OUT fields: documents, counts (struct), skipped (cellstr), borderValues
%   (struct array, one per stored borderAmplitude statement: imageNum, row --
%   its position among the image's lawnAnalysis rows --, patchId,
%   statementId; for stage 12's fits, decision #65).

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
    options.ProfilesFile (1,:) char = ''
    options.PatchLayout = struct([])
end
if height(session) ~= 1
    error('ndi:setup:conv:haley:oneSession', 'Give exactly one session row.');
end
sid = char(session.session_id{1});
ref = char(session.local_identifier{1});
out = struct('documents', {{}}, 'skipped', {{}}, 'borderValues', struct('imageNum', {}, 'row', {}, ...
    'patchId', {}, 'statementId', {}), 'counts', struct('coordinate_system', 0, ...
    'mask', 0, 'nearest_patch', 0, 'matched_images', 0, 'template_matched_images', 0, 'unmatched_images', 0, ...
    'patch_values', 0, 'normalized_image', 0, 'profiles', 0));
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
rawMode = isfolder(fullfile(root, 'raw'));
P = [];
TPL = struct([]);
pf = options.ProfilesFile;
if isempty(pf), pf = fullfile(root, 'analyzeGFP_24-04-04.mat'); end
if isfile(pf)
    P = lawnProfileReader(pf);
    w = whos('-file', pf);
    if any(strcmp({w.name}, 'template'))
        S = load(pf, 'template');
        TPL = S.template;            % acetate registrations (extractTemplates)
    end
else
    out.skipped{end+1} = sprintf('%s: no %s; no profile curves', ref, pf);
end
fi = haleyTerm('fluorescence intensity');
patchEdge = haleyTerm('bacterial patch edge');
% each lawnAnalysis intensity column and the method / conditions that tell its
% `fluorescence intensity` statement from the others on the same patch
intensityValues = {
    'borderAmplitude', {'Method', haleyTerm('peak amplitude'), 'MethodParameters', did2.build.list( ...
        did2.build.parameter(haleyTerm('reference point'), 'Term', patchEdge))}
    'centerAmplitude', {'Method', haleyTerm('mean'), 'Conditions', did2.build.list( ...
        did2.build.condition(haleyTerm('location'), 'Term', haleyTerm('bacterial patch center')))}
    'yPeak',           {'Method', haleyTerm('maximum')}
    'yOuterEdge',      {'Conditions', did2.build.list( ...
        did2.build.condition(haleyTerm('location'), 'Term', patchEdge))}
    };

for k = 1:height(R)
    epoch = R.epoch{k};
    n = str2double(regexp(epoch, '(\d+)$', 'tokens', 'once'));
    if ~isKey(options.RecordingStatements, epoch)
        continue;                                % not written
    end
    plate = R.plate{k};
    rows = L(L.imageNum == n, :);
    normFile = fullfile(root, 'images', sprintf('%04d.tiff', n));
    if ~isKey(subjectIds, plate)
        if height(rows) > 0 || (rawMode && isfile(normFile))
            out.skipped{end+1} = sprintf('%s: plate %s is not a subject of this session', epoch, plate);
        end
        continue;
    end
    imageId = options.RecordingStatements(epoch);
    timeIds = {};
    if isKey(options.RecordingRefs, epoch), timeIds = {options.RecordingRefs(epoch)}; end
    calc = [{'SessionId', sid, 'TimeReferenceIds', timeIds}, env];

    % the image's background image, when it is a recording of this session
    bgEpoch = '';
    if height(M) > 0 && ismember('backgroundImageNum', M.Properties.VariableNames)
        bg = M.backgroundImageNum(M.imageNum == n);
        if ~isempty(bg) && ~isnan(bg(1)) && isKey(options.RecordingStatements, sprintf('ecoli_image%04d', bg(1)))
            bgEpoch = sprintf('ecoli_image%04d', bg(1));
        end
    end

    % the background-normalized image (decision #64): the TIFF in images/
    srcId = imageId;
    if rawMode && isfile(normFile)
        inputs = {imageId};
        if ~isempty(bgEpoch), inputs{end+1} = options.RecordingStatements(bgEpoch); end %#ok<AGROW>
        nm = did2.build.statement('calculation', subjectIds(plate), fi, [], ...
            'DataBody', true, 'DatumType', 'uint16', ...
            'Method', haleyTerm('normalization to background illumination'), ...
            'InputIds', inputs, calc{:}, 'Notes', ...
            ['The raw image (saturated pixels filled by linear interpolation) times the ' ...
            'maximum of its smoothed background image, divided by that smoothed image, ' ...
            'rounded to uint16 (analyzeLawnProfiles imageNormalized).'], 'ValueKind', 'intensity');
        info = dir(normFile);
        nb = did2.build.document('opaque_body', struct('format', fileFormat('EDAM:format_3591', 'TIFF'), ...
            'filename', sprintf('%04d.tiff', n), 'size_bytes', info.bytes, ...
            'notes', 'The background-normalized image, from ecoli/images.'), ...
            'SessionId', sid, 'Edges', struct('owner_id', nm.base.id), 'Files', {'body_data_0'});
        nb.files.file_info = struct('name', 'body_data_0', 'locations', struct( ...
            'delete_original', 0, 'uid', ndi.ido.unique_id(), 'location', normFile, ...
            'parameters', '', 'location_type', 'file', 'ingest', 0));
        docs = [docs, {nm, nb}]; %#ok<AGROW>
        srcId = nm.base.id;
        out.counts.normalized_image = out.counts.normalized_image + 1;
    end

    if height(rows) == 0
        continue;                                % not analysed
    end
    maskFile = fullfile(root, 'mask', sprintf('%04d.png', n));
    if ~isfile(maskFile)
        out.skipped{end+1} = sprintf('%s: no mask/%04d.png', epoch, n);
        continue;
    end

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
            'SourceUnit', ndi.setup.V2.sourceUnit('mm'), 'Approximate', true);
        % reference_point / axes: did-schema [coordinate system names]
        cs = did2.build.document('coordinate_system', struct( ...
            'reference_point', haleyTerm('image upper-left corner'), ...
            'axes', did2.build.list( ...
                struct('axis', haleyTerm('x-axis'), ...
                    'positive_direction', haleyTerm('image right'), 'spacing', step), ...
                struct('axis', haleyTerm('y-axis'), ...
                    'positive_direction', haleyTerm('image down'), 'spacing', step))), ...
            'SessionId', sid, 'Edges', struct('referent_id', imageId));
        docs{end+1} = cs; %#ok<AGROW>
        out.counts.coordinate_system = out.counts.coordinate_system + 1;
    end

    % the mask
    mask = logical(imread(maskFile));
    keys = pixelKeys(mask, pixel);
    inputs = {srcId};
    if ~rawMode && ~isempty(bgEpoch)
        inputs{end+1} = options.RecordingStatements(bgEpoch); %#ok<AGROW>
    end
    ms = did2.build.statement('calculation', subjectIds(plate), ...
        haleyTerm('region of interest'), [], 'DataBody', true, 'DatumType', 'bool', ...
        keys.args{:}, 'Method', haleyTerm('image segmentation'), ...
        'Conditions', did2.build.list(did2.build.condition(haleyTerm('location'), ...
            'Term', haleyTerm('bacterial patch'))), ...
        'InputIds', inputs, calc{:}, 'ValueKind', 'label');
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
    slot = matchFullImage(centroids, nDetected, numel(pIds));
    match = {'Notes', 'Detected patch matched to its grid patch by position (decision #62).'};
    why = '';
    if isempty(slot) && nDetected < 12 && numel(pIds) == 12
        % some patches not detected: place them by the acetate template
        % registered on the image's brightfield image (decision #80)
        [slot, why] = templateMatch(n, centroids);
        if ~isempty(slot)
            out.counts.template_matched_images = out.counts.template_matched_images + 1;
            match = {'Notes', sprintf(['Detected patch placed at the nearest patch position of ' ...
                'the acetate template registered on this image''s brightfield image; %d of 12 ' ...
                'patches detected in this image (decision #80).'], nDetected)};
        end
    end
    if isempty(slot)
        if isempty(why), why = sprintf('the plate has %d patch subject(s)', numel(pIds)); end
        out.skipped{end+1} = sprintf('%s: %d detected patch(es) on %s; not matched: %s', ...
            epoch, nDetected, plate, why);
        out.counts.unmatched_images = out.counts.unmatched_images + 1;
        continue;
    end
    out.counts.matched_images = out.counts.matched_images + 1;

    % the profile curves: one row per detected patch, in the same order
    curves = [];
    if ~isempty(P)
        [x, Y] = lawnProfileRead(P, n);
        if isempty(Y)
            if isKey(P.byImage, n)
                out.skipped{end+1} = sprintf('%s: lawnProfiles holds no curves for image %d', epoch, n);
            end
        elseif size(Y, 1) ~= nDetected || size(Y, 2) ~= numel(x)
            out.skipped{end+1} = sprintf('%s: lawnProfiles has %d x %d curves for %d patches and %d distances; no curves', ...
                epoch, size(Y, 1), size(Y, 2), nDetected, numel(x));
        elseif numel(x) < 2 || any(abs(diff(x) - 1e-3) > 1e-9)
            out.skipped{end+1} = sprintf('%s: lawnProfiles distances are not in 1 um steps; no curves', epoch);
        else
            curves = struct('Y', Y, 'keys', haleyAxes({haleyTerm('distance'), ...
                numel(x), 'Unit', haleyTerm('meter'), 'Origin', x(1) * 1e-3, 'Spacing', 1e-6, ...
                'SourceUnit', ndi.setup.V2.sourceUnit('mm'), 'SourceOrigin', x(1), 'SourceSpacing', 1e-3}));
        end
    end

    % the nearest-patch map
    closestFile = fullfile(root, 'closest', sprintf('%04d.png', n));
    if isfile(closestFile)
        c = double(imread(closestFile));
        if all(c(:) >= 1 & c(:) <= nDetected)
            v = slot(c) - 1;
            dt = 'uint8';
            if numel(pIds) > 255, dt = 'uint16'; end
            np = did2.build.statement('calculation', subjectIds(plate), ...
                haleyTerm('nearest bacterial patch'), [], 'DataBody', true, 'DatumType', dt, ...
                keys.args{:}, 'InputIds', {ms.base.id}, ...
                'Edges', struct('item_id', {pIds}), calc{:}, match{:}, 'ValueKind', 'item');
            docs = [docs, {np, ingestedBody(np, v, dt, keys, sid, ...
                'Each pixel''s nearest patch: a 0-based index into item_id.')}]; %#ok<AGROW>
            out.counts.nearest_patch = out.counts.nearest_patch + 1;
        else
            out.skipped{end+1} = sprintf('%s: closest/%04d.png holds values outside 1..%d; no map', ...
                epoch, n, nDetected);
        end
    end

    % the per-patch values: one variable, told apart by method and conditions
    in = {'InputIds', {srcId, ms.base.id}};
    for j = 1:nDetected
        patch = pIds{slot(j)};
        r = rows(j, :);
        % the profile curve first: the values below are read off it
        fromCurve = in;
        if ~isempty(curves)
            pc = did2.build.statement('calculation', patch, fi, [], ...
                'DataBody', true, 'DatumType', 'float64', curves.keys.args{:}, ...
                'Conditions', did2.build.list(did2.build.condition(haleyTerm('reference point'), ...
                    'Term', patchEdge)), ...
                'Method', haleyTerm('mean'), ...
                'MethodParameters', did2.build.list(did2.build.parameter(haleyTerm('bin width'), ...
                    'Value', 1e-6, 'Unit', haleyTerm('meter'), 'SourceValue', '0.001', 'SourceUnit', ndi.setup.V2.sourceUnit('mm'))), ...
                in{:}, calc{:}, match{:}, 'ValueKind', 'intensity');
            docs = [docs, {pc, ingestedBody(pc, curves.Y(j, :), 'float64', curves.keys, sid, ...
                ['Mean background-normalized intensity at each distance from the patch edge ' ...
                '(lawnProfiles pixelValuesNormalized); NaN where the patch has no pixels.'], 'NaN')}]; %#ok<AGROW>
            out.counts.profiles = out.counts.profiles + 1;
            fromCurve = {'InputIds', {srcId, ms.base.id, pc.base.id}};
        end
        for q = 1:size(intensityValues, 1)
            col = intensityValues{q, 1};
            if ~ismember(col, r.Properties.VariableNames) || isnan(r.(col)), continue; end
            v = did2.build.valueCell('intensity', double(r.(col)));
            docs{end+1} = did2.build.statement('calculation', patch, fi, v, ...
                intensityValues{q, 2}{:}, fromCurve{:}, calc{:}, match{:}, 'ValueKind', 'intensity'); %#ok<AGROW>
            out.counts.patch_values = out.counts.patch_values + 1;
            if strcmp(col, 'borderAmplitude')
                out.borderValues(end+1) = struct('imageNum', n, 'row', j, 'patchId', patch, ...
                    'statementId', docs{end}.base.id);
            end
        end
        if ismember('xPeak', r.Properties.VariableNames) && ~isnan(r.xPeak)
            v = did2.build.valueCell('length', r.xPeak * 1e-3, 'SourceValue', r.xPeak, 'SourceUnit', ndi.setup.V2.sourceUnit('mm'));
            docs{end+1} = did2.build.statement('calculation', patch, ...
                haleyTerm('distance'), v, 'Conditions', did2.build.list( ...
                    did2.build.condition(haleyTerm('reference point'), 'Term', patchEdge), ...
                    did2.build.condition(haleyTerm('distance end point'), ...
                        'Term', haleyTerm('bacterial patch fluorescence peak'))), ...
                fromCurve{:}, calc{:}, match{:}, 'ValueKind', 'length'); %#ok<AGROW>
            out.counts.patch_values = out.counts.patch_values + 1;
        end
        if ismember('circularity', r.Properties.VariableNames) && ~isnan(r.circularity)
            v = did2.build.valueCell('score', r.circularity, 'Fields', struct( ...
                'scale', haleyTerm('circularity'), 'scale_min', 0, 'scale_max', 1));
            docs{end+1} = did2.build.statement('calculation', patch, ...
                haleyTerm('circularity'), v, in{:}, calc{:}, match{:}, 'ValueKind', 'score'); %#ok<AGROW>
            out.counts.patch_values = out.counts.patch_values + 1;
        end
    end
end
out.documents = docs;

    function [slot, why] = templateMatch(imageNum, centroids)
        slot = [];
        if isempty(options.PatchLayout)
            why = 'no ecoli_patch_layout in the spec';
            return;
        end
        if isempty(TPL)
            why = 'the profiles file holds no template (run extractTemplates)';
            return;
        end
        r = find(M.imageNum == imageNum, 1);
        if isempty(r) || ~ismember('brightfieldImageNum', M.Properties.VariableNames)
            why = 'metaData names no brightfield image';
            return;
        end
        t = find(TPL.imageNum == M.brightfieldImageNum(r), 1);
        if isempty(t)
            why = sprintf('no template registered on brightfield image %g', M.brightfieldImageNum(r));
            return;
        end
        [slot, why] = ndi.setup.conv.haley.matchTemplatePatches(centroids, TPL.center(t, :), ...
            TPL.angle(t), TPL.scale(t), options.PatchLayout);
    end
end

% -----------------------------------------------------------------------------
function keys = pixelKeys(a, pixel)
% as part A: pixel centers from the upper-left corner, in meters when the
% scale is known, else in pixels
arguments
    a
    pixel (1,1) {mustBeNumeric}
end
if isnan(pixel)
    keys = haleyAxes( ...
        {haleyTerm('Y-coordinate'), size(a, 1), 'Unit', haleyTerm('pixel'), ...
            'Origin', 0.5, 'Spacing', 1}, ...
        {haleyTerm('X-coordinate'), size(a, 2), 'Unit', haleyTerm('pixel'), ...
            'Origin', 0.5, 'Spacing', 1});
    return;
end
keys = haleyAxes( ...
    {haleyTerm('Y-coordinate'), size(a, 1), 'Unit', haleyTerm('meter'), ...
        'Origin', pixel / 2, 'Spacing', pixel, 'SourceUnit', ndi.setup.V2.sourceUnit('pixel'), 'SourceOrigin', 0.5, 'SourceSpacing', 1}, ...
    {haleyTerm('X-coordinate'), size(a, 2), 'Unit', haleyTerm('meter'), ...
        'Origin', pixel / 2, 'Spacing', pixel, 'SourceUnit', ndi.setup.V2.sourceUnit('pixel'), 'SourceOrigin', 0.5, 'SourceSpacing', 1});
end
