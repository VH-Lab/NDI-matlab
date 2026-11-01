function T = covariatesTable(covariates, dimensions)
%COVARIATESTABLE A value's covariates as a table.
%
%   T = ndi.v2.covariatesTable(COVARIATES, DIMENSIONS): one row per entry of
%   a data.covariates list (did-schema V_eta_data_body_model_plan.md
%   AMENDMENT 6) with
%     variable   the covariate's variable (its term's name)
%     along      the 0-based dimension indices it runs along (a cell)
%     form       how its values are stored: origin_spacing, quantity, count,
%                term, text, logical, matrix or key (did-schema
%                [covariate key], 2026-11-01)
%     unit       its unit's name ("" when none)
%     values     a cell: the values, shaped by the extents of the `along`
%                dimensions (see ndi.v2.covariateValues)
%
%   See also ndi.v2.axesTable, ndi.v2.covariateValues.

arguments
    covariates
    dimensions = []
end

covs = ndi.v2.entries(covariates);
m = numel(covs);
variable = strings(m, 1); along = cell(m, 1); form = strings(m, 1);
unit = strings(m, 1); values = cell(m, 1);
for c = 1:m
    x = covs{c};
    if isstruct(x) && isfield(x, 'variable')
        variable(c) = string(ndi.v2.termName(x.variable));
    end
    if isstruct(x) && isfield(x, 'along')
        along{c} = double(x.along(:)');
    end
    if isstruct(x) && isfield(x, 'unit') && ~isempty(x.unit)
        unit(c) = string(ndi.v2.termName(x.unit));
    end
    [values{c}, form(c)] = ndi.v2.covariateValues(x, dimensions);
end
T = table(variable, along, form, unit, values);
end
