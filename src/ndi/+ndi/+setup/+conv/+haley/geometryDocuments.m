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
%     coordinate_system   the video's pixel grid: origin the image's upper-left
%                         corner, x along the image horizontal axis (positive
%                         right), y along the vertical axis (positive down), one
%                         pixel = 1/`scale` mm (the lab's scale: the arena's
%                         known diameter over its mask's size in pixels, so it
%                         is marked approximate)
%     label_calculation   one per mask: `arenaMask` (variable `arena region`),
%                         `refMask` (`reference mark region`; foragingMini's
%                         arenas have no mark and its masks are empty, so none)
%                         and `lawnMask` (`bacterial lawn region`). A bool per
%                         pixel, in a sampled_body keyed [image vertical
%                         position, image horizontal position], metres with
%                         pixels as the source unit
%     item_calculation    `lawnClosest`: which patch is nearest each pixel, as a
%                         0-based index into the plate's patch subjects (item_id,
%                         in lawnCenters order, decision #38). Only when the
%                         schema in use has `item` (did-schema PR #87)
%     score_calculation   `lawnRegistration`: the fraction of the arena that
%                         overlaps once the lawn clip is registered onto the
%                         video (0-1); its inputs are both recordings
%   And per patch (the plate's patch subjects, in lawnCenters order, #38), each
%   about the PATCH, its input the recording:
%     position_calculation `patch centre` (`lawnCenters`), in the video's
%                         coordinate system: MATLAB's pixel centres are at 1,
%                         2, ..., the system's origin is the image's corner, so
%                         a centre at column x is x - 0.5 pixels from it
%     length_calculation  `patch radius` (`lawnRadii`, pixels -> metres)
%     score_calculation   `patch circularity` (`lawnCircularity`, 0-1)
%   (doImport's patch table had these; decision #70)
%   The arena's nominal diameter and the patches' nominal diameter and spacing
%   are method parameters of the masks that used them; the lawn mask's method
%   is the patches' `lawnMethod` when they all share one (else none, and its
%   notes list them). `lawnClosestOD600` (the closest map with each patch's
%   OD600) and `firstFrame` (frame 0 of the video) are not stored: both are
%   already in the dataset.
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
end
if height(session) ~= 1
    error('ndi:setup:conv:haley:oneSession', 'Give exactly one session row.');
end
sid = char(session.session_id{1});
ref = char(session.local_identifier{1});
folder = char(session.folder{1});
out = struct('documents', {{}}, 'skipped', {{}}, 'counts', struct('coordinate_system', 0, ...
    'arena', 0, 'reference_mark', 0, 'lawn', 0, 'nearest_patch', 0, 'registration', 0, ...
    'patch_centre', 0, 'patch_radius', 0, 'patch_circularity', 0), ...
    'byEpoch', containers.Map());
if strcmp(folder, 'ecoli')
    return;
end
if isempty(options.OperatingSystemId)
    % every calculation names the OS it ran on (subject_calculation requires it)
    out.skipped{end+1} = sprintf(['%s: no operating system document (the spec''s `macos`, ' ...
        'built by the metadata stage); no calculations'], ref);
    return;
end
hasItem = ndi.setup.V2.schemaHasField('item', 'value');
if ~hasItem
    out.skipped{end+1} = sprintf(['%s: the schema in use has no `item` (did-schema PR #87); ' ...
        'no nearest-patch maps'], ref);
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
        'SourceUnit', 'mm', 'Approximate', true);
    cs = did2.build.document('coordinate_system', struct( ...
        'origin', did2.build.term('', 'image upper-left corner'), ...
        'dimensions', did2.build.list( ...
            struct('axis', did2.build.term('', 'image horizontal axis'), ...
                'positive_direction', did2.build.term('', 'image right'), 'spacing', step), ...
            struct('axis', did2.build.term('', 'image vertical axis'), ...
                'positive_direction', did2.build.term('', 'image down'), 'spacing', step))), ...
        'SessionId', sid, 'Edges', struct('referent_id', videoId));
    docs{end+1} = cs; %#ok<AGROW>
    out.counts.coordinate_system = out.counts.coordinate_system + 1;

    calc = {'SessionId', sid, 'TimeReferenceIds', timeIds, 'InputIds', {videoId}};
    calc = [calc, env]; %#ok<AGROW>

    % ---- masks ---------------------------------------------------------------
    arenaParams = did2.build.list(did2.build.parameter('arena diameter', ...
        'Value', colOr(d, 'arenaDiameter', NaN) * 1e-3, 'Unit', 'meter', ...
        'SourceValue', num2str(colOr(d, 'arenaDiameter', NaN)), 'SourceUnit', 'mm'));
    [docs, n] = mask(docs, d, 'arenaMask', 'arena region', {'MethodParameters', arenaParams});
    out.counts.arena = out.counts.arena + n;
    [docs, n] = mask(docs, d, 'refMask', 'reference mark region', {});
    out.counts.reference_mark = out.counts.reference_mark + n;
    lawnArgs = {'MethodParameters', did2.build.list( ...
        did2.build.parameter('patch diameter', 'Value', colOr(d, 'lawnDiameter', NaN) * 1e-3, ...
            'Unit', 'meter', 'SourceValue', num2str(colOr(d, 'lawnDiameter', NaN)), 'SourceUnit', 'mm'), ...
        did2.build.parameter('patch spacing', 'Value', colOr(d, 'lawnSpacing', NaN) * 1e-3, ...
            'Unit', 'meter', 'SourceValue', num2str(colOr(d, 'lawnSpacing', NaN)), 'SourceUnit', 'mm'))};
    found = cellOr(d, 'lawnMethod');
    if ~iscell(found), found = {}; end
    found = found(~cellfun(@isempty, found));
    if ~isempty(found) && numel(unique(found)) == 1
        lawnArgs = [lawnArgs, {'Method', did2.build.term('', ['patch detection by ' found{1}])}]; %#ok<AGROW>
    elseif ~isempty(found)
        lawnArgs = [lawnArgs, {'Notes', sprintf('Each patch''s detection method, in patch order: %s.', ...
            strjoin(found, ', '))}]; %#ok<AGROW>
    end
    [docs, n, lawnMaskId] = mask(docs, d, 'lawnMask', 'bacterial lawn region', lawnArgs);
    out.counts.lawn = out.counts.lawn + n;
    ids = struct('coordinate_system', cs.base.id, 'lawn_mask', lawnMaskId, ...
        'nearest_patch', '', 'pixel', pixel);

    % ---- nearest patch ---------------------------------------------------------
    closest = cellOr(d, 'lawnClosest');
    if hasItem && ~isempty(closest)
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
            st = did2.build.statement('item_calculation', subjectIds(plate), ...
                did2.build.term('', 'nearest patch'), [], 'DataBody', true, 'DatumType', dt, ...
                'Keys', pixelKeys(closest, pixel), 'SessionId', sid, ...
                'TimeReferenceIds', timeIds, 'InputIds', inputs, ...
                'Edges', struct('item_id', {pIds}), env{:});
            docs = [docs, {st, ingestedBody(st, closest - 1, dt, pixelKeys(closest, pixel), sid, ...
                'Each pixel''s nearest patch: a 0-based index into item_id.')}]; %#ok<AGROW>
            out.counts.nearest_patch = out.counts.nearest_patch + 1;
            ids.nearest_patch = st.base.id;
        end
    end

    % ---- each patch's centre, radius and circularity ---------------------------
    docs = patchGeometry(docs, d, plate, cs.base.id, pixel, calc);

    % ---- lawn clip registration ------------------------------------------------
    fit = colOr(d, 'lawnRegistration', NaN);
    lawnEpoch = epochOf(pre, cellOrChar(d, 'lawnFileName'));
    if ~isnan(fit) && ~isempty(lawnEpoch) && any(strcmp(lawnClips.epoch, lawnEpoch)) ...
            && isKey(options.RecordingStatements, lawnEpoch)
        v = did2.build.valueCell('score', fit, 'Fields', struct( ...
            'scale', did2.build.term('', 'fraction of the arena overlapping'), ...
            'scale_min', 0, 'scale_max', 1));
        st = did2.build.statement('score_calculation', subjectIds(plate), ...
            did2.build.term('', 'lawn clip registration fit'), v, 'SessionId', sid, ...
            'TimeReferenceIds', timeIds, ...
            'InputIds', {videoId, options.RecordingStatements(lawnEpoch)}, env{:});
        docs{end+1} = st; %#ok<AGROW>
        out.counts.registration = out.counts.registration + 1;
    end
    out.byEpoch(epoch) = ids;
end
out.documents = docs;

% =============================================================================
    function docs = patchGeometry(docs, d, plate, csId, pixel, calc)
        centres = cellOr(d, 'lawnCenters');
        if isempty(centres)
            return;
        end
        pIds = patchIds(subjectIds, plate);
        n = size(centres, 1);
        if numel(pIds) ~= n
            out.skipped{end+1} = sprintf(['%s: %d lawnCenters but %d patch subject(s); ' ...
                'no patch geometry'], epoch, n, numel(pIds));
            return;
        end
        radii = cellOr(d, 'lawnRadii');
        circ = cellOr(d, 'lawnCircularity');
        for j = 1:n
            xy = double(centres(j, 1:2)) - 0.5;
            if all(isfinite(xy))
                docs{end+1} = did2.build.statement('position_calculation', pIds{j}, ...
                    did2.build.term('', 'patch centre'), struct('coordinates', xy), ...
                    'Edges', struct('coordinate_system_id', csId), calc{:}); %#ok<AGROW>
                out.counts.patch_centre = out.counts.patch_centre + 1;
            end
            if numel(radii) == n && isfinite(radii(j))
                v = did2.build.valueCell('length', double(radii(j)) * pixel, ...
                    'SourceValue', double(radii(j)), 'SourceUnit', 'pixel', 'Approximate', true);
                docs{end+1} = did2.build.statement('length_calculation', pIds{j}, ...
                    did2.build.term('', 'patch radius'), v, calc{:}); %#ok<AGROW>
                out.counts.patch_radius = out.counts.patch_radius + 1;
            end
            if numel(circ) == n && isfinite(circ(j))
                v = did2.build.valueCell('score', double(circ(j)), 'Fields', struct( ...
                    'scale', did2.build.term('', 'circularity'), 'scale_min', 0, 'scale_max', 1));
                docs{end+1} = did2.build.statement('score_calculation', pIds{j}, ...
                    did2.build.term('', 'patch circularity'), v, calc{:}); %#ok<AGROW>
                out.counts.patch_circularity = out.counts.patch_circularity + 1;
            end
        end
    end

    function [docs, n, id] = mask(docs, d, column, variable, extra)
        % one label_calculation + its body; none when the mask is absent or empty
        n = 0; id = '';
        m = cellOr(d, column);
        if isempty(m) || ~any(m(:))
            return;
        end
        st = did2.build.statement('label_calculation', subjectIds(plate), ...
            did2.build.term('', variable), [], 'DataBody', true, 'DatumType', 'bool', ...
            'Keys', pixelKeys(m, pixel), calc{:}, extra{:});
        docs = [docs, {st, ingestedBody(st, logical(m), 'bool', pixelKeys(m, pixel), sid, ...
            sprintf('The %s mask (1 = inside), from the source''s `%s`.', variable, column))}];
        n = 1; id = st.base.id;
    end
end

% -----------------------------------------------------------------------------
function e = runEnvironment(options)
% the calculation's software, interpreter and operating system edges
e = {};
if ~isempty(options.SoftwareId), e = [e, {'SoftwareId', options.SoftwareId}]; end
if ~isempty(options.InterpreterId), e = [e, {'InterpreterId', options.InterpreterId}]; end
if ~isempty(options.OperatingSystemId), e = [e, {'OperatingSystemId', options.OperatingSystemId}]; end
end

function keys = pixelKeys(a, pixel)
% [image vertical position, image horizontal position]: MATLAB's [row, column].
% Each position is a pixel's CENTRE, measured from the image's upper-left
% corner (the coordinate system's origin): the first is half a pixel in.
keys = did2.build.list( ...
    did2.build.key('image vertical position', size(a, 1), 'Unit', 'meter', ...
        'Origin', pixel / 2, 'Spacing', pixel, 'SourceUnit', 'pixel', 'SourceOrigin', 0.5, 'SourceSpacing', 1), ...
    did2.build.key('image horizontal position', size(a, 2), 'Unit', 'meter', ...
        'Origin', pixel / 2, 'Spacing', pixel, 'SourceUnit', 'pixel', 'SourceOrigin', 0.5, 'SourceSpacing', 1));
end


function e = epochOf(pre, name)
% a recording's epoch id from the file name the table records
e = '';
name = strtrim(char(name));
if isempty(name), return; end
[~, stem] = fileparts(name);
e = [pre '_' stem];
end

function v = colOr(d, name, default)
v = default;
if ismember(name, d.Properties.VariableNames)
    x = d.(name);
    if iscell(x), x = x{1}; end
    if isnumeric(x) && isscalar(x), v = double(x); end
end
end

function v = cellOr(d, name)
% d.(NAME){1}, or [] when the table has no such column
v = [];
if ismember(name, d.Properties.VariableNames)
    v = d.(name);
    if iscell(v), v = v{1}; end
end
end

function v = cellOrChar(d, name)
v = cellOr(d, name);
if isempty(v) || ~(ischar(v) || isstring(v)), v = ''; end
v = char(v);
end
