function value = getfieldpath(s, propertyPath)
% GETFIELDPATH - safely read a nested struct field named by a dotted path
%
%   VALUE = ndi.fun.getfieldpath(S, PROPERTYPATH)
%
%   Returns the value of the nested field of struct S named by the dotted
%   PROPERTYPATH (e.g. 'document_class.property_list_name' returns
%   S.document_class.property_list_name).
%
%   This replaces eval(['s.' name]) / eval(strcat('s.', name)) when NAME is
%   derived from a document or other data: building and evaluating such a
%   string lets a crafted property name execute arbitrary code. Here every
%   path segment must be a valid field name (isvarname) or an error is
%   raised, and the read is performed with getfield, which cannot execute
%   code.
%
%   See also: ndi.document.assignPropertyPath, getfield

    parts = strsplit(char(propertyPath), '.');
    for p = 1:numel(parts)
        if ~isvarname(parts{p})
            error('ndi:fun:getfieldpath:invalidPropertyName', ...
                'Invalid property name "%s".', char(propertyPath));
        end
    end
    value = getfield(s, parts{:}); %#ok<GFLD>
end
