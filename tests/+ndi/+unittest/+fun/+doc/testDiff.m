classdef testDiff < matlab.unittest.TestCase
    % TESTDIFF - Test class for ndi.fun.doc.diff

    properties
        Session
        TempDir
    end

    methods (TestMethodSetup)
        function setup(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            testCase.Session = ndi.session.dir('test_session', testCase.TempDir);
        end
    end

    methods (TestMethodTeardown)
        function teardown(testCase)
            if ~isempty(testCase.Session)
                delete(testCase.Session);
            end
            if exist(testCase.TempDir, 'dir')
                rmdir(testCase.TempDir, 's');
            end
        end
    end

    methods (Test)
        function testIdenticalDocuments(testCase)
            % Create two identical documents
            doc1 = testCase.Session.newdocument('demoNDI', 'base.name', 'MyDoc', 'demoNDI.value', 10);
            doc2 = ndi.document(doc1.document_properties);

            [are_equal, report] = ndi.fun.doc.diff(doc1, doc2);

            testCase.verifyTrue(are_equal, 'Identical documents should be equal.');
            testCase.verifyFalse(report.mismatch, 'Report mismatch flag should be false.');
            testCase.verifyEmpty(report.details, 'Report details should be empty.');
        end

        function testPropertyMismatch(testCase)
            doc1 = testCase.Session.newdocument('demoNDI', 'base.name', 'MyDoc', 'demoNDI.value', 10);
            props = doc1.document_properties;
            props.demoNDI.value = 20;
            doc2 = ndi.document(props);

            [are_equal, report] = ndi.fun.doc.diff(doc1, doc2);

            testCase.verifyFalse(are_equal, 'Documents with different properties should not be equal.');
            testCase.verifyTrue(report.mismatch, 'Report mismatch flag should be true.');
            testCase.verifyTrue(any(contains(report.details, 'properties')), 'Report should mention property mismatch.');
        end

        function testIgnoreFields(testCase)
            doc1 = testCase.Session.newdocument('demoNDI', 'base.name', 'MyDoc', 'demoNDI.value', 10);
            props = doc1.document_properties;
            props.demoNDI.value = 20; % Normally a mismatch
            doc2 = ndi.document(props);

            % Ignore the specific mismatching field
            [are_equal, ~] = ndi.fun.doc.diff(doc1, doc2, 'ignoreFields', {'base.session_id', 'demoNDI.value'});

            testCase.verifyTrue(are_equal, 'Documents should be equal when mismatching field is ignored.');
        end

        function testDifferentIDs(testCase)
            doc1 = testCase.Session.newdocument('demoNDI', 'base.name', 'MyDoc', 'demoNDI.value', 10);
            % Create doc2 completely fresh so it has a different ID
            doc2 = testCase.Session.newdocument('demoNDI', 'base.name', 'MyDoc', 'demoNDI.value', 10);

            % Default behavior: base.id is compared, so they should differ
            [are_equal, ~] = ndi.fun.doc.diff(doc1, doc2);
            testCase.verifyFalse(are_equal, 'Documents with different IDs should differ by default.');

            % Ignore base.id
            [are_equal, ~] = ndi.fun.doc.diff(doc1, doc2, 'ignoreFields', {'base.session_id', 'base.id', 'base.datestamp'});
            testCase.verifyTrue(are_equal, 'Documents should be equal if ID is ignored.');
        end

        function testDependenciesOrderIndependence(testCase)
            doc1 = testCase.Session.newdocument('demoNDI', 'base.name', 'MyDoc', 'demoNDI.value', 10);

            % Add dependencies manually to props structure
            props1 = doc1.document_properties;
            props1.depends_on = [struct('name', 'depA', 'value', 'idA'), struct('name', 'depB', 'value', 'idB')];
            doc1 = ndi.document(props1);

            props2 = doc1.document_properties;
            % Swap order
            props2.depends_on = [struct('name', 'depB', 'value', 'idB'), struct('name', 'depA', 'value', 'idA')];
            doc2 = ndi.document(props2);

            [are_equal, report] = ndi.fun.doc.diff(doc1, doc2);
            testCase.verifyTrue(are_equal, 'Dependency order should not affect equality.');

            % Change a value
            props3 = props2;
            props3.depends_on(1).value = 'idChanged';
            doc3 = ndi.document(props3);

            [are_equal, report] = ndi.fun.doc.diff(doc1, doc3);
            testCase.verifyFalse(are_equal, 'Dependency value mismatch should be detected.');
            testCase.verifyTrue(any(contains(report.details, 'Dependencies')), 'Report should mention dependencies.');
        end

        function testFileListsOrderIndependence(testCase)
            % Note: this only tests the file LIST, not binary content
            doc1 = testCase.Session.newdocument('demoNDI', 'base.name', 'MyDoc', 'demoNDI.value', 10);

            % Mock up file structure since adding real files requires them to exist
            props1 = doc1.document_properties;
            props1.files = struct('file_list', {{'fileA.txt', 'fileB.txt'}}, 'file_info', []);
            doc1 = ndi.document(props1);

            props2 = props1;
            props2.files.file_list = {'fileB.txt', 'fileA.txt'}; % Swapped
            doc2 = ndi.document(props2);

            [are_equal, ~] = ndi.fun.doc.diff(doc1, doc2, 'checkFileList', true);
            testCase.verifyTrue(are_equal, 'File list order should not affect equality.');

            props3 = props1;
            props3.files.file_list = {'fileA.txt'}; % Missing one
            doc3 = ndi.document(props3);

            [are_equal, report] = ndi.fun.doc.diff(doc1, doc3, 'checkFileList', true);
            testCase.verifyFalse(are_equal, 'Mismatched file lists should be detected.');
            testCase.verifyTrue(any(contains(report.details, 'File lists')), 'Report should mention file lists.');

            % Test checkFileList = false
            [are_equal, ~] = ndi.fun.doc.diff(doc1, doc3, 'checkFileList', false);
            testCase.verifyTrue(are_equal, 'Should be equal if checkFileList is false and other props match.');
        end

        function testBinaryFileComparison(testCase)
            % Create documents with files
            doc1 = testCase.Session.newdocument('demoNDI', 'base.name', 'MyDoc', 'demoNDI.value', 10);
            file1_path = fullfile(testCase.TempDir, 'file1.bin');
            fid1 = fopen(file1_path, 'w');
            fwrite(fid1, 'content1', 'char');
            fclose(fid1);
            doc1 = doc1.add_file('filename1.ext', file1_path);
            testCase.Session.database_add(doc1);

            % Clone doc1 to doc2 in a "second session" (using same session for simplicity of file access, but different docs)
            % Ideally we would use two sessions, but we can mock it by passing the same session twice
            % However, we need the documents to be distinct objects.
            doc2 = ndi.document(doc1.document_properties);

            % Create a different file for doc2
            file2_path = fullfile(testCase.TempDir, 'file2.bin');
            fid2 = fopen(file2_path, 'w');
            fwrite(fid2, 'content2', 'char'); % Different content
            fclose(fid2);

            % We need to hack the file location for doc2 because reset_file_info clears it
            doc2 = doc2.reset_file_info();
            doc2 = doc2.add_file('filename1.ext', file2_path);

            % Add doc2 to database so we can open it
            % Note: In real life we can't add same ID twice. Here we just need the file access to work.
            % But database_openbinarydoc works on doc objects.
            % Let's use a second session to be proper.
            tempDir2 = [testCase.TempDir '_2'];
            mkdir(tempDir2);
            S2 = ndi.session.dir('test_session_2', tempDir2);
            S2.database_add(doc2);

            % Test mismatch detection
            [are_equal, report] = ndi.fun.doc.diff(doc1, doc2, 'checkFiles', true, 'session1', testCase.Session, 'session2', S2);
            testCase.verifyFalse(are_equal, 'Files with different content should be detected.');
            testCase.verifyTrue(any(contains(report.details, 'content mismatch')), 'Report should mention content mismatch.');

            % Test identical files
            file3_path = fullfile(tempDir2, 'file3.bin');
            fid3 = fopen(file3_path, 'w');
            fwrite(fid3, 'content1', 'char'); % Same content as file1
            fclose(fid3);
            doc3 = doc2.reset_file_info();
            doc3 = doc3.add_file('filename1.ext', file3_path);
            S2.database_rm(doc2.id()); % Remove old doc2 to avoid conflict
            S2.database_add(doc3);

            [are_equal, ~] = ndi.fun.doc.diff(doc1, doc3, 'checkFiles', true, 'session1', testCase.Session, 'session2', S2);
            testCase.verifyTrue(are_equal, 'Files with identical content should match.');

            % Clean up
            rmdir(tempDir2, 's');
        end
    end
end
