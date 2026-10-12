classdef FileCrc32OfflineTest < matlab.unittest.TestCase
% FILECRC32OFFLINETEST - offline tests for file CRC-32 support (NDI Cloud #162).
%
% Covers the parts that need no live cloud: computing a local file's CRC-32
% in the cloud's encoding, the lookupFiles request and response handling,
% the checksumCRC32 query parameter on the upload URL request, and the
% signed-url-set fileInfo field.
%
% The live round trip (upload with a checksum, then read it back from
% getFileDetails, listFiles and lookupFiles) is in
% tests/+ndi/+unittest/+cloud/FilesTest.m.
%
% Expected CRC values were computed with Python's zlib.crc32, the same
% CRC-32 (IEEE) S3 uses.
%
% Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    methods (Static, Access = private)
        function filePath = writeTempFile(testCase, bytes)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            filePath = fullfile(folder, 'payload.bin');
            fid = fopen(filePath, 'w');
            fwrite(fid, uint8(bytes), 'uint8');
            fclose(fid);
        end
    end

    methods (Test)

        % ---- encoding -----------------------------------------------------

        function testCrc32ToBase64IsBigEndian(testCase)
            testCase.verifyEqual(ndi.fun.file.crc32ToBase64(hex2dec('3610A686')), 'NhCmhg==');
            testCase.verifyEqual(ndi.fun.file.crc32ToBase64(0), 'AAAAAA==');
            testCase.verifyEqual(ndi.fun.file.crc32ToBase64(4294967295), '/////w==');
        end

        function testCrc32ToBase64RejectsOutOfRange(testCase)
            testCase.verifyError(@() ndi.fun.file.crc32ToBase64(-1), ?MException);
            testCase.verifyError(@() ndi.fun.file.crc32ToBase64(2^32), ?MException);
        end

        % ---- local file CRC ----------------------------------------------

        function testCrc32OfKnownText(testCase)
            p = ndi.unittest.FileCrc32OfflineTest.writeTempFile(testCase, double('hello'));
            testCase.verifyEqual(ndi.fun.file.crc32(p), 'NhCmhg==');
        end

        function testCrc32OfEmptyFile(testCase)
            p = ndi.unittest.FileCrc32OfflineTest.writeTempFile(testCase, []);
            testCase.verifyEqual(ndi.fun.file.crc32(p), 'AAAAAA==');
        end

        function testCrc32OfBytesWithTheHighBitSet(testCase)
            % Bytes 128-255 are read as negative int8 and handed to Java as
            % byte[]; the CRC must still be of the unsigned bytes.
            p = ndi.unittest.FileCrc32OfflineTest.writeTempFile(testCase, 0:255);
            testCase.verifyEqual(ndi.fun.file.crc32(p), 'KQWMcw==');
        end

        function testCrc32DoesNotDependOnChunkSize(testCase)
            p = ndi.unittest.FileCrc32OfflineTest.writeTempFile(testCase, ...
                double('The quick brown fox jumps over the lazy dog'));
            testCase.verifyEqual(ndi.fun.file.crc32(p), 'QU+jOQ==');
            testCase.verifyEqual(ndi.fun.file.crc32(p, 'chunkSize', 1), 'QU+jOQ==');
            testCase.verifyEqual(ndi.fun.file.crc32(p, 'chunkSize', 7), 'QU+jOQ==');
        end

        function testCrc32AcrossManyChunks(testCase)
            p = ndi.unittest.FileCrc32OfflineTest.writeTempFile(testCase, repmat(0:255, 1, 1000));
            testCase.verifyEqual(ndi.fun.file.crc32(p, 'chunkSize', 4096), '/HCvGg==');
        end

        % ---- upload URL request ------------------------------------------

        function testUploadUrlCarriesAnEncodedChecksum(testCase)
            call = ndi.cloud.api.implementation.files.GetFileUploadURL(...
                'cloudDatasetID', "ds1", 'cloudFileUID', "uid1", ...
                'checksumCRC32', "QU+jOQ==");
            u = string(call.buildURL("org1"));
            testCase.verifyTrue(contains(u, "/datasets/org1/ds1/files/uid1"));
            testCase.verifyTrue(contains(u, "checksumCRC32="));
            % An unencoded '+' would reach the server as a space.
            testCase.verifyFalse(contains(u, "QU+jOQ"), ...
                'the base64 checksum must be percent-encoded');
        end

        function testUploadUrlWithoutChecksumHasNoQuery(testCase)
            call = ndi.cloud.api.implementation.files.GetFileUploadURL(...
                'cloudDatasetID', "ds1", 'cloudFileUID', "uid1");
            u = string(call.buildURL("org1"));
            testCase.verifyFalse(contains(u, "checksumCRC32"));
        end

        % ---- PUT with a checksum header ----------------------------------

        function testPutSendsTheChecksumHeader(testCase)
            p = ndi.unittest.FileCrc32OfflineTest.writeTempFile(testCase, double('hello'));
            call = ndi.cloud.api.implementation.files.PutFiles(...
                'preSignedURL', "https://bucket.s3.amazonaws.com/k?X-Amz-Signature=abc", ...
                'filePath', p, 'checksumCRC32', "NhCmhg==");
            cmd = string(call.curlArguments());
            testCase.verifyTrue(contains(cmd, '-H "x-amz-checksum-crc32: NhCmhg=="'), ...
                'the signed x-amz-checksum-crc32 header must be sent');
        end

        function testPutWithoutChecksumSendsNoHeader(testCase)
            p = ndi.unittest.FileCrc32OfflineTest.writeTempFile(testCase, double('hello'));
            call = ndi.cloud.api.implementation.files.PutFiles(...
                'preSignedURL', "https://bucket.s3.amazonaws.com/k?X-Amz-Signature=abc", ...
                'filePath', p);
            testCase.verifyFalse(contains(string(call.curlArguments()), "x-amz-checksum-crc32"));
        end

        function testPutRefusesAMalformedChecksum(testCase)
            % The value goes into a shell command, so only a real base64
            % CRC-32 is accepted.
            p = ndi.unittest.FileCrc32OfflineTest.writeTempFile(testCase, double('hello'));
            testCase.verifyError(@() ndi.cloud.api.implementation.files.PutFiles(...
                'preSignedURL', "https://bucket.s3.amazonaws.com/k", ...
                'filePath', p, 'checksumCRC32', "abc"" && rm -rf x"), ...
                'NDI:CloudApi:PutFiles:InvalidChecksum');
        end

        % ---- lookupFiles request -----------------------------------------

        function testLookupEndpoint(testCase)
            u = ndi.cloud.api.url('lookup_dataset_files', 'dataset_id', "ds1");
            testCase.verifyTrue(endsWith(string(u), "/datasets/ds1/files/lookup"));
        end

        function testLookupBodyIsAJsonArrayEvenForOneUid(testCase)
            call = ndi.cloud.api.implementation.files.LookupFiles(...
                'cloudDatasetID', "ds1", 'cloudFileUIDs', "4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6");
            txt = jsonencode(call.requestBody());
            decoded = jsondecode(txt);
            testCase.verifyTrue(iscell(decoded.uids) || numel(string(decoded.uids)) > 1, ...
                'uids must encode as a JSON array, not a bare string');
            testCase.verifyEqual(unique(string(decoded.uids)), "4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6");
        end

        function testLookupBodyKeepsEveryUid(testCase)
            uids = ["a1", "b2", "c3"];
            call = ndi.cloud.api.implementation.files.LookupFiles(...
                'cloudDatasetID', "ds1", 'cloudFileUIDs', uids);
            decoded = jsondecode(jsonencode(call.requestBody()));
            testCase.verifyEqual(reshape(string(decoded.uids), 1, []), uids);
        end

        function testLookupRefusesMoreThanTheServerLimit(testCase)
            uids = "u" + string(1:5001);
            testCase.verifyError(@() ndi.cloud.api.implementation.files.LookupFiles(...
                'cloudDatasetID', "ds1", 'cloudFileUIDs', uids), ...
                'NDI:CloudApi:LookupFiles:TooManyUids');
        end

        function testLookupRefusesNoUids(testCase)
            testCase.verifyError(@() ndi.cloud.api.implementation.files.LookupFiles(...
                'cloudDatasetID', "ds1", 'cloudFileUIDs', strings(1, 0)), ...
                'NDI:CloudApi:LookupFiles:NoUids');
        end

        function testLookupFilesWithNoUidsMakesNoCall(testCase)
            % No request is sent, so this needs no credentials.
            [b, answer, resp, url] = ndi.cloud.api.files.lookupFiles("ds1", strings(1, 0));
            testCase.verifyTrue(b);
            testCase.verifyEmpty(answer.files);
            testCase.verifyEmpty(answer.missing);
            testCase.verifyEmpty(resp);
            testCase.verifyEmpty(url);
        end

        % ---- lookupFiles response ----------------------------------------

        function testLookupResultNormalizesFilesAndMissing(testCase)
            txt = ['{"files":[' ...
                '{"uid":"4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6","uploaded":true,"size":5,"crc32":"NhCmhg=="},' ...
                '{"uid":"aa","uploaded":false,"size":0,"crc32":null}],' ...
                '"missing":["zz"]}'];
            r = ndi.cloud.api.implementation.files.lookupFilesResult(jsondecode(txt));

            testCase.verifySize(r.files, [2 1]);
            testCase.verifyEqual(r.files(1).uid, '4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6');
            testCase.verifyEqual(r.files(1).uploaded, true);
            testCase.verifyEqual(r.files(1).size, 5);
            testCase.verifyEqual(r.files(1).crc32, 'NhCmhg==');
            testCase.verifyEqual(r.files(2).uploaded, false);
            testCase.verifyEqual(r.files(2).crc32, '', 'a null crc32 becomes ''''');
            testCase.verifyEqual(r.missing, "zz");
        end

        function testLookupResultWithNothingFound(testCase)
            r = ndi.cloud.api.implementation.files.lookupFilesResult(...
                jsondecode('{"files":[],"missing":["a","b"]}'));
            testCase.verifyEmpty(r.files);
            testCase.verifyTrue(all(isfield(r.files, {'uid','uploaded','size','crc32'})));
            testCase.verifyEqual(r.missing, ["a" "b"]);
        end

        function testLookupResultWithNothingMissing(testCase)
            r = ndi.cloud.api.implementation.files.lookupFilesResult(...
                jsondecode('{"files":[{"uid":"a","uploaded":true,"size":1,"crc32":"AAAAAA=="}],"missing":[]}'));
            testCase.verifySize(r.files, [1 1]);
            testCase.verifyEqual(r.missing, strings(1, 0));
        end

        % ---- signed-url-set fileInfo -------------------------------------

        function testSignedURLSetPageCarriesFileInfo(testCase)
            uid = '4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6';
            txt = ['{"files":{"' uid '":"https://s3/x"},' ...
                   '"fileInfo":[{"uid":"' uid '","uploaded":true,"size":5,"crc32":"NhCmhg=="}],' ...
                   '"nextCursor":null}'];
            page = ndi.cloud.api.implementation.files.signedURLSetPage(jsondecode(txt), txt);

            testCase.verifySize(page.fileInfo, [1 1]);
            testCase.verifyEqual(page.fileInfo(1).uid, uid, ...
                'a uid starting with a digit must survive (it is a value, not a key)');
            testCase.verifyEqual(page.fileInfo(1).crc32, 'NhCmhg==');
            testCase.verifyEqual(page.files(uid), 'https://s3/x');
        end

        function testSignedURLSetPageWithoutFileInfo(testCase)
            % A server that predates fileInfo: the field is present and empty.
            txt = '{"files":{"9a":"u1"},"nextCursor":null}';
            page = ndi.cloud.api.implementation.files.signedURLSetPage(jsondecode(txt), txt);
            testCase.verifyTrue(isfield(page, 'fileInfo'));
            testCase.verifyEmpty(page.fileInfo);
        end
    end
end
