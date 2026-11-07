classdef TestDtypeName < matlab.unittest.TestCase
    % TestDtypeName - ndi.fun.doc.lightsheet.dtypeName: Zarr dtype <-> MATLAB class.
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    methods (Test)
        function testBothWays(testCase)
            d = @ndi.fun.doc.lightsheet.dtypeName;
            testCase.verifyEqual(d('uint16', 'zarr'), '<u2');
            testCase.verifyEqual(d('<u2', 'zarr'), '<u2');
            testCase.verifyEqual(d('<u2', 'matlab'), 'uint16');
            testCase.verifyEqual(d('uint16', 'matlab'), 'uint16', ...
                'documents written before the change say uint16');
            testCase.verifyEqual(d('uint8', 'zarr'), '|u1');
            testCase.verifyEqual(d('float32', 'matlab'), 'single', 'a Zarr v3 name');
            testCase.verifyEqual(d('<f8', 'matlab'), 'double');
            testCase.verifyEqual(d("int16", 'zarr'), '<i2', 'a string is fine');
        end

        function testAnUnknownTypeIsRefused(testCase)
            testCase.verifyError(@() ndi.fun.doc.lightsheet.dtypeName('<c8', 'matlab'), ...
                'NDI:lightsheet:dtypeName:unknown');
        end
    end
end
