function organizationId = resolveOrganizationId(options)
% RESOLVEORGANIZATIONID - Resolve an organization name or id to an id.
%
%   ORGANIZATIONID = ndi.cloud.internal.resolveOrganizationId( ...
%       'organizationName', <name>) resolves the given name against the
%   organizations the current user belongs to (via ndi.cloud.api.users.me).
%
%   ORGANIZATIONID = ndi.cloud.internal.resolveOrganizationId( ...
%       'organizationID', <id>) verifies the given id is one the current
%   user belongs to and returns it.
%
%   Exactly one of the two must be non-empty. Names are matched
%   case-sensitively; ambiguous or unknown values raise an error naming
%   the organizations that ARE available, so a caller can print a useful
%   diagnostic.
%
%   See also: ndi.cloud.uploadDataset, ndi.cloud.ui.dialog.selectOrganization.

    arguments
        options.organizationName (1,:) char = ''
        options.organizationID   (1,:) char = ''
    end

    nameGiven = ~isempty(options.organizationName);
    idGiven   = ~isempty(options.organizationID);
    if nameGiven == idGiven
        error('NDI:Cloud:OrganizationArguments', ...
            'Exactly one of organizationName or organizationID must be given.');
    end

    [ok, userInfo] = ndi.cloud.api.users.me();
    if ~ok
        error('NDI:Cloud:MeFailed', ...
            'Could not retrieve your NDI Cloud user information.');
    end

    orgIds   = cellfun(@(x) char(string(x)), userInfo.organizationID,   'UniformOutput', false);
    orgNames = cellfun(@(x) char(string(x)), userInfo.organizationName, 'UniformOutput', false);

    if isempty(orgIds)
        error('NDI:Cloud:NoOrganizations', ...
            'Your NDI Cloud account does not belong to any organizations.');
    end

    if nameGiven
        matches = find(strcmp(orgNames, options.organizationName));
        if isempty(matches)
            error('NDI:Cloud:UnknownOrganization', ...
                ['Organization name "%s" is not one of the organizations you belong ', ...
                 'to. Available: %s.'], options.organizationName, ...
                availableList(orgNames, orgIds));
        end
        if numel(matches) > 1
            error('NDI:Cloud:AmbiguousOrganization', ...
                ['Organization name "%s" matches %d organizations you belong to; ', ...
                 'pass organizationID instead. Ids: %s.'], options.organizationName, ...
                numel(matches), strjoin(orgIds(matches), ', '));
        end
        organizationId = orgIds{matches};
    else
        matches = find(strcmp(orgIds, options.organizationID));
        if isempty(matches)
            error('NDI:Cloud:UnknownOrganization', ...
                ['Organization id "%s" is not one of the organizations you belong ', ...
                 'to. Available: %s.'], options.organizationID, ...
                availableList(orgNames, orgIds));
        end
        organizationId = orgIds{matches};
    end
end

function s = availableList(names, ids)
    parts = strings(1, numel(ids));
    for k = 1:numel(ids)
        if k <= numel(names) && ~isempty(names{k})
            parts(k) = sprintf('"%s" (%s)', names{k}, ids{k});
        else
            parts(k) = sprintf('(no name) (%s)', ids{k});
        end
    end
    s = char(strjoin(parts, ', '));
end
