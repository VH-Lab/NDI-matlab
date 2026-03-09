classdef ExportBinaryTest < matlab.unittest.TestCase
    methods (Test)
        function testExportBinary(testCase)
            disp('Testing ndi.fun.probe.export_binary');

            mockProbe = ndi.unittest.fun.probe.MockProbe();

            outputfile = [tempdir, 'test_export.bin'];

            if exist(outputfile, 'file')
                delete(outputfile);
            end
            metafile = [outputfile, '.metadata'];
            if exist(metafile, 'file')
                delete(metafile);
            end

            ndi.fun.probe.export_binary(mockProbe, outputfile, 'multiplier', 2, 'verbose', 0, 'precision', 'int16');

            testCase.verifyTrue(exist(outputfile, 'file') > 0, 'Output file not created');
            testCase.verifyTrue(exist(metafile, 'file') > 0, 'Metadata file not created');

            % Verify metadata contents
            meta = vlt.file.loadStructArray(metafile);

            testCase.verifyTrue(isfield(meta, 'multiplier'), 'Metadata missing multiplier field');
            testCase.verifyEqual(meta(1).multiplier, 2, 'Metadata multiplier value incorrect');
            testCase.verifyTrue(isfield(meta, 'probe_name'), 'Metadata missing probe_name field');
            testCase.verifyEqual(meta(1).probe_name, 'mock_probe', 'Metadata probe_name value incorrect');

            disp('Test passed.');
        end
    end
end
