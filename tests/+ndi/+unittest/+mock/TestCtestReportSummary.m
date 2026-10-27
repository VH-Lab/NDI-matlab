classdef TestCtestReportSummary < matlab.unittest.TestCase
    % TestCtestReportSummary - the failure message a calculator self-test gives.
    %
    % ndi.mock.ctest.reportSummary turns a docComparison report into the text
    % that follows "did not reproduce its stored expectation". It must say how
    % far out of tolerance each field was, not only that it was, since the mock
    % data are not seeded and a failing run cannot be reproduced afterwards.

    methods (Test)

        function testEmptyReportSaysNothing(testCase)
            testCase.verifyEqual(ndi.mock.ctest.reportSummary([]), '');
            testCase.verifyEqual(ndi.mock.ctest.reportSummary(struct('name', {})), '');
        end

        function testTextReportIsPassedThrough(testCase)
            testCase.verifyEqual(ndi.mock.ctest.reportSummary('no output document'), ...
                ' no output document');
            testCase.verifyEqual(ndi.mock.ctest.reportSummary("no output document"), ...
                ' no output document');
        end

        function testNamesOnlyReportKeepsTheOldSentence(testCase)
            r = struct('name', {'a.b', 'c.d'});
            testCase.verifyEqual(ndi.mock.ctest.reportSummary(r), ...
                ' Out of tolerance: a.b, c.d.');
        end

        function testValuesAndDifferenceAreReported(testCase)
            r = failureReport('fit.p', [1 2 30], [1 2 10], ...
                'Abs difference > tolerance matrix');
            s = ndi.mock.ctest.reportSummary(r);
            testCase.verifySubstring(s, ' Out of tolerance: fit.p.');
            testCase.verifySubstring(s, 'fit.p: actual [1 2 30], expected [1 2 10]');
            testCase.verifySubstring(s, 'abs difference [0 0 20]');
            testCase.verifySubstring(s, '(Abs difference > tolerance matrix)');
        end

        function testEachFailingFieldGetsItsOwnLine(testCase)
            r = [failureReport('x', 1, 2, 'm1'), ...
                 failureReport('y', 3, 5, 'm2')];
            lines = splitlines(string(ndi.mock.ctest.reportSummary(r)));
            testCase.verifyNumElements(lines, 3);
            testCase.verifySubstring(lines(2), 'x: actual 1, expected 2, abs difference 1 (m1)');
            testCase.verifySubstring(lines(3), 'y: actual 3, expected 5, abs difference 2 (m2)');
        end

        function testNoDifferenceWhenSizesDiffer(testCase)
            r = failureReport('v', [1 2], [1 2 3], ...
                'Dimension mismatch between actual and expected values.');
            s = ndi.mock.ctest.reportSummary(r);
            testCase.verifySubstring(s, 'v: actual [1 2], expected [1 2 3]');
            testCase.verifyEmpty(strfind(s, 'abs difference'));
        end

        function testNoDifferenceForText(testCase)
            s = ndi.mock.ctest.reportSummary( ...
                failureReport('t', 'abc', 'abd', 'Strings differ'));
            testCase.verifySubstring(s, 't: actual ''abc'', expected ''abd''');
            testCase.verifyEmpty(strfind(s, 'abs difference'));
        end

        function testEmptyCommentIsOmitted(testCase)
            s = ndi.mock.ctest.reportSummary(failureReport('n', 1, 2, ''));
            testCase.verifyEqual(s(end), '1');
        end

        function testValueStringFormats(testCase)
            testCase.verifyEqual(ndi.mock.ctest.valueString(pi), '3.14159');
            testCase.verifyEqual(ndi.mock.ctest.valueString(true), 'true');
            testCase.verifyEqual(ndi.mock.ctest.valueString(reshape(1:8,2,2,2)), ...
                '[1 2 3 4 5 6 7 8]');
            testCase.verifyEqual(ndi.mock.ctest.valueString("s"), '''s''');
            testCase.verifyEqual(ndi.mock.ctest.valueString({1,2}), '[1x2 cell]');
        end

        function testLongValuesAreCut(testCase)
            s = ndi.mock.ctest.valueString(1:1000);
            testCase.verifyEqual(numel(s), 204);
            testCase.verifyEqual(s(end-3:end), ' ...');
        end
    end
end

function r = failureReport(name, actualValue, expectedValue, comment)
    % One docComparison report entry, as compare() builds it.
    r = struct('name', name, 'actualValue', actualValue, ...
        'expectedValue', expectedValue, 'comment', comment);
end
