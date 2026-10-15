function [p, vintage] = lightsheetLevel(levelDoc, pyramidDoc)
%LIGHTSHEETLEVEL A lightsheet pyramid level's fields, by their v1 names, in either vintage.
%
%   [P, VINTAGE] = ndi.vintage.lightsheetLevel(LEVELDOC)
%   [P, VINTAGE] = ndi.vintage.lightsheetLevel(LEVELDOC, PYRAMIDDOC)
%
%   v1 LEVELDOC (lightsheetZarrLevel, what NDI writes today): P IS the
%   document's `lightsheetZarrLevel` block, untouched, and VINTAGE is 'v1'.
%   Nothing is recomputed, so every v1 reader reads exactly what it read
%   before.
%
%   V_eta LEVELDOC (the `sampled_body` DID-matlab
%   +migrators_j/lightsheet_zarr_level.m makes of a level that held bytes,
%   its id kept, owner_id = the pyramid's observation): P is a struct with
%   the v1 block's field names, read back from where the migrator put each
%   value, and VINTAGE is 'V_eta':
%
%     axes_order, shape, chunks, voxel_size, translation, voxel_size_units
%                         from the body's `keys` (ndi.vintage.lightsheetKeys;
%                         spacing and origin in the SOURCE's unit, as v1)
%     chunk_grid          ceil(shape ./ chunks), as makePyramid computes it
%     n_chunks_stored     the `body_data` series' slot count (series_info),
%                         else the number of body_data_<k> members it names
%     chunk_index_origin  0: the first member is body_data_0
%                         (ndi.vintage.seriesMemberBase). v1 says 1.
%     chunk_order         sampled_body.datum_order
%     byte_order, fill_value   sampled_body's (fill_value parsed as a number)
%     codec               'raw' when the body has no `compression`, else the
%                         compression ('blosc' for v1's 'blosc-zstd': a Blosc
%                         chunk's header carries its own settings, #73 L4)
%     reduction_function  the `summary statistic` condition: NCIT:C25564 ->
%                         'max', NCIT:C53319 -> 'mean', else the term's name;
%                         'none' for a body with no such condition
%     redundant           data_body.redundant (false on level 0)
%     dtype               the PYRAMID's: its observation's
%                         value.source_data_type (the v1 spelling, '<u2' or
%                         'uint16'), else value.data_type. A sampled_body
%                         carries no type of its own; '' without PYRAMIDDOC.
%     level               NaN. The migrator does not carry the level index
%                         (it says "derivable"); it is derivable only from
%                         the SET of levels, which ndi.vintage.lightsheetLevels
%                         does.
%     label               ''. Not carried by the migrator.
%
%   See also: ndi.vintage.lightsheetLevels, ndi.vintage.lightsheetPyramid,
%             ndi.vintage.lightsheetChunkName.

if nargin < 2
    pyramidDoc = [];
end
props = ndi.v2.props(levelDoc);
if isfield(props, 'lightsheetZarrLevel')
    p = props.lightsheetZarrLevel;
    vintage = 'v1';
    return;
end
vintage = 'V_eta';

k = ndi.vintage.lightsheetKeys(etaField(props, 'keys'));
p = struct();
p.level = NaN;
p.label = '';
p.reduction_function = reductionOf(etaField(props, 'conditions'));
p.axes_order = k.axes_order;
p.shape = k.shape;
p.chunks = k.chunks;
if isempty(p.chunks)
    p.chunks = p.shape;
end
p.chunk_grid = ceil(p.shape ./ max(p.chunks, 1));
p.n_chunks_stored = storedCount(props);
p.chunk_index_origin = ndi.vintage.seriesMemberBase(props);
p.chunk_order = charOr(etaField(props, 'datum_order'), 'C');
p.dtype = '';
if ~isempty(pyramidDoc)
    p.dtype = pyramidDtype(ndi.v2.props(pyramidDoc));
end
p.fill_value = fillOf(etaField(props, 'fill_value'));
p.byte_order = charOr(etaField(props, 'byte_order'), '');
p.codec = charOr(etaField(props, 'compression'), 'raw');
p.voxel_size = k.voxel_size;
p.voxel_size_units = k.voxel_size_units;
p.translation = k.translation;
r = etaField(props, 'redundant');
p.redundant = ~isempty(r) && logical(r(1));
end

% ===================== helpers =============================================

function v = etaField(props, name)
% The value of NAME in whichever property block holds it: a V_eta body's
% fields are routed to the block that declares them (`keys` and `complete` in
% `data`, `conditions`/`compression`/`redundant` in `data_body`,
% `datum_order`/`byte_order`/`fill_value` in `sampled_body`), and which block
% that is has moved between did-schema revisions.
v = [];
skip = {'base', 'document_class', 'depends_on', 'files'};
order = {'data', 'data_body', 'sampled_body'};
names = fieldnames(props);
names = [order(ismember(order, names)), setdiff(names, [order, skip], 'stable')'];
for i = 1:numel(names)
    b = props.(names{i});
    if isstruct(b) && isscalar(b) && isfield(b, name)
        v = b.(name);
        return;
    end
end
end

function r = reductionOf(conditions)
r = 'none';
list = {};
if iscell(conditions)
    for i = 1:numel(conditions)
        c = conditions{i};
        if isstruct(c), list = [list, num2cell(reshape(c, 1, []))]; end %#ok<AGROW>
    end
elseif isstruct(conditions)
    list = num2cell(reshape(conditions, 1, []));
end
for i = 1:numel(list)
    c = list{i};
    if ~isfield(c, 'variable') || ~strcmpi(termOf(c.variable, 'name'), 'summary statistic')
        continue;
    end
    t = [];
    if isfield(c, 'term') && isstruct(c.term) && isfield(c.term, 'value')
        t = c.term.value;
    end
    switch termOf(t, 'node')
        case 'NCIT:C25564', r = 'max';
        case 'NCIT:C53319', r = 'mean';
        otherwise
            name = lower(termOf(t, 'name'));
            switch name
                case 'maximum',         r = 'max';
                case 'arithmetic mean', r = 'mean';
                case 'minimum',         r = 'min';
                case '',                r = 'none';
                otherwise,              r = name;
            end
    end
    return;
end
end

function s = termOf(t, part)
s = '';
if iscell(t)
    if isempty(t), return; end
    t = t{1};
end
if isstruct(t) && ~isempty(t) && isfield(t, part)
    s = char(t(1).(part));
elseif strcmp(part, 'name') && (ischar(t) || isstring(t))
    s = char(t);
end
end

function n = storedCount(props)
n = 0;
if ~isfield(props, 'files') || ~isstruct(props.files)
    return;
end
files = props.files;
if isfield(files, 'series_info') && ~isempty(files.series_info)
    si = files.series_info;
    if iscell(si), si = [si{:}]; end
    for i = 1:numel(si)
        if isfield(si(i), 'name') && strcmp(char(si(i).name), 'body_data') ...
                && isfield(si(i), 'count') && ~isempty(si(i).count)
            n = double(si(i).count);
            return;
        end
    end
end
if isfield(files, 'file_info') && ~isempty(files.file_info)
    fi = files.file_info;
    if iscell(fi), fi = [fi{:}]; end
    names = arrayfun(@(x) char(x.name), fi, 'UniformOutput', false);
    n = sum(~cellfun(@isempty, regexp(names, '^body_data_\d+$', 'once')));
end
end

function d = pyramidDtype(pp)
d = charOr(ndi.v2.blockOf(pp, 'value', 'source_data_type'), '');
if isempty(d)
    d = charOr(ndi.v2.blockOf(pp, 'value', 'data_type'), '');
end
if isempty(d) && isfield(pp, 'lightsheetZarrPyramid')
    d = charOr(pp.lightsheetZarrPyramid.dtype, '');
end
end

function v = fillOf(x)
v = 0;
if isempty(x), return; end
if ischar(x) || isstring(x)
    v = str2double(x);
else
    v = double(x(1));
end
end

function s = charOr(x, default)
if isempty(x)
    s = default;
elseif iscell(x)
    s = char(x{1});
else
    s = char(x);
end
end
