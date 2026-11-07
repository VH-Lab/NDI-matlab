classdef TestReferenceDataSet < matlab.unittest.TestCase
%TESTREFERENCEDATASET A reference Data Set is not the dataset.
%
%   Since DID-matlab #420 (180bc8cc) the generic migration turns a v1
%   geneList's annotation_source and genome_assembly into minimal `entity`
%   documents of type Data Set (NCIT:C47824), chained from the gene-list term
%   by `derived_from` (prov:wasDerivedFrom) relations (Decided by Jess Haley,
%   2026-11-07, did-schema did_v2_go_forward_class_audit.md [gene-list
%   history entities]). Those are reference data, not the dataset the
%   documents belong to. did2.convert.migrationRecord skips a Data Set that
%   something was derived from, that no document names as its session_id and
%   that nothing is included_in; ndi.v2.referenceDatasets is the same rule
%   here, and these use it:
%     - ndi.migrate.internal.datasetScope (where the shared-entity passes put
%       dataset-level entities);
%     - the dataset census of ndi.migrate.local (its datasetLayerCensus, a
%       local function: it counts what ndi.v2.referenceDatasets returns as
%       `reference_datasets`, not as `dataset_entities`);
%     - ndi.v2.datasetSessions (which `dataset` document a dataset's sessions
%       are filed under): ndi.unittest.setup.V2.TestReferenceDataSetSessions,
%       which writes a dataset and so needs DID-matlab V2 and a did-schema
%       set (run-tests.yml runs it).
%
%   The fixture, the shapes DID-matlab +migrators_j/gene_list.m and
%   migrationRecord read: a dataset entity (its id is the dataset's session
%   id), a session `included_in` it, a gene-list `term` stored with the
%   session, a Data Set "GRCm39" stored with the session, and the term
%   `derived_from` that Data Set.
%
%   Pure struct logic: no database, schema or DID-matlab needed.
%
%   Run with:  runtests('ndi.unittest.migrate.TestReferenceDataSet')

    methods (Test)

        % ====================================================== the rule

        function testTheRuleFindsTheReferenceOnly(testCase)
            [docs, id] = fixture();
            testCase.verifyEqual(ndi.v2.referenceDatasets(docs), {id.reference});
        end

        function testADataSetSomethingIsStoredWithIsNotAReference(testCase)
            % a document naming it as its session anchors it, as in
            % migrationRecord
            [docs, id] = fixture();
            docs{end+1} = termDoc('stored with the reference', id.reference);
            testCase.verifyEmpty(ndi.v2.referenceDatasets(docs));
        end

        function testADataSetSomethingIsIncludedInIsNotAReference(testCase)
            [docs, id] = fixture();
            docs{end+1} = relationDoc(id.session, id.reference, includedIn(), id.session);
            testCase.verifyEmpty(ndi.v2.referenceDatasets(docs));
        end

        function testTheRealDatasetIsNeverAReference(testCase)
            % even when something is derived from it, its own documents name it
            [docs, id] = fixture();
            docs{end+1} = relationDoc(id.term, id.dataset, derivedFrom(), id.session);
            testCase.verifyEqual(ndi.v2.referenceDatasets(docs), {id.reference});
        end

        % ================================================ datasetScope

        function testDatasetScopeTakesTheRealDataset(testCase)
            [docs, id] = fixture();
            scope = ndi.migrate.internal.datasetScope(docs);
            testCase.verifyTrue(scope.is_dataset, scope.reason);
            testCase.verifyEqual(scope.dataset_id, id.dataset);
            testCase.verifyEqual(scope.reason, 'dataset');
            testCase.verifyEqual(scope.dataset_entities, 1, ...
                'the reference Data Set is not counted as a dataset entity');
            testCase.verifyEqual(scope.reference_datasets, 1);
        end

        function testDatasetScopeWithOnlyAReferenceIsNoDataset(testCase)
            % a lone session holding a gene list: no dataset, so shared
            % entities stay in the session
            [docs, id] = fixture();
            keep = cellfun(@(d) ~strcmp(d.base.id, id.dataset) && ...
                ~strcmp(d.base.id, id.includedIn), docs);
            scope = ndi.migrate.internal.datasetScope(docs(keep));
            testCase.verifyFalse(scope.is_dataset);
            testCase.verifyEqual(scope.reason, 'no dataset entity');
            testCase.verifyEqual(scope.dataset_entities, 0);
            testCase.verifyEqual(scope.reference_datasets, 1);
        end
    end
end

% =============================================================================
% fixtures (local functions; see TestPathSPromotion for why not static methods)

function [docs, id] = fixture()
% property structs: the dataset, its session, a gene-list term and the
% reference Data Set it is derived from
id = struct('dataset', 'ds_0001', 'session', 'sess_0001', 'term', 'term_0001', ...
    'reference', 'ref_0001', 'includedIn', 'rel_inc_0001', 'derivedFrom', 'rel_der_0001');
docs = { ...
    entityDoc(id.dataset, dataSetType(), 'A dataset', id.dataset), ...
    entityDoc(id.session, struct('node', '', 'name', 'session'), 'day1', id.session), ...
    relationDoc(id.session, id.dataset, includedIn(), id.session, id.includedIn), ...
    termDoc(id.term, id.session), ...
    entityDoc(id.reference, dataSetType(), 'GRCm39', id.session), ...
    relationDoc(id.term, id.reference, derivedFrom(), id.session, id.derivedFrom)};
end

function s = entityDoc(docId, type, name, sessionId)
s = struct();
s.document_class = struct('class_name', 'entity');
s.depends_on = struct('name', 'session_id', 'document_id', sessionId);
s.base = struct('id', docId);
s.entity = struct('type', type, 'name', name);
end

function s = termDoc(docId, sessionId)
s = struct();
s.document_class = struct('class_name', 'term');
s.depends_on = struct('name', 'session_id', 'document_id', sessionId);
s.base = struct('id', docId);
end

function s = relationDoc(childId, parentId, relation, sessionId, docId)
if nargin < 5
    docId = ['rel_' childId '_' parentId];
end
s = struct();
s.document_class = struct('class_name', 'directed_relation');
s.depends_on = struct('name', {'session_id', 'child_id', 'parent_id'}, ...
    'document_id', {sessionId, childId, parentId});
s.base = struct('id', docId);
s.directed_relation = struct('relation', relation);
end

function t = dataSetType()
t = struct('node', 'NCIT:C47824', 'name', 'Data Set');
end

function t = derivedFrom()
t = struct('node', 'prov:wasDerivedFrom', 'name', 'wasDerivedFrom');
end

function t = includedIn()
t = struct('node', 'schema:isPartOf', 'name', 'included_in');
end
