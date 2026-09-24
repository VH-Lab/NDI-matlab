function [doc, vintage] = elementDoc(ndi_element_obj)
%ELEMENTDOC The document that IS this element, in whichever vintage exists.
%
%   [DOC, VINTAGE] = ndi.vintage.elementDoc(NDI_ELEMENT_OBJ)
%
%   DOC is an ndi.document, or [] when the element has no document in this
%   session (a legitimate state -- `ndi.element` constructs an object before
%   it is added to a database). VINTAGE is 'v1', 'V_eta' or ''.
%
%   ---------------------------------------------------------------------
%   WHY `searchquery` COULD NOT SIMPLY BE FIXED
%   ---------------------------------------------------------------------
%   `ndi.element.searchquery` matches FOUR fields of the v1 `element`
%   block, and a migrated document has none of them:
%
%       element.name                -> `subject.local_identifier`, COMBINED
%                                      with `reference` as '%s (ref %s)'
%       element.reference           -> the same combined field
%       element.type                -> an inbound `term_assertion`
%       element.ndi_element_class   -> an inbound `term_assertion`
%
%   Two of the four moved onto OTHER DOCUMENTS. A did.query is evaluated
%   against one document at a time and cannot join, so there is no query
%   -- widened, OR-ed or otherwise -- that finds a migrated element by its
%   name and class. That is the same wall `ndi.vintage.isaQuery` hits for
%   `element` (`isa_bridges = false`), and the answer is the same: a
%   two-step lookup, here rather than in a query object.
%
%   ---------------------------------------------------------------------
%   THE FAILURE THIS FIXES, AND IT IS THE EIGHTH FRAME OF ONE BUG
%   ---------------------------------------------------------------------
%   `load_element_doc` -> `searchquery` -> nothing. Then
%   `load_all_element_docs` returns `{}` on its own `if
%   ~isempty(element_doc)` guard, and `loadaddedepochs` iterates over an
%   empty list. Measured on migrated 20211116, e2e run 74 -- AFTER the
%   added-epoch reader itself was fixed and its 11 unit tests were green:
%
%       DENOMINATOR: 1220 source body(ies) read; 21 derived
%                    (direct==false) element(s); 12 distinct epoch id(s)
%       MEASURED: 21 derived element object(s) driven of 23 returned;
%                 0 returned a non-empty epoch table; 0 ERRORED
%
%   So the reader was correct and NOTHING REACHED IT. Worth stating plainly
%   because it is the shape that wasted the round trip: a green unit suite
%   over hand-built documents says the function is right, and says nothing
%   about whether anything calls it with real input.
%
%   `getelements` was unaffected throughout -- it goes through
%   `ndi.vintage.elementSubjectDocs`, which never asks `searchquery`. So
%   the session could hand you 23 element objects, every one of which
%   could not find its own document. Two paths to the same object, one
%   ported and one not.
%
%   ---------------------------------------------------------------------
%   v1 IS TRIED FIRST AND IS BYTE-FOR-BYTE UNCHANGED
%   ---------------------------------------------------------------------
%   NDI still WRITES v1, so the v1 query must keep working exactly as it
%   did; the V_eta lookup is a FALLBACK reached only when it finds nothing.
%   An element that is simply not in the database yet reaches the fallback
%   too, finds nothing there either, and gets [] -- the same answer as
%   before, at the cost of one extra query.
%
%   THE FALLBACK MATCHES THE SAME FOUR FIELDS the v1 query does, taken from
%   `ndi.vintage.elementFields`, so the two paths accept the same elements.
%   Matching fewer would make a migrated session return an element the v1
%   path would have refused.
%
%   See also: ndi.vintage.elementSubjectDocs, ndi.vintage.elementFields,
%             ndi.element/load_element_doc, ndi.vintage.isaQuery.

arguments
    ndi_element_obj
end

doc = [];
vintage = '';

E = ndi_element_obj.session;

% ---- v1: the original query, unchanged --------------------------------
hits = E.database_search(ndi_element_obj.searchquery());
if numel(hits) > 1
    error('NDI:vintage:tooManyElementDocs', ...
        ['More than one v1 document matches the ELEMENT definition ' ...
         '(%d). This should not happen.'], numel(hits));
elseif ~isempty(hits)
    doc = hits{1};
    vintage = 'v1';
    return;
end

% ---- V_eta: assertion-first, then match the same four fields ----------
subjects = ndi.vintage.elementSubjectDocs(E);
wantClass = class(ndi_element_obj);
matches = {};
for i = 1:numel(subjects)
    f = ndi.vintage.elementFields(subjects{i}, E);
    if ~strcmp(f.name, ndi_element_obj.name); continue; end
    if ~strcmp(f.type, ndi_element_obj.type); continue; end
    if ~strcmp(f.ndi_element_class, wantClass); continue; end
    if ~sameReference(f.reference, ndi_element_obj.reference); continue; end
    matches{end+1} = subjects{i}; %#ok<AGROW>
end

if numel(matches) > 1
    % RAISED, NOT RESOLVED BY PICKING THE FIRST. The v1 path errors on a
    % duplicate and this path must too, or a migrated session would
    % silently behave differently from the session it was migrated from.
    error('NDI:vintage:tooManyElementDocs', ...
        ['More than one V_eta subject matches the ELEMENT definition ' ...
         '("%s", type "%s", class %s): %d found. The name/reference ' ...
         'split is not escaped, so a name ending in " (ref X)" can ' ...
         'collide -- see ndi.vintage.elementFields.'], ...
        ndi_element_obj.name, ndi_element_obj.type, wantClass, ...
        numel(matches));
elseif ~isempty(matches)
    doc = matches{1};
    vintage = 'V_eta';
end
end

% ===================== helpers =========================================

function tf = sameReference(a, b)
%SAMEREFERENCE v1 compared `element.reference` with `exact_number`.
%   `elementFields` restores a number when the stored text is one and keeps
%   the text when it is not, so both sides can be either. Compared as
%   NUMBERS when both are numeric and as text otherwise; an element with no
%   reference (the migrator writes a bare name) matches another with none.
if isempty(a) && isempty(b)
    tf = true;
    return;
end
if isempty(a) || isempty(b)
    tf = false;
    return;
end
if isnumeric(a) && isnumeric(b)
    tf = isequal(double(a), double(b));
    return;
end
tf = strcmp(char(string(a)), char(string(b)));
end
