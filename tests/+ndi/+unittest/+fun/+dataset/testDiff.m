classdef testDiff < matlab.unittest.TestCase
    properties
        testDir
        session1
        session2
    end

    methods (TestMethodSetup)
        function createTestDir(testCase)
            testCase.testDir = tempname;
            mkdir(testCase.testDir);
            mkdir(fullfile(testCase.testDir, 'session1'));
            mkdir(fullfile(testCase.testDir, 'session2'));

            % Create two sessions to compare
            testCase.session1 = ndi.session.dir('session1', fullfile(testCase.testDir, 'session1'));
            testCase.session2 = ndi.session.dir('session2', fullfile(testCase.testDir, 'session2'));
        end
    end

    methods (TestMethodTeardown)
        function removeTestDir(testCase)
            rmdir(testCase.testDir, 's');
        end
    end

    methods (Test)
        function testIdenticalDatasets(testCase)
            doc_data = struct('name', 'test_doc', 'value', 1);
            doc1 = ndi.document(doc_data);
            doc2 = ndi.document(doc_data);
            testCase.session1.database_add(doc1);
            testCase.session2.database_add(doc2);
            doc1.add_binary_file('hello', 'file1.txt');
            doc2.add_binary_file('hello', 'file1.txt');

            report = ndi.fun.dataset.diff(testCase.session1, testCase.session2, 'verbose', false);

            testCase.verifyEmpty(report.documentsInAOnly);
            testCase.verifyEmpty(report.documentsInBOnly);
            testCase.verifyEmpty(report.mismatchedDocuments);
            testCase.verifyEmpty(report.fileDifferences);
        end

        function testFileMissingInB(testCase)
            doc_data = struct('name', 'test_doc', 'value', 1);
            doc1 = ndi.document(doc_data);
            doc2 = ndi.document(doc_data);
            testCase.session1.database_add(doc1);
            testCase.session2.database_add(doc2);
            doc1.add_binary_file('hello', 'file1.txt');

            report = ndi.fun.dataset.diff(testCase.session1, testCase.session2, 'verbose', false);

            testCase.verifySize(report.fileDifferences, [1 1]);
            testCase.verifyEqual(report.fileDifferences(1).documentA_fname, 'file1.txt');
            testCase.verifyEqual(report.fileDifferences(1).documentB_errormsg, 'not present');
        end

        function testFileContentMismatch(testCase)
            doc_data = struct('name', 'test_doc', 'value', 1);
            doc1 = ndi.document(doc_data);
            doc2 = ndi.document(doc_data);
            testCase.session1.database_add(doc1);
            testCase.session2.database_add(doc2);
            doc1.add_binary_file('hello', 'file1.txt');
            doc2.add_binary_file('goodbye', 'file1.txt');

            report = ndi.fun.dataset.diff(testCase.session1, testCase.session2, 'verbose', false);

            testCase.verifySize(report.fileDifferences, [1 1]);
            testCase.verifyNotEmpty(report.fileDifferences(1).documentDiff);
        end

        function testRecheck(testCase)
            doc_data = struct('name', 'test_doc', 'value', 1);
            doc1 = ndi.document(doc_data);
            doc2 = ndi.document(doc_data);
            testCase.session1.database_add(doc1);
            testCase.session2.database_add(doc2);
            doc1.add_binary_file('hello', 'file1.txt');
            doc2.add_binary_file('goodbye', 'file1.txt');

            report1 = ndi.fun.dataset.diff(testCase.session1, testCase.session2, 'verbose', false);
            testCase.verifySize(report1.fileDifferences, [1 1]);

            % now fix it
            doc2.delete_binary_file('file1.txt');
            doc2.add_binary_file('hello', 'file1.txt');

            report2 = ndi.fun.dataset.diff(testCase.session1, testCase.session2, 'recheckFileReport', report1, 'verbose', false);
            testCase.verifyEmpty(report2.fileDifferences);
        end
    end
end
