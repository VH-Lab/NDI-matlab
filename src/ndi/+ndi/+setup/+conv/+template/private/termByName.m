function t = termByName(name)
%TERMBYNAME A term, looked up by its name in DID-schema's term registry.
%
%   T = termByName(NAME) returns ndi.setup.V2.registeredTerm('', NAME): the
%   registry's node and name for the term registered under NAME (case is
%   ignored). The import's code and spec name terms; the registry decides
%   their nodes, so no node is ever typed into an importer (tenet T19: a term
%   already used in an NDI dataset is reused exactly).
%
%   A NAME the registry does not hold comes back as a term with no node.
%   did2.build refuses it, or -- as import_V2 builds -- collects it, and
%   import_V2 then lists every such term and writes nothing. To add one, see
%   "Adding terms" in Using_V2.md.

arguments
    name {mustBeTextScalar, mustBeNonzeroLengthText}
end
t = ndi.setup.V2.registeredTerm('', char(name));
end
