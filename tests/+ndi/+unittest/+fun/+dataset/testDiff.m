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

            report = ndi.fun.dataset.diff(testCase.session1, testCase.session2, 'verbose', false);

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

            report = ndi.fun.dataset.diff(testCase.session1, testCase.session2, 'verbose', false);

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

            report = ndi.fun.dataset.diff(testCase.session1, testCase.session2, 'verbose', false);

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

            report = ndi.fun.dataset.diff(testCase.session1, testCase.session2, 'verbose', false);

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

            report = ndi.fun.dataset.diff(testCase.session1, testCase.session2, 'verbose', false);

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

            report = ndi.fun.dataset.diff(testCase.session1, testCase.session2, 'verbose', false);

            testCase.verifyEmpty(report.documentsInAOnly);
            testCase.verifyEmpty(report.documentsInBOnly);
            testCase.verifyEmpty(report.mismatchedDocuments);
            testCase.verifySize(report.mismatchedFiles, [1 1]);
            testCase.verifyEmpty(report.fileListDifferences);
        end

        function testVerboseOption(testCase)
            % Test that the verbose option prints output

            console_output = evalc("ndi.fun.dataset.diff(testCase.session1, testCase.session2, 'verbose', true)");
            testCase.verifyNotEmpty(console_output);
        end

        function testRecheckFileReport(testCase)
            % Test the recheckFileReport option

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

            report1 = ndi.fun.dataset.diff(testCase.session1, testCase.session2, 'verbose', false);
            testCase.verifySize(report1.mismatchedFiles, [1 1]);

            % Now, fix the file
            doc2.delete_binary_file('file.txt');
            doc2.add_binary_file(file1_content, 'file.txt');

            report2 = ndi.fun.dataset.diff(testCase.session1, testCase.session2, 'verbose', false, 'recheckFileReport', report1);
            testCase.verifyEmpty(report2.mismatchedFiles);
        end

        function testRecheckFileReportWithError(testCase)
            % Test the recheckFileReport option with an error

            doc_data = struct('name', 'test_doc', 'value', 1);
            doc1 = ndi.document(doc_data);
            doc2 = ndi.document(doc_data);

            testCase.session1.database_add(doc1);
            testCase.session2.database_add(doc2);

            file1_content = 'hello';
            doc1.add_binary_file(file1_content, 'file.txt');
            doc2.add_binary_file(file1_content, 'file.txt');

            % Create a fake error report
            report1 = struct(...
                'documentsInAOnly', {{}}, ...
                'documentsInBOnly', {{}}, ...
                'mismatchedDocuments', struct('id',{}, 'mismatch',{}), ...
                'mismatchedFiles', struct('uid',{}, 'document_id',{}, 'diff',{}), ...
                'fileListDifferences', struct('id',{},'filesInAOnly',{},'filesInBOnly',{}), ...
                'errors', struct('document_id',{doc1.id()}, 'uid',{'file.txt'}, 'message',{'Simulated error'}) ...
            );

            report2 = ndi.fun.dataset.diff(testCase.session1, testCase.session2, 'verbose', false, 'recheckFileReport', report1);

            testCase.verifyEmpty(report2.errors);
            testCase.verifyEmpty(report2.mismatchedFiles);
        end
    end
end
