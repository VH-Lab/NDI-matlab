classdef diffTest < matlab.unittest.TestCase
    % DIFFTEST - Test for ndi.fun.dataset.diff
    %

    methods (Test)
        function testIdenticalDatasets(testCase)
            % Create temporary directories
            tempDir1 = tempname;
            mkdir(tempDir1);
            cleanup1 = onCleanup(@() rmdir(tempDir1, 's'));

            tempDir2 = tempname;
            mkdir(tempDir2);
            cleanup2 = onCleanup(@() rmdir(tempDir2, 's'));

            % Setup identical sessions and datasets
            mkdir(fullfile(tempDir1, 'session'));
            S1 = ndi.session.dir('ref1', fullfile(tempDir1, 'session'));
            D1 = ndi.dataset.dir('dref1', tempDir1);
            D1.add_linked_session(S1);

            mkdir(fullfile(tempDir2, 'session'));
            S2 = ndi.session.dir('ref2', fullfile(tempDir2, 'session'));
            D2 = ndi.dataset.dir('dref2', tempDir2);
            D2.add_linked_session(S2);

            % Add identical documents
            doc1 = S1.newdocument('demoNDI', 'base.name', 'test doc', 'demoNDI.value', 1);
            doc1 = doc1 + S1.newdocument();
            S1.database_add(doc1);

            doc2 = S2.newdocument('demoNDI', 'base.name', 'test doc', 'demoNDI.value', 1);
            doc2 = doc2 + S2.newdocument();
            S2.database_add(doc2);

            % Call the diff function
            report = ndi.fun.dataset.diff(D1, D2);

            % Verify the report is empty - accounting for the session document
            testCase.verifyEqual(numel(report.documentsInAOnly), 1, 'Should be one document in A only (the session doc).');
            testCase.verifyEqual(numel(report.documentsInBOnly), 1, 'Should be one document in B only (the session doc).');
            testCase.verifyEmpty(report.mismatchedDocuments, 'Mismatched documents should be empty.');
            testCase.verifyEmpty(report.fileDifferences, 'File differences should be empty.');
        end

        function testDocumentsInAOnly(testCase)
            % Create temporary directories
            tempDir1 = tempname;
            mkdir(tempDir1);
            cleanup1 = onCleanup(@() rmdir(tempDir1, 's'));

            tempDir2 = tempname;
            mkdir(tempDir2);
            cleanup2 = onCleanup(@() rmdir(tempDir2, 's'));

            % Setup sessions and datasets
            mkdir(fullfile(tempDir1, 'session'));
            S1 = ndi.session.dir('ref1', fullfile(tempDir1, 'session'));
            D1 = ndi.dataset.dir('dref1', tempDir1);
            D1.add_linked_session(S1);

            mkdir(fullfile(tempDir2, 'session'));
            S2 = ndi.session.dir('ref2', fullfile(tempDir2, 'session'));
            D2 = ndi.dataset.dir('dref2', tempDir2);
            D2.add_linked_session(S2);

            % Add a document only to the first dataset
            doc1 = S1.newdocument('demoNDI', 'base.name', 'doc in A only', 'demoNDI.value', 1);
            doc1 = doc1 + S1.newdocument();
            added_doc = S1.database_add(doc1);

            % Call the diff function
            report = ndi.fun.dataset.diff(D1, D2);

            % Verify the report
            testCase.verifyEqual(numel(report.documentsInAOnly), 2, 'Should be two documents in A only.');
            testCase.verifyTrue(any(strcmp(added_doc.id(), report.documentsInAOnly)), 'The added document was not found in A only.');
            testCase.verifyEqual(numel(report.documentsInBOnly), 1, 'Should be one document in B only (the session doc).');
            testCase.verifyEmpty(report.mismatchedDocuments, 'Mismatched documents should be empty.');
            testCase.verifyEmpty(report.fileDifferences, 'File differences should be empty.');
        end

        function testDocumentsInBOnly(testCase)
            % Create temporary directories
            tempDir1 = tempname;
            mkdir(tempDir1);
            cleanup1 = onCleanup(@() rmdir(tempDir1, 's'));

            tempDir2 = tempname;
            mkdir(tempDir2);
            cleanup2 = onCleanup(@() rmdir(tempDir2, 's'));

            % Setup sessions and datasets
            mkdir(fullfile(tempDir1, 'session'));
            S1 = ndi.session.dir('ref1', fullfile(tempDir1, 'session'));
            D1 = ndi.dataset.dir('dref1', tempDir1);
            D1.add_linked_session(S1);

            mkdir(fullfile(tempDir2, 'session'));
            S2 = ndi.session.dir('ref2', fullfile(tempDir2, 'session'));
            D2 = ndi.dataset.dir('dref2', tempDir2);
            D2.add_linked_session(S2);

            % Add a document only to the second dataset
            doc2 = S2.newdocument('demoNDI', 'base.name', 'doc in B only', 'demoNDI.value', 1);
            doc2 = doc2 + S2.newdocument();
            added_doc = S2.database_add(doc2);

            % Call the diff function
            report = ndi.fun.dataset.diff(D1, D2);

            % Verify the report
            testCase.verifyEqual(numel(report.documentsInAOnly), 1, 'Should be one document in A only (the session doc).');
            testCase.verifyEqual(numel(report.documentsInBOnly), 2, 'Should be two documents in B only.');
            testCase.verifyTrue(any(strcmp(added_doc.id(), report.documentsInBOnly)), 'The added document was not found in B only.');
            testCase.verifyEmpty(report.mismatchedDocuments, 'Mismatched documents should be empty.');
            testCase.verifyEmpty(report.fileDifferences, 'File differences should be empty.');
        end

        function testMismatchedDocuments(testCase)
            % Create temporary directories
            tempDir1 = tempname;
            mkdir(tempDir1);
            cleanup1 = onCleanup(@() rmdir(tempDir1, 's'));

            tempDir2 = tempname;
            mkdir(tempDir2);
            cleanup2 = onCleanup(@() rmdir(tempDir2, 's'));

            % Setup sessions and datasets
            mkdir(fullfile(tempDir1, 'session'));
            S1 = ndi.session.dir('ref1', fullfile(tempDir1, 'session'));
            D1 = ndi.dataset.dir('dref1', tempDir1);
            D1.add_linked_session(S1);

            mkdir(fullfile(tempDir2, 'session'));
            S2 = ndi.session.dir('ref2', fullfile(tempDir2, 'session'));
            D2 = ndi.dataset.dir('dref2', tempDir2);
            D2.add_linked_session(S2);

            % Add documents with same ID but different properties
            doc1 = S1.newdocument('demoNDI', 'base.name', 'test doc', 'demoNDI.value', 1);
            doc1 = doc1 + S1.newdocument();
            added_doc = S1.database_add(doc1);

            doc2 = S2.newdocument('demoNDI', 'base.name', 'test doc', 'demoNDI.value', 2); % Different value
            doc2 = doc2 + S2.newdocument();
            S2.database_add(doc2);

            % Call the diff function
            report = ndi.fun.dataset.diff(D1, D2);

            % Verify the report
            testCase.verifyEqual(numel(report.documentsInAOnly), 1, 'Should be one document in A only (the session doc).');
            testCase.verifyEqual(numel(report.documentsInBOnly), 1, 'Should be one document in B only (the session doc).');
            testCase.verifyEqual(numel(report.mismatchedDocuments), 1, 'Should be one mismatched document.');
            testCase.verifyEqual(report.mismatchedDocuments(1).id, added_doc.id(), 'The mismatched document ID is incorrect.');
            testCase.verifyEmpty(report.fileDifferences, 'File differences should be empty.');
        end

        function testMismatchedFiles(testCase)
            % Create temporary directories
            tempDir1 = tempname;
            mkdir(tempDir1);
            cleanup1 = onCleanup(@() rmdir(tempDir1, 's'));

            tempDir2 = tempname;
            mkdir(tempDir2);
            cleanup2 = onCleanup(@() rmdir(tempDir2, 's'));

            % Setup sessions and datasets
            mkdir(fullfile(tempDir1, 'session'));
            S1 = ndi.session.dir('ref1', fullfile(tempDir1, 'session'));
            D1 = ndi.dataset.dir('dref1', tempDir1);
            D1.add_linked_session(S1);

            mkdir(fullfile(tempDir2, 'session'));
            S2 = ndi.session.dir('ref2', fullfile(tempDir2, 'session'));
            D2 = ndi.dataset.dir('dref2', tempDir2);
            D2.add_linked_session(S2);

            % Add documents with files that have different content
            doc1 = S1.newdocument('demoNDI', 'base.name', 'test doc', 'demoNDI.value', 1);
            file1_path = fullfile(tempDir1, 'file1.bin');
            fid1 = fopen(file1_path, 'w');
            fwrite(fid1, 'content1', 'char');
            fclose(fid1);
            doc1 = doc1.add_file('filename1.ext', file1_path);
            doc1 = doc1 + S1.newdocument();
            added_doc1 = S1.database_add(doc1);

            doc2 = S2.newdocument('demoNDI', 'base.name', 'test doc', 'demoNDI.value', 1);
            file2_path = fullfile(tempDir2, 'file2.bin');
            fid2 = fopen(file2_path, 'w');
            fwrite(fid2, 'content2', 'char');
            fclose(fid2);
            doc2 = doc2.add_file('filename1.ext', file2_path);
            doc2 = doc2 + S2.newdocument();
            added_doc2 = S2.database_add(doc2);

            % Call the diff function
            report = ndi.fun.dataset.diff(D1, D2);

            % Verify the report
            testCase.verifyEqual(numel(report.documentsInAOnly), 1, 'Should be one document in A only (the session doc).');
            testCase.verifyEqual(numel(report.documentsInBOnly), 1, 'Should be one document in B only (the session doc).');
            testCase.verifyEmpty(report.mismatchedDocuments, 'Mismatched documents should be empty.');
            testCase.verifyEqual(numel(report.fileDifferences), 1, 'Should be one file difference.');
            testCase.verifyEqual(report.fileDifferences(1).documentA_uid, added_doc1.id(), 'The document A UID is incorrect.');
            testCase.verifyEqual(report.fileDifferences(1).documentB_uid, added_doc2.id(), 'The document B UID is incorrect.');
            testCase.verifyNotEmpty(report.fileDifferences(1).documentDiff, 'The document diff should not be empty.');
        end

        function testFileListDifferences(testCase)
            % Test for differences in the list of files associated with a document
        end

        function testFileAccessErrors(testCase)
            % Test for errors when accessing files
        end
    end
end
