function T = axesTable(dimensions, covariates)
%AXESTABLE A value's dimensions (its axes) as a table.
%
%   T = ndi.v2.axesTable(DIMENSIONS, COVARIATES), DIMENSIONS a data.dimensions
%   list and COVARIATES a data.covariates list (did-schema
%   V_eta_data_body_model_plan.md AMENDMENT 6: dimension k IS array axis k;
%   a covariate states something known at each position along one or more
%   dimensions). One row per dimension:
%     dimension    0-based index (what a covariate's `along` names)
%     term         the dimension's term name (what the axis is)
%     n            its length
%     unit         the unit of its coordinates ("" when none)
%     coordinates  a cell: the positions along it, read from the covariate
%                  that runs along this dimension alone and whose variable is
%                  the dimension's term, else the first covariate that runs
%                  along it alone ([] when none: a plain index)
%     covariates   the variables of every covariate along it (string array)
%
%   See also ndi.v2.covariatesTable, ndi.v2.covariateValues.

arguments
    dimensions
    covariates = []
end

dims = ndi.v2.entries(dimensions);
covs = ndi.v2.entries(covariates);
nd = numel(dims);
dimension = (0:nd-1)';
term = strings(nd, 1); n = nan(nd, 1); unit = strings(nd, 1);
coordinates = cell(nd, 1); covariateNames = cell(nd, 1);
for k = 1:nd
    term(k) = string(ndi.v2.termName(field(dims{k}, 'term', '')));
    nk = double(field(dims{k}, 'n', NaN));
    if isempty(nk), nk = NaN; end
    n(k) = nk(1);
    names = strings(0, 1);
    best = 0;
    for c = 1:numel(covs)
        along = double(field(covs{c}, 'along', []));
        if ~any(along(:) == k - 1), continue; end
        v = string(ndi.v2.termName(field(covs{c}, 'variable', '')));
        names(end+1, 1) = v; %#ok<AGROW>
        if isscalar(along) && (best == 0 || (v == term(k) && ...
                string(ndi.v2.termName(field(covs{best}, 'variable', ''))) ~= term(k)))
            best = c;
        end
    end
    covariateNames{k} = names;
    if best > 0
        coordinates{k} = ndi.v2.covariateValues(covs{best}, dims);
        unit(k) = string(ndi.v2.termName(field(covs{best}, 'unit', '')));
    end
end
covariates = covariateNames;
T = table(dimension, term, n, unit, coordinates, covariates);
end

function v = field(s, name, default)
arguments
    s
    name {mustBeText}
    default
end
v = default;
if isstruct(s) && isfield(s, name) && ~isempty(s(1).(name))
    v = s(1).(name);
end
end
