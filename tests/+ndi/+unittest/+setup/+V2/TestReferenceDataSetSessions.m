classdef TestReferenceDataSetSessions < matlab.unittest.TestCase
%TESTREFERENCEDATASETSESSIONS A reference Data Set is not the dataset a v2 dataset is read from.
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
%   Each test writes a small did2 database with ndi.setup.V2.writeDocuments
%   and calls ndi.v2.datasetSessions on it: a session "day1", an organism
%   stored with it, a Data Set "GRCm39" stored with it as DID-matlab
%   +migrators_j/gene_list.m mints one, and the organism `derived_from` that
%   Data Set; with or without the dataset entity the session is
%   `included_in`. testADatasetHoldingAReferenceOpensWithItsOwnId writes the
%   dataset with ndi.setup.V2.createDataset and opens it with
%   ndi.dataset.dir: before they used ndi.v2.datasetDocuments, both took
%   every Data Set entity as the dataset, and a dataset holding a reference
%   opened with its session's id (first CI run of this test, 2026-11-07).
%
%   Needs DID-matlab V2 and did-schema #88 on DID_SCHEMA_PATH. Run by
%   run-tests.yml (the whole suite).

    methods (Test)
        function testDatasetSessionsListsTheSessionOfTheRealDataset(testCase)
            needV2(testCase);
            [docs, id] = writableFixture(true);
            [db, folder] = writeDatabase(testCase, docs);
            [sessions, notes] = ndi.v2.datasetSessions(db, id.dataset, folder, ...
                'OpenLinked', false);
            testCase.verifyEqual({sessions.entity_id}, {id.session});
            testCase.verifyEqual({sessions.reference}, {'day1'});
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
            [docs, id] = writableFixture(false);
            [db, folder] = writeDatabase(testCase, docs);
            [sessions, notes] = ndi.v2.datasetSessions(db, id.dataset, folder, ...
                'OpenLinked', false);
            testCase.verifyEqual({sessions.entity_id}, {id.session});
            testCase.verifyEqual({sessions.reference}, {'day1'});
            testCase.verifyTrue(any(contains(notes, 'no dataset document')), ...
                strjoin(notes, newline));
            testCase.verifyTrue(any(contains(notes, 'reference Data Set') & ...
                contains(notes, id.reference)), strjoin(notes, newline));
            testCase.verifyFalse(any(contains(notes, 'not included_in the dataset')), ...
                strjoin(notes, newline));
        end

        function testADatasetHoldingAReferenceOpensWithItsOwnId(testCase)
            % ndi.setup.V2.createDataset accepts a reference Data Set among
            % the dataset-level documents; ndi.dataset.dir opens the dataset
            % with the real dataset's id, lists its session, and files a
            % newly linked session under the real dataset entity
            % (ndi.dataset.v2DatasetDocId), not under a reference
            needV2(testCase);
            [docs, id] = writableFixture(true);
            % a second reference, stored with the dataset: an organism at the
            % dataset level derived from it
            D = {'SessionId', id.dataset};
            ref2 = did2.build.document('entity', struct('type', ...
                ndi.setup.V2.registeredTerm('NCIT:C47824'), 'name', 'Xenium panel v1'), D{:});
            id.reference2 = ref2.base.id;
            worm2 = ndi.setup.V2.entityDocuments('subject', struct('local_identifier', 'worm2', ...
                'type', did2.build.term('', 'organism')), struct(), D{:});
            worm2 = worm2(1);
            derived2 = did2.build.directedRelation(worm2{1}.base.id, id.reference2, ...
                ndi.v2.vocabTerm('relation', 'derived_from'), D{:});
            atDataset = cellfun(@(d) strcmp(ndi.v2.sessionIdOf(d), id.dataset), docs);
            dsDocs = [docs(atDataset), {ref2}, worm2, {derived2}];
            sessDocs = docs(~atDataset);

            root = tempname;
            mkdir(root);
            testCase.addTeardown(@() rmdir(root, 's'));
            dsPath = fullfile(root, 'dataset');
            ndi.setup.V2.createDataset(dsPath, 'reference data set', id.dataset, ...
                dsDocs, {sessDocs}, 'Progress', false);

            ds = ndi.dataset.dir(dsPath);
            testCase.verifyEqual(ds.id(), id.dataset, ...
                'the dataset opens with the real dataset''s id, not a reference''s session');
            [refs, ids] = ds.session_list();
            testCase.verifyEqual(refs, {'day1'});
            testCase.verifyEqual(ids, {id.session});
            notes = ds.session_notes();
            testCase.verifyTrue(any(contains(notes, 'reference Data Set') & ...
                contains(notes, id.reference2)), strjoin(notes, newline));

            % a linked session is filed under the real dataset entity
            folder = fullfile(root, 'extra');
            mkdir(folder);
            S2 = ndi.setup.V2.createSession(folder, 'extra');
            ds.add_linked_session(S2);
            rels = ds.database_search(ndi.query('', 'isa', 'directed_relation', '') & ...
                ndi.query('', 'depends_on', 'child_id', S2.id()));
            parents = cellfun(@(r) ndi.v2.edgeIds(r.document_properties, 'parent_id'), ...
                rels, 'UniformOutput', false);
            parents = [parents{:}];
            testCase.verifyTrue(ismember(id.dataset, parents), strjoin(parents, ', '));
            testCase.verifyFalse(any(ismember({id.reference, id.reference2}, parents)));
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

function [docs, id] = writableFixture(withDataset)
% WITHDATASET: the dataset entity and the session's included_in it; without,
% the database holds no dataset entity (an import whose metadata stage did
% not run)
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
docs = [dsDocs, sessDocs, {ref}, child, {derived}];
end

function [db, folder] = writeDatabase(testCase, docs)
% DOCS written to a did2 database in a fresh folder, opened unscoped as
% ndi.dataset does for ndi.v2.datasetSessions
folder = tempname;
ndiDir = fullfile(folder, '.ndi');
mkdir(ndiDir);
testCase.addTeardown(@() rmdir(folder, 's'));
file = fullfile(ndiDir, ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME());
ndi.setup.V2.writeDocuments(file, docs, 'Progress', false);
db = ndi.database.implementations.database.did2sqlite(ndiDir, 'reference data set', ...
    'load', file);
end
