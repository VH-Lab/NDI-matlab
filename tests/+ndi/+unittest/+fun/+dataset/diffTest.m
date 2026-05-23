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

            % Setup dataset and session and make a copy
            mkdir(fullfile(tempDir1, 'session'));
            S1 = ndi.session.dir('ref1', fullfile(tempDir1, 'session'));
            D1 = ndi.dataset.dir('dref1', tempDir1);

            % Add document
            doc1_base = S1.newdocument('demoNDI', 'base.name', 'test doc', 'demoNDI.value', 1);
            doc1 = doc1_base + S1.newdocument();
            S1.database_add(doc1);

            D1.add_linked_session(S1);

            % make a copy
            copyfile(tempDir1,tempDir2);
            D2 = ndi.dataset.dir(tempDir2);

            % Call the diff function
            report = ndi.fun.dataset.diff(D1, D2);

            % Verify the report is empty - accounting for the session document
            testCase.verifyEqual(numel(report.documentsInAOnly), 0, 'Should be zero.');
            testCase.verifyEqual(numel(report.documentsInBOnly), 0, 'Should be zero.');
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

            % Setup dataset and session and make a copy
            mkdir(fullfile(tempDir1, 'session'));
            S1 = ndi.session.dir('ref1', fullfile(tempDir1, 'session'));
            D1 = ndi.dataset.dir('dref1', tempDir1);

            D1.add_ingested_session(S1);
            S1 = D1.open_session(S1.id());

            % make a copy
            copyfile(tempDir1,tempDir2);
            D2 = ndi.dataset.dir(tempDir2);            

            % Add a document only to the first dataset
            doc1 = S1.newdocument('demoNDI', 'base.name', 'doc in A only', 'demoNDI.value', 1);
            doc1 = doc1 + S1.newdocument();
            S1.database_add(doc1);

            % Call the diff function
            report = ndi.fun.dataset.diff(D1, D2);

            % Verify the report
            testCase.verifyEqual(numel(report.documentsInAOnly), 1, 'Should be 1 documents in A only.');
            testCase.verifyTrue(any(strcmp(doc1.id(), report.documentsInAOnly)), 'The added document was not found in A only.');
            testCase.verifyEqual(numel(report.documentsInBOnly), 0, 'Should be zero documents in B only.');
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

            % Setup dataset and session and make a copy
            mkdir(fullfile(tempDir1, 'session'));
            S1 = ndi.session.dir('ref1', fullfile(tempDir1, 'session'));
            D1 = ndi.dataset.dir('dref1', tempDir1);

            D1.add_ingested_session(S1);

            % make a copy
            copyfile(tempDir1,tempDir2);
            D2 = ndi.dataset.dir(tempDir2); 

            % Add a document only to the second dataset
            [~,sessions] = D2.session_list();

            S2 = D2.open_session(sessions{1});

            doc2 = S2.newdocument('demoNDI', 'base.name', 'doc in B only', 'demoNDI.value', 1);
            doc2 = doc2 + S2.newdocument();
            S2.database_add(doc2);

            % Call the diff function
            report = ndi.fun.dataset.diff(D1, D2);

            % Verify the report
            testCase.verifyEqual(numel(report.documentsInAOnly), 0, 'Should be zero documents in A only.');
            testCase.verifyEqual(numel(report.documentsInBOnly), 1, 'Should be 1 documents in B only.');
            testCase.verifyTrue(any(strcmp(doc2.id(), report.documentsInBOnly)), 'The added document was not found in B only.');
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

            % Setup dataset and session and make a copy
            mkdir(fullfile(tempDir1, 'session'));
            S1 = ndi.session.dir('ref1', fullfile(tempDir1, 'session'));
            D1 = ndi.dataset.dir('dref1', tempDir1);

            D1.add_ingested_session(S1);
            S1 = D1.open_session(S1.id());

            % make a copy
            copyfile(tempDir1,tempDir2);

            % Add documents with same ID but different properties
            doc1 = S1.newdocument('demoNDI', 'base.name', 'test doc', 'demoNDI.value', 1);
            doc1 = doc1 + S1.newdocument();
            S1.database_add(doc1);

            doc2_structure = doc1.document_properties;
            doc2_structure.demoNDI.value = 2;
            doc2_structure.base.session_id = S1.id();

            doc2 = ndi.document(doc2_structure);

            D2 = ndi.dataset.dir(tempDir2); 
            [~,sessions] = D2.session_list();
            S2 = D2.open_session(sessions{1});

            S2.database_add(doc2);

            % Call the diff function
            report = ndi.fun.dataset.diff(D1, D2);

            % Verify the report
            testCase.verifyEqual(numel(report.documentsInAOnly), 0, 'Doc IDs should be the same.');
            testCase.verifyEqual(numel(report.documentsInBOnly), 0, 'Doc IDs should be the same.');
            testCase.verifyEqual(numel(report.mismatchedDocuments), 1, 'Should be one mismatched document.');
            testCase.verifyEqual(report.mismatchedDocuments(1).id, doc1.id(), 'The mismatched document ID is incorrect.');
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

            % Setup dataset and session and make a copy
            mkdir(fullfile(tempDir1, 'session'));
            S1 = ndi.session.dir('ref1', fullfile(tempDir1, 'session'));
            D1 = ndi.dataset.dir('dref1', tempDir1);

            D1.add_ingested_session(S1);
            S1 = D1.open_session(S1.id());

            % make a copy
            copyfile(tempDir1,tempDir2);

            % Add documents with files that have different content
            doc1 = S1.newdocument('demoNDI', 'base.name', 'test doc', 'demoNDI.value', 1);
            file1_path = fullfile(tempDir1, 'file1.bin');
            fid1 = fopen(file1_path, 'w');
            fwrite(fid1, 'content1', 'char');
            fclose(fid1);
            doc1 = doc1.add_file('filename1.ext', file1_path);
            doc1 = doc1 + S1.newdocument();
            S1.database_add(doc1);

            doc2_structure = doc1.document_properties;
            doc2_structure.demoNDI.value = 2;
            doc2_structure.base.session_id = S1.id();

            doc2 = ndi.document(doc2_structure);
            doc2 = doc2.reset_file_info();

            file2_path = fullfile(tempDir2, 'file2.bin');
            fid2 = fopen(file2_path, 'w');
            fwrite(fid2, 'content2', 'char');
            fclose(fid2);
            doc2 = doc2.add_file('filename1.ext', file2_path);

            D2 = ndi.dataset.dir(tempDir2); 
            [~,sessions] = D2.session_list();
            S2 = D2.open_session(sessions{1});
            S2.database_add(doc2);

            % Call the diff function
            report = ndi.fun.dataset.diff(D1, D2);

            % Verify the report
            testCase.verifyEqual(numel(report.documentsInAOnly), 0, 'Doc IDs should be the same.');
            testCase.verifyEqual(numel(report.documentsInBOnly), 0, 'Doc IDs should be the same.');
            testCase.verifyEqual(numel(report.fileDifferences), 1, 'Should be one file difference.');
            testCase.verifyEqual(report.fileDifferences(1).documentA_uid, doc1.id(), 'The document A UID is incorrect.');
            testCase.verifyEqual(report.fileDifferences(1).documentB_uid, doc2.id(), 'The document B UID is incorrect.');
            testCase.verifyNotEmpty(report.fileDifferences(1).documentDiff, 'The document diff should not be empty.');
        end
    end
end
