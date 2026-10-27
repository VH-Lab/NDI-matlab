function c = asStructCell(x)
%ASSTRUCTCELL Normalize a decoded JSON array of objects to a cell array of structs.
%
%   C = ndi.cloud.api.implementation.admin.asStructCell(X)
%
%   jsondecode returns an array of objects as a struct array when every
%   object has the same fields, and as a cell array of scalar structs when
%   they differ (for example, when an optional field is present on only
%   some of them). This returns a 1-by-N cell array of scalar structs in
%   both cases, and an empty cell for an empty or missing array.

    c = {};
    if isstruct(x)
        c = cell(1, numel(x));
        for i = 1:numel(x)
            c{i} = x(i);
        end
    elseif iscell(x)
        c = x(:)';
        c = c(cellfun(@isstruct, c));
    end
end
