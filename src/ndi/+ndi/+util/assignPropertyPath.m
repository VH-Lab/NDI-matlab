function s = assignPropertyPath(s, propertyPath, value)
% ASSIGNPROPERTYPATH - safely assign s.<propertyPath> = value
%
%   S = ndi.util.assignPropertyPath(S, PROPERTYPATH, VALUE)
%
%   Assigns VALUE to the nested field of struct S named by the dotted
%   PROPERTYPATH (e.g. 'base.name' sets S.base.name = VALUE). Intermediate
%   structs are created as needed (this is the functional form of
%   S.a.b.c = VALUE), for paths of any depth.
%
%   This replaces eval-based property assignment such as
%   eval(['s.' name '=value']): building and evaluating that string lets a
%   crafted property name (read from a document or passed by a caller)
%   execute arbitrary code. Here every path segment must be a valid field
%   name (isvarname) or an error is raised, and the assignment is performed
%   with subsasgn, which cannot execute code.
%
%   See also: ndi.util.getfieldpath, subsasgn, isvarname

    parts = strsplit(char(propertyPath), '.');
    for p = 1:numel(parts)
        if ~isvarname(parts{p})
            error('ndi:util:assignPropertyPath:invalidPropertyName', ...
                'Invalid property name "%s".', char(propertyPath));
        end
    end
    subs = struct('type', repmat({'.'}, 1, numel(parts)), ...
                  'subs', parts);
    s = subsasgn(s, subs, value);
end % assignPropertyPath()
