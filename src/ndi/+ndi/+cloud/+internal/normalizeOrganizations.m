function organizations = normalizeOrganizations(raw)
% NORMALIZEORGANIZATIONS - Normalize an NDI Cloud organizations list.
%
%   ORGANIZATIONS = ndi.cloud.internal.normalizeOrganizations(RAW)
%
%   Converts the 'organizations' field of an NDI Cloud login or /users/me
%   response (or a previously normalized list, or its jsondecode'd JSON
%   cache) into a 1xN struct array with the fields:
%
%       id               - (char) the organization id
%       name             - (char) the organization name ('' if none)
%       canUploadDataset - (logical) whether datasets may be created in it
%
%   RAW may be a struct array, a cell array of scalar structs (as jsondecode
%   sometimes returns), or empty. Entries without an id are dropped. An
%   absent canUploadDataset field is treated as true so that an older API
%   response never blocks an upload on the client side; the server still
%   enforces the permission.
%
%   See also: ndi.cloud.internal.getOrganizations,
%             ndi.cloud.internal.setOrganizations

    organizations = struct('id', {}, 'name', {}, 'canUploadDataset', {});

    if isempty(raw)
        return;
    end

    if isstruct(raw)
        orgList = num2cell(raw(:)');
    elseif iscell(raw)
        orgList = raw(:)';
    else
        error('NDI:Cloud:InvalidOrganizations', ...
            'Organizations must be a struct array or a cell array of structs.');
    end

    for i = 1:numel(orgList)
        org = orgList{i};
        if ~isstruct(org) || ~isscalar(org) || ~isfield(org, 'id') || isempty(org.id)
            continue;
        end
        entry.id = char(string(org.id));
        entry.name = '';
        if isfield(org, 'name') && ~isempty(org.name)
            entry.name = char(string(org.name));
        end
        entry.canUploadDataset = true;
        if isfield(org, 'canUploadDataset') && ~isempty(org.canUploadDataset)
            entry.canUploadDataset = logical(org.canUploadDataset);
        end
        organizations(end+1) = entry; %#ok<AGROW>
    end
end
