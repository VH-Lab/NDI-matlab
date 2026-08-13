function [organizationID, organizationName] = selectOrganization(options)
% SELECTORGANIZATION - Choose one of the current user's NDI Cloud organizations by name.
%
%   [ORGANIZATIONID, ORGANIZATIONNAME] = ndi.cloud.ui.dialog.selectOrganization()
%
%   Retrieves the list of organizations that the currently authenticated NDI
%   Cloud user belongs to (via ndi.cloud.api.users.me) and opens a modal
%   dialog that lets the user choose one by name. Returns the chosen
%   organization's id and name.
%
%   This is the interactive counterpart to the "use the first organization"
%   behaviour of ndi.cloud.authenticate: it lets a user who belongs to more
%   than one organization pick which one to act on.
%
%   Name-value options:
%       Parent           - a figure to center the dialog over. Default [].
%       AutoSelectSingle - (logical) when true (default), and the user belongs
%                          to exactly one organization, that organization is
%                          returned immediately without showing a dialog. Set
%                          false to always show the dialog.
%       SetActive        - (logical) when true, the chosen organization id is
%                          stored in the NDI_CLOUD_ORGANIZATION_ID environment
%                          variable so subsequent NDI Cloud operations act on
%                          it. Default false.
%       PromptString     - (string) prompt shown above the list. Default
%                          "Select an organization:".
%
%   Outputs:
%       ORGANIZATIONID   - (char) the chosen organization's id.
%       ORGANIZATIONNAME - (char) the chosen organization's name (may be empty
%                          if the organization has no name).
%
%   If the user cancels the dialog, this throws NDI:CloudDialog:UserCanceled.
%
%   Example:
%       orgId = ndi.cloud.ui.dialog.selectOrganization('SetActive', true);
%
%   See also: ndi.cloud.ui.dialog.selectCloudDataset,
%             ndi.cloud.ui.dialog.organizationLabels,
%             ndi.cloud.api.users.me, ndi.cloud.authenticate

    arguments
        options.Parent = []
        options.AutoSelectSingle (1,1) logical = true
        options.SetActive (1,1) logical = false
        options.PromptString (1,1) string = "Select an organization:"
    end

    % 1. Retrieve the user's organizations (this authenticates as needed).
    [success, userInfo] = ndi.cloud.api.users.me();
    if ~success
        error('NDI:Cloud:MeFailed', ...
            'Could not retrieve your NDI Cloud user information.');
    end

    orgIds   = userInfo.organizationID;
    orgNames = userInfo.organizationName;

    if isempty(orgIds)
        error('NDI:Cloud:NoOrganizations', ...
            'Your NDI Cloud account does not belong to any organizations.');
    end

    labels = ndi.cloud.ui.dialog.organizationLabels(orgNames, orgIds);

    % 2. Pick one. A lone organization is returned without a dialog unless the
    %    caller asked to always show it.
    if options.AutoSelectSingle && numel(orgIds) == 1
        idx = 1;
    else
        [idx, ok] = ndi.util.ListDialog.choose(labels, ...
            'Title',    'Select organization', ...
            'Prompt',   char(options.PromptString), ...
            'FontSize', 14, ...
            'Parent',   options.Parent);
        if ~ok
            error('NDI:CloudDialog:UserCanceled', ...
                'Operation canceled during selection of an organization.');
        end
    end

    organizationID = char(string(orgIds{idx}));
    if idx <= numel(orgNames)
        organizationName = char(string(orgNames{idx}));
    else
        organizationName = '';
    end

    % 3. Optionally make the chosen organization the active one.
    if options.SetActive
        setenv('NDI_CLOUD_ORGANIZATION_ID', organizationID);
    end
end
