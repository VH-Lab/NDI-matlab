function labels = organizationLabels(organizationName, organizationID)
% ORGANIZATIONLABELS - Build unique display labels for a list of organizations.
%
%   LABELS = ndi.cloud.ui.dialog.organizationLabels(ORGANIZATIONNAME, ORGANIZATIONID)
%
%   Given parallel cell arrays of organization names and ids (as returned by
%   ndi.cloud.api.users.me in its 'organizationName' and 'organizationID'
%   fields), returns a cell array of char display labels suitable for a
%   name-based picker.
%
%   The label for each organization is its name. Two rules keep the labels
%   usable as unique keys in a list dialog (ndi.util.ListDialog matches the
%   selection back to items by string):
%       * An organization with no name falls back to its id.
%       * When a name is shared by more than one organization (or a name
%         collides with another organization's id/label), the organization id
%         is appended in parentheses so every label is distinct.
%
%   Inputs:
%       ORGANIZATIONNAME (cell) - organization names (char/string), parallel
%           to ORGANIZATIONID. May be shorter than ORGANIZATIONID, in which
%           case the missing names are treated as empty.
%       ORGANIZATIONID (cell)   - organization ids (char/string).
%
%   Outputs:
%       LABELS (1,N cell) - one char label per organization, in the input
%           order, all distinct.
%
%   See also: ndi.cloud.ui.dialog.selectOrganization, ndi.cloud.api.users.me,
%             ndi.util.ListDialog

    arguments
        organizationName cell
        organizationID cell
    end

    n = numel(organizationID);
    ids   = cell(1, n);
    names = cell(1, n);
    for i = 1:n
        ids{i} = char(string(organizationID{i}));
        if i <= numel(organizationName)
            names{i} = char(string(organizationName{i}));
        else
            names{i} = '';
        end
    end

    % Base label: the name, or the id when the name is empty.
    base = cell(1, n);
    for i = 1:n
        if isempty(names{i})
            base{i} = ids{i};
        else
            base{i} = names{i};
        end
    end

    % Any base label shared by more than one organization is ambiguous; append
    % the id to every occurrence of it so the labels remain unique keys.
    labels = base;
    for i = 1:n
        if sum(strcmp(base, base{i})) > 1 && ~isempty(ids{i})
            labels{i} = [base{i} '  (' ids{i} ')'];
        end
    end
end
