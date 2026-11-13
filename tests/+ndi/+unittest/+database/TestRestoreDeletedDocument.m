classdef TestRestoreDeletedDocument < matlab.unittest.TestCase
    % TestRestoreDeletedDocument - re-adding a deleted document (issue #1238)
    %
    % DID retires the id of a document removed from the database and refuses
    % it ever after. A cloud mirror that re-downloads a document deleted
    % locally is bringing back the SAME document, so it passes
    % RestoreDeletedId to database_add. These tests cover that option at the
    % session level, where the cloud sync code reaches it through
    % ndi.dataset/database_add.

    properties
        session
    end

    methods (TestMethodSetup)
        function setupSession(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            ndi.test.helper.initializeMksqliteNoOutput()
            testCase.session = ndi.session.dir('restoreTest', fixture.Folder);
        end
    end

    methods (Test)
        function testDeletedDocumentIsRefusedByDefault(testCase)
            doc = testCase.session.newdocument('base', 'base.name', 'restoreMe');
            testCase.session.database_add(doc);
            testCase.session.database_rm(doc.id());

            testCase.verifyError(@() testCase.session.database_add(doc), ...
                'DID:SQLITEDB:DELETED_DOC', ...
                'without RestoreDeletedId a deleted id must still be refused');
        end

        function testDeletedDocumentCanBeRestored(testCase)
            doc = testCase.session.newdocument('base', 'base.name', 'restoreMe');
            testCase.session.database_add(doc);
            testCase.session.database_rm(doc.id());

            testCase.verifyWarningFree(@() ...
                testCase.session.database_add(doc, 'RestoreDeletedId', true));

            found = testCase.session.database_search( ...
                ndi.query('base.id', 'exact_string', doc.id()));
            testCase.verifyNumElements(found, 1, ...
                'the restored document should be in the session again');
            testCase.verifyEqual(found{1}.document_properties.base.name, 'restoreMe');
        end
    end
end
