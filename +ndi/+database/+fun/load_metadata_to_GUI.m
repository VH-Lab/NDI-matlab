function metadata = load_metadata_to_GUI(s)
%LOAD_METADATA_TO_GUI Summary of this function goes here
%   Detailed explanation goes here
% fig = app.UIFigure;
% ud = fig.UserData;

% Initialize an empty cell array to store matching elements
%% check if the user filled in authors
Authors = {};

% Iterate through the struct array
for i = 1:numel(s)
    % Check if the "matlab_type" field matches the specified value
    if isfield(s(i), 'matlab_type') && strcmp(s(i).matlab_type, 'openminds.core.actors.Person')
        % If it's a match, add the element to the cell array
        Authors{end+1} = s(i).fields;
    end
end

AuthorsArray = [];
ndi_ids = {s.ndi_id};
givenName = {};
familyName = {};
contactInformation = {};
digitalIdentifier = {};
RORID = {};
% Check if any matching elements were found
if ~isempty(Authors)
    % Convert the cell array to a struct array
    AuthorsArray = [Authors{:}];
    for i = 1:numel(AuthorsArray)
        givenName{i} = AuthorsArray(i).givenName;
        familyName{i} = AuthorsArray(i).familyName;

        contactInformation{i} = [];
        contactInformation_id = strrep(AuthorsArray(i).contactInformation, 'ndi://', '');
        index = find(strcmp(ndi_ids, contactInformation_id));
        if ~isempty(index)
            contactInformation{i} = s(index).fields.email;
        end

        digitalIdentifier{i} = [];
        digitalIdentifier_id = strrep(AuthorsArray(i).digitalIdentifier, 'ndi://', '');
        index = find(strcmp(ndi_ids, digitalIdentifier_id));
        if ~isempty(index)
            digitalIdentifier{i} = s(index).fields.identifier;
        end
        
        affiliations = AuthorsArray(i).affiliation;
        RORID{i} = cell(1, numel(affiliations));
        for j = 1:numel(affiliations)
            affiliation_id = strrep(affiliations(j), 'ndi://', '');
            index = find(strcmp(ndi_ids, affiliation_id));
            if ~isempty(index)
                organization = s(index).fields.memberOf;
                organization_id = strrep(organization, 'ndi://', '');
                index = find(strcmp(ndi_ids, organization_id));
                if ~isempty(index)
                    ror_ndi_id = s(index).fields.digitalIdentifier;
                    ror_ndi_id = strrep(ror_ndi_id, 'ndi://', '');
                    index = find(strcmp(ndi_ids, ror_ndi_id));
                    if ~isempty(index)
                        RORID{i}{j} = s(index).fields.identifier;
                    end
                end

            end
        end
    end

end

metadata.givenName = givenName;
metadata.familyName = familyName;
metadata.contactInformation = contactInformation;
metadata.digitalIdentifier = digitalIdentifier;
metadata.RORID = RORID;
end

