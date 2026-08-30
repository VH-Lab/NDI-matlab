classdef SyncgraphResurrectionTest < matlab.unittest.TestCase
    % SYNCGRAPHRESURRECTIONTEST - regression tests for syncrule resurrection
    %
    % ndi.session/update_syncgraph_in_db used to delete every stored syncrule
    % document and then re-add documents built from the same in-memory rule
    % objects. Those documents carry the rules' original ids, so a surviving
    % rule was re-added under an id DID had just retired -- an id that leaves
    % its last branch is recorded in deleted_docs and refused on any later add.
    %
    % The failure needs two adds, where the first rule survives into the
    % second update. A single add, or an add followed by removing the only
    % rule, never re-adds anything and so never trips it.
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    properties
        testDir
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);

            testCase.testDir = fullfile(fixture.Folder, 'exp1_syncgraph_resurrection');
            if ~isfolder(testCase.testDir)
                mkdir(testCase.testDir);
            end

            ndi.test.helper.initializeMksqliteNoOutput()
        end
    end

    methods (TestMethodSetup)
        function setupTest(testCase)
            % Each test starts from a session with no syncgraph and no syncrules.
            E = ndi.session.dir('exp1', testCase.testDir);
            docTypes = {'syncgraph','syncrule'};
            for i=1:numel(docTypes)
                docs = E.database_search(ndi.query('','isa',docTypes{i},''));
                if ~isempty(docs)
                    E.database_rm(docs);
                end
            end
        end
    end

    methods (Test)

        function testSecondAddKeepsFirstRuleDocument(testCase)
            % The reported failure: update 2 deletes rule 1's document and
            % re-adds it under the same, now retired, id.
            E = ndi.session.dir('exp1', testCase.testDir);

            E = E.syncgraph_addrule(ndi.time.syncrule.filematch(struct('number_fullpath_matches',2)));
            firstRuleId = E.syncgraph.rules{1}.id();
            firstRuleDoc = E.database_search(ndi.query('base.id','exact_string',firstRuleId,''));
            testCase.assertEqual(numel(firstRuleDoc), 1, ...
                'The first rule should have exactly one document after the first add.');

            % This is the add that used to raise "a document with this id was
            % previously removed from every branch".
            E = E.syncgraph_addrule(ndi.time.syncrule.filematch(struct('number_fullpath_matches',3)));

            testCase.verifyEqual(numel(E.syncgraph.rules), 2);
            testCase.verifyEqual(E.syncgraph.rules{1}.id(), firstRuleId, ...
                'A surviving rule must keep its id across a syncgraph update.');

            survivingDoc = E.database_search(ndi.query('base.id','exact_string',firstRuleId,''));
            testCase.verifyEqual(numel(survivingDoc), 1, ...
                'The surviving rule''s document must still be in the database.');

            ruleDocs = E.database_search(ndi.query('','isa','syncrule',''));
            testCase.verifyEqual(numel(ruleDocs), 2, ...
                'Both rules should have exactly one document each.');
        end

        function testSyncgraphDocumentReferencesBothRules(testCase)
            % The rebuilt syncgraph document must depend on the surviving
            % rule's id as well as the new one, or the survivor is orphaned.
            E = ndi.session.dir('exp1', testCase.testDir);

            E = E.syncgraph_addrule(ndi.time.syncrule.filematch(struct('number_fullpath_matches',2)));
            E = E.syncgraph_addrule(ndi.time.syncrule.filematch(struct('number_fullpath_matches',3)));

            [syncgraphDoc, syncruleDocs] = ndi.time.syncgraph.load_all_syncgraph_docs(E, ...
                E.syncgraph.id());
            testCase.assertNotEmpty(syncgraphDoc, ...
                'The rebuilt syncgraph must have a document in the database.');
            testCase.verifyEqual(numel(syncruleDocs), 2, ...
                'The syncgraph document must reference both rules.');

            loadedIds = cellfun(@(d) d.id(), syncruleDocs, 'UniformOutput', false);
            for i=1:numel(E.syncgraph.rules)
                testCase.verifyTrue(any(strcmp(E.syncgraph.rules{i}.id(), loadedIds)), ...
                    'Every in-memory rule must be reachable from the syncgraph document.');
            end
        end

        function testThirdAddStillSucceeds(testCase)
            % Two survivors on the same update, not just one.
            E = ndi.session.dir('exp1', testCase.testDir);

            E = E.syncgraph_addrule(ndi.time.syncrule.filematch(struct('number_fullpath_matches',2)));
            E = E.syncgraph_addrule(ndi.time.syncrule.filematch(struct('number_fullpath_matches',3)));
            keptIds = {E.syncgraph.rules{1}.id(), E.syncgraph.rules{2}.id()};

            E = E.syncgraph_addrule(ndi.time.syncrule.filematch(struct('number_fullpath_matches',4)));

            testCase.verifyEqual(numel(E.syncgraph.rules), 3);
            for i=1:numel(keptIds)
                docHere = E.database_search(ndi.query('base.id','exact_string',keptIds{i},''));
                testCase.verifyEqual(numel(docHere), 1, ...
                    'Both earlier rules must keep their documents.');
            end
            testCase.verifyEqual(numel(E.database_search(ndi.query('','isa','syncrule',''))), 3);
        end

        function testRemoveRuleDeletesOnlyThatRulesDocument(testCase)
            % Removing one of two rules must delete exactly that rule's
            % document and leave the survivor's alone.
            E = ndi.session.dir('exp1', testCase.testDir);

            E = E.syncgraph_addrule(ndi.time.syncrule.filematch(struct('number_fullpath_matches',2)));
            E = E.syncgraph_addrule(ndi.time.syncrule.filematch(struct('number_fullpath_matches',3)));
            removedId = E.syncgraph.rules{1}.id();
            survivorId = E.syncgraph.rules{2}.id();

            E = E.syncgraph_rmrule(1);

            testCase.verifyEqual(numel(E.syncgraph.rules), 1);
            testCase.verifyEqual(E.syncgraph.rules{1}.id(), survivorId, ...
                'The survivor must keep its id when another rule is removed.');
            testCase.verifyEmpty(E.database_search(ndi.query('base.id','exact_string',removedId,'')), ...
                'The removed rule''s document must be gone.');
            testCase.verifyEqual(numel(E.database_search(ndi.query('base.id','exact_string',survivorId,''))), 1, ...
                'The survivor''s document must remain.');
            testCase.verifyEqual(numel(E.database_search(ndi.query('','isa','syncrule',''))), 1);
        end

        function testRemoveOnlyRuleLeavesNoSyncruleDocuments(testCase)
            E = ndi.session.dir('exp1', testCase.testDir);

            E = E.syncgraph_addrule(ndi.time.syncrule.filematch(struct('number_fullpath_matches',2)));
            E = E.syncgraph_rmrule(1);

            testCase.verifyEmpty(E.syncgraph.rules);
            testCase.verifyEmpty(E.database_search(ndi.query('','isa','syncrule','')), ...
                'Removing the only rule must leave no syncrule documents behind.');
        end

    end

end
