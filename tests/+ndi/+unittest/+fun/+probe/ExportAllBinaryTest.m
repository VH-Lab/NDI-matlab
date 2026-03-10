classdef ExportAllBinaryTest < matlab.unittest.TestCase
    methods (Test)
        function testExportAllBinary(testCase)
            disp('Testing ndi.fun.probe.export_all_binary');

            mockSession = ndi.unittest.fun.probe.MockSession();

            % Ensure clean directory state
            kilosort_path = [mockSession.path, filesep, 'kilosort'];
            if exist(kilosort_path, 'dir')
                rmdir(kilosort_path, 's');
            end

            ndi.fun.probe.export_all_binary(mockSession, 'verbose', 0, 'kilosort_dir', 'kilosort');

            % Verify the output structure
            expected_outfile = [kilosort_path, filesep, 'mock_probe', filesep, 'kilosort.bin'];
            expected_metafile = [kilosort_path, filesep, 'mock_probe', filesep, 'kilosort.bin.metadata'];

            testCase.verifyTrue(exist(expected_outfile, 'file') > 0, 'Output file not created in expected directory');
            testCase.verifyTrue(exist(expected_metafile, 'file') > 0, 'Metadata file not created in expected directory');

            % Cleanup
            if exist(kilosort_path, 'dir')
                rmdir(kilosort_path, 's');
            end

            disp('Test passed.');
        end
    end
end
