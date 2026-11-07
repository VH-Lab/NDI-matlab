classdef CurlSenderOfflineTest < matlab.unittest.TestCase
% CURLSENDEROFFLINETEST - ndi.cloud.upload.CurlSender without a server.
%
% The config file it writes, the curl version check, and a real
% background curl sent to a local port nothing listens on: it must run
% without blocking, end, and report every file as not sent. (A send that
% succeeds is covered live, by ndi.unittest.cloud.LightsheetSessionWriterTest,
% whose writer sends this way.)
%
% Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    methods (Test)

        function testTheConfigBlockPutsOneFile(testCase)
            s = ndi.cloud.upload.CurlSender.configBlock( ...
                'https://bucket.example/obj?X-Amz-Signature=ab&x=1', ...
                'C:\Users\Jane Doe\a"b.bin', 'NhCmhg==', 'uid_1');
            testCase.verifySubstring(s, 'url = "https://bucket.example/obj?X-Amz-Signature=ab&x=1"');
            testCase.verifySubstring(s, 'upload-file = "C:\\Users\\Jane Doe\\a\"b.bin"', ...
                'backslashes and quotes are escaped; a space is fine');
            testCase.verifySubstring(s, 'header = "x-amz-checksum-crc32: NhCmhg=="');
            testCase.verifySubstring(s, 'header = "Content-Type: application/octet-stream"');
            testCase.verifySubstring(s, 'write-out = "uid_1 %{http_code}\n"');
            for opt = {'fail', 'retry = 3', 'speed-limit = 1024', 'speed-time = 120'}
                testCase.verifySubstring(s, sprintf('\n%s\n', opt{1}));
            end
        end

        function testNoChecksumNoHeader(testCase)
            s = ndi.cloud.upload.CurlSender.configBlock('https://h/x', '/tmp/f', '', 'u');
            testCase.verifyFalse(contains(s, 'x-amz-checksum-crc32'));
        end

        function testTheUploadURLRequestsCarryTheTokenInTheConfig(testCase)
            cfg = ndi.cloud.upload.signedUploadURLs_config( ...
                {'https://api.example/v1/datasets/o/d/files/u1?checksumCRC32=NhCmhg%3D%3D', ...
                 'https://api.example/v1/datasets/o/d/files/u2'}, ...
                'aaa.bbb.ccc', {'/tmp/x 1.json', 'C:\out\x2.json'});
            testCase.verifyEqual(numel(strfind(cfg, 'Authorization: Bearer aaa.bbb.ccc')), 2);
            testCase.verifyEqual(numel(regexp(cfg, '^next$', 'lineanchors')), 1);
            testCase.verifySubstring(cfg, 'output = "/tmp/x 1.json"');
            testCase.verifySubstring(cfg, 'output = "C:\\out\\x2.json"');
            testCase.verifyError(@() ndi.cloud.upload.signedUploadURLs_config( ...
                {'https://h/x'}, sprintf('tok\nurl = "https://evil"'), {'/tmp/o'}), ...
                'NDI:cloud:signedUploadURLs:controlCharacter');
        end

        function testTheVersionIsRead(testCase)
            v = @ndi.cloud.upload.CurlSender.parseVersion;
            testCase.verifyEqual(v('curl 8.7.1 (x86_64-apple-darwin23.0) libcurl/8.7.1'), [8 7]);
            testCase.verifyEqual(v('curl 7.55.1 (Windows) libcurl/7.55.1'), [7 55]);
            testCase.verifyEqual(v('not curl'), [0 0]);
        end

        function testAnUnsafeUrlIsRefused(testCase)
            f = testCase.someFile();
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            testCase.verifyError(@() ndi.cloud.upload.CurlSender({'http://h/x'}, {f}, {''}, ...
                {'u'}, folder), 'NDI:cloud:CurlSender:badUrl');
            testCase.verifyError(@() ndi.cloud.upload.CurlSender({sprintf('https://h/x\nurl = "https://evil"')}, ...
                {f}, {''}, {'u'}, folder), 'NDI:cloud:CurlSender:badUrl');
        end

        function testASendThatCannotConnectEndsAndSaysSo(testCase)
            testCase.assumeTrue(ndi.cloud.upload.CurlSender.supported(), ...
                'No curl 7.68+ on this computer.');
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            a = testCase.someFile();
            b = testCase.someFile();
            % Port 9 (discard) on this computer: refused at once.
            t0 = tic;
            S = ndi.cloud.upload.CurlSender({'https://127.0.0.1:9/a', 'https://127.0.0.1:9/b'}, ...
                {a, b}, {'', ''}, {'uid_a', 'uid_b'}, folder, 'Parallel', 2);
            testCase.verifyLessThan(toc(t0), 5, 'starting a send does not wait for it');
            [ok, msg, failed] = S.wait(120);
            testCase.verifyFalse(ok);
            testCase.verifyTrue(S.isDone());
            testCase.verifyEqual(sort(failed), {'uid_a', 'uid_b'});
            testCase.verifySubstring(msg, 'not sent');
            cfg = S.cfgFile;
            testCase.verifyTrue(isfile(cfg));
            delete(S);
            testCase.verifyFalse(isfile(cfg), 'a finished sender removes its files');
        end
    end

    methods
        function f = someFile(testCase)
            f = [tempname '.bin'];
            fid = fopen(f, 'w');
            fwrite(fid, uint8(1:100));
            fclose(fid);
            testCase.addTeardown(@() deleteIfThere(f));
        end
    end
end

function deleteIfThere(f)
    if isfile(f), delete(f); end
end
