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
            % Test that two identical datasets produce an empty report

            % Add a document to both sessions
            doc_data = struct('name', 'test_doc', 'value', 1);
            testCase.session1.database_add(ndi.document(doc_data));
            testCase.session2.database_add(ndi.document(doc_data));

            report = ndi.fun.dataset.diff(testCase.session1, testCase.session2);

            testCase.verifyEmpty(report.documentsInAOnly);
            testCase.verifyEmpty(report.documentsInBOnly);
            testCase.verifyEmpty(report.mismatchedDocuments);
            testCase.verifyEmpty(report.mismatchedFiles);
            testCase.verifyEmpty(report.fileListDifferences);
        end

        function testMissingDocument(testCase)
            % Test the case where one dataset is missing a document

            doc_data = struct('name', 'test_doc', 'value', 1);
            testCase.session1.database_add(ndi.document(doc_data));

            report = ndi.fun.dataset.diff(testCase.session1, testCase.session2);

            testCase.verifySize(report.documentsInAOnly, [1 1]);
            testCase.verifyEmpty(report.documentsInBOnly);
            testCase.verifyEmpty(report.mismatchedDocuments);
            testCase.verifyEmpty(report.mismatchedFiles);
            testCase.verifyEmpty(report.fileListDifferences);
        end

        function testMismatchedDocument(testCase)
            % Test the case where a document has different properties

            doc_data1 = struct('name', 'test_doc', 'value', 1);
            doc_data2 = struct('name', 'test_doc', 'value', 2);
            testCase.session1.database_add(ndi.document(doc_data1));
            testCase.session2.database_add(ndi.document(doc_data2));

            report = ndi.fun.dataset.diff(testCase.session1, testCase.session2);

            testCase.verifyEmpty(report.documentsInAOnly);
            testCase.verifyEmpty(report.documentsInBOnly);
            testCase.verifySize(report.mismatchedDocuments, [1 1]);
            testCase.verifyEmpty(report.mismatchedFiles);
            testCase.verifyEmpty(report.fileListDifferences);
        end

        function testReorderedFileList(testCase)
            doc_data = struct('name', 'test_doc', 'value', 1);
            doc1 = ndi.document(doc_data);
            doc2 = ndi.document(doc_data);

            testCase.session1.database_add(doc1);
            testCase.session2.database_add(doc2);

            doc1.add_binary_file('hello', 'file1.txt');
            doc1.add_binary_file('world', 'file2.txt');

            doc2.add_binary_file('world', 'file2.txt');
            doc2.add_binary_file('hello', 'file1.txt');

            report = ndi.fun.dataset.diff(testCase.session1, testCase.session2);

            testCase.verifyEmpty(report.documentsInAOnly);
            testCase.verifyEmpty(report.documentsInBOnly);
            testCase.verifyEmpty(report.mismatchedDocuments);
            testCase.verifyEmpty(report.mismatchedFiles);
            testCase.verifyEmpty(report.fileListDifferences);
        end

        function testSubsetFileList(testCase)
            doc_data = struct('name', 'test_doc', 'value', 1);
            doc1 = ndi.document(doc_data);
            doc2 = ndi.document(doc_data);

            testCase.session1.database_add(doc1);
            testCase.session2.database_add(doc2);

            doc1.add_binary_file('hello', 'file1.txt');
            doc1.add_binary_file('world', 'file2.txt');
            doc2.add_binary_file('hello', 'file1.txt');

            report = ndi.fun.dataset.diff(testCase.session1, testCase.session2);

            testCase.verifyEmpty(report.documentsInAOnly);
            testCase.verifyEmpty(report.documentsInBOnly);
            testCase.verifyEmpty(report.mismatchedDocuments);
            testCase.verifyEmpty(report.mismatchedFiles);
            testCase.verifySize(report.fileListDifferences, [1 1]);
            testCase.verifySize(report.fileListDifferences(1).filesInAOnly, [1 1]);
            testCase.verifyEmpty(report.fileListDifferences(1).filesInBOnly);
        end

        function testMismatchedFiles(testCase)
            % Test the case where a document has different file content

            doc_data = struct('name', 'test_doc', 'value', 1);
            doc1 = ndi.document(doc_data);
            doc2 = ndi.document(doc_data);

            testCase.session1.database_add(doc1);
            testCase.session2.database_add(doc2);

            % Add different file content to each
            file1_content = 'hello';
            file2_content = 'goodbye';

            doc1.add_binary_file(file1_content, 'file.txt');
            doc2.add_binary_file(file2_content, 'file.txt');

            report = ndi.fun.dataset.diff(testCase.session1, testCase.session2);

            testCase.verifyEmpty(report.documentsInAOnly);
            testCase.verifyEmpty(report.documentsInBOnly);
            testCase.verifyEmpty(report.mismatchedDocuments);
            testCase.verifySize(report.mismatchedFiles, [1 1]);
            testCase.verifyEmpty(report.fileListDifferences);
        end
    end
end
