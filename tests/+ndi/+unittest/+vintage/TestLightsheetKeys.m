classdef TestLightsheetKeys < matlab.unittest.TestCase
%TESTLIGHTSHEETKEYS ndi.vintage.lightsheetKeys reads an axis by its term's node first, then its name.
%
%   DID-matlab writes image axes as registered terms: x -> NCIT:C44477
%   "X-Coordinate", y -> NCIT:C44478 "Y-Coordinate", z -> NCIT:C44479
%   "Z-Coordinate", t -> om:Time "time". Documents migrated before carry
%   bare names ('x', 'y', 'z', 'time'). Both spellings must read as the
%   same axes; a name that compares is compared by node first (did-schema
%   CLAUDE.md, "A name that code compares": code compares by node first).
%   Pure: no session, no schema.

    methods (Test)

        function testBareNames(testCase)
            [d, c] = ndi.unittest.vintage.TestLightsheetKeys.axesWith( ...
                {struct('node', '', 'name', 'time'), struct('node', '', 'name', 'channel'), ...
                 struct('node', '', 'name', 'z'), struct('node', '', 'name', 'y'), ...
                 struct('node', '', 'name', 'x')});
            ndi.unittest.vintage.TestLightsheetKeys.verifyKeys(testCase, ...
                ndi.vintage.lightsheetKeys(d, c));
        end

        function testRegisteredTerms(testCase)
            [d, c] = ndi.unittest.vintage.TestLightsheetKeys.axesWith( ...
                {struct('node', 'om:Time', 'name', 'time'), struct('node', '', 'name', 'channel'), ...
                 struct('node', 'NCIT:C44479', 'name', 'Z-Coordinate'), ...
                 struct('node', 'NCIT:C44478', 'name', 'Y-Coordinate'), ...
                 struct('node', 'NCIT:C44477', 'name', 'X-Coordinate')});
            ndi.unittest.vintage.TestLightsheetKeys.verifyKeys(testCase, ...
                ndi.vintage.lightsheetKeys(d, c));
        end

        function testTheNodeDecidesOverTheName(testCase)
            % a label that says nothing about the axis: only the node can
            % say which it is (the first-letter fallback would read d, w, h)
            [d, c] = ndi.unittest.vintage.TestLightsheetKeys.axesWith( ...
                {struct('node', 'om:Time', 'name', 'Time'), struct('node', '', 'name', 'channel'), ...
                 struct('node', 'NCIT:C44479', 'name', 'depth'), ...
                 struct('node', 'NCIT:C44478', 'name', 'height'), ...
                 struct('node', 'NCIT:C44477', 'name', 'width')});
            ndi.unittest.vintage.TestLightsheetKeys.verifyKeys(testCase, ...
                ndi.vintage.lightsheetKeys(d, c));
        end

        function testTheCovariateIsMatchedByNode(testCase)
            % the dimension and its covariate carry the same node under
            % different labels; a decoy covariate along the same axis comes
            % first, so only a node match picks the right one
            [d, c] = ndi.unittest.vintage.TestLightsheetKeys.axesWith( ...
                {struct('node', 'om:Time', 'name', 'time'), struct('node', '', 'name', 'channel'), ...
                 struct('node', 'NCIT:C44479', 'name', 'Z-Coordinate'), ...
                 struct('node', 'NCIT:C44478', 'name', 'Y-Coordinate'), ...
                 struct('node', 'NCIT:C44477', 'name', 'X-Coordinate')});
            c{5}.variable = struct('node', 'NCIT:C44477', 'name', 'x');
            decoy = struct('variable', struct('node', 'EMPTY:9999999', 'name', 'X-Coordinate'), ...
                'source_unit', 'micrometer', 'along', 4, ...
                'origin', struct('value', 0, 'source_value', 0), ...
                'spacing', struct('value', 9e-6, 'source_value', 9));
            c = [c(1:4), {decoy}, c(5)];
            f = ndi.vintage.lightsheetKeys(d, c);
            testCase.verifyEqual(f.voxel_size(5), 0.5, 'AbsTol', 1e-12, ...
                'the covariate whose variable has the dimension''s node');
        end
    end

    methods (Static)

        function [d, c] = axesWith(terms)
            % t, c, z, y, x of a 1x2x400x2048x2048 volume, voxel 2 x 0.5 x 0.5
            % micrometre, z translated by 10; the dimension terms are TERMS
            % and each covariate's variable is its dimension's term
            n = [1 2 400 2048 2048];
            d = cell(1, 5);
            for a = 1:5
                d{a} = struct('term', terms{a}, 'n', n(a));
            end
            t = struct('variable', terms{1}, ...
                'unit', struct('node', 'UO:0000010', 'name', 'second'), 'along', 0, ...
                'origin', struct('value', 0), 'spacing', struct('value', 1));
            ch = struct('variable', terms{2}, 'along', 1, ...
                'term', struct('node', '', 'name', {'GCaMP6s', 'tdTomato'}));
            vox = [2 0.5 0.5];
            origin = [10 0 0];
            space = cell(1, 3);
            for a = 1:3
                space{a} = struct('variable', terms{2 + a}, ...
                    'unit', struct('node', 'UO:0000008', 'name', 'meter'), ...
                    'source_unit', 'micrometer', 'along', 1 + a, ...
                    'origin', struct('value', origin(a) * 1e-6, 'source_value', origin(a)), ...
                    'spacing', struct('value', vox(a) * 1e-6, 'source_value', vox(a)));
            end
            c = [{t, ch}, space];
        end

        function verifyKeys(testCase, f)
            testCase.verifyEqual(f.axes_order, 'tczyx');
            testCase.verifyEqual(f.shape, [1 2 400 2048 2048]);
            testCase.verifyEqual(f.voxel_size, [1 1 2 0.5 0.5], 'AbsTol', 1e-12);
            testCase.verifyEqual(f.translation, [0 0 10 0 0], 'AbsTol', 1e-12);
            testCase.verifyEqual(f.voxel_size_units, 'micrometer');
            testCase.verifyEqual(f.channel_names, 'GCaMP6s,tdTomato');
        end
    end
end
