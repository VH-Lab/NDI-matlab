classdef ExportAllBinaryTest < matlab.unittest.TestCase
    methods (Test)
        function testExportAllBinary(testCase)
            disp('Testing ndi.fun.probe.export.all_binary');

            mockSession = ndi.unittest.fun.probe.MockSession();

            % Ensure clean directory state
            kilosort_path = [mockSession.path, filesep, 'kilosort'];
            if exist(kilosort_path, 'dir')
                rmdir(kilosort_path, 's');
            end

            ndi.fun.probe.export.all_binary(mockSession, 'verbose', 0, 'binary_dir', 'kilosort');

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

        function testDefaultMultiplierFloatingPoint(testCase)
            % floating-point data keep the Intan default
            mult = testCase.exportAndReadMultiplier(ndi.unittest.fun.probe.MockProbe(), {});
            testCase.verifyEqual(mult, 1/0.195, 'RelTol', 1e-9);
        end

        function testDefaultMultiplierWholeNumberCounts(testCase)
            % raw counts returned as double (e.g. SpikeGLX) pass through unscaled
            p = ndi.unittest.fun.probe.MockDataProbe(@(t) round(1000*sin(1000*t*[1 2]) + 600));
            mult = testCase.exportAndReadMultiplier(p, {});
            testCase.verifyEqual(mult, 1);
        end

        function testExplicitMultiplierOverrides(testCase)
            p = ndi.unittest.fun.probe.MockDataProbe(@(t) round(1000*sin(1000*t*[1 2]) + 600));
            mult = testCase.exportAndReadMultiplier(p, {'multiplier', 2});
            testCase.verifyEqual(mult, 2);
        end
    end

    methods
        function mult = exportAndReadMultiplier(testCase, probe, extraArgs)
            mockSession = ndi.unittest.fun.probe.MockSession();
            mockSession.probes = {probe};
            binary_dir = 'kilosort_mult_test';
            outpath = [mockSession.path, filesep, binary_dir];
            if exist(outpath, 'dir')
                rmdir(outpath, 's');
            end
            testCase.addTeardown(@() ndi.unittest.fun.probe.ExportAllBinaryTest.removeDir(outpath));

            ndi.fun.probe.export.all_binary(mockSession, 'verbose', 0, ...
                'binary_dir', binary_dir, 'noBinary', true, extraArgs{:});

            metafile = [outpath, filesep, probe.elementstring(), filesep, 'kilosort.bin.metadata'];
            testCase.assertTrue(exist(metafile, 'file') > 0, 'Metadata file not created');
            meta = vlt.file.loadStructArray(metafile);
            mult = meta(1).multiplier;
        end
    end

    methods (Static)
        function removeDir(d)
            if exist(d, 'dir')
                rmdir(d, 's');
            end
        end
    end
end
