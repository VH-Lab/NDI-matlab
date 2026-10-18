function [organizationID, organizationName] = selectOrganization(options)
% SELECTORGANIZATION - Choose one of the current user's NDI Cloud organizations by name.
%
%   [ORGANIZATIONID, ORGANIZATIONNAME] = ndi.cloud.ui.dialog.selectOrganization()
%
%   Opens a modal dialog listing, by name, the organizations that the
%   currently authenticated NDI Cloud user belongs to, and returns the
%   chosen organization's id and name. The list comes from
%   ndi.cloud.internal.getOrganizations (cached at login).
%
%   This is the always-interactive form of
%   ndi.cloud.internal.chooseOrganization.
%
%   Name-value options:
%       Parent           - a figure to center the dialog over. Default [].
%       AutoSelectSingle - (logical) when true (default), and only one
%                          organization qualifies, that organization is
%                          returned immediately without showing a dialog. Set
%                          false to always show the dialog.
%       RequireUpload    - (logical) only list organizations in which the user
%                          may create datasets. Default false.
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
%       orgId = ndi.cloud.ui.dialog.selectOrganization('RequireUpload', true);
%
%   See also: ndi.cloud.internal.chooseOrganization,
%             ndi.cloud.internal.getOrganizations,
%             ndi.cloud.ui.dialog.selectCloudDataset,
%             ndi.cloud.ui.dialog.organizationLabels

    arguments
        options.Parent = []
        options.AutoSelectSingle (1,1) logical = true
        options.RequireUpload (1,1) logical = false
        options.PromptString (1,1) string = "Select an organization:"
    end

    [organizationID, organizationName] = ndi.cloud.internal.chooseOrganization( ...
        'Interactive', true, ...
        'AlwaysAsk', ~options.AutoSelectSingle, ...
        'RequireUpload', options.RequireUpload, ...
        'Parent', options.Parent, ...
        'PromptString', options.PromptString);
end
