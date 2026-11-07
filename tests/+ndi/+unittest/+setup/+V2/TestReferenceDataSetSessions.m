classdef TestReferenceDataSetSessions < matlab.unittest.TestCase
%TESTREFERENCEDATASETSESSIONS ndi.v2.datasetSessions does not take a reference Data Set as the dataset.
%
%   Since DID-matlab #420 (180bc8cc) a migrated v1 geneList brings minimal
%   `entity` documents of type Data Set (NCIT:C47824), its genome annotation
%   and assembly, that the gene-list term is `derived_from` (Decided by Jess
%   Haley, 2026-11-07, did-schema did_v2_go_forward_class_audit.md [gene-list
%   history entities]). ndi.v2.datasetSessions reads a dataset's sessions
%   from the `dataset` document they are `included_in`; a reference Data Set
%   (something was derived from it, no document is stored with it, nothing is
%   included in it: ndi.v2.referenceDatasets, DID-matlab migrationRecord's
%   rule) is not that document. The struct-level tests of the rule and of
%   ndi.migrate.internal.datasetScope are ndi.unittest.migrate.
%   TestReferenceDataSet.
%
%   Each test writes a small dataset with ndi.setup.V2.createDataset (as
%   TestGenericDatasetEndToEnd): a session "day1", an organism stored with
%   it, a Data Set "GRCm39" stored with it as DID-matlab +migrators_j/
%   gene_list.m mints one, and the organism `derived_from` that Data Set;
%   with or without the dataset entity the session is `included_in`.
%
%   Needs DID-matlab V2 and did-schema #88 on DID_SCHEMA_PATH.
%
%   UNVERIFIED: written without MATLAB; test-import-v2.yml is the first run.

    methods (Test)
        function testDatasetSessionsListsTheSessionOfTheRealDataset(testCase)
            needV2(testCase);
            [dsDocs, sessDocs, id] = writableFixture(true);
            ds = writeDataset(testCase, id, dsDocs, sessDocs);
            [refs, ids] = ds.session_list();
            testCase.verifyEqual(refs, {'day1'});
            testCase.verifyEqual(ids, {id.session});
            notes = ds.session_notes();
            testCase.verifyTrue(startsWith(notes{1}, 'DENOMINATOR:'), notes{1});
            testCase.verifyTrue(contains(notes{1}, '1 ingested and 0 linked'), notes{1});
            testCase.verifyTrue(any(contains(notes, 'reference Data Set') & ...
                contains(notes, id.reference)), strjoin(notes, newline));
            testCase.verifyFalse(any(contains(notes, 'no dataset document')), ...
                strjoin(notes, newline));
        end

        function testDatasetSessionsDoesNotTakeAReferenceAsTheDataset(testCase)
            % no dataset entity: membership cannot be read, so the session is
            % listed. Taking the reference Data Set as the dataset would leave
            % the session out as "not included_in the dataset".
            needV2(testCase);
            [dsDocs, sessDocs, id] = writableFixture(false);
            ds = writeDataset(testCase, id, dsDocs, sessDocs);
            [refs, ids] = ds.session_list();
            testCase.verifyEqual(refs, {'day1'});
            testCase.verifyEqual(ids, {id.session});
            notes = ds.session_notes();
            testCase.verifyTrue(any(contains(notes, 'no dataset document')), ...
                strjoin(notes, newline));
            testCase.verifyFalse(any(contains(notes, 'not included_in the dataset')), ...
                strjoin(notes, newline));
        end
    end
end

% ---- the written dataset (did2.build, as TestGenericDatasetEndToEnd) --------

function needV2(testCase)
testCase.assumeTrue(~isempty(which('did2.build.document')), ...
    'did2.build (DID-matlab V2) is not on the path');
schemaPath = getenv('DID_SCHEMA_PATH');
testCase.assumeTrue(~isempty(schemaPath) && ...
    isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')), ...
    'DID_SCHEMA_PATH does not hold a v2 schema with `entity` (did-schema #88)');
% the session's and the dataset's names are this test's own; what is tested
% is the listing, not the term registry
if ~isempty(which('did2.schema.termIndex'))
    prev = did2.schema.cache.strictMode('TermRegistry', false);
    testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end
end

function [dsDocs, sessDocs, id] = writableFixture(withDataset)
% WITHDATASET: the dataset entity and the session's included_in it; without,
% the dataset's database records the dataset as a session (createDataset)
id.dataset = ndi.ido.unique_id();
id.session = ndi.ido.unique_id();
D = {'SessionId', id.dataset};
S = {'SessionId', id.session};
dsDocs = {};
sessDocs = ndi.setup.V2.entityDocuments('session', struct('local_identifier', 'day1'), ...
    struct(), S{:}, 'Id', id.session);
if withDataset
    dsDocs = ndi.setup.V2.entityDocuments('dataset', struct('name', 'A dataset'), ...
        struct(), D{:}, 'Id', id.dataset);
    sessDocs{end+1} = did2.build.directedRelation(id.session, id.dataset, ...
        ndi.v2.vocabTerm('relation', 'included_in'), S{:});
end
% the reference Data Set, as DID-matlab +migrators_j/gene_list.m mints it,
% and an entity derived from it, stored with the session
ref = did2.build.document('entity', struct('type', ...
    ndi.setup.V2.registeredTerm('NCIT:C47824'), 'name', 'GRCm39'), S{:});
id.reference = ref.base.id;
child = ndi.setup.V2.entityDocuments('subject', struct('local_identifier', 'worm1', ...
    'type', did2.build.term('', 'organism')), struct(), S{:});
child = child(1);
id.child = child{1}.base.id;
derived = did2.build.directedRelation(id.child, id.reference, ...
    ndi.v2.vocabTerm('relation', 'derived_from'), S{:});
sessDocs = [sessDocs, {ref}, child, {derived}];
end

function ds = writeDataset(testCase, id, dsDocs, sessDocs)
root = tempname;
mkdir(root);
testCase.addTeardown(@() rmdir(root, 's'));
ndi.setup.V2.createDataset(fullfile(root, 'dataset'), 'reference data set', id.dataset, ...
    dsDocs, {sessDocs}, 'Progress', false);
ds = ndi.dataset.dir(fullfile(root, 'dataset'));
end
