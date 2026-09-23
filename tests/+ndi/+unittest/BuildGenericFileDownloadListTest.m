classdef BuildGenericFileDownloadListTest < matlab.unittest.TestCase
% BUILDGENERICFILEDOWNLOADLISTTEST - the downloadList-shaping step.
%
% Verifies the shape of records ndi.cloud.download.downloadGenericFiles
% hands to its per-file download loop. The only reason the loop lives in
% its own package function is so the record shape can be pinned here,
% offline, against real ndi.document instances -- see NDI-matlab#962 and
% #963. The one-per-uid ordering, the naming strategies, and the newly
% added `documentId` (which the batch presign cache keys on) all get
% coverage below without going anywhere near the network.

    properties
        Dir % Per-test working folder
    end

    methods (TestMethodSetup)
        function setupWorkingFolder(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.Dir = pwd;
            testCase.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                'MATLAB:structRefFromNonStruct'));
        end
    end

    methods (Access = private)
        function doc = makeGenericFileDoc(testCase, sessionId, docName, originalName)
            % A minimal generic_file document with one attached file, in
            % the shape downloadGenericFiles reads (files.file_info,
            % generic_file.filename, has_files()).
            docPath = fullfile(testCase.Dir, [docName '.bin']);
            fid = fopen(docPath, 'w');
            fwrite(fid, uint8(1:8), 'uint8');
            fclose(fid);

            doc = ndi.document('generic_file', ...
                'base.name', docName, ...
                'generic_file.filename', originalName, ...
                'generic_file.dateCreated', 0, ...
                'generic_file.dateUpdated', 0, ...
                'base.session_id', sessionId);
            doc = doc.add_file('generic_file.ext', docPath);
        end
    end

    methods (Test)

        function testEmptyDocumentsProducesEmptyList(testCase)
            % No documents in, no rows out. Shape is preserved so the
            % downstream `numel(downloadList)` loop is a zero-iteration
            % pass rather than an error.
            list = ndi.cloud.download.internal.buildGenericFileDownloadList( ...
                {}, "original");
            testCase.verifyTrue(isstruct(list));
            testCase.verifyEqual(numel(list), 0);
            testCase.verifyTrue(all(isfield(list, {'uid','filename','documentId'})));
        end

        function testOneDocumentPopulatesEveryField(testCase)
            % The most important assertion in this file: `documentId` is
            % on every entry. That is the field the batch presign cache
            % (#962) keys on; without it, the per-uid fallback runs
            % every time and this PR's whole point evaporates.
            sessionId = char(did.ido.unique_id());
            doc = testCase.makeGenericFileDoc(sessionId, 'a', 'my_original.txt');

            list = ndi.cloud.download.internal.buildGenericFileDownloadList( ...
                {doc}, "original");

            testCase.assertNumElements(list, 1);
            testCase.verifyEqual(list(1).documentId, doc.id());
            testCase.verifyEqual(list(1).filename, 'my_original.txt');
            testCase.verifyNotEmpty(list(1).uid, ...
                'The uid must come from the file_info entry the download loop resolves.');
        end

        function testIdNamingStrategy(testCase)
            % NamingStrategy "id" replaces the filename with the
            % document's own id, preserving the extension. Verifies the
            % strategy is honored inside the extracted helper.
            sessionId = char(did.ido.unique_id());
            doc = testCase.makeGenericFileDoc(sessionId, 'b', 'name.dat');

            list = ndi.cloud.download.internal.buildGenericFileDownloadList( ...
                {doc}, "id");
            testCase.verifyEqual(list(1).filename, [doc.id() '.dat']);
        end

        function testIdOriginalNamingStrategy(testCase)
            % "id_original" carries both the docId prefix and the
            % original name. The concatenation shape is what the caller
            % sees on disk.
            sessionId = char(did.ido.unique_id());
            doc = testCase.makeGenericFileDoc(sessionId, 'c', 'thing.bin');

            list = ndi.cloud.download.internal.buildGenericFileDownloadList( ...
                {doc}, "id_original");
            testCase.verifyEqual(list(1).filename, [doc.id() '_thing.bin']);
        end

        function testMultipleDocumentsProduceMultipleEntries(testCase)
            % Two documents, two rows, each row's documentId matching
            % its own doc. Order matches input document order.
            sessionId = char(did.ido.unique_id());
            docA = testCase.makeGenericFileDoc(sessionId, 'da', 'a.bin');
            docB = testCase.makeGenericFileDoc(sessionId, 'db', 'b.bin');

            list = ndi.cloud.download.internal.buildGenericFileDownloadList( ...
                {docA, docB}, "original");

            testCase.assertNumElements(list, 2);
            testCase.verifyEqual(list(1).documentId, docA.id());
            testCase.verifyEqual(list(2).documentId, docB.id());
            testCase.verifyEqual(list(1).filename, 'a.bin');
            testCase.verifyEqual(list(2).filename, 'b.bin');
        end
    end
end
