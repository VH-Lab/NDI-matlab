function [organizationID, organizationName] = chooseOrganization(options)
% CHOOSEORGANIZATION - Decide which of the user's NDI Cloud organizations to act on.
%
%   [ORGANIZATIONID, ORGANIZATIONNAME] = ndi.cloud.internal.chooseOrganization(...)
%
%   NDI Cloud users may belong to several organizations, so any operation
%   that needs one (for example, creating a dataset) must decide which. This
%   function makes that decision from the user's organization list
%   (ndi.cloud.internal.getOrganizations), in this order:
%
%     1. If 'organizationName' or 'organizationID' is given, it is matched
%        against the user's organizations and returned. When logged in, an
%        unknown value triggers one refresh of the list from the server
%        before failing, in case the user was added to an organization
%        after login.
%     2. Otherwise, if exactly one organization qualifies, it is returned
%        (unless 'AlwaysAsk' is true).
%     3. Otherwise, if 'Interactive' is true, a dialog lets the user pick
%        one by name.
%     4. Otherwise an error is thrown that lists the available organizations
%        by name and id, so the caller can pass one explicitly.
%
%   When 'RequireUpload' is true, only organizations in which the user may
%   create datasets qualify: those with canUploadDataset set, or any of the
%   user's organizations if the user is an NDI Cloud administrator (as on
%   the server). The administrator check (ndi.cloud.internal.userIsAdmin)
%   is only made when canUploadDataset would exclude an organization.
%
%   Name-value options:
%       organizationName - (char) name of the organization to use. Names are
%                          matched case-sensitively. Mutually exclusive with
%                          organizationID.
%       organizationID   - (char) id of the organization to use.
%       RequireUpload    - (logical) only consider organizations that allow
%                          dataset upload. Default false.
%       Interactive      - (logical) allow a selection dialog when a choice
%                          is needed. Default: true when running in the
%                          MATLAB desktop, false otherwise (e.g. -batch).
%       AlwaysAsk        - (logical) show the dialog even when only one
%                          organization qualifies. Default false. Ignored
%                          when Interactive is false.
%       Parent           - a figure to center the dialog over. Default [].
%       PromptString     - (string) prompt shown in the dialog. Default
%                          "Select an organization:".
%
%   Outputs:
%       ORGANIZATIONID   - (char) the chosen organization's id.
%       ORGANIZATIONNAME - (char) the chosen organization's name ('' if none).
%
%   If the user cancels the dialog, this throws NDI:CloudDialog:UserCanceled.
%
%   Example:
%       orgId = ndi.cloud.internal.chooseOrganization( ...
%           'organizationName', 'My Lab', 'RequireUpload', true);
%
%   See also: ndi.cloud.internal.getOrganizations,
%             ndi.cloud.ui.dialog.selectOrganization,
%             ndi.cloud.ui.dialog.organizationLabels

    arguments
        options.organizationName (1,:) char = ''
        options.organizationID (1,:) char = ''
        options.RequireUpload (1,1) logical = false
        options.Interactive (1,1) logical = usejava('desktop')
        options.AlwaysAsk (1,1) logical = false
        options.Parent = []
        options.PromptString (1,1) string = "Select an organization:"
    end

    nameGiven = ~isempty(options.organizationName);
    idGiven = ~isempty(options.organizationID);
    if nameGiven && idGiven
        error('NDI:Cloud:OrganizationArguments', ...
            'organizationName and organizationID are mutually exclusive.');
    end

    organizations = ndi.cloud.internal.getOrganizations();
    if isempty(organizations)
        error('NDI:Cloud:NoOrganizations', ...
            'Your NDI Cloud account does not belong to any organizations.');
    end

    % 1. An explicit request.
    if nameGiven || idGiven
        idx = findRequested(organizations, options);
        if isempty(idx) && ~isempty(ndi.cloud.internal.getActiveToken())
            organizations = ndi.cloud.internal.getOrganizations('Refresh', true);
            idx = findRequested(organizations, options);
        end
        if isempty(idx)
            if nameGiven
                requested = sprintf('name "%s"', options.organizationName);
            else
                requested = sprintf('id "%s"', options.organizationID);
            end
            error('NDI:Cloud:UnknownOrganization', ...
                'Organization %s is not one of the organizations you belong to. Available: %s.', ...
                requested, availableList(organizations));
        end
        if numel(idx) > 1
            error('NDI:Cloud:AmbiguousOrganization', ...
                'Organization name "%s" matches %d organizations you belong to; pass organizationID instead. Matches: %s.', ...
                options.organizationName, numel(idx), availableList(organizations(idx)));
        end
        if options.RequireUpload && ~organizations(idx).canUploadDataset ...
                && ~ndi.cloud.internal.userIsAdmin()
            error('NDI:Cloud:OrganizationCannotUpload', ...
                'Organization %s does not allow dataset upload.', ...
                describe(organizations(idx)));
        end
        organizationID = organizations(idx).id;
        organizationName = organizations(idx).name;
        return;
    end

    % 2. Only one candidate.
    candidates = organizations;
    if options.RequireUpload && ~all([organizations.canUploadDataset]) ...
            && ~ndi.cloud.internal.userIsAdmin()
        candidates = organizations([organizations.canUploadDataset]);
        if isempty(candidates)
            error('NDI:Cloud:NoUploadableOrganization', ...
                'None of your organizations allows dataset upload. Your organizations: %s.', ...
                availableList(organizations));
        end
    end

    if isscalar(candidates) && ~(options.AlwaysAsk && options.Interactive)
        organizationID = candidates.id;
        organizationName = candidates.name;
        return;
    end

    % 3. Ask the user.
    if options.Interactive
        labels = ndi.cloud.ui.dialog.organizationLabels({candidates.name}, {candidates.id});
        [idx, ok] = ndi.util.ListDialog.choose(labels, ...
            'Title', 'Select organization', ...
            'Prompt', char(options.PromptString), ...
            'FontSize', 14, ...
            'Parent', options.Parent);
        if ~ok || isempty(idx)
            error('NDI:CloudDialog:UserCanceled', ...
                'Operation canceled during selection of an organization.');
        end
        organizationID = candidates(idx(1)).id;
        organizationName = candidates(idx(1)).name;
        return;
    end

    % 4. No way to decide.
    error('NDI:Cloud:OrganizationRequired', ...
        ['You belong to %d organizations; specify one with organizationName ', ...
         'or organizationID. Available: %s.'], ...
        numel(candidates), availableList(candidates));
end

function idx = findRequested(organizations, options)
    arguments
        organizations struct
        options (1,1) struct
    end
    if ~isempty(options.organizationName)
        idx = find(strcmp({organizations.name}, options.organizationName));
    else
        idx = find(strcmp({organizations.id}, options.organizationID));
    end
end

function s = describe(organization)
    arguments
        organization (1,1) struct
    end
    if isempty(organization.name)
        s = sprintf('(no name) (%s)', organization.id);
    else
        s = sprintf('"%s" (%s)', organization.name, organization.id);
    end
end

function s = availableList(organizations)
    arguments
        organizations struct
    end
    parts = arrayfun(@describe, organizations, 'UniformOutput', false);
    s = strjoin(parts, ', ');
end
