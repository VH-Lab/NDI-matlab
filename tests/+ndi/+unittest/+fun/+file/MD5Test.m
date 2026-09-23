classdef MD5Test < matlab.unittest.TestCase
    % MD5TEST - tests for ndi.fun.file.MD5
    %
    % ndi.fun.file.MD5 shells out to a different native tool on each platform
    % (CertUtil on Windows, md5 on macOS, md5sum on Linux), so these tests check
    % the one thing that must be identical everywhere: the digest of known bytes.

    properties
        tempDir
    end

    methods (TestMethodSetup)
        function makeTempDir(testCase)
            testCase.tempDir = tempname;   % unique, does not yet exist
            mkdir(testCase.tempDir);
            testCase.addTeardown(@() rmdir(testCase.tempDir, 's'));
        end
    end

    methods (Access = private)
        function fileName = writeBytes(testCase, name, bytes)
            % Write BYTES exactly, with no platform-dependent line endings.
            fileName = fullfile(testCase.tempDir, name);
            fid = fopen(fileName, 'w');
            testCase.assertGreaterThan(fid, 0, ['Could not open ' fileName ' for writing.']);
            closeFile = onCleanup(@() fclose(fid)); %#ok<NASGU>
            if ~isempty(bytes)
                fwrite(fid, bytes, 'uint8');
            end
        end
    end

    methods (Test)

        function testKnownChecksumOfEmptyFile(testCase)
            f = testCase.writeBytes('empty.bin', []);
            testCase.verifyEqual(ndi.fun.file.MD5(f), ...
                'd41d8cd98f00b204e9800998ecf8427e');
        end

        function testKnownChecksumOfAbc(testCase)
            f = testCase.writeBytes('abc.bin', uint8('abc'));
            testCase.verifyEqual(ndi.fun.file.MD5(f), ...
                '900150983cd24fb0d6963f7d28e17f72');
        end

        function testChecksumIsLowercaseHex32(testCase)
            % Every platform branch must normalize to the same shape: CertUtil
            % puts spaces between the bytes on some Windows versions, and the
            % md5/md5sum output has the file name in it.
            f = testCase.writeBytes('shape.bin', uint8(0:255));
            checksum = ndi.fun.file.MD5(f);
            testCase.verifyClass(checksum, 'char');
            testCase.verifyEqual(numel(checksum), 32);
            testCase.verifyNotEmpty(regexp(checksum, '^[a-f0-9]{32}$', 'once'), ...
                ['Checksum ''' checksum ''' is not 32 lowercase hex digits.']);
        end

        function testIdenticalContentGivesIdenticalChecksum(testCase)
            bytes = uint8('the same bytes');
            a = testCase.writeBytes('a.bin', bytes);
            b = testCase.writeBytes('b.bin', bytes);
            testCase.verifyEqual(ndi.fun.file.MD5(a), ndi.fun.file.MD5(b));
        end

        function testDifferentContentGivesDifferentChecksum(testCase)
            a = testCase.writeBytes('a.bin', uint8('content one'));
            b = testCase.writeBytes('b.bin', uint8('content two'));
            testCase.verifyNotEqual(ndi.fun.file.MD5(a), ndi.fun.file.MD5(b));
        end

        function testChecksumIsBinarySafe(testCase)
            % The exported probe binaries this is used on are not text, so a
            % byte that could be mistaken for a line ending must not change it.
            f = testCase.writeBytes('binary.bin', uint8([13 10 0 255 26]));
            testCase.verifyNotEmpty(regexp(ndi.fun.file.MD5(f), '^[a-f0-9]{32}$', 'once'));
        end

        function testAcceptsStringInput(testCase)
            f = testCase.writeBytes('abc.bin', uint8('abc'));
            testCase.verifyEqual(ndi.fun.file.MD5(string(f)), ...
                '900150983cd24fb0d6963f7d28e17f72');
        end

        function testPathWithSpacesIsQuoted(testCase)
            % The command is built with sprintf and the path is quoted; a path
            % with a space must not split into two arguments.
            f = testCase.writeBytes('name with spaces.bin', uint8('abc'));
            testCase.verifyEqual(ndi.fun.file.MD5(f), ...
                '900150983cd24fb0d6963f7d28e17f72');
        end

        function testErrorOnMissingFile(testCase)
            missing = fullfile(testCase.tempDir, 'does_not_exist.bin');
            testCase.verifyError(@() ndi.fun.file.MD5(missing), ?MException);
        end

    end
end
