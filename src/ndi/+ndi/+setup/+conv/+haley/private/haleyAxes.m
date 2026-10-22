function ax = haleyAxes(varargin)
%HALEYAXES A value's dimensions and covariates, one axis per argument.
%
%   AX = haleyAxes(AXIS1, AXIS2, ...) where each AXIS is a cell
%   {TERM, N, <did2.build.covariate value form and options>...} describes
%   array axis k (did-schema V_eta_data_body_model_plan.md AMENDMENT 6,
%   Decided by Jess Haley, 2026-10-22 [covariates]): a dimension with TERM
%   and N positions, and -- when a value form is given -- a covariate whose
%   variable is the same TERM, along that one dimension (what a `keys` entry
%   held until 2026-10-22: the dimension term is the old key's variable, and
%   a regular origin/spacing stays). An AXIS of {TERM, N} alone is a bare
%   dimension (a plain index).
%
%   AX has fields
%     dimensions  did2.build.list of the dimensions, in array order
%     covariates  did2.build.list of the covariates ([] when none)
%     args        {'Dimensions', ..., 'Covariates', ...} for
%                 did2.build.statement (no 'Covariates' when none)
%   AX = haleyAxes(AX, 'Covariate', C) adds the covariate C (built with
%   did2.build.covariate against AX's dimension indices).

if nargin == 3 && isstruct(varargin{1}) && strcmp(varargin{2}, 'Covariate')
    ax = varargin{1};
    covs = ax.covariateCells;
    covs{end+1} = varargin{3};
    ax = finish(ax.dimensionCells, covs);
    return;
end
dims = cell(1, numel(varargin));
covs = {};
for k = 1:numel(varargin)
    a = varargin{k};
    dims{k} = did2.build.dimension(a{1}, a{2});
    if numel(a) > 2
        covs{end+1} = did2.build.covariate(a{1}, k - 1, a{3:end}); %#ok<AGROW>
    end
end
ax = finish(dims, covs);
end

function ax = finish(dims, covs)
ax = struct();
ax.dimensionCells = dims;
ax.covariateCells = covs;
ax.dimensions = did2.build.list(dims{:});
ax.covariates = [];
ax.args = {'Dimensions', ax.dimensions};
if ~isempty(covs)
    ax.covariates = did2.build.list(covs{:});
    ax.args = [ax.args, {'Covariates', ax.covariates}];
end
end
