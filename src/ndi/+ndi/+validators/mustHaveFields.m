function mustHaveFields(s, fields)
% MUSTHAVEFIELDS - Validate that a structure has specific fields
%
% NDI.VALIDATORS.MUSTHAVEFIELDS(S, FIELDS)
%
% Validates that the structure S has all of the fields specified in the cell array of strings FIELDS.
%
% If S is missing any fields, an error is thrown.
%

arguments
    s (1,1) struct
    fields (1,:) cell
end

missing_fields = setdiff(fields, fieldnames(s));
if ~isempty(missing_fields)
    error('ndi:validators:mustHaveFields:MissingFields', ['Structure is missing fields: ' strjoin(missing_fields, ', ')]);
end

end
