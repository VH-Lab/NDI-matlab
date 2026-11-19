classdef TestSplitSeriesRead < matlab.unittest.TestCase
%TESTSPLITSERIESREAD ndi.vintage.splitSeriesRead reads the time axis in both numeric shapes.
%
%   The owner's `time` covariate gives the frame times, origin + k * spacing.
%   did-schema did_v2_numeric_shape_plan.md ([one shape for measured
%   numbers], Jess Haley, 2026-11-17): origin and spacing are
%   {value, source_value} blocks (old) or plain numbers beside
%   source_origin / source_spacing (new). Both read the same rows and times.
%   The body is a gzip'd little-endian float64 array, read through a stand-in
%   for the session's binary-document calls: no session or database.

    properties
        Dir
    end

    methods (TestMethodSetup)
        function makeDir(testCase)
            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
        end
    end

    methods (Test)
        function testBothShapesReadTheSameRows(testCase)
            a = reshape(1:10, 5, 2);   % 5 frames x 2 channels
            [session, body] = gzBody(testCase.Dir, a);
            timeTerm = struct('node', 'om:Time', 'name', 'time');
            old = struct('variable', timeTerm, 'along', 0, ...
                'origin', struct('value', 1, 'source_value', 1000), ...
                'spacing', struct('value', 0.5, 'source_value', 500));
            new = struct('variable', timeTerm, 'along', 0, 'origin', 1, 'spacing', 0.5, ...
                'source_origin', 1000, 'source_spacing', 500);
            [d1, t1] = ndi.vintage.splitSeriesRead(session, body, owner(old), 1.5, 2.5);
            [d2, t2] = ndi.vintage.splitSeriesRead(session, body, owner(new), 1.5, 2.5);
            testCase.verifyEqual(t1, [1.5; 2; 2.5], 'old shape');
            testCase.verifyEqual(d1, a(2:4, :), 'old shape');
            testCase.verifyEqual(t2, t1, 'new shape');
            testCase.verifyEqual(d2, d1, 'new shape');
        end
    end
end

% =====================================================================

function p = owner(timeCovariate)
p = struct('value', struct('data_type', 'float64'), ...
    'data', struct('covariates', timeCovariate));
end

function [session, body] = gzBody(dirName, a)
% the body document and a stand-in session whose binary-document calls
% open the gzip'd array
raw = fullfile(dirName, 'body_data_0');
fid = fopen(raw, 'w', 'ieee-le');
fwrite(fid, a, 'double');
fclose(fid);
gz = gzip(raw, dirName);
session = struct('database_openbinarydoc', @(~, ~) fopen(gz{1}, 'r'), ...
    'database_closebinarydoc', @(f) fclose(f));
body = struct('document_properties', struct('data', struct('dimensions', ...
    struct('n', {size(a, 1), size(a, 2)}))));
end
