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
%       element.name                -> `entity.name` ([element name and
%                                      reference stored apart], 2026-10-29;
%                                      before it, `entity.local_identifier`
%                                      only)
%       element.reference           -> what follows the name in
%                                      `entity.local_identifier`
%                                      '<name> | <ref>' (or, migrated before
%                                      2026-10-26, '<name> (ref <ref>)')
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

% ---- built from a migrated element: read it back by id ----------------
% Its fields are what the object was built from, so rebuilding them
% (ndi.vintage.elementFields, five searches) to check them, after a full-
% table search for a v1 element block no migrated element has, only cost
% time: 7 searches per id() call, 172 s for Dab's 606 elements against 5 s
% in v1 (run 42241497254). Jess Haley, 2026-11-06: "Speed can't be slower
% than v1." If the document is gone, the searches below run as before.
if isprop(ndi_element_obj, 'etaDocumentId') && ~isempty(ndi_element_obj.etaDocumentId) ...
        && strcmp(char(ndi_element_obj.etaDocumentId), char(ndi_element_obj.identifier))
    % read by the documents table's key where the session can, with no
    % query to compile (ndi.session/database_read_id)
    if ismethod(E, 'database_read_id')
        byId = E.database_read_id(char(ndi_element_obj.identifier));
        if ~isempty(byId); byId = {byId}; else; byId = {}; end
    else
        byId = E.database_search(ndi.query('base.id', 'exact_string', ...
            char(ndi_element_obj.identifier), ''));
    end
    if isscalar(byId)
        doc = byId{1};
        vintage = 'V_eta';
        return;
    end
end

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
wantClass = class(ndi_element_obj);

% THE OBJECT'S OWN ID FIRST. An element built from its document (every
% element getelements and getprobes return) carries that document's id as
% its identifier, and the migrator keeps the v1 element id on the entity.
% Fetch that one document and accept it when it is this element by the
% same test as the scan below. Only when it is not does the scan run: the
% scan rebuilds every element of the session (ndi.vintage.elementFields),
% so calling id() on each of a session's N elements cost N^2 rebuilds. On
% Dab's migrated session (606 elements) one id() took minutes and the
% corpus equivalence check did not finish in five hours
% (VH-Lab/NDI-matlab#785, run 41761142755).
if ~isempty(ndi_element_obj.identifier)
    % by the documents table's key where the session can (the answer the
    % base.id search gives, ndi.session/database_read_id), else by search
    if ismethod(E, 'database_read_id')
        byId = E.database_read_id(char(ndi_element_obj.identifier));
        if ~isempty(byId); byId = {byId}; else; byId = {}; end
    else
        byId = E.database_search(ndi.query('base.id', 'exact_string', ...
            char(ndi_element_obj.identifier), ''));
    end
    if isscalar(byId) && ndi.vintage.isEtaElement(byId{1}, E) && ...
            isThisElement(ndi.vintage.elementFields(byId{1}, E), ndi_element_obj, wantClass)
        doc = byId{1};
        vintage = 'V_eta';
        return;
    end
end

% Only the entities with an element-class assertion naming this object's
% class can match (isThisElement compares the class); the others are not
% read. The order is the assertions' order, as elementSubjectDocs gives it.
subjects = classCandidates(E, wantClass, ndi_element_obj);
matches = matchingOf(subjects, E, ndi_element_obj, wantClass);
if isempty(matches)
    % none with an assertion: an element recognised by its links alone
    % ([element recognised by its links]), found by its name
    seen = cellfun(@(d) char(d.id()), subjects, 'UniformOutput', false);
    matches = matchingOf(nameCandidates(E, ndi_element_obj.name, seen), E, ...
        ndi_element_obj, wantClass);
end
if numel(matches) > 1
    % RAISED, NOT RESOLVED BY PICKING THE FIRST. The v1 path errors on a
    % duplicate and this path must too, or a migrated session would
    % silently behave differently from the session it was migrated from.
    error('NDI:vintage:tooManyElementDocs', ...
        ['More than one V_eta subject matches the ELEMENT definition ' ...
         '("%s", type "%s", class %s): %d found. An entity migrated ' ...
         'before its name was stored apart is read from ' ...
         'local_identifier alone and can collide -- see ' ...
         'ndi.vintage.elementNameReferenceApart.'], ...
        ndi_element_obj.name, ndi_element_obj.type, wantClass, ...
        numel(matches));
elseif ~isempty(matches)
    doc = matches{1};
    vintage = 'V_eta';
end
end

% ===================== helpers =========================================

function matches = matchingOf(subjects, E, ndi_element_obj, wantClass)
% the candidates that are this element
matches = {};
for i = 1:numel(subjects)
    % The name and reference are read from the entity document itself, as
    % ndi.vintage.elementFields reads them; only an entity whose name and
    % reference match has its other fields rebuilt (five searches). Every
    % entity used to be rebuilt: 4,814 rebuilds for six probes' id() in one
    % Dab getprobes (run 42248853676). Jess Haley, 2026-11-06: "Speed can't
    % be slower than v1."
    [nm, rf] = localNameReference(subjects{i});
    if ~strcmp(nm, ndi_element_obj.name) || ~sameReference(rf, ndi_element_obj.reference)
        continue;
    end
    f = ndi.vintage.elementFields(subjects{i}, E);
    if ~isThisElement(f, ndi_element_obj, wantClass); continue; end
    matches{end+1} = subjects{i}; %#ok<AGROW>
end
end


function tf = isThisElement(f, ndi_element_obj, wantClass)
% do the rebuilt element fields F describe NDI_ELEMENT_OBJ?
tf = strcmp(f.name, ndi_element_obj.name) && strcmp(f.type, ndi_element_obj.type) && ...
    strcmp(f.ndi_element_class, wantClass) && ...
    sameReference(f.reference, ndi_element_obj.reference);
end

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

function [name, reference] = localNameReference(doc)
% the element name and reference, from the entity block alone (as
% ndi.vintage.elementFields reads them)
props = doc.document_properties;
localId = '';
entityName = '';
for blk = {'entity', 'subject'}
    if isfield(props, blk{1}) && isstruct(props.(blk{1})) ...
            && isfield(props.(blk{1}), 'local_identifier')
        localId = props.(blk{1}).local_identifier;
        if isfield(props.(blk{1}), 'name')
            entityName = props.(blk{1}).name;
        end
        break;
    end
end
[name, reference] = ndi.vintage.elementNameReferenceApart(entityName, localId);
end

function docs = classCandidates(E, wantClass, ndi_element_obj)
% the migrated element entities with an `ndi element class` assertion whose
% value is WANTCLASS, in the assertions' (database) order; each candidate's
% first class assertion is checked again by elementFields
docs = {};
% The candidates of WANTCLASS and their names and references are the same
% for every element asked about in one call (ndi.vintage.elementFieldsScope,
% open in getprobes and getelements), so they are read once per call: a
% getprobes that adds probes asks once per new probe (NDI-matlab run
% 42340066168).
key = '';
T = [];
if ndi.vintage.elementFieldsScope('isopen')
    key = ['cc|' char(E.id()) '|' wantClass];
    [T, hit] = ndi.vintage.elementFieldsScope('get', key);
    if ~hit; T = []; end
end
if isempty(T)
    T = candidateTable(E, wantClass);
    if ~isempty(key)
        ndi.vintage.elementFieldsScope('put', key, T);
    end
end
ids = T.ids;
if isempty(ids)
    return;
end
keep = true(1, numel(ids));
for j = find(T.known)
    keep(j) = strcmp(T.names{j}, ndi_element_obj.name) && sameReference(T.refs{j}, ndi_element_obj.reference);
end
ids = ids(keep);
if isempty(ids)
    return;
end
byId = ndi.vintage.docsById(E, ids);
for i = 1:numel(ids)
    d = byId(ids{i});
    if ~isempty(d)
        docs{end+1} = d; %#ok<AGROW>
    end
end
end

function docs = nameCandidates(E, name, known)
% the entities named NAME (`entity.name`) that are not among KNOWN: an
% element recognised by its links with no `ndi element class` assertion
% ([element recognised by its links], Jess Haley 2026-11-10) is found by its
% name, one search, and checked by elementFields like the others (its class
% rebuilt from its links)
docs = {};
if isempty(name)
    return;
end
found = E.database_search(ndi.query('', 'isa', 'entity', '') & ...
    ndi.query('entity.name', 'exact_string', char(name), ''));
for k = 1:numel(found)
    if ~any(strcmp(char(found{k}.id()), known))
        docs{end+1} = found{k}; %#ok<AGROW>
    end
end
end

function T = candidateTable(E, wantClass)
% the ids of the migrated element entities whose class assertion is
% WANTCLASS, in order, and (where the text index answers) each one's name
% and reference (KNOWN)
q = ndi.v2.statementQuery('assertion', 'term') & ...
    ndi.v2.fieldQuery('statement.variable.name', 'exact_string', ...
        ndi.vintage.elementLabel('class'));
% From the indexes where the database can (no document decoded): each class
% assertion's term and entity edge, and each candidate entity's name and
% local identifier; only an entity whose name and reference could match is
% read whole. Else the documents, as before.
vals = [];
edges = [];
if ismethod(E, 'database_search_values') && ismethod(E, 'database_search_edges')
    vals = E.database_search_values(q, {'term.value[*].name'});
    if isstruct(vals)
        edges = E.database_search_edges(q, {'entity_id', 'subject_id'});
    end
end
ids = {};
if isstruct(vals) && isstruct(edges)
    want = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    for k = 1:numel(vals)
        if strcmp(vals(k).values{1}, wantClass)
            want(vals(k).doc_id) = true;
        end
    end
    % each assertion's entity: its first entity_id, else its first subject_id
    % (as ndi.v2.edgeIds reads it)
    firstE = containers.Map('KeyType', 'char', 'ValueType', 'char');
    firstS = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for k = 1:numel(edges)
        d = edges(k).doc_id;
        if strcmp(edges(k).name, 'entity_id') && ~isKey(firstE, d)
            firstE(d) = edges(k).document_id;
        elseif strcmp(edges(k).name, 'subject_id') && ~isKey(firstS, d)
            firstS(d) = edges(k).document_id;
        end
    end
    for k = 1:numel(vals)
        d = vals(k).doc_id;
        if ~isKey(want, d); continue; end
        e = '';
        if isKey(firstE, d); e = firstE(d); elseif isKey(firstS, d); e = firstS(d); end
        if ~isempty(e) && ~any(strcmp(e, ids))
            ids{end+1} = e; %#ok<AGROW>
        end
    end
else
    assertions = E.database_search(q & ...
        ndi.query('term.value.name', 'exact_string', wantClass, ''));
    for i = 1:numel(assertions)
        sid = ndi.v2.edgeIds(ndi.v2.props(assertions{i}), 'entity_id');
        if isempty(sid), continue; end
        if ~any(strcmp(sid{1}, ids))
            ids{end+1} = sid{1}; %#ok<AGROW>
        end
    end
end
if isempty(ids)
    T = struct('ids', {{}}, 'known', false(1, 0), 'names', {{}}, 'refs', {{}});
    return;
end
% the candidates' name and local identifier from the text index, so only
% one whose name and reference could match is read whole
known = false(1, numel(ids));
names = repmat({''}, 1, numel(ids));
refs = cell(1, numel(ids));
for c = 1:200:numel(ids)
    part = c:min(c + 199, numel(ids));
    light = ndi.vintage.valueDocs(E, ndi.v2.anyOf(cellfun(@(i) ndi.query('base.id', ...
        'exact_string', i, ''), ids(part), 'UniformOutput', false)), ...
        {'entity.name', 'entity.local_identifier'}, 'entity');
    if ~iscell(light); break; end
    seen = cellfun(@(d) char(d.id()), light, 'UniformOutput', false);
    for j = part
        hit = find(strcmp(seen, ids{j}), 1);
        if isempty(hit); continue; end   % not found here: read whole below
        [names{j}, refs{j}] = localNameReference(light{hit});
        known(j) = true;
    end
end
T = struct('ids', {ids}, 'known', known, 'names', {names}, 'refs', {refs});
end

