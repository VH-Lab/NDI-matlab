function setOrganizations(organizations)
% SETORGANIZATIONS - Cache the logged-in user's NDI Cloud organizations.
%
%   ndi.cloud.internal.setOrganizations(ORGANIZATIONS)
%
%   Stores the list of organizations the current NDI Cloud user belongs to,
%   so that callers can offer a choice by name without another round trip
%   to the server. ORGANIZATIONS is the 'organizations' field of a login or
%   /users/me response (struct array or cell array of structs with fields
%   'id', 'name' and 'canUploadDataset'), or a list as returned by
%   ndi.cloud.internal.getOrganizations.
%
%   The list is stored as JSON in the NDI_CLOUD_ORGANIZATIONS environment
%   variable, alongside NDI_CLOUD_TOKEN, so that it survives 'clear all'
%   for the life of the MATLAB process.
%
%   ndi.cloud.internal.setOrganizations([]) clears the cache. This is what
%   ndi.cloud.logout does.
%
%   See also: ndi.cloud.internal.getOrganizations, ndi.cloud.logout

    arguments
        organizations = []
    end

    organizations = ndi.cloud.internal.normalizeOrganizations(organizations);

    if isempty(organizations)
        setenv('NDI_CLOUD_ORGANIZATIONS', '');
    else
        setenv('NDI_CLOUD_ORGANIZATIONS', jsonencode(organizations));
    end
end
