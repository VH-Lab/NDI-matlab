function docs = elementSubjectDocs(ndi_session_obj, classFilter)
%ELEMENTSUBJECTDOCS The subject documents that used to be elements.
%
%   DOCS = ndi.vintage.elementSubjectDocs(NDI_SESSION_OBJ)
%   DOCS = ndi.vintage.elementSubjectDocs(NDI_SESSION_OBJ, CLASSFILTER)
%
%   Returns a cell array of ndi.document. CLASSFILTER, when given, keeps
%   only those whose MATLAB class name CONTAINS it -- pass 'probe' to get
%   what `getprobes` used to get from
%   `ndi.query('element.ndi_element_class','contains_string','probe')`.
%
%   WHY THIS IS TWO QUERIES AND NOT ONE
%   -----------------------------------
%   V_eta turned one v1 `element` document into a `subject` plus
%   satellites, and the class name -- the thing that says this subject is
%   apparatus and not an animal -- moved into an inbound `term_assertion`.
%   A did.query is evaluated against ONE document at a time and cannot
%   join, so there is no single query that says "subjects that have an
%   assertion". The lookup therefore runs assertion-first:
%
%       1. find term_assertions labelled `ndi element class`
%          (+ optionally whose value contains CLASSFILTER)
%       2. collect their `subject_id`s and fetch those subjects
%
%   Step 1 is a perfectly ordinary single-document query -- the assertion
%   carries both the label and the value -- so the filter runs in the
%   database rather than over everything in MATLAB.
%
%   WHY NOT `isa subject` PLUS A FILTER: because it returns the wrong
%   answer in the dangerous direction. In PRED, 2 elements plus 1 animal
%   migrate to THREE subject documents, so `isa subject` hands back the
%   animal alongside the electrode and the stimulator. Widening a search
%   raises no error; the caller just acts on the extra rows.
%
%   AN ELEMENT WITH NO CLASS NAME IS INVISIBLE HERE, and that is a real
%   limit rather than an oversight. The migrator writes the assertion only
%   `if ~isempty(ndiClass)` (+migrators_j/element.m:104). NDI's own writer
%   always sets it (`element.m:543` writes `class(obj)`, with 'ndi.element'
%   as the floor at `:40`), so anything NDI wrote is found; a document from
%   other tooling with no class name is not, and cannot be, because nothing
%   about it says it was ever an element.
%
%   See also: ndi.vintage.elementSubjectIds, ndi.vintage.elementLabel,
%             ndi.vintage.objectClass,
%             ndi.session/getelements, ndi.session/getprobes.

arguments
    ndi_session_obj
    classFilter (1,:) char = ''
end

% A COLUMN, so callers can stack it under a column of v1 hits
% (ndi.session/getelements, ndi.session/getprobes); see
% ndi.unittest.vintage.TestElementDocsBothVintages.
docs = cell(0, 1);

[ids, label] = ndi.vintage.elementSubjectIds(ndi_session_obj, classFilter);

for i = 1:numel(ids)
    hit = ndi_session_obj.database_search( ...
        ndi.query('base.id', 'exact_string', ids{i}, ''));
    if numel(hit) ~= 1
        error('NDI:vintage:elementSubjectNotFound', ...
            ['a "%s" assertion names subject %s and %d document(s) match; ' ...
             'the migrator preserves the element id onto the subject, so ' ...
             'this edge should always resolve'], label, ids{i}, numel(hit));
    end
    docs{end+1, 1} = hit{1}; %#ok<AGROW>
end
end
