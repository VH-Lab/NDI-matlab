classdef testHexDump < matlab.unittest.TestCase
    %TESTHEXDUMP Unit tests for the ndi.util.hexDump function.
    %
    %   To run these tests, you must have the ndi.util.hexDump function
    %   on your MATLAB path.
    %
    %   Example:
    %       results = runtests('ndi.unittest.util.testHexDump');
    %

    properties (Constant)
        TestDir = fullfile(tempdir, 'hexDumpTestDir');
    end

    properties
        TestFile
        TestFileContent
    end

    methods (TestClassSetup)
        % Create a temporary directory for test files once per class.
        function createTestDirectory(testCase)
            if exist(testCase.TestDir, 'dir')
                rmdir(testCase.TestDir, 's');
            end
            mkdir(testCase.TestDir);
        end
    end

    methods (TestClassTeardown)
        % Remove the temporary directory once all tests are done.
        function removeTestDirectory(testCase)
            if exist(testCase.TestDir, 'dir')
                rmdir(testCase.TestDir, 's');
            end
        end
    end

    methods (TestMethodSetup)
        % Create a fresh test file before each test method runs.
        function createTestFile(testCase)
            testCase.TestFile = fullfile(testCase.TestDir, 'test_data.bin');
            
            % Create some known binary data (0 to 255, repeated)
            testCase.TestFileContent = uint8(mod(0:511, 256));
            
            fid = fopen(testCase.TestFile, 'wb');
            if fid == -1
                error('Could not create test file for writing.');
            end
            fwrite(fid, testCase.TestFileContent, 'uint8');
            fclose(fid);
        end
    end

    methods (TestMethodTeardown)
        % Delete the test file after each test method runs.
        function deleteTestFile(testCase)
            if exist(testCase.TestFile, 'file')
                delete(testCase.TestFile);
            end
        end
    end

    methods (Test)
        % Test basic dumping of an entire file.
        function testFullFileDump(testCase)
            import matlab.unittest.constraints.ContainsSubstring

            % Capture the command window output
            dumpOutput = evalc('ndi.util.hexDump(testCase.TestFile)');
            
            % Verify the header is present
            testCase.verifyThat(dumpOutput, ContainsSubstring('Hex Dump of:'));
            testCase.verifyThat(dumpOutput, ContainsSubstring('File Size: 512 bytes'));
            
            % Verify the first line of output
            firstLineHex = '00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F';
            firstLineAscii = '................';
            testCase.verifyThat(dumpOutput, ContainsSubstring(firstLineHex));
            testCase.verifyThat(dumpOutput, ContainsSubstring(firstLineAscii));
            
            % Verify the last line of output
            lastLineOffset = '000001f0:';
            testCase.verifyThat(dumpOutput, ContainsSubstring(lastLineOffset));
        end

        % Test the 'StartByte' option.
        function testStartByteOption(testCase)
            import matlab.unittest.constraints.ContainsSubstring

            startOffset = 256;
            dumpOutput = evalc("ndi.util.hexDump(testCase.TestFile, 'StartByte', startOffset)");
            
            % Verify the header shows the correct range
            testCase.verifyThat(dumpOutput, ContainsSubstring('Displaying bytes 256 through 511'));
            
            % Verify the first line starts with the correct offset
            firstLineOffset = sprintf('%08x:', startOffset);
            testCase.verifyThat(dumpOutput, ContainsSubstring(firstLineOffset));
            
            % Verify the first line's content (which should be 00 01 02... again)
            firstLineHex = '00 01 02 03 04 05 06 07';
            testCase.verifyThat(dumpOutput, ContainsSubstring(firstLineHex));
        end

        % Test the 'StopByte' option.
        function testStopByteOption(testCase)
            import matlab.unittest.constraints.ContainsSubstring

            stopOffset = 15; % Dump only the first line
            dumpOutput = evalc("ndi.util.hexDump(testCase.TestFile, 'StopByte', stopOffset)");
            
            % Verify the header shows the correct range
            testCase.verifyThat(dumpOutput, ContainsSubstring('Displaying bytes 0 through 15'));

            % Verify the first line is present
            firstLineHex = '00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F';
            testCase.verifyThat(dumpOutput, ContainsSubstring(firstLineHex));

            % Verify that the second line's offset is NOT present
            secondLineOffset = '00000010:';
            testCase.verifyThat(dumpOutput, ~ContainsSubstring(secondLineOffset));
        end

        % Test using both 'StartByte' and 'StopByte'.
        function testStartAndStopByteOption(testCase)
            import matlab.unittest.constraints.ContainsSubstring

            startOffset = 16;
            stopOffset = 31;
            dumpOutput = evalc("ndi.util.hexDump(testCase.TestFile, 'StartByte', startOffset, 'StopByte', stopOffset)");
            
            % Verify the header
            testCase.verifyThat(dumpOutput, ContainsSubstring('Displaying bytes 16 through 31'));
            
            % Verify the single line of output
            expectedHex = '10 11 12 13 14 15 16 17  18 19 1A 1B 1C 1D 1E 1F';
            testCase.verifyThat(dumpOutput, ContainsSubstring(expectedHex));
            
            % Verify other lines are not present
            testCase.verifyThat(dumpOutput, ~ContainsSubstring('00000000:'));
            testCase.verifyThat(dumpOutput, ~ContainsSubstring('00000020:'));
        end

        % Test error for a non-existent file.
        function testFileDoesNotExistError(testCase)
            nonExistentFile = fullfile(testCase.TestDir, 'no_such_file.bin');
            
            testCase.verifyError(@() ndi.util.hexDump(nonExistentFile), 'hexDump:FileOpenError');
        end

        % Test errors for invalid byte ranges.
        function testInvalidRangeErrors(testCase)
            fileSize = numel(testCase.TestFileContent);
            
            % StartByte is beyond the end of the file
            testCase.verifyError(@() ndi.util.hexDump(testCase.TestFile, 'StartByte', fileSize), 'hexDump:InvalidRange');
            
            % StartByte is greater than StopByte
            testCase.verifyError(@() ndi.util.hexDump(testCase.TestFile, 'StartByte', 100, 'StopByte', 50), 'hexDump:InvalidRange');
        end

        % Test behavior with an empty file.
        function testEmptyFile(testCase)
            import matlab.unittest.constraints.ContainsSubstring

            emptyFile = fullfile(testCase.TestDir, 'empty.bin');
            fclose(fopen(emptyFile, 'w')); % Create an empty file
            
            dumpOutput = evalc("ndi.util.hexDump(emptyFile)");
            
            % Check for the "No data" message
            testCase.verifyThat(dumpOutput, ContainsSubstring('No data to display'));
        end
    end
end
