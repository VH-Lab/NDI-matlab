function organizations = getOrganizations(options)
% GETORGANIZATIONS - The organizations the logged-in NDI Cloud user belongs to.
%
%   ORGANIZATIONS = ndi.cloud.internal.getOrganizations()
%
%   Returns a 1xN struct array with fields 'id', 'name' and
%   'canUploadDataset' (see ndi.cloud.internal.normalizeOrganizations), one
%   entry per organization the current user belongs to, in the order the
%   server returned them.
%
%   The list is read from the cache written at login
%   (ndi.cloud.internal.setOrganizations). If the cache is empty or
%   unreadable, the list is fetched from ndi.cloud.api.users.me (which
%   authenticates as needed) and cached.
%
%   ORGANIZATIONS = ndi.cloud.internal.getOrganizations('Refresh', true)
%   always fetches a fresh list from the server and updates the cache; use
%   this if the user may have been added to an organization since login.
%
%   See also: ndi.cloud.internal.chooseOrganization,
%             ndi.cloud.internal.setOrganizations, ndi.cloud.api.users.me

    arguments
        options.Refresh (1,1) logical = false
    end

    if ~options.Refresh
        cached = getenv('NDI_CLOUD_ORGANIZATIONS');
        if ~isempty(cached)
            try
                organizations = ndi.cloud.internal.normalizeOrganizations(jsondecode(cached));
                if ~isempty(organizations)
                    return;
                end
            catch
                % Unreadable cache; fall through and fetch a fresh list.
            end
        end
    end

    [ok, userInfo] = ndi.cloud.api.users.me();
    if ~ok
        error('NDI:Cloud:MeFailed', ...
            'Could not retrieve your NDI Cloud user information.');
    end

    raw = [];
    if isstruct(userInfo) && isfield(userInfo, 'organizations')
        raw = userInfo.organizations;
    end
    organizations = ndi.cloud.internal.normalizeOrganizations(raw);
    ndi.cloud.internal.setOrganizations(organizations);
end
