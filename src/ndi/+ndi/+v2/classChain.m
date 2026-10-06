function chain = classChain(p)
%CLASSCHAIN Every class a document IS: its own and all its superclasses.
%
%   CHAIN = ndi.v2.classChain(P) returns a cellstr, the document's class
%   first. P is document properties (ndi.v2.props). The chain comes from the
%   V2 schema (did2.schema.cache); a class the schema does not know (a v1
%   document) falls back to the superclasses the document itself lists.
%
%   See also ndi.v2.directParents, ndi.statement.fromDocument.

name = char(p.document_class.class_name);
chain = {name};
try
    chain = [{name}, reshape(did2.schema.cache.shared().superclasses(name), 1, [])];
    return;
catch
end
if isfield(p.document_class, 'superclasses')
    sc = p.document_class.superclasses;
    if isstruct(sc), sc = num2cell(sc); end
    for k = 1:numel(sc)
        if isstruct(sc{k}) && isfield(sc{k}, 'class_name')
            chain{end+1} = char(sc{k}.class_name); %#ok<AGROW>
        end
    end
end
end
