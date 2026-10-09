classdef TestLinkedSessions < matlab.unittest.TestCase
%TESTLINKEDSESSIONS Linked and ingested sessions in a V2 dataset.
%
%   V_eta_linked_session_plan.md (signed 2026-10-09): a session is in a
%   dataset when it is `part_of` the dataset or a study of it; an INGESTED
%   session's documents are in the dataset's database, a LINKED one's in its
%   own folder, which a `linked_session` document names. Writes
%   TestHaleyRecordings' synthetic concentration_0001 into a dataset once,
%   then each test works on its own copy of that dataset.
%
%   Tests that link need the `linked_session` class; with a schema that
%   does not have it (the `current` CI leg) they return early (the workflow
%   fails a run in which any test is filtered).

    properties
        Root
        Master      % the dataset the import wrote, every session ingested
        Result
        Linked      % the import's result with its default: sessions linked
        Path        % this test's copy of the dataset
        Dataset
    end

    methods (TestClassSetup)
        function fixture(testCase)
            testCase.Root = tempname;
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            ndi.unittest.setup.V2.TestHaleyRecordings.writeFixture(testCase.Root);
            testCase.Result = ndi.setup.conv.haley.import_V2(testCase.Root, ...
                'Stages', ["sessions", "subjects", "acquisition", "relations", "metadata", ...
                "assertions", "manipulations", "observations", "calculations", "dataset"], ...
                'Sessions', "concentration_0001", ...
                'OutputRoot', fullfile(testCase.Root, 'haley_V2'), 'Write', true, ...
                'Overwrite', true, 'ReadVideos', false, 'SessionFolders', false);
            testCase.Master = testCase.Result.dataset.path;
            % the default (decision #71): each session written once, to its
            % folder, and linked from the dataset
            testCase.Linked = ndi.setup.conv.haley.import_V2(testCase.Root, ...
                'Stages', ["sessions", "subjects", "acquisition", "relations", "metadata", ...
                "assertions", "dataset"], ...
                'Sessions', "concentration_0001", ...
                'OutputRoot', fullfile(testCase.Root, 'haley_V2_linked'), 'Write', true, ...
                'Overwrite', true, 'ReadVideos', false);
        end
    end

    methods (TestMethodSetup)
        function copyDataset(testCase)
            testCase.Path = fullfile(testCase.Root, ['ds_' char(ndi.ido.unique_id())]);
            copyfile(testCase.Master, testCase.Path);
            testCase.Dataset = ndi.dataset.dir(testCase.Path);
        end
    end

    methods (Test)
        function testIngestedSessionIsListedFromPartOf(testCase)
            [refs, ids] = testCase.Dataset.session_list();
            testCase.verifyEqual(refs, {'concentration_0001'});
            testCase.verifyEqual(numel(ids), 1);
            notes = testCase.Dataset.session_notes();
            testCase.verifyTrue(startsWith(notes{1}, 'DENOMINATOR:'), ...
                'The listing states its denominator first.');
            testCase.verifyTrue(contains(notes{1}, '1 ingested and 0 linked'), notes{1});
            S = testCase.Dataset.open_session(ids{1});
            testCase.verifyEqual(S.reference, 'concentration_0001');
        end

        function testIngestedToLinkedAndBack(testCase)
            if ~canLink(), return; end
            [~, ids] = testCase.Dataset.session_list();
            sid = ids{1};
            before = testCase.sessionDocuments(sid);
            [docId, name] = ingestedFile(before);

            folder = fullfile(testCase.Root, ['linked_' char(ndi.ido.unique_id())]);
            testCase.Dataset.convertIngestedSessionToLinked(sid, folder, 'areYouSure', true);
            testCase.verifyTrue(isfile(fullfile(folder, '.ndi', ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME())));

            % opened again from disk, the session is linked and in the folder
            ds = ndi.dataset.dir(testCase.Path);
            [refs, ids2] = ds.session_list();
            testCase.verifyEqual(refs, {'concentration_0001'});
            testCase.verifyEqual(ids2, {sid});
            notes = ds.session_notes();
            testCase.verifyTrue(contains(notes{1}, '0 ingested and 1 linked'), notes{1});
            S = ds.open_session(sid);
            testCase.verifyEqual(canonical(S.path), canonical(folder));
            % every document is still reached through the dataset
            testCase.verifyEqual(sort(idsOf(testCase.sessionDocuments(sid, ds))), sort(idsOf(before)));
            if ~isempty(docId)
                testCase.verifyTrue(S.database_existbinarydoc(docId, name), ...
                    'An ingested file moves out with its document.');
            end

            ds.convertLinkedSessionToIngested(sid, 'areYouSure', true);
            ds = ndi.dataset.dir(testCase.Path);
            notes = ds.session_notes();
            testCase.verifyTrue(contains(notes{1}, '1 ingested and 0 linked'), notes{1});
            testCase.verifyEqual(sort(idsOf(testCase.sessionDocuments(sid, ds))), sort(idsOf(before)));
            if ~isempty(docId)
                testCase.verifyTrue(ds.database_existbinarydoc(docId, name), ...
                    'An ingested file comes back with its document.');
            end
        end

        function testAddAndUnlinkALinkedSession(testCase)
            if ~canLink(), return; end
            folder = fullfile(testCase.Root, ['extra_' char(ndi.ido.unique_id())]);
            mkdir(folder);
            S2 = ndi.setup.V2.createSession(folder, 'extra');
            testCase.Dataset.add_linked_session(S2);
            [refs, ids] = testCase.Dataset.session_list();
            testCase.verifyEqual(sort(refs), sort({'concentration_0001', 'extra'}));
            % its documents are found through the dataset
            found = testCase.Dataset.database_search(ndi.query('base.session_id', 'exact_string', S2.id(), ''));
            testCase.verifyNotEmpty(found);
            % and the dataset opened again from disk still has it
            ds = ndi.dataset.dir(testCase.Path);
            [refs2, ~] = ds.session_list();
            testCase.verifyEqual(sort(refs2), sort(refs));

            ds.unlink_session(S2.id(), 'areYouSure', true);
            [refs3, ~] = ds.session_list();
            testCase.verifyEqual(refs3, {'concentration_0001'});
            testCase.verifyTrue(isfolder(fullfile(folder, '.ndi')), 'Unlinking leaves the folder.');
            testCase.verifyNotEmpty(ids);
        end

        function testASessionAlreadyInTheDatasetIsNotAddedTwice(testCase)
            if ~canLink(), return; end
            % the linked import's session folder holds a session its dataset has
            ds = ndi.dataset.dir(testCase.Linked.dataset.path);
            S = ndi.session.dir(testCase.Linked.sessions.path{1});
            testCase.verifyError(@() ds.add_linked_session(S), ?MException);
        end

        function testTheImportLinksItsSessions(testCase)
            if ~canLink(), return; end
            L = testCase.Linked;
            ds = ndi.dataset.dir(L.dataset.path);
            [refs, ids] = ds.session_list();
            testCase.verifyEqual(refs, {'concentration_0001'});
            notes = ds.session_notes();
            testCase.verifyTrue(contains(notes{1}, '0 ingested and 1 linked'), notes{1});
            % written once: the dataset's database holds no document of the
            % session but its part_of relation
            files = ndi.setup.V2.datasetDatabaseFiles(L.dataset.path);
            testCase.verifyNumElements(files, 2, 'the dataset''s database and the session folder''s');
            db = did2.database.sqlitedb(files{1});
            n = mksqlite(db.testHookDbId(), sprintf(['SELECT COUNT(*) AS n FROM documents ' ...
                'WHERE session_id = ''%s'' AND classname <> ''directed_relation'''], ids{1}));
            db.close();
            testCase.verifyEqual(double(n.n), 0, 'no session document is copied into the dataset');
            % opened through the dataset, the session reaches the dataset's documents
            S = ds.open_session(ids{1});
            testCase.verifyEqual(canonical(S.path), canonical(L.sessions.path{1}));
            testCase.verifyNotEmpty(S.database_search_with_dataset(ndi.v2.isaQuery('study')), ...
                'a linked session opened through its dataset finds the dataset''s studies');
            alone = ndi.session.dir(L.sessions.path{1});
            testCase.verifyEmpty(alone.database_search_with_dataset(ndi.v2.isaQuery('study')), ...
                'opened on its own, the folder holds only the session''s documents');
            % and the dataset passes its checks, over both databases
            v = ndi.setup.conv.haley.verifyDataset(L.dataset.path, 'Expected', L, 'Hashes', false);
            testCase.verifyEmpty(v.failed, evalc('disp(v.census.differences)'));
            testCase.verifyEqual(v.edges.dangling, 0);
        end

        function testAddAnIngestedSession(testCase)
            folder = fullfile(testCase.Root, ['ingest_' char(ndi.ido.unique_id())]);
            mkdir(folder);
            S2 = ndi.setup.V2.createSession(folder, 'ingested_extra');
            testCase.Dataset.add_ingested_session(S2);
            ds = ndi.dataset.dir(testCase.Path);
            [refs, ids] = ds.session_list();
            testCase.verifyEqual(sort(refs), sort({'concentration_0001', 'ingested_extra'}));
            notes = ds.session_notes();
            testCase.verifyTrue(contains(notes{1}, '2 ingested and 0 linked'), notes{1});
            S = ds.open_session(ids{strcmp(refs, 'ingested_extra')});
            testCase.verifyEqual(canonical(S.path), canonical(testCase.Path), ...
                'An ingested session opens from the dataset''s folder.');
        end

        function testAFolderThatMovedIsReported(testCase)
            if ~canLink(), return; end
            [~, ids] = testCase.Dataset.session_list();
            folder = fullfile(testCase.Root, ['moving_' char(ndi.ido.unique_id())]);
            testCase.Dataset.convertIngestedSessionToLinked(ids{1}, folder, 'areYouSure', true);
            movefile(folder, [folder '_moved']);
            ds = ndi.dataset.dir(testCase.Path);
            refs = testCase.verifyWarning(@() ds.session_list(), 'ndi:dataset:sessionsLeftOut');
            testCase.verifyEmpty(refs);
            notes = ds.session_notes();
            testCase.verifyTrue(any(contains(notes, 'no such folder')), strjoin(notes, newline));
        end

        function testMakeSelfContained(testCase)
            dry = testCase.Dataset.makeSelfContained('DryRun', true);
            testCase.verifyGreaterThan(dry.documents, 0);
            testCase.verifyGreaterThan(dry.ingested, 0, ...
                'The fixture records its videos by location, so there is something to copy in.');
            done = testCase.Dataset.makeSelfContained();
            testCase.verifyEqual(done.ingested, dry.ingested);
            testCase.verifyEqual(done.withByLocation, dry.withByLocation);
            again = testCase.Dataset.makeSelfContained('DryRun', true);
            testCase.verifyEqual(again.ingested, 0, 'Nothing is left by location.');
            testCase.verifyEqual(again.documents, dry.documents, 'No document was lost.');
        end
    end

    methods
        function docs = sessionDocuments(testCase, sid, ds)
            if nargin < 3, ds = testCase.Dataset; end
            found = ds.database_search(ndi.query('base.session_id', 'exact_string', sid, ''));
            docs = cellfun(@(d) d.document_properties, found, 'UniformOutput', false);
        end
    end
end

function tf = canLink()
% the schema in use has the linked_session class
tf = ndi.setup.V2.schemaHasClass('linked_session');
end

function ids = idsOf(docs)
ids = cellfun(@(d) d.base.id, docs, 'UniformOutput', false);
end

function p = canonical(p)
p = char(java.io.File(p).getCanonicalPath());
end

function [docId, name] = ingestedFile(docs)
% a document of DOCS with an ingested file, and that file's name ('' if none)
docId = ''; name = '';
for i = 1:numel(docs)
    d = docs{i};
    if ~isfield(d, 'files') || ~isfield(d.files, 'file_info') || isempty(d.files.file_info)
        continue;
    end
    fi = d.files.file_info;
    if iscell(fi), fi = [fi{:}]; end
    for a = 1:numel(fi)
        L = fi(a).locations;
        if iscell(L), L = [L{:}]; end
        if any(arrayfun(@(x) isfield(x, 'ingest') && logical(x.ingest), L))
            docId = d.base.id;
            name = char(fi(a).name);
            return;
        end
    end
end
end
