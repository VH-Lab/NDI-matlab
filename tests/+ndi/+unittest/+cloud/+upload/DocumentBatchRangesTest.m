classdef DocumentBatchRangesTest < matlab.unittest.TestCase
    % DOCUMENTBATCHRANGESTEST - tests for bulk document upload batching
    %
    % Guards ndi.cloud.upload.internal.documentBatchRanges, which splits a
    % bulk document upload into zips capped by document count AND by JSON
    % size, and the DocumentJson option of zip_documents_for_upload, which
    % must write the same JSON array as encoding the documents itself.
    %
    % Background: a 100000-document upload went out as a single 638 MB JSON
    % file in one zip; the server's ingestion Lambda ran out of scratch disk
    % and ingested nothing.
    %
    % Needs no cloud access.

    methods (Test)

        function testEmptyInputGivesNoBatches(testCase)
            ranges = ndi.cloud.upload.internal.documentBatchRanges([], 10, 100);
            testCase.verifyEmpty(ranges);
            testCase.verifyClass(ranges, 'cell');
        end

        function testCountCapOnly(testCase)
            ranges = ndi.cloud.upload.internal.documentBatchRanges(ones(1,5), 2, Inf);
            testCase.verifyEqual(ranges, {[1 2], [3 4], 5});
        end

        function testByteCapOnly(testCase)
            ranges = ndi.cloud.upload.internal.documentBatchRanges([40 40 40 40], Inf, 100);
            testCase.verifyEqual(ranges, {[1 2], [3 4]});
        end

        function testByteCapIsInclusive(testCase)
            % A batch may hold exactly maxBytes.
            ranges = ndi.cloud.upload.internal.documentBatchRanges([50 50 1], Inf, 100);
            testCase.verifyEqual(ranges, {[1 2], 3});
        end

        function testWhicheverCapComesFirst(testCase)
            ranges = ndi.cloud.upload.internal.documentBatchRanges([10 10 10 90 10], 3, 100);
            testCase.verifyEqual(ranges, {[1 2 3], 4, 5});
        end

        function testOversizedDocumentGetsOwnBatch(testCase)
            ranges = ndi.cloud.upload.internal.documentBatchRanges([10 500 10], Inf, 100);
            testCase.verifyEqual(ranges, {1, 2, 3});
        end

        function testEveryDocumentAppearsOnceInOrder(testCase)
            rng(7);
            sizes = randi([1 300], 1, 1000);
            ranges = ndi.cloud.upload.internal.documentBatchRanges(sizes, 37, 2000);
            testCase.verifyEqual([ranges{:}], 1:1000);
            for k = 1:numel(ranges)
                testCase.verifyLessThanOrEqual(numel(ranges{k}), 37);
                if numel(ranges{k}) > 1
                    testCase.verifyLessThanOrEqual(sum(sizes(ranges{k})), 2000);
                end
            end
        end

        function testZipWithDocumentJsonMatchesEncodedZip(testCase)
            docs = {ndi.document('base'), ndi.document('base'), ndi.document('base')};
            json = cellfun(@(x) did.datastructures.jsonencodenan(x.document_properties), ...
                docs, 'UniformOutput', false);

            folder = tempname;
            mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, 's'));

            [zipA, idsA] = ndi.cloud.upload.internal.zip_documents_for_upload(docs, ...
                'datasetX', 'TargetFolder', folder);
            [zipB, idsB] = ndi.cloud.upload.internal.zip_documents_for_upload(docs, ...
                'datasetX', 'TargetFolder', folder, 'DocumentJson', json);
            testCase.verifyEqual(idsB, idsA);

            decodedA = testCase.readZippedJson(zipA, fullfile(folder, 'a'));
            decodedB = testCase.readZippedJson(zipB, fullfile(folder, 'b'));
            testCase.verifyEqual(decodedB, decodedA);
            % The server requires the top level to be an array of documents.
            testCase.verifyEqual(numel(decodedB), 3);
        end

        function testZipDocumentJsonCountMismatchErrors(testCase)
            docs = {ndi.document('base'), ndi.document('base')};
            testCase.verifyError(@() ndi.cloud.upload.internal.zip_documents_for_upload(docs, ...
                'datasetX', 'DocumentJson', {'{}'}), 'NDI:Cloud:Upload:DocumentJsonMismatch');
        end

        function testDefaultBatchSizePreference(testCase)
            ndi.preferences.reset('Cloud.Upload.Max_Document_Batch_Size');
            testCase.verifyEqual(ndi.preferences.get('Cloud.Upload.Max_Document_Batch_Size'), 50e6);
        end
    end

    methods (Access = private)
        function decoded = readZippedJson(~, zipPath, outFolder)
            files = unzip(zipPath, outFolder);
            decoded = jsondecode(fileread(files{1}));
        end
    end
end
