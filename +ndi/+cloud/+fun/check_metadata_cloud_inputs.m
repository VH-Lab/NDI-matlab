function is_valid = check_metadata_cloud_inputs(S)
%CHECK_METADATA_CLOUD_INPUTS - check if the input is valid
%   IS_VALID = ndi.cloud.fun.CHECK_METADATA_CLOUD_INPUTS(S)
%
% Inputs:
%   S - a structure with fields 'DatasetFullName', 'DatasetShortName', 'Author'
%                               'Funding', 'Description', 'License', 'Subjects'
%       'Author' is a structure with fields 'givenName', 'familyName', 'authorRole', 'digitalIdentifier'
%       'digitalIdentifier' is a structure with field 'identifier'
%       'Funding' is a structure with field 'funder'
%       'Subjects' is an instance from ndi.database.metadata_app.class.Subject class
%
% Outputs:
%   IS_VALID - 1 if the input is valid, 0 otherwise

required_fields = {'DatasetFullName', 'DatasetShortName', 'Author', ...
                      'Funding', 'Description', 'License', 'Subjects'};
author_fields = {'givenName', 'familyName', 'authorRole', 'digitalIdentifier'};
funding_fields = {'funder'};

is_valid = all(isfield(S, required_fields));
if is_valid && isfield(S, 'Author')
    is_valid = is_valid && all(isfield(S.Author, author_fields));
    if is_valid
        identifier = S.Author.digitalIdentifier;
        is_valid = is_valid && isfield(identifier, 'identifier');
    end
               
end
if is_valid && isfield(S, 'Funding')
    is_valid = is_valid && all(isfield(S.Funding, funding_fields));
end
% check if the Subjects is an instance of ndi.database.metadata_app.class.Subject
if is_valid && isfield(S, 'Subjects')
    is_valid = is_valid && isa(S.Subjects, 'ndi.database.metadata_app.class.Subject');
end
end

