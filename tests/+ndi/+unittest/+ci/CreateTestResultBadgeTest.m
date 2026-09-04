classdef CreateTestResultBadgeTest < matlab.unittest.TestCase
    % CREATETESTRESULTBADGETEST - regression tests for the CI tests-badge logic
    %
    % Guards nditools.testBadgeColorMessage, the decision logic behind the
    % "tests" badge written by testToolboxNoCloud. The key regression: a suite
    % with zero discovered tests must NOT produce a green badge.
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    methods (Test)

        function testZeroTestsIsNotGreen(testCase)
            [color, message] = nditools.testBadgeColorMessage(0, 0, 0);
            testCase.verifyNotEqual(color, "green");
            testCase.verifyEqual(color, "red");
            testCase.verifyEqual(message, "no tests");
        end

        function testAllPassedIsGreen(testCase)
            [color, message] = nditools.testBadgeColorMessage(100, 100, 0);
            testCase.verifyEqual(color, "green");
            testCase.verifyEqual(message, "100 passed");
        end

        function testSmallFailureRateIsYellow(testCase)
            % 2 of 100 failed -> 2% < 5% -> yellow.
            [color, message] = nditools.testBadgeColorMessage(100, 98, 2);
            testCase.verifyEqual(color, "yellow");
            testCase.verifyEqual(message, "98/100 passed");
        end

        function testLargeFailureRateIsRed(testCase)
            % 10 of 100 failed -> 10% >= 5% -> red.
            [color, ~] = nditools.testBadgeColorMessage(100, 90, 10);
            testCase.verifyEqual(color, "red");
        end

        function testSingleFailureIsRedNotYellow(testCase)
            % 1 of 1 failed -> 100% -> red (a green/near-green badge here would
            % hide a fully broken one-test suite).
            [color, ~] = nditools.testBadgeColorMessage(1, 0, 1);
            testCase.verifyEqual(color, "red");
        end

    end

end
