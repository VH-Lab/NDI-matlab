function f = lightsheetKeys(keys)
%LIGHTSHEETKEYS A V_eta lightsheet array's `keys`, read back into v1's terms.
%
%   F = ndi.vintage.lightsheetKeys(KEYS)
%
%   KEYS is the `keys` list of a migrated lightsheet body (a level's
%   sampled_body, or the OME-Zarr store's opaque_body): one entry per array
%   dimension, in dimension order, as DID-matlab
%   +migrators_j/private/jLightsheetKeys.m writes them. It may arrive as a
%   struct array or a cell array (a JSON round trip makes either).
%
%   F has the v1 fields NDI's lightsheet readers use, per axis and in the
%   keys' order:
%     axes_order        'tczyx'-style: time -> t, channel -> c, z/y/x as named
%     shape             each key's `n`
%     chunks            each key's `chunk` ([] when no key has one)
%     voxel_size        the axis spacing IN THE SOURCE'S OWN UNIT
%     translation       the axis origin, likewise
%     units             cellstr, the source's unit per axis ('' if none)
%     voxel_size_units  the unit of the first space axis (v1 hard-coded
%                       'micrometer' there; the migrator converts it)
%     channel_names     the `c` key's terms' names, comma-joined ('' if none)
%
%   SOURCE UNITS, NOT CANONICAL ONES. The migrator converts a space or time
%   axis to V_eta's canonical unit (meter, second) and keeps what the source
%   said in spacing.source_value / origin.source_value / source_unit. v1 readers and their
%   callers (chooseLevel's target voxel size, the napari viewer) work in the
%   source's micrometres, so the source values are read where they exist and
%   the canonical ones only where the source's were already canonical.
%
%   AN AXIS WITH NO SPACING READS AS 1, ORIGIN AS 0. The `c` key is
%   categorical (names or indices, no spacing). v1 stored the NGFF `scale`
%   there, which for a channel axis is 1. This is a reader's convention so
%   chooseLevel can compare whole vectors; it is not a value the document
%   states. A space/time axis the source gave no scale is written by the
%   migrator as REGULAR with origin 0, spacing 1 and NO unit (its indices
%   0..n-1; Jess 2026-10-15), so it reads as voxel size 1, translation 0 and
%   unit '' from the key itself. A key whose positions are stored (a
%   `quantity` 0..n-1) reads as 1 and 0 by the convention above, the same.
%
%   See also: ndi.vintage.lightsheetLevel, ndi.vintage.lightsheetPyramid.

arguments
    keys
end

list = asList(keys);
n = numel(list);
f = struct('axes_order', '', 'shape', zeros(1, n), 'chunks', [], ...
    'voxel_size', ones(1, n), 'translation', zeros(1, n), ...
    'units', {repmat({''}, 1, n)}, 'voxel_size_units', '', 'channel_names', '');
chunks = nan(1, n);
axes = blanks(n);
for k = 1:n
    key = list{k};
    v = lower(termName(get(key, 'variable')));
    switch v
        case 'time',    axes(k) = 't';
        case 'channel', axes(k) = 'c';
        case {'z', 'y', 'x'}, axes(k) = v;
        otherwise
            if ~isempty(v), axes(k) = v(1); else, axes(k) = '?'; end
    end
    f.shape(k) = double(firstOr(get(key, 'n'), 0));
    c = get(key, 'chunk');
    if ~isempty(c), chunks(k) = double(c(1)); end

    % did2.build.key writes a regular axis as origin = {value,
    % source_value} and spacing = {value, source_value}: the canonical
    % number and, when the unit was converted, the source's own.
    unit = termName(get(key, 'source_unit'));
    [spacing, sourceSpacing] = pairOf(get(key, 'spacing'), get(key, 'source_spacing'));
    [origin, sourceOrigin] = pairOf(get(key, 'origin'), get(key, 'source_origin'));
    if ~isempty(sourceSpacing)
        spacing = sourceSpacing;
        if ~isempty(sourceOrigin), origin = sourceOrigin; end
    elseif isempty(unit)
        unit = termName(get(key, 'unit'));
    end
    if ~isempty(spacing), f.voxel_size(k) = double(spacing(1)); end
    if ~isempty(origin),  f.translation(k) = double(origin(1)); end
    f.units{k} = unit;
    if axes(k) == 'c'
        terms = get(key, 'term');
        names = cellfun(@termName, asList(terms), 'UniformOutput', false);
        f.channel_names = strjoin(names, ',');
    end
end
f.axes_order = axes;
if any(~isnan(chunks))
    chunks(isnan(chunks)) = f.shape(isnan(chunks));
    f.chunks = chunks;
end
space = find(ismember(axes, 'zyx'), 1);
if ~isempty(space)
    f.voxel_size_units = f.units{space};
end
end

function v = get(s, name)
arguments
    s
    name {mustBeText}
end
v = [];
if isstruct(s) && isfield(s, name)
    v = s.(name);
end
end

function [v, source] = pairOf(p, flatSource)
% A key's origin or spacing: the {value, source_value} pair did2.build.key
% writes, or a bare number with the source in a sibling field (flatSource).
arguments
    p
    flatSource
end
v = [];
source = flatSource;
if isstruct(p)
    if isfield(p, 'value'), v = p(1).value; end
    if isfield(p, 'source_value') && ~isempty(p(1).source_value)
        source = p(1).source_value;
    end
elseif isnumeric(p)
    v = p;
end
end

function v = firstOr(v, default)
arguments
    v
    default
end
if isempty(v)
    v = default;
elseif iscell(v)
    v = v{1};
elseif ~ischar(v)
    v = v(1);
end
end

function n = termName(t)
% A term or a name: {node, name} struct, a bare name, or a one-element cell.
arguments
    t
end
n = '';
if iscell(t)
    if isempty(t), return; end
    t = t{1};
end
if isstruct(t) && ~isempty(t) && isfield(t, 'name')
    n = char(t(1).name);
elseif ischar(t) || isstring(t)
    n = char(t);
end
end

function c = asList(x)
arguments
    x
end
if iscell(x)
    c = reshape(x, 1, []);
elseif isstruct(x)
    c = reshape(num2cell(x), 1, []);
else
    c = {};
end
end
