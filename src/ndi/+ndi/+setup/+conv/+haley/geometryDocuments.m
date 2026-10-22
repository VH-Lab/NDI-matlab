function out = geometryDocuments(dataParentDir, session, R, subjectIds, options)
%GEOMETRYDOCUMENTS Stage 10 part A (Haley): each behaviour video's geometry.
%
%   OUT = ndi.setup.conv.haley.geometryDocuments(DATAPARENTDIR, SESSION, R,
%   SUBJECTIDS, ...) builds, for the one-row session table SESSION, the
%   calculations the lab's analysis package (getForagingInfo, Haley et al.
%   2024) made from each behaviour video's first frame, read from the
%   session's experimentInfo.mat rows. Decision log #60.
%
%   Per behaviour video (R rows of kind 'behaviour' with a recording
%   statement in 'RecordingStatements'), all about the video's assay plate,
%   each a calculation whose input is the recording:
%     coordinate_system   the video's pixel grid: reference point the image upper-left
%                         corner, x-axis positive toward image right, y-axis
%                         positive toward image down, one pixel = 1/`scale` mm
%                         (the lab's scale: the arena's known diameter over its
%                         mask's size in pixels, so it is marked approximate)
%     label calculation   one per mask, variable `Imaging Region of Interest`
%                         (NCIT:C85402) with the condition `Location` = the
%                         region (decision #113): `arenaMask` (arena),
%                         `refMask` (reference mark; foragingMini's arenas
%                         have no mark and its masks are empty, so none) and
%                         `lawnMask` (bacterial patch). A bool per pixel, in a sampled_body keyed
%                         [Y-coordinate, X-coordinate] (MATLAB's [row,
%                         column]), metres with pixels as the source unit
%     item calculation    `lawnClosest` (`nearest bacterial patch`): which patch
%                         is nearest each pixel, as a 0-based index into the
%                         plate's patch subjects (item_id, in lawnCenters
%                         order, decision #38)
%     score calculation   `lawnRegistration` (variable `overlap`, method image
%                         registration): the fraction of the arena that
%                         overlaps once the lawn clip is registered onto the
%                         video (0-1, scale `fraction`); its inputs are both
%                         recordings
%   And per patch (the plate's patch subjects, in lawnCenters order, #38), each
%   about the PATCH, its input the recording:
%     position calculation `position` (`lawnCenters`, the patch's center), in
%                         the video's coordinate system: MATLAB's pixel centers
%                         are at 1, 2, ..., the system's origin is the image's
%                         corner, so a center at column x is x - 0.5 pixels
%                         from it
%     length calculation  `radius` (`lawnRadii`, pixels -> metres)
%     score calculation   `circularity` (`lawnCircularity`, 0-1)
%   (doImport's patch table had these; decision #70)
%   The arena mask's method parameter is the plate or arena diameter. The lawn
%   mask's inputs are the recording and the plate's target design statements
%   ('TargetIds': the patches' target diameter and the plate's target
%   spacing, built by an earlier stage); its method is the patches'
%   `lawnMethod` when they all share one (threshold: image segmentation;
%   template: image registration), else none, and its notes list them.
%   `lawnClosestOD600` (the closest map with each patch's OD600) and
%   `firstFrame` (frame 0 of the video) are not stored: both are already in
%   the dataset.
%
%   Each mask and map is written to a temporary gzip file of its raw bytes
%   (column-major, little-endian) that the database INGESTS when the session
%   is written (files.file_info `ingest` 1, `delete_original` 1), so it is
%   held in <session>/.ndi/files with the session.
%
%   Options:
%     'RecordingStatements'  containers.Map, epoch -> recording statement id
%                            (sessionDocuments' OUT.recordingStatements)
%     'RecordingRefs'        containers.Map, epoch -> its UTC reference id
%     'SoftwareId'           the analysis package (spec `haley_analysis`)
%     'InterpreterId'        MATLAB (spec `matlab`)
%     'OperatingSystemId'    the analysis computer's OS (spec `macos`)
%     'TargetIds'            containers.Map, plate local_identifier -> cell of
%                            the ids of that plate's target design statements
%                            (each patch's target diameter, the plate's target
%                            spacing); inputs of the plate's lawn mask.
%                            Default: none
%
%   OUT fields: documents (cell of structs), counts (struct), skipped (cellstr),
%   byEpoch (containers.Map, epoch -> struct of the ids part B needs:
%   coordinate_system, lawn_mask, nearest_patch, pixel (metres per pixel)).

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
    options.TargetIds = containers.Map()
end
if height(session) ~= 1
    error('ndi:setup:conv:haley:oneSession', 'Give exactly one session row.');
end
sid = char(session.session_id{1});
ref = char(session.local_identifier{1});
folder = char(session.folder{1});
out = struct('documents', {{}}, 'skipped', {{}}, 'counts', struct('coordinate_system', 0, ...
    'arena', 0, 'reference_mark', 0, 'lawn', 0, 'nearest_patch', 0, 'registration', 0, ...
    'patch_center', 0, 'patch_radius', 0, 'patch_circularity', 0), ...
    'byEpoch', containers.Map());
if strcmp(folder, 'ecoli')
    return;
end
if isempty(options.OperatingSystemId)
    % every calculation names the OS it ran on (a calculation requires it)
    out.skipped{end+1} = sprintf(['%s: no operating system document (the spec''s `macos`, ' ...
        'built by the metadata stage); no calculations'], ref);
    return;
end
pre = ndi.setup.conv.haley.idPrefix(folder);
I = load(fullfile(dataParentDir, 'haley', 'celegans', folder, 'experimentInfo.mat'), 'info');
D = I.info;
D = D(D.expNum == session.experiment(1), :);
R = R(strcmp(R.session, ref), :);
lawnClips = R(strcmp(R.kind, 'lawn'), :);
R = R(strcmp(R.kind, 'behaviour'), :);
docs = {};
env = runEnvironment(options);

for k = 1:height(R)
    epoch = R.epoch{k};
    if ~isKey(options.RecordingStatements, epoch)
        out.skipped{end+1} = sprintf('%s: no recording statement (not written)', epoch);
        continue;
    end
    row = find(arrayfun(@(r) strcmp(epochOf(pre, D.videoFileName{r}), epoch), 1:height(D)), 1);
    if isempty(row)
        out.skipped{end+1} = sprintf('%s: no experimentInfo row', epoch);
        continue;
    end
    d = D(row, :);
    plate = R.plate{k};
    if ~isKey(subjectIds, plate)
        out.skipped{end+1} = sprintf('%s: plate %s is not a subject of this session', epoch, plate);
        continue;
    end
    scale = colOr(d, 'scale', NaN);
    if ~(scale > 0)
        out.skipped{end+1} = sprintf('%s: no pixel scale; no geometry', epoch);
        continue;
    end
    videoId = options.RecordingStatements(epoch);
    timeIds = {};
    if isKey(options.RecordingRefs, epoch)
        timeIds = {options.RecordingRefs(epoch)};
    end
    pixel = 1e-3 / scale;                         % metres per pixel

    % ---- the video's coordinate system --------------------------------------
    step = did2.build.valueCell('length', pixel, 'SourceValue', 1 / scale, ...
        'SourceUnit', ndi.setup.V2.sourceUnit('mm'), 'Approximate', true);
    % did-schema [coordinate system names] (Jess Haley, 2026-10-22): the zero
    % point is `reference_point` and the axes `axes` (`origin` / `dimensions`
    % until then; a value's `dimensions` are its array's, a different thing)
    cs = did2.build.document('coordinate_system', struct( ...
        'reference_point', haleyTerm('image upper-left corner'), ...
        'axes', did2.build.list( ...
            struct('axis', haleyTerm('x-axis'), ...
                'positive_direction', haleyTerm('image right'), 'spacing', step), ...
            struct('axis', haleyTerm('y-axis'), ...
                'positive_direction', haleyTerm('image down'), 'spacing', step))), ...
        'SessionId', sid, 'Edges', struct('referent_id', videoId));
    docs{end+1} = cs; %#ok<AGROW>
    out.counts.coordinate_system = out.counts.coordinate_system + 1;

    common = [{'SessionId', sid, 'TimeReferenceIds', timeIds}, env];
    calc = [common, {'InputIds', {videoId}}];

    % ---- masks ---------------------------------------------------------------
    arenaParams = did2.build.list(did2.build.parameter(haleyTerm('arena diameter'), ...
        'Value', colOr(d, 'arenaDiameter', NaN) * 1e-3, 'Unit', haleyTerm('meter'), ...
        'SourceValue', num2str(colOr(d, 'arenaDiameter', NaN)), 'SourceUnit', ndi.setup.V2.sourceUnit('mm')));
    [docs, n] = mask(docs, d, 'arenaMask', 'arena', ...
        [calc, {'MethodParameters', arenaParams}]);
    out.counts.arena = out.counts.arena + n;
    [docs, n] = mask(docs, d, 'refMask', 'reference mark', calc);
    out.counts.reference_mark = out.counts.reference_mark + n;
    targets = {};
    if isKey(options.TargetIds, plate)
        targets = reshape(cellstr(options.TargetIds(plate)), 1, []);
    end
    lawnArgs = [common, {'InputIds', [{videoId}, targets]}];
    found = cellOr(d, 'lawnMethod');
    if ~iscell(found), found = {}; end
    found = found(~cellfun(@isempty, found));
    if ~isempty(found) && numel(unique(found)) == 1
        lawnArgs = [lawnArgs, {'Method', detectionMethod(found{1})}]; %#ok<AGROW>
    elseif ~isempty(found)
        lawnArgs = [lawnArgs, {'Notes', sprintf('Each patch''s detection method, in patch order: %s.', ...
            strjoin(found, ', '))}]; %#ok<AGROW>
    end
    [docs, n, lawnMaskId] = mask(docs, d, 'lawnMask', 'bacterial patch', lawnArgs);
    out.counts.lawn = out.counts.lawn + n;
    ids = struct('coordinate_system', cs.base.id, 'lawn_mask', lawnMaskId, ...
        'nearest_patch', '', 'pixel', pixel);

    % ---- nearest patch ---------------------------------------------------------
    closest = cellOr(d, 'lawnClosest');
    if ~isempty(closest)
        pIds = patchIds(subjectIds, plate);
        nPatch = max(closest(:));
        if isempty(pIds) || nPatch > numel(pIds) || any(closest(:) < 1)
            out.skipped{end+1} = sprintf(['%s: lawnClosest names patches 1..%d; plate %s has ' ...
                '%d patch subject(s); no nearest-patch map'], epoch, nPatch, plate, numel(pIds));
        else
            dt = 'uint8';
            if numel(pIds) > 255, dt = 'uint16'; end
            inputs = {videoId};
            if ~isempty(lawnMaskId), inputs{end+1} = lawnMaskId; end %#ok<AGROW>
            pk = pixelKeys(closest, pixel);
            st = did2.build.statement('calculation', subjectIds(plate), ...
                haleyTerm('nearest bacterial patch'), [], 'DataBody', true, 'DatumType', dt, ...
                pk.args{:}, 'SessionId', sid, ...
                'TimeReferenceIds', timeIds, 'InputIds', inputs, ...
                'Edges', struct('item_id', {pIds}), env{:}, 'ValueKind', 'item');
            docs = [docs, {st, ingestedBody(st, closest - 1, dt, pk, sid, ...
                'Each pixel''s nearest patch: a 0-based index into item_id.')}]; %#ok<AGROW>
            out.counts.nearest_patch = out.counts.nearest_patch + 1;
            ids.nearest_patch = st.base.id;
        end
    end

    % ---- each patch's center, radius and circularity ---------------------------
    docs = patchGeometry(docs, d, plate, cs.base.id, pixel, calc);

    % ---- lawn clip registration ------------------------------------------------
    fit = colOr(d, 'lawnRegistration', NaN);
    lawnEpoch = epochOf(pre, cellOrChar(d, 'lawnFileName'));
    if ~isnan(fit) && ~isempty(lawnEpoch) && any(strcmp(lawnClips.epoch, lawnEpoch)) ...
            && isKey(options.RecordingStatements, lawnEpoch)
        v = did2.build.valueCell('score', fit, 'Fields', struct( ...
            'scale', haleyTerm('proportion'), 'scale_min', 0, 'scale_max', 1));
        st = did2.build.statement('calculation', subjectIds(plate), ...
            haleyTerm('overlap'), v, 'Method', haleyTerm('image registration'), ...
            'SessionId', sid, 'TimeReferenceIds', timeIds, ...
            'InputIds', {videoId, options.RecordingStatements(lawnEpoch)}, env{:}, 'ValueKind', 'score');
        docs{end+1} = st; %#ok<AGROW>
        out.counts.registration = out.counts.registration + 1;
    end
    out.byEpoch(epoch) = ids;
end
out.documents = docs;

% =============================================================================
    function docs = patchGeometry(docs, d, plate, csId, pixel, calc)
        centers = cellOr(d, 'lawnCenters');
        if isempty(centers)
            return;
        end
        pIds = patchIds(subjectIds, plate);
        n = size(centers, 1);
        if numel(pIds) ~= n
            out.skipped{end+1} = sprintf(['%s: %d lawnCenters but %d patch subject(s); ' ...
                'no patch geometry'], epoch, n, numel(pIds));
            return;
        end
        radii = cellOr(d, 'lawnRadii');
        circ = cellOr(d, 'lawnCircularity');
        for j = 1:n
            xy = double(centers(j, 1:2)) - 0.5;
            if all(isfinite(xy))
                docs{end+1} = did2.build.statement('calculation', pIds{j}, ...
                    haleyTerm('position'), struct('coordinates', xy), ...
                    'Edges', struct('coordinate_system_id', csId), calc{:}, 'ValueKind', 'position'); %#ok<AGROW>
                out.counts.patch_center = out.counts.patch_center + 1;
            end
            if numel(radii) == n && isfinite(radii(j))
                v = did2.build.valueCell('length', double(radii(j)) * pixel, ...
                    'SourceValue', double(radii(j)), 'SourceUnit', ndi.setup.V2.sourceUnit('pixel'), 'Approximate', true);
                docs{end+1} = did2.build.statement('calculation', pIds{j}, ...
                    haleyTerm('radius'), v, calc{:}, 'ValueKind', 'length'); %#ok<AGROW>
                out.counts.patch_radius = out.counts.patch_radius + 1;
            end
            if numel(circ) == n && isfinite(circ(j))
                v = did2.build.valueCell('score', double(circ(j)), 'Fields', struct( ...
                    'scale', haleyTerm('circularity'), 'scale_min', 0, 'scale_max', 1));
                docs{end+1} = did2.build.statement('calculation', pIds{j}, ...
                    haleyTerm('circularity'), v, calc{:}, 'ValueKind', 'score'); %#ok<AGROW>
                out.counts.patch_circularity = out.counts.patch_circularity + 1;
            end
        end
    end

    function [docs, n, id] = mask(docs, d, column, region, args)
        % one label calculation + its body; none when the mask is absent or
        % empty. Variable Imaging Region of Interest (decision #113, tenet T16:
        % the pixels say where a region is; `binary mask` named how it is
        % stored), with the condition Location = REGION (a haleyTerm handle):
        % which region it is, a fact of its own that does not repeat the
        % variable (T19); ARGS the statement's other name-value pairs
        n = 0; id = '';
        m = cellOr(d, column);
        if isempty(m) || ~any(m(:))
            return;
        end
        roi = did2.build.list(did2.build.condition(haleyTerm('location'), ...
            'Term', haleyTerm(region)));
        pk = pixelKeys(m, pixel);
        st = did2.build.statement('calculation', subjectIds(plate), ...
            haleyTerm('region of interest'), [], 'DataBody', true, 'DatumType', 'bool', ...
            pk.args{:}, 'Conditions', roi, args{:}, 'ValueKind', 'label');
        docs = [docs, {st, ingestedBody(st, logical(m), 'bool', pk, sid, ...
            sprintf('The %s mask (1 = inside), from the source''s `%s`.', region, column))}];
        n = 1; id = st.base.id;
    end
end

% -----------------------------------------------------------------------------
function e = runEnvironment(options)
% the calculation's software, interpreter and operating system edges
arguments
    options (1,1) struct
end
e = {};
if ~isempty(options.SoftwareId), e = [e, {'SoftwareId', options.SoftwareId}]; end
if ~isempty(options.InterpreterId), e = [e, {'InterpreterId', options.InterpreterId}]; end
if ~isempty(options.OperatingSystemId), e = [e, {'OperatingSystemId', options.OperatingSystemId}]; end
end

function keys = pixelKeys(a, pixel)
% [Y-coordinate, X-coordinate]: MATLAB's [row, column]. Each position is a
% pixel's CENTER, measured from the image's upper-left corner (the coordinate
% system's origin): the first is half a pixel in.
arguments
    a
    pixel (1,1) {mustBeNumeric}
end
keys = haleyAxes( ...
    {haleyTerm('Y-coordinate'), size(a, 1), 'Unit', haleyTerm('meter'), ...
        'Origin', pixel / 2, 'Spacing', pixel, 'SourceUnit', ndi.setup.V2.sourceUnit('pixel'), 'SourceOrigin', 0.5, 'SourceSpacing', 1}, ...
    {haleyTerm('X-coordinate'), size(a, 2), 'Unit', haleyTerm('meter'), ...
        'Origin', pixel / 2, 'Spacing', pixel, 'SourceUnit', ndi.setup.V2.sourceUnit('pixel'), 'SourceOrigin', 0.5, 'SourceSpacing', 1});
end

function t = detectionMethod(name)
% the term for a patch detection method the source names (`lawnMethod`)
arguments
    name {mustBeText}
end
switch char(name)
    case 'threshold', t = haleyTerm('image segmentation');
    case 'template',  t = haleyTerm('image registration');
    otherwise
        error('ndi:setup:conv:haley:unregisteredLabel', ...
            ['The patch detection method "%s" (the lawn table''s `lawnMethod` column) ' ...
             'is neither threshold nor template, so it has no registered term; ' ...
             '"patch detection by %s" is not written as a label. Decide its term and ' ...
             'add it to haleyTerm and detectionMethod.'], char(name), char(name));
end
end


function e = epochOf(pre, name)
% a recording's epoch id from the file name the table records
arguments
    pre {mustBeText}
    name
end
e = '';
name = strtrim(char(name));
if isempty(name), return; end
[~, stem] = fileparts(name);
e = [pre '_' stem];
end

function v = colOr(d, name, default)
arguments
    d table
    name {mustBeText}
    default
end
v = default;
if ismember(name, d.Properties.VariableNames)
    x = d.(name);
    if iscell(x), x = x{1}; end
    if isnumeric(x) && isscalar(x), v = double(x); end
end
end

function v = cellOr(d, name)
% d.(NAME){1}, or [] when the table has no such column
arguments
    d table
    name {mustBeText}
end
v = [];
if ismember(name, d.Properties.VariableNames)
    v = d.(name);
    if iscell(v), v = v{1}; end
end
end

function v = cellOrChar(d, name)
arguments
    d table
    name {mustBeText}
end
v = cellOr(d, name);
if isempty(v) || ~(ischar(v) || isstring(v)), v = ''; end
v = char(v);
end
