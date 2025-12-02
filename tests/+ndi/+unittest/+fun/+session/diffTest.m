classdef diffTest < matlab.unittest.TestCase
    % DIFFTEST - Test for ndi.fun.session.diff
    %

    methods (Test)
        function testIdenticalSessions(testCase)
            % Create temporary directories
            tempDir1 = tempname;
            mkdir(tempDir1);
            cleanup1 = onCleanup(@() rmdir(tempDir1, 's'));

            % Setup S1
            S1 = ndi.session.dir('ref1', tempDir1);

            % Add a doc
            fixed_id = '12345_fixed_id_for_testing';
            doc1 = S1.newdocument('demoNDI', 'base.id', fixed_id, 'base.name', 'test doc', 'demoNDI.value', 1);
            S1.database_add(doc1);

            % Create S2 as a COPY of S1
            tempDir2 = tempname;
            % To copy efficiently, we must copy the content.
            copyfile(tempDir1, tempDir2);
            cleanup2 = onCleanup(@() rmdir(tempDir2, 's'));

            S2 = ndi.session.dir('ref1', tempDir2);

            % Ensure IDs match (they should if logic works)
            testCase.verifyEqual(S1.id(), S2.id(), 'Session IDs should match after copy');

            % Call the diff function
            report = ndi.fun.session.diff(S1, S2);

            % Verify the report is empty of OUR documents
            testCase.verifyFalse(any(strcmp(doc1.id(), report.documentsInAOnly)), 'Our doc should not be in A only.');
            testCase.verifyFalse(any(strcmp(doc1.id(), report.documentsInBOnly)), 'Our doc should not be in B only.');

            % For identical sessions (copies), mismatchedDocuments should be empty for our doc
            mismatchedIDs = {report.mismatchedDocuments.id};
            testCase.verifyFalse(any(strcmp(doc1.id(), mismatchedIDs)), 'Our doc should not have a mismatch.');

            % Also check file differences for our doc
            fileDiffIDs = {report.fileDifferences.documentA_uid};
            testCase.verifyFalse(any(strcmp(doc1.id(), fileDiffIDs)), 'Our doc should not have file differences.');
        end

        function testDocumentsInAOnly(testCase)
            % Create temporary directories
            tempDir1 = tempname;
            mkdir(tempDir1);
            cleanup1 = onCleanup(@() rmdir(tempDir1, 's'));

            % Setup S1
            S1 = ndi.session.dir('ref1', tempDir1);

            % Create S2 as a copy of S1 (initially identical)
            tempDir2 = tempname;
            copyfile(tempDir1, tempDir2);
            cleanup2 = onCleanup(@() rmdir(tempDir2, 's'));
            S2 = ndi.session.dir('ref1', tempDir2);

            % Add a document only to S1
            doc1 = S1.newdocument('demoNDI', 'base.name', 'doc in A only', 'demoNDI.value', 1);
            S1.database_add(doc1);

            % Call the diff function
            report = ndi.fun.session.diff(S1, S2);

            % Verify the report
            % Check that doc1 is in A only
            testCase.verifyTrue(any(strcmp(doc1.id(), report.documentsInAOnly)), 'The added document was not found in A only.');
            % Check that doc1 is NOT in B only
            testCase.verifyFalse(any(strcmp(doc1.id(), report.documentsInBOnly)), 'The added document was found in B only.');

            % Check that NO common docs have mismatches (doc1 is not common)
            % We generally don't check verifyEmpty(mismatchedDocuments) because internal docs might mismatch if session logic changes.
            % But we can verify that doc1 is NOT in mismatched documents (which implies it's not in both).
            mismatchedIDs = {report.mismatchedDocuments.id};
            testCase.verifyFalse(any(strcmp(doc1.id(), mismatchedIDs)), 'Our doc should not have a mismatch.');
        end

        function testDocumentsInBOnly(testCase)
            % Create temporary directories
            tempDir1 = tempname;
            mkdir(tempDir1);
            cleanup1 = onCleanup(@() rmdir(tempDir1, 's'));

            % Setup S1
            S1 = ndi.session.dir('ref1', tempDir1);

            % Create S2 as a copy
            tempDir2 = tempname;
            copyfile(tempDir1, tempDir2);
            cleanup2 = onCleanup(@() rmdir(tempDir2, 's'));
            S2 = ndi.session.dir('ref1', tempDir2);

            % Add a document only to S2
            doc2 = S2.newdocument('demoNDI', 'base.name', 'doc in B only', 'demoNDI.value', 1);
            S2.database_add(doc2);

            % Call the diff function
            report = ndi.fun.session.diff(S1, S2);

            % Verify the report
            testCase.verifyTrue(any(strcmp(doc2.id(), report.documentsInBOnly)), 'The added document was not found in B only.');
            testCase.verifyFalse(any(strcmp(doc2.id(), report.documentsInAOnly)), 'The added document was found in A only.');

            % Verify doc2 is not mismatched
            mismatchedIDs = {report.mismatchedDocuments.id};
            testCase.verifyFalse(any(strcmp(doc2.id(), mismatchedIDs)), 'Our doc should not have a mismatch.');
        end

        function testMismatchedDocuments(testCase)
            % Create temporary directories
            tempDir1 = tempname;
            mkdir(tempDir1);
            cleanup1 = onCleanup(@() rmdir(tempDir1, 's'));

            S1 = ndi.session.dir('ref1', tempDir1);

            fixed_id = '99999_mismatch_test_id';
            doc1 = S1.newdocument('demoNDI', 'base.id', fixed_id, 'base.name', 'test doc', 'demoNDI.value', 1);
            S1.database_add(doc1);

            % Create S2 as copy
            tempDir2 = tempname;
            copyfile(tempDir1, tempDir2);
            cleanup2 = onCleanup(@() rmdir(tempDir2, 's'));
            S2 = ndi.session.dir('ref1', tempDir2);

            % Modify doc in S2
            % First remove the old one (which is identical to S1's)
            S2.database_rm(fixed_id);

            % Add modified version
            doc2_props = doc1.document_properties;
            doc2_props.demoNDI.value = 2;
            doc2 = ndi.document(doc2_props);
            % ID is preserved in properties
            S2.database_add(doc2);

            % Call the diff function
            report = ndi.fun.session.diff(S1, S2);

            % Verify the report
            testCase.verifyFalse(any(strcmp(fixed_id, report.documentsInAOnly)), 'Doc should not be in A only.');
            testCase.verifyFalse(any(strcmp(fixed_id, report.documentsInBOnly)), 'Doc should not be in B only.');

            % Find mismatch for this ID
            mismatchedIDs = {report.mismatchedDocuments.id};
            testCase.verifyTrue(any(strcmp(fixed_id, mismatchedIDs)), 'Should be one mismatched document.');
        end

        function testMismatchedFiles(testCase)
            % Create temporary directories
            tempDir1 = tempname;
            mkdir(tempDir1);
            cleanup1 = onCleanup(@() rmdir(tempDir1, 's'));

            S1 = ndi.session.dir('ref1', tempDir1);

            fixed_id = '88888_file_test_id';
            file1_path = fullfile(tempDir1, 'file1.bin');
            fid1 = fopen(file1_path, 'w');
            fwrite(fid1, 'content1', 'char');
            fclose(fid1);

            doc1 = S1.newdocument('demoNDI', 'base.id', fixed_id, 'base.name', 'test doc', 'demoNDI.value', 1);
            doc1 = doc1.add_file('filename1.ext', file1_path);
            S1.database_add(doc1);

            % Create S2 as copy
            tempDir2 = tempname;
            copyfile(tempDir1, tempDir2);
            cleanup2 = onCleanup(@() rmdir(tempDir2, 's'));
            S2 = ndi.session.dir('ref1', tempDir2);

            % In S2, modify the file content.
            % We must update S2's doc to point to a new file in S2's dir because copyfile doesn't update paths.
            S2.database_rm(fixed_id);

            file2_path = fullfile(tempDir2, 'file2.bin');
            fid2 = fopen(file2_path, 'w');
            fwrite(fid2, 'content2', 'char');
            fclose(fid2);

            doc2_props = doc1.document_properties;
            % Reset file info
            doc2 = ndi.document(doc2_props);
            doc2 = doc2.reset_file_info();
            doc2 = doc2.add_file('filename1.ext', file2_path);

            S2.database_add(doc2);

            % Now diff(S1, S2).
            % Doc IDs match.
            % File names match ('filename1.ext').
            % Content differs.

            report = ndi.fun.session.diff(S1, S2);

            % Verify the report
            fileDiffs = report.fileDifferences;
            if isempty(fileDiffs)
                testCase.verifyFail('Should be one file difference.');
            else
                % Check if our doc is in the diff
                found = false;
                for i=1:numel(fileDiffs)
                    if strcmp(fileDiffs(i).documentA_uid, fixed_id)
                        found = true;
                        testCase.verifyNotEmpty(fileDiffs(i).documentDiff, 'The document diff should not be empty.');
                    end
                end
                testCase.verifyTrue(found, 'File difference for fixed_id not reported.');
            end
        end
    end
end
