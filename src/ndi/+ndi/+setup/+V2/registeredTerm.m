function t = registeredTerm(node, name)
%REGISTEREDTERM A term as DID-schema's term registry writes it.
%
%   T = ndi.setup.V2.registeredTerm(NODE, NAME) returns did2.build.term with
%   the registry's node and name for the term NODE names (matched by its CURIE
%   key) or, with NODE empty, for the term registered under NAME (ignoring
%   case). Tenet T19 (DID-schema V_eta_term_registry_plan.md): a term already
%   used in an NDI dataset is reused exactly, and did2.build refuses one the
%   registry does not hold, so a writer that has only a field name
%   ('accessibility', 'species') takes the registry's spelling here.
%
%   When the schema in use has no registry (did-schema main), or the registry
%   does not hold the term, T is the term as given: did2.build then decides
%   (a schema with a registry refuses it, naming it).
%
%   See also did2.schema.termIndex, ndi.setup.V2.entityDocuments.

arguments
    node {mustBeText}
    name {mustBeText} = ''
end

node = strtrim(char(node));
name = strtrim(char(name));
t = did2.build.term(node, name);
if isempty(which('did2.schema.termIndex'))
    return;
end
ix = did2.schema.termIndex();
if ~ix.present
    return;
end
if ~isempty(node)
    key = did2.schema.curieKey(node);
    if isKey(ix.byNode, key)
        e = ix.byNode(key);
        t = did2.build.term(e.node, e.name);
    end
elseif isKey(ix.byName, lower(name))
    e = ix.byName(lower(name));
    t = did2.build.term(e.node, e.name);
end
end
