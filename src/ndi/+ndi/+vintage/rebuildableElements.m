function [docs, left] = rebuildableElements(S, docs)
%REBUILDABLEELEMENTS The v2 element entities whose class can be rebuilt.
%
%   [DOCS, LEFT] = ndi.vintage.rebuildableElements(SESSION, DOCS) keeps, of
%   DOCS (a column cell of ndi.document, as ndi.vintage.elementSubjectDocs
%   returns), those whose `ndi_element_class` ndi.vintage.elementFields can
%   give: rebuilt from the entity type and device kind, or read from an
%   "ndi element class" assertion where one is present. LEFT holds the ids
%   of the others, and a warning (NDI:vintage:elementClassNotRebuilt) names
%   them.
%
%   Decided by Jess Haley, 2026-10-27 [ndi element class not kept]: "an
%   element whose class cannot be rebuilt that way is brought to the team".
%   Such an element (an entity with a recording or a wiring relation whose
%   type has no row in probetype2object.json) is not constructed by
%   getprobes / getelements, which would otherwise stop at it; the warning
%   is how it is brought up. Whether it should be skipped is Proposed (not
%   decided).
%
%   See also ndi.vintage.elementClassOfKind, ndi.session/getprobes.

left = {};
if isempty(docs)
    return;
end
keep = true(size(docs));
for k = 1:numel(docs)
    f = ndi.vintage.elementFields(docs{k}, S);
    if isempty(f.ndi_element_class)
        keep(k) = false;
        left{end+1} = char(docs{k}.id()); %#ok<AGROW>
    end
end
docs = docs(keep);
if ~isempty(left)
    warning('NDI:vintage:elementClassNotRebuilt', ...
        ['%d element(s) recognised by their links have a class that cannot be ' ...
         'rebuilt from their entity type and device kind, and no "ndi element ' ...
         'class" assertion; they are left out ([ndi element class not kept]): %s'], ...
        numel(left), strjoin(left, ', '));
end
end
