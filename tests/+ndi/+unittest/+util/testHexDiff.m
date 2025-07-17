classdef testHexDiff < matlab.unittest.TestCase
    %TESTHEXDIFF Unit tests for the ndi.util.hexDiff function.
    %
    %   To run these tests, you must have the ndi.util.hexDiff function
    %   on your MATLAB path.
    %
    %   Example:
    %       results = runtests('ndi.unittest.util.testHexDiff');
    %

    properties (Constant)
        TestDir = fullfile(tempdir, 'hexDiffTestDir');
    end

    properties
        File1
        File2
        BaseContent
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
        % Create fresh test files before each test method runs.
        function createTestFiles(testCase)
            testCase.File1 = fullfile(testCase.TestDir, 'file1.bin');
            testCase.File2 = fullfile(testCase.TestDir, 'file2.bin');
            
            % Create some known binary data (3 lines worth)
            testCase.BaseContent = uint8(0:47);
            
            % Write base content to File1
            testCase.writeFile(testCase.File1, testCase.BaseContent);
        end
    end

    methods (Test)
        % Test that identical files produce no diff output.
        function testIdenticalFiles(testCase)
            import matlab.unittest.constraints.ContainsSubstring
            
            % Make File2 identical to File1
            testCase.writeFile(testCase.File2, testCase.BaseContent);
            
            output = evalc("ndi.util.hexDiff(testCase.File1, testCase.File2)");
            
            testCase.verifyThat(output, ContainsSubstring('Files are identical'));
        end

        % Test a single byte difference.
        function testSingleByteDifference(testCase)
            import matlab.unittest.constraints.ContainsSubstring
            
            modifiedContent = testCase.BaseContent;
            modifiedContent(5) = 255; % 0-based index 4
            testCase.writeFile(testCase.File2, modifiedContent);
            
            output = evalc("ndi.util.hexDiff(testCase.File1, testCase.File2)");
            
            % Verify the first line is printed because it differs
            testCase.verifyThat(output, ContainsSubstring('00000000:'));
            testCase.verifyThat(output, ContainsSubstring('00 01 02 03 04'));
            testCase.verifyThat(output, ContainsSubstring('00 01 02 03 FF'));
            
            % Verify the second line is NOT printed
            testCase.verifyThat(output, ~ContainsSubstring('00000010:'));
        end

        % Test when the second file is shorter.
        function testShorterSecondFile(testCase)
            import matlab.unittest.constraints.ContainsSubstring
            
            shorterContent = testCase.BaseContent(1:32); % Only two lines
            testCase.writeFile(testCase.File2, shorterContent);
            
            output = evalc("ndi.util.hexDiff(testCase.File1, testCase.File2)");
            
            % Verify the third line is printed because File2 is shorter
            testCase.verifyThat(output, ContainsSubstring('00000020:'));
            
            % Verify the first two lines are NOT printed
            testCase.verifyThat(output, ~ContainsSubstring('00000000:'));
            testCase.verifyThat(output, ~ContainsSubstring('00000010:'));
        end
        
        % Test when the first file is shorter.
        function testShorterFirstFile(testCase)
            import matlab.unittest.constraints.ContainsSubstring
            
            shorterContent = testCase.BaseContent(1:32); % Only two lines
            testCase.writeFile(testCase.File1, shorterContent);
            testCase.writeFile(testCase.File2, testCase.BaseContent);
            
            output = evalc("ndi.util.hexDiff(testCase.File1, testCase.File2)");
            
            % Verify the third line is printed because File1 is shorter
            testCase.verifyThat(output, ContainsSubstring('00000020:'));
        end

        % Test using the 'StartByte' and 'StopByte' options.
        function testRangeOptions(testCase)
            import matlab.unittest.constraints.ContainsSubstring
            
            modifiedContent = testCase.BaseContent;
            modifiedContent(20) = 99; % Difference on the second line
            testCase.writeFile(testCase.File2, modifiedContent);
            
            % Run diff, but only on the first line (bytes 0-15)
            output = evalc("ndi.util.hexDiff(testCase.File1, testCase.File2, 'StopByte', 15)");
            
            % Verify that no differences are reported
            testCase.verifyThat(output, ContainsSubstring('Files are identical'));
            
            % Now run on the second line
            output = evalc("ndi.util.hexDiff(testCase.File1, testCase.File2, 'StartByte', 16, 'StopByte', 31)");
            
            % Verify the difference is now found
            testCase.verifyThat(output, ContainsSubstring('00000010:'));
            testCase.verifyThat(output, ContainsSubstring('13')); % 19 in decimal
            testCase.verifyThat(output, ContainsSubstring('63')); % 99 in decimal
        end

        % Test error for a non-existent file.
        function testFileDoesNotExistError(testCase)
            nonExistentFile = fullfile(testCase.TestDir, 'no_such_file.bin');
            
            testCase.verifyError(@() ndi.util.hexDiff(testCase.File1, nonExistentFile), 'hexDiff:FileOpenError');
        end
    end
    
    methods (Access = private)
        function writeFile(~, filename, content)
            fid = fopen(filename, 'wb');
            if fid == -1, error('Failed to write test file.'); end
            fwrite(fid, content, 'uint8');
            fclose(fid);
        end
    end
end
