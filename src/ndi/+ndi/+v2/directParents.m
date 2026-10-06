function parents = directParents(className)
%DIRECTPARENTS The classes CLASSNAME names as its own superclasses (V2 schema).
%
%   PARENTS = ndi.v2.directParents(CLASSNAME) returns a cellstr; empty when
%   the schema does not know the class.

parents = {};
try
    s = did2.schema.cache.shared().getClass(className);
catch
    return;
end
if ~isfield(s, 'document_class') || ~isfield(s.document_class, 'superclasses')
    return;
end
sc = s.document_class.superclasses;
if isstruct(sc), sc = num2cell(sc); end
for k = 1:numel(sc)
    if isstruct(sc{k}) && isfield(sc{k}, 'class_name')
        parents{end+1} = char(sc{k}.class_name); %#ok<AGROW>
    end
end
end
