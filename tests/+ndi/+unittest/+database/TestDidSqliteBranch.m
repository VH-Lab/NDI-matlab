classdef TestDidSqliteBranch < matlab.unittest.TestCase
%TESTDIDSQLITEBRANCH The DID branch ndi.database.implementations.database.didsqlite uses.
%
%   Issue #316: the branch name 'a' was written out in every method. It is now
%   one constant property, BRANCH, still 'a' so that existing databases (all
%   of which hold their documents on 'a') open unchanged.

    properties
        Dir
    end

    methods (TestMethodSetup)
        function makeDir(testCase)
            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
        end
    end

    methods (Test)

        function testTheBranchIsA(testCase)
            testCase.verifyEqual( ...
                ndi.database.implementations.database.didsqlite.branch, 'a');
        end

        function testANewDatabaseGetsTheBranch(testCase)
            db = ndi.database.implementations.database.didsqlite(testCase.Dir, 'ref1');
            raw = did.implementations.sqlitedb(fullfile(testCase.Dir, 'did-sqlite.sqlite'));
            testCase.verifyEqual(raw.all_branch_ids(), {db.branch});
        end

        function testDocumentsAreWrittenAndReadOnTheBranch(testCase)
            db = ndi.database.implementations.database.didsqlite(testCase.Dir, 'ref1');
            doc = ndi.document('base', 'base.session_id', ndi.ido.unique_id());
            db.add(doc);
            testCase.verifyTrue(ismember(doc.id(), db.alldocids()));
            hits = db.search(ndi.query('base.id', 'exact_string', doc.id(), ''));
            testCase.verifyNumElements(hits, 1);
            raw = did.implementations.sqlitedb(fullfile(testCase.Dir, 'did-sqlite.sqlite'));
            testCase.verifyTrue(ismember(doc.id(), raw.get_doc_ids('a')), ...
                'the document is not on branch ''a'', where existing databases keep theirs');
        end

        function testADatabaseOnBranchAStillOpens(testCase)
            % a database written before the constant existed: branch 'a',
            % made directly through DID
            raw = did.implementations.sqlitedb(fullfile(testCase.Dir, 'did-sqlite.sqlite'));
            raw.add_branch('a');
            clear raw
            db = ndi.database.implementations.database.didsqlite(testCase.Dir, 'ref1');
            testCase.verifyEmpty(db.alldocids());
        end

        function testADatabaseWithoutTheBranchIsRefused(testCase)
            raw = did.implementations.sqlitedb(fullfile(testCase.Dir, 'did-sqlite.sqlite'));
            raw.add_branch('b');
            clear raw
            testCase.verifyError(@() ndi.database.implementations.database.didsqlite( ...
                testCase.Dir, 'ref1'), 'NDI:Database:MissingBranch');
        end
    end
end
