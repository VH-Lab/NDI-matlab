function [p, vintage] = lightsheetPyramid(pyramidDoc, session, levelRecs)
%LIGHTSHEETPYRAMID A lightsheet pyramid's fields, by their v1 names, in either vintage.
%
%   [P, VINTAGE] = ndi.vintage.lightsheetPyramid(PYRAMIDDOC)
%   [P, VINTAGE] = ndi.vintage.lightsheetPyramid(PYRAMIDDOC, SESSION)
%   [P, VINTAGE] = ndi.vintage.lightsheetPyramid(PYRAMIDDOC, SESSION, LEVELRECS)
%
%   v1 PYRAMIDDOC (lightsheetZarrPyramid, what NDI writes today): P IS the
%   document's `lightsheetZarrPyramid` block, untouched; VINTAGE 'v1'. SESSION
%   and LEVELRECS are not used.
%
%   V_eta PYRAMIDDOC (the intensity `observation` DID-matlab
%   +migrators_j/lightsheet_zarr_pyramid.m makes of it, its id kept): P has
%   the v1 block's field names, read from where the migration put each one:
%
%     dtype            value.source_data_type (the v1 spelling), else
%                      value.data_type
%     axes_order, shape_level0, voxel_size_level0, translation_level0,
%     voxel_size_units, axes_units, channel_names, n_channels
%                      the full-resolution array's keys. The migration moves
%                      them onto the OME-Zarr STORE's unheld opaque_body (owned
%                      by the observation; did2.convert.foldGenericFiles), so
%                      with SESSION that body is read first. A SmartSPIM
%                      store's body (a TIFF folder) has no keys, and without
%                      SESSION there is no body to read: then level 0's keys
%                      (LEVELRECS, ndi.vintage.lightsheetLevels), which the
%                      same pass completed from the pyramid's units and
%                      channel names.
%     label            the observation's `statement.notes` (Jess
%                      2026-10-15: the label stays there, permanently). When
%                      the batch pass did not run, the notes also carry, after
%                      a newline and '-- store body: ', the text the pass
%                      would have moved to the store body; only the part
%                      before the LAST such separator is the label. The
%                      separator is DID-matlab's lightsheet_zarr_pyramid.m /
%                      foldGenericFiles.m NOTES_SEPARATOR, character for
%                      character.
%     pyramid_name     parsed from the store body's `description`
%                      ('NGFF multiscales name "..."'); '' when there is no
%                      store body (or no SESSION).
%     pyramid_type     '' always: the migration DROPS it (Jess 2026-10-15; it
%                      repeats the levels' summary statistic, and the v1
%                      docs say not to trust it).
%     pipeline_version ''. It became a `version` text_assertion about the
%                      software entity, not read here.
%     byte_order       level 0's, if given.
%
%   See also: ndi.vintage.lightsheetLevels, ndi.vintage.lightsheetPyramidDocs,
%             ndi.fun.doc.lightsheet.levelTable.

if nargin < 2, session = []; end
if nargin < 3, levelRecs = {}; end
props = ndi.v2.props(pyramidDoc);
if isfield(props, 'lightsheetZarrPyramid')
    p = props.lightsheetZarrPyramid;
    vintage = 'v1';
    return;
end
vintage = 'V_eta';

p = struct('label', '', 'pyramid_name', '', 'pyramid_type', '', ...
    'axes_order', '', 'axes_units', '', 'channel_names', '', 'n_channels', 0, ...
    'shape_level0', [], 'voxel_size_level0', [], 'voxel_size_units', '', ...
    'translation_level0', [], 'dtype', '', 'pipeline_version', '', 'byte_order', '');

p.label = labelOf(charOr(ndi.v2.blockOf(props, 'statement', 'notes', '')));

p.dtype = charOr(ndi.v2.blockOf(props, 'value', 'source_data_type'));
if isempty(p.dtype)
    p.dtype = charOr(ndi.v2.blockOf(props, 'value', 'data_type'));
end

frame = [];
if ~isempty(session)
    stores = session.database_search(ndi.query('', 'isa', 'opaque_body', '') & ...
        ndi.query('', 'depends_on', 'owner_id', props.base.id));
    for k = 1:numel(stores)
        sp = stores{k}.document_properties;
        d = blockValue(sp, 'description');
        if ~isempty(d)
            p.pyramid_name = quoted(charOr(d), 'NGFF multiscales name');
        end
        keys = blockValue(sp, 'keys');
        if ~isempty(keys) && isempty(frame)
            frame = ndi.vintage.lightsheetKeys(keys);
        end
    end
end

level0 = [];
for k = 1:numel(levelRecs)
    r = levelRecs{k};
    if isfield(r, 'level') && isequal(r.level, 0)
        level0 = r;
        break;
    end
end
if isempty(frame) && ~isempty(level0)
    frame = struct('axes_order', level0.axes_order, 'shape', level0.shape, ...
        'voxel_size', level0.voxel_size, 'translation', level0.translation, ...
        'voxel_size_units', level0.voxel_size_units, 'units', {{}}, 'channel_names', '');
end
if ~isempty(level0) && isfield(level0, 'byte_order')
    p.byte_order = level0.byte_order;
end
if isempty(frame)
    return;
end
p.axes_order = frame.axes_order;
p.shape_level0 = frame.shape;
p.voxel_size_level0 = frame.voxel_size;
p.translation_level0 = frame.translation;
p.voxel_size_units = frame.voxel_size_units;
if ~isempty(frame.units)
    p.axes_units = strjoin(frame.units, ',');
end
p.channel_names = frame.channel_names;
c = find(frame.axes_order == 'c', 1);
if ~isempty(c)
    p.n_channels = frame.shape(c);
end
end

function label = labelOf(notes)
% The label: NOTES up to the LAST separator DID-matlab's migrator writes
% before the text its store-record pass moves out (present only when that pass
% did not run), else all of NOTES.
SEPARATOR = sprintf('\n-- store body: ');
label = notes;
at = strfind(notes, SEPARATOR);
if ~isempty(at)
    label = notes(1:at(end) - 1);
end
end

function s = quoted(text, label)
s = '';
tok = regexp(text, [regexptranslate('escape', label) ' "([^"]*)"'], 'tokens', 'once');
if ~isempty(tok)
    s = tok{1};
end
end

function v = blockValue(props, name)
v = [];
skip = {'base', 'document_class', 'depends_on', 'files'};
names = fieldnames(props);
for i = 1:numel(names)
    if any(strcmp(names{i}, skip)), continue; end
    b = props.(names{i});
    if isstruct(b) && isscalar(b) && isfield(b, name) && ~isempty(b.(name))
        v = b.(name);
        return;
    end
end
end

function s = charOr(x)
if isempty(x)
    s = '';
elseif iscell(x)
    s = char(x{1});
else
    s = char(x);
end
end
