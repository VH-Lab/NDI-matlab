function T = axesTable(keys)
%AXESTABLE A value's keys (its axes) as a table.
%
%   T = ndi.v2.axesTable(KEYS), KEYS a data.keys struct array: one row per
%   key with variable, unit, n and coordinates (a cell: the numeric
%   positions, origin + spacing * (0:n-1) for a regular key, or the labels'
%   names).

keys = ndi.v2.entries(keys);
variable = strings(0, 1); unit = strings(0, 1); n = zeros(0, 1); coordinates = cell(0, 1);
for k = 1:numel(keys)
    key = keys{k};
    variable(end+1, 1) = string(ndi.v2.termName(field(key, 'variable', ''))); %#ok<AGROW>
    unit(end+1, 1) = string(ndi.v2.termName(field(key, 'unit', ''))); %#ok<AGROW>
    nk = double(field(key, 'n', NaN));
    if isempty(nk), nk = NaN; end
    n(end+1, 1) = nk; %#ok<AGROW>
    c = [];
    if logical(field(key, 'regular', false)) && ~isnan(nk)
        o = field(field(key, 'origin', struct()), 'value', 0);
        s = field(field(key, 'spacing', struct()), 'value', 1);
        c = double(o) + double(s) * (0:nk-1)';
    elseif ~isempty(field(key, 'values', []))
        c = field(field(key, 'values', struct()), 'values', []);
        c = c(:);
    elseif ~isempty(field(key, 'labels', []))
        l = field(key, 'labels', []);
        l = ndi.v2.entries(l);
        c = strings(numel(l), 1);
        for j = 1:numel(l), c(j) = string(ndi.v2.termName(l{j})); end
    end
    coordinates{end+1, 1} = c; %#ok<AGROW>
end
T = table(variable, unit, n, coordinates);
end

function v = field(s, name, default)
v = default;
if isstruct(s) && isfield(s, name) && ~isempty(s(1).(name))
    v = s(1).(name);
end
end
