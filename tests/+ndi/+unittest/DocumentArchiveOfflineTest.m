classdef DocumentArchiveOfflineTest < matlab.unittest.TestCase
    % ndi.cloud.download.internal.assertSingleArchiveEntry - offline.
    %
    % downloadDocumentCollection used to take unzippedFiles{1} from each
    % chunk's archive and ignore anything else. One JSON per archive is what
    % the server sends today, but nothing guarantees it and a chunk holds up
    % to ChunkSize documents -- 2000 by default. A server that split a chunk
    % would have made the download return fewer documents than were asked
    % for, with no error anywhere: a silent wrong answer, the same shape as
    % VH-Lab/NDI-matlab#945.
    %
    % The check lives in its own function precisely so it can be tested. It
    % is pure -- a cell array in, an error or nothing out -- so this suite
    % needs no credentials and no network, and lives outside
    % tests/+ndi/+unittest/+cloud so it runs in the fast workflow, following
    % SignedURLSetOfflineTest.

    methods (Test)

        function testExactlyOneEntryIsAccepted(testCase)
            testCase.verifyWarningFree(@() ...
                ndi.cloud.download.internal.assertSingleArchiveEntry( ...
                    {'/tmp/chunk1.json'}, 1, 1));
        end

        function testTwoEntriesAreRefused(testCase)
            % The case that would have silently dropped documents.
            testCase.verifyError(@() ...
                ndi.cloud.download.internal.assertSingleArchiveEntry( ...
                    {'/tmp/chunk1.json', '/tmp/chunk2.json'}, 1, 1), ...
                'NDI:Cloud:DocumentDownloadUnexpectedArchive');
        end

        function testZeroEntriesAreRefused(testCase)
            % Previously a bare indexing error from {1}, which said nothing
            % about what had gone wrong.
            testCase.verifyError(@() ...
                ndi.cloud.download.internal.assertSingleArchiveEntry( ...
                    {}, 1, 1), ...
                'NDI:Cloud:DocumentDownloadUnexpectedArchive');
        end

        function testTheErrorNamesTheChunkAndWhatItFound(testCase)
            % A download that refuses has to say which chunk and why, or the
            % next person is where I was: reading a stack trace and guessing.
            try
                ndi.cloud.download.internal.assertSingleArchiveEntry( ...
                    {'/tmp/a.json', '/tmp/b.json'}, 3, 7);
                testCase.verifyFail('expected an error');
            catch ME
                testCase.verifySubstring(ME.message, 'chunk 3 of 7');
                testCase.verifySubstring(ME.message, 'a.json');
                testCase.verifySubstring(ME.message, 'b.json');
            end
        end

        function testTheEmptyCaseSaysNoneRatherThanNothing(testCase)
            try
                ndi.cloud.download.internal.assertSingleArchiveEntry({}, 2, 5);
                testCase.verifyFail('expected an error');
            catch ME
                testCase.verifySubstring(ME.message, 'chunk 2 of 5');
                testCase.verifySubstring(ME.message, 'none');
            end
        end

    end
end
