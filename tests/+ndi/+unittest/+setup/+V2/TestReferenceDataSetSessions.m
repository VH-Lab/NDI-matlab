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
%   Each test writes a small did2 database with ndi.setup.V2.writeDocuments
%   and calls ndi.v2.datasetSessions on it: a session "day1", an organism
%   stored with it, a Data Set "GRCm39" stored with it as DID-matlab
%   +migrators_j/gene_list.m mints one, and the organism `derived_from` that
%   Data Set; with or without the dataset entity the session is
%   `included_in`. Not through ndi.setup.V2.createDataset and
%   ndi.dataset.dir: when they work out the dataset's id they too take every
%   Data Set entity as the dataset, and open a dataset holding a reference
%   Data Set with the wrong id (first CI run of this test, 2026-11-07).
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
% ndi.dataset does for ndi.v2.datasetSessions. Not through
% ndi.setup.V2.createDataset / ndi.dataset.dir: those also take every Data
% Set entity as the dataset when they work out the dataset's id.
folder = tempname;
ndiDir = fullfile(folder, '.ndi');
mkdir(ndiDir);
testCase.addTeardown(@() rmdir(folder, 's'));
file = fullfile(ndiDir, ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME());
ndi.setup.V2.writeDocuments(file, docs, 'Progress', false);
db = ndi.database.implementations.database.did2sqlite(ndiDir, 'reference data set', ...
    'load', file);
end
