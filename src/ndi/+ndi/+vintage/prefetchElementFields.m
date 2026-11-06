function n = prefetchElementFields(S, docs)
%PREFETCHELEMENTFIELDS Read many migrated elements' fields in five searches.
%
%   N = ndi.vintage.prefetchElementFields(SESSION, DOCS) reads, for every
%   migrated element entity in DOCS (a cell of ndi.document; v1 documents
%   and documents that are not entities are skipped), what
%   ndi.vintage.elementFields reads for one element with five searches --
%   its type and class assertions, its `derived_from` relation, the first
%   observation made with it, its `observes` relation -- with ONE search per
%   kind for all of them (the edge lists go through ndi.vintage.edgeIn, one
%   SQL `IN`). Each element's fields are then built from its share of the
%   answers by ndi.vintage.elementFields itself, and kept in the call's
%   cache (ndi.vintage.elementFieldsScope) with its class assertions, so
%   ndi.vintage.elementFields, ndi.vintage.isEtaElement and
%   ndi.vintage.objectClass answer from there. N is the number of elements
%   read.
%
%   It does nothing (N = 0) unless a scope is open: outside a scope there is
%   nowhere to keep the answers. The answers are the same as the searches
%   one element at a time: each search returns its documents in the
%   database's order, and an element's share keeps that order, so "the
%   first observation" is the same document.
%
%   Jess Haley, 2026-11-06: "Speed can't be slower than v1. We need to
%   match or beat."
%
%   See also ndi.vintage.elementFields, ndi.vintage.elementFieldsScope.

n = 0;
if isempty(docs) || ~ndi.vintage.elementFieldsScope('isopen')
    return;
end
if ~iscell(docs)
    docs = num2cell(docs);
end
sid = char(S.id());

% the entity documents not already in the cache
ids = {};
keep = {};
for k = 1:numel(docs)
    d = docs{k};
    if isempty(d); continue; end
    p = d.document_properties;
    if ~isfield(p, 'document_class') || ~strcmp(char(p.document_class.class_name), 'entity')
        continue;
    end
    id = char(p.base.id);
    [~, hit] = ndi.vintage.elementFieldsScope('get', ['f|' sid '|' id]);
    if hit || any(strcmp(ids, id))
        continue;
    end
    ids{end+1} = id; %#ok<AGROW>
    keep{end+1} = d; %#ok<AGROW>
end
if isempty(ids)
    return;
end

classLabel = ndi.vintage.elementLabel('class');
kindVar = ndi.vintage.equipmentTypeVariable();
about = ndi.vintage.edgeIn('entity_id', ids) | ndi.vintage.edgeIn('subject_id', ids);

classQuery = ndi.v2.statementQuery('assertion', 'term') & ...
    ndi.v2.fieldQuery('statement.variable.name', 'exact_string', classLabel) & about;
typeQuery = ndi.v2.statementQuery('assertion', 'term') & ...
    (ndi.v2.fieldQuery('statement.variable.name', 'exact_string', ...
        ndi.vintage.elementLabel('type')) | ...
     ndi.v2.fieldQuery('statement.variable.node', 'exact_string', kindVar.node) | ...
     ndi.v2.fieldQuery('statement.variable.name', 'exact_string', kindVar.name)) & about;
% The assertions are read for four short texts and their entity edge: as
% light documents built from the database's text and edge indexes where it
% can (no document decoded), else the documents themselves, as before.
classDocs = lightAssertions(S, classQuery);
typeDocs = lightAssertions(S, typeQuery);
children = ndi.vintage.edgeIn('child_id', ids) | ndi.vintage.edgeIn('child', ids);
derivedDocs = S.database_search(ndi.query('', 'isa', 'directed_relation', '') & ...
    ndi.v2.vocabQuery('directed_relation.relation', 'relation', 'derived_from') & children);
observesDocs = S.database_search(ndi.query('', 'isa', 'directed_relation', '') & ...
    ndi.v2.vocabQuery('directed_relation.relation', 'relation', 'observes') & children);
% The observations are only asked which entity the FIRST one made with each
% element is about: read as edges where the database can (no document
% decoded; on Dab about 3,900 observations for 606 elements), else as
% documents, as before.
obsQuery = ndi.v2.isaQuery('observation') & ndi.vintage.edgeIn('instrument_id', ids);
obsEdges = [];
if ismethod(S, 'database_search_edges')
    obsEdges = S.database_search_edges(obsQuery, {'instrument_id', 'entity_id'});
end
observationDocs = {};
if ~isstruct(obsEdges)
    observationDocs = S.database_search(obsQuery);
end

byClass = groupBy(classDocs, {'entity_id', 'subject_id'}, ids);
byType = groupBy(typeDocs, {'entity_id', 'subject_id'}, ids);
byDerived = groupBy(derivedDocs, {'child_id', 'child'}, ids);
byObserves = groupBy(observesDocs, {'child_id', 'child'}, ids);
if isstruct(obsEdges)
    firstObs = firstObservationOf(obsEdges, ids);
else
    byObservation = groupBy(observationDocs, {'instrument_id'}, ids);
end

for k = 1:numel(ids)
    pieces = struct('classDocs', {byClass(ids{k})}, 'typeDocs', {byType(ids{k})}, ...
        'derivedDocs', {byDerived(ids{k})}, 'observesDocs', {byObserves(ids{k})});
    if isstruct(obsEdges)
        pieces.observationSpecimen = firstObs(ids{k});   % struct(found, entity)
    else
        pieces.observationDocs = byObservation(ids{k});
    end
    ndi.vintage.elementFields(keep{k}, S, pieces);   % builds and caches the fields
    cls = byClass(ids{k});
    v = '';
    if ~isempty(cls)
        p = cls{1}.document_properties;
        if isfield(p, 'term') && isstruct(p.term) && isfield(p.term, 'value') ...
                && isfield(p.term.value, 'name')
            v = p.term.value.name;
        end
    end
    ndi.vintage.elementFieldsScope('put', ['c|' sid '|' ids{k}], ...
        struct('count', numel(cls), 'value', v));
end
n = numel(ids);
end

function m = groupBy(found, edgeNames, ids)
% each id's documents among FOUND (in FOUND's order) whose edge, by any of
% EDGENAMES, names it; a document naming an id by two edges counts once
m = containers.Map(ids, repmat({{}}, 1, numel(ids)));
for i = 1:numel(found)
    targets = {};
    for e = 1:numel(edgeNames)
        targets = [targets, ndi.vintage.edgeTargets(found{i}, edgeNames{e})]; %#ok<AGROW>
    end
    targets = unique(targets, 'stable');
    for t = 1:numel(targets)
        if isKey(m, targets{t})
            m(targets{t}) = [m(targets{t}), found(i)];
        end
    end
end
end

function m = firstObservationOf(edges, ids)
% for each id: whether an observation names it as its instrument, and the
% first `entity_id` of the FIRST such observation (in the database's order,
% as the search returns them), as ndi.vintage.elementFields reads it
m = containers.Map(ids, repmat({struct('found', false, 'entity', '')}, 1, numel(ids)));
% the edges of each document, in order
docOrder = {};
instr = containers.Map('KeyType', 'char', 'ValueType', 'any');
ent = containers.Map('KeyType', 'char', 'ValueType', 'char');
for k = 1:numel(edges)
    d = edges(k).doc_id;
    if ~isKey(instr, d)
        instr(d) = {};
        docOrder{end+1} = d; %#ok<AGROW>
    end
    switch edges(k).name
        case 'instrument_id'
            instr(d) = [instr(d), {edges(k).document_id}];
        case 'entity_id'
            if ~isKey(ent, d)
                ent(d) = edges(k).document_id;
            end
    end
end
for k = 1:numel(docOrder)
    d = docOrder{k};
    targets = instr(d);
    e = '';
    if isKey(ent, d); e = ent(d); end
    for t = 1:numel(targets)
        if isKey(m, targets{t}) && ~m(targets{t}).found
            m(targets{t}) = struct('found', true, 'entity', e);
        end
    end
end
end

function docs = lightAssertions(S, q)
% the term assertions Q matches, in the database's order: light ndi.documents
% holding statement.variable.{node,name}, term.value.{node,name} and their
% entity_id / subject_id edges (all elementFields, isEtaElement and
% objectClass read of them), or the full documents where the database
% cannot answer from its indexes
% term.value is declared an array: its [*] paths give the FIRST element's
% text, which is the term.value(1) elementTypeOf and classValueOf read
paths = {'statement.variable.node', 'statement.variable.name', ...
    'term.value[*].node', 'term.value[*].name'};
vals = [];
edges = [];
if ismethod(S, 'database_search_values') && ismethod(S, 'database_search_edges')
    vals = S.database_search_values(q, paths);
    if isstruct(vals)
        edges = S.database_search_edges(q, {'entity_id', 'subject_id'});
    end
end
if ~isstruct(vals) || ~isstruct(edges)
    docs = S.database_search(q);
    return;
end
byDoc = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(edges)
    d = edges(k).doc_id;
    e = struct('name', edges(k).name, 'value', edges(k).document_id);
    if isKey(byDoc, d)
        byDoc(d) = [byDoc(d), e];
    else
        byDoc(d) = e;
    end
end
docs = cell(1, numel(vals));
for k = 1:numel(vals)
    v = vals(k).values;
    dep = struct('name', {}, 'value', {});
    if isKey(byDoc, vals(k).doc_id)
        dep = byDoc(vals(k).doc_id);
    end
    p = struct('base', struct('id', vals(k).doc_id), ...
        'document_class', struct('class_name', 'assertion'), ...
        'statement', struct('variable', struct('node', v{1}, 'name', v{2})), ...
        'term', struct('value', struct('node', v{3}, 'name', v{4})), ...
        'depends_on', dep);
    docs{k} = ndi.document(p);
end
end
