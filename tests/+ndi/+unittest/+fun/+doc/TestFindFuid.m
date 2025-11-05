classdef TestFindFuid < matlab.unittest.TestCase
    % TESTFINDFUID - Test for ndi.fun.doc.findFuid
    %

    properties
        tempDir
        S
        D
        known_fuid
        test_doc
        test_filename
    end

    methods (TestMethodSetup)
        function setupTest(testCase)
            testCase.tempDir = tempname;
            mkdir(testCase.tempDir);

            sessionDir = fullfile(testCase.tempDir, 'session1');
            mkdir(sessionDir);

            testCase.S = ndi.session.dir('ref1', sessionDir);
            testCase.D = ndi.dataset.dir('dref1', testCase.tempDir);
            testCase.D.add_linked_session(testCase.S);

            % Create a test document with a file
            test_doc_ndi = ndi.document('demoNDI');

            % Create a dummy file
            testCase.test_filename = 'dummy.txt';
            dummy_filepath = fullfile(testCase.tempDir, testCase.test_filename);
            fid = fopen(dummy_filepath, 'w');
            fprintf(fid, 'some data');
            fclose(fid);

            test_doc_ndi = test_doc_ndi.add_file('text_file', dummy_filepath, 'ingest', 1, 'delete_original', 0);

            % Store the known FUID and add the doc to the database
            testCase.known_fuid = test_doc_ndi.document_properties.files.file_info(1).locations(1).uid;
            testCase.test_doc = testCase.S.database_add(test_doc_ndi);
        end
    end

    methods (TestMethodTeardown)
        function teardownTest(testCase)
            if exist(testCase.tempDir, 'dir')
                rmdir(testCase.tempDir, 's');
            end
        end
    end

    methods (Test)
        function testFindFuid_Success(testCase)
            % Test finding a document by a known FUID

            [found_doc, found_filename] = ndi.fun.doc.findFuid(testCase.D, testCase.known_fuid);

            testCase.verifyNotEmpty(found_doc, 'Should have found a document.');
            testCase.verifyEqual(found_doc.id(), testCase.test_doc.id(), 'The found document ID does not match the expected ID.');
            testCase.verifyEqual(found_filename, 'text_file', 'The found filename does not match the expected filename.');
        end

        function testFindFuid_NotFound(testCase)
            % Test searching for a non-existent FUID

            non_existent_fuid = 'fuid-that-does-not-exist';
            [found_doc, found_filename] = ndi.fun.doc.findFuid(testCase.D, non_existent_fuid);

            testCase.verifyEmpty(found_doc, 'Should not have found a document for a non-existent FUID.');
            testCase.verifyEmpty(found_filename, 'Filename should be empty for a non-existent FUID.');
        end

        function testFindFuid_InSession(testCase)
            % Test finding a document by searching the session directly

            [found_doc, found_filename] = ndi.fun.doc.findFuid(testCase.S, testCase.known_fuid);

            testCase.verifyNotEmpty(found_doc, 'Should have found a document in the session.');
            testCase.verifyEqual(found_doc.id(), testCase.test_doc.id(), 'The found document ID does not match the expected ID.');
            testCase.verifyEqual(found_filename, 'text_file', 'The found filename does not match the expected filename.');
        end
    end
end
