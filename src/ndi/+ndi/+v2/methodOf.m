function m = methodOf(container, p, block)
%METHODOF HOW a statement or relation was done: its method term and settings.
%
%   M = ndi.v2.methodOf(CONTAINER, P, BLOCK) reads the method of the document
%   whose properties are P (BLOCK is the block that declares it:
%   'interaction' for a statement, 'relation' for a relation). did-schema #88
%   (V_eta_method_plan.md, Jess Haley 2026-10-21): the method is ONE block,
%   `method: {term, parameters}`, carried inline OR as a standalone `method`
%   document named by the `method_id` edge -- never both. Both are read: the
%   inline block when present, else the document the edge names (fetched from
%   CONTAINER, an ndi.session / ndi.dataset; [] skips the edge).
%
%   M is a struct:
%     term        the {node, name} term, or [] when none
%     parameters  the settings, a struct array of entries (ndi.v2.entryValue
%                 reads one), or [] when none
%     name        the standalone document's protocol name ('' inline)
%     id          the standalone document's id ('' inline or none)

arguments
    container
    p
    block {mustBeText} = 'interaction'
end

m = struct('term', [], 'parameters', [], 'name', '', 'id', '');
b = ndi.v2.blockOf(p, block, 'method', []);
if ~isstruct(b) || isempty(b)
    ids = ndi.v2.edgeIds(p, 'method_id');
    if isempty(ids) || isempty(container)
        return;
    end
    d = ndi.v2.getDocument(container, ids{1});
    if isempty(d)
        return;
    end
    q = ndi.v2.props(d);
    if ~isfield(q, 'method') || ~isstruct(q.method)
        return;
    end
    b = q.method;
    m.id = ids{1};
    if isfield(b, 'name') && ~isempty(b.name)
        m.name = char(b.name);
    end
end
b = b(1);
if isfield(b, 'term') && isstruct(b.term) && ~isempty(ndi.v2.termName(b.term))
    m.term = b.term;
end
if isfield(b, 'parameters') && ~isempty(b.parameters)
    m.parameters = b.parameters;
end
end
