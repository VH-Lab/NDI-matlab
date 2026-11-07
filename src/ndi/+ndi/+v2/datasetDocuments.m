function [docs, reference] = datasetDocuments(database)
%DATASETDOCUMENTS The `dataset` documents in a database, without reference Data Sets.
%
%   [DOCS, REFERENCE] = ndi.v2.datasetDocuments(DATABASE) searches DATABASE
%   (an ndi.database, searched without a session scope) for the documents of
%   kind `dataset` (an `entity` of type dataset, NCIT:C47824 "Data Set", or a
%   pre-#88 `dataset` document) and returns them as a cell of ndi.document,
%   leaving out every REFERENCE dataset. REFERENCE is a cellstr of the ids
%   left out.
%
%   A reference dataset is a Data Set entity something was derived from
%   (`derived_from`), that no document names as its session and nothing is
%   `included_in`, such as a migrated gene list's genome annotation or
%   assembly (Decided by Jess Haley, 2026-11-07, did-schema
%   did_v2_go_forward_class_audit.md [gene-list history entities]). The rule
%   is ndi.v2.referenceDatasets, the one DID-matlab's
%   did2.convert.migrationRecord applies (#420). This function reads the
%   documents the rule needs from DATABASE: the dataset documents, the
%   relations whose parent each one is, and, for a candidate, the documents
%   stored with it (base.session_id, which a did2 database answers from the
%   field or the edge).
%
%   See also ndi.v2.referenceDatasets, ndi.v2.datasetSessions, ndi.dataset.dir.

arguments
    database
end

docs = database.search(ndi.v2.isaQuery('dataset'));
docs = docs(cellfun(@(d) strcmp(ndi.v2.kindOf(d.document_properties), 'dataset'), docs));
reference = {};
if isempty(docs)
    return;
end
ids = cellfun(@(d) char(d.id()), docs, 'UniformOutput', false);
propsOf = @(c) reshape(cellfun(@(d) d.document_properties, c, 'UniformOutput', false), 1, []);
evidence = propsOf(docs);
for k = 1:numel(ids)
    rels = database.search(ndi.query('', 'isa', 'directed_relation', '') & ...
        ndi.query('', 'depends_on', 'parent_id', ids{k}));
    evidence = [evidence, propsOf(rels)]; %#ok<AGROW>
end
candidates = ndi.v2.referenceDatasets(evidence);
if isempty(candidates)
    return;
end
for k = 1:numel(candidates)
    stored = database.search(ndi.query('base.session_id', 'exact_string', candidates{k}, ''));
    evidence = [evidence, propsOf(stored)]; %#ok<AGROW>
end
reference = ndi.v2.referenceDatasets(evidence);
docs = docs(~ismember(ids, reference));
end
