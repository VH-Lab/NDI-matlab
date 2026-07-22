% TestStatusIcon.m
classdef TestStatusIcon < matlab.unittest.TestCase
    % TestStatusIcon Tests the navigator session-node status badge generator.
    %
    %   ndi.gui.nav.statusIcon renders a small badge PNG from a status
    %   struct. These tests are display-free (the badge is drawn from a
    %   built-in bitmap font and written with imwrite), so they run headless.

    methods (Test)
        function testUnknownDrawsNothing(testCase)
            % An 'unknown' (or missing) state yields no badge.
            p = ndi.gui.nav.statusIcon(struct('ingestion', 'unknown'));
            testCase.verifyEqual(p, '', ...
                'An unknown ingestion state should produce no icon.');

            p2 = ndi.gui.nav.statusIcon(struct('somethingElse', 'x'));
            testCase.verifyEqual(p2, '', ...
                'A status with no known dimension should produce no icon.');
        end

        function testIngestedProducesFile(testCase)
            % An 'ingested' state produces a real, transparent RGB PNG.
            p = ndi.gui.nav.statusIcon(struct('ingestion', 'ingested'));
            testCase.verifyClass(p, 'char');
            testCase.verifyTrue(isfile(p), 'The badge file should exist.');
            testCase.verifyTrue(endsWith(p, '.png'), 'The badge should be a PNG.');

            [rgb, ~, alpha] = imread(p);
            testCase.verifyEqual(size(rgb, 3), 3, 'Badge should be truecolor.');
            testCase.verifyNotEmpty(alpha, 'Badge should carry an alpha channel.');
            % The badge is transparent around the glyph and opaque on it.
            testCase.verifyEqual(max(alpha(:)), uint8(255), ...
                'Glyph pixels should be fully opaque.');
            testCase.verifyEqual(min(alpha(:)), uint8(0), ...
                'The area around the glyph should be transparent.');
        end

        function testColorMatchesState(testCase)
            % The 'ingested' glyph is painted in the shared okGreen colour.
            c = ndi.gui.cloudColors();
            want = uint8(round(c.okGreen * 255));
            p = ndi.gui.nav.statusIcon(struct('ingestion', 'ingested'));
            [rgb, ~, alpha] = imread(p);

            % Look only at painted (opaque) pixels; they should all be the
            % target colour.
            opaque = alpha == 255;
            R = rgb(:, :, 1); G = rgb(:, :, 2); B = rgb(:, :, 3);
            testCase.verifyTrue(any(opaque(:)), 'Expected some painted pixels.');
            testCase.verifyEqual(unique(R(opaque)), want(1));
            testCase.verifyEqual(unique(G(opaque)), want(2));
            testCase.verifyEqual(unique(B(opaque)), want(3));
        end

        function testCachingReturnsSamePath(testCase)
            % Repeated calls with the same status reuse one cached file.
            s = struct('ingestion', 'linked');
            p1 = ndi.gui.nav.statusIcon(s);
            p2 = ndi.gui.nav.statusIcon(s);
            testCase.verifyEqual(p1, p2, ...
                'The same status should map to the same cached path.');
            testCase.verifyTrue(isfile(p1));
        end

        function testDistinctStatesDistinctFiles(testCase)
            % Different states produce different badge files.
            pIngested = ndi.gui.nav.statusIcon(struct('ingestion', 'ingested'));
            pLinked   = ndi.gui.nav.statusIcon(struct('ingestion', 'linked'));
            pNone     = ndi.gui.nav.statusIcon(struct('ingestion', 'none'));
            testCase.verifyNotEqual(pIngested, pLinked);
            testCase.verifyNotEqual(pIngested, pNone);
            testCase.verifyNotEqual(pLinked, pNone);
        end
    end
end
