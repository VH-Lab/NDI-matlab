classdef TestDid2SqliteRemove < matlab.unittest.TestCase
%TESTDID2SQLITEREMOVE Removing documents from a V2 (did2) session.
%
%   ndi.database/remove passes 'OnMissing' to do_remove on every call, so
%   did2sqlite's do_remove must take it: before, database_rm and
%   database_clear on a V2 session failed with MATLAB:TooManyInputs.
%
%   Filtered (never passed) when did2.build or a V2 schema with `entity` is
%   missing.

    properties
        Dir
    end

    methods (TestClassSetup)
        function needV2(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `entity`');
        end
    end

    methods (TestMethodSetup)
        function makeDir(testCase)
            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
        end
    end

    methods (Test)
        function testRemoveMissingAndClear(testCase)
            S = ndi.setup.V2.createSession(testCase.Dir, 'd1');
            testCase.assertTrue(S.writesV2());
            sub = ndi.subject('mouse1@nosuchlab.org', '');
            S.database_add(sub.newdocument(S));
            q = ndi.query('base.id', 'exact_string', sub.id(), '');
            testCase.assertNumElements(S.database_search(q), 1);

            S.database_rm(sub.id());
            testCase.verifyEmpty(S.database_search(q), 'database_rm did not remove the document');

            % removing it again is not an error
            S.database_rm(sub.id());

            S.database_add(sub.newdocument(S));
            S.database_clear('yes');
            testCase.verifyEmpty(S.database_search(q), 'database_clear left the document');
        end
    end
end
