function tf = userIsAdmin()
% USERISADMIN - Whether the logged-in NDI Cloud user is an administrator.
%
%   TF = ndi.cloud.internal.userIsAdmin()
%
%   Returns true if a user is logged in (there is an active token) and
%   ndi.cloud.api.users.me reports isAdmin. Returns false when no one is
%   logged in or the lookup fails; this never prompts for a login.
%
%   NDI Cloud lets administrators create datasets in any organization they
%   belong to, regardless of that organization's canUploadDataset flag.
%
%   See also: ndi.cloud.internal.chooseOrganization, ndi.cloud.api.users.me

    tf = false;
    if isempty(ndi.cloud.internal.getActiveToken())
        return;
    end
    try
        [ok, userInfo] = ndi.cloud.api.users.me();
        tf = ok && isstruct(userInfo) && isfield(userInfo, 'isAdmin') ...
            && ~isempty(userInfo.isAdmin) && logical(userInfo.isAdmin);
    catch
        tf = false;
    end
end
