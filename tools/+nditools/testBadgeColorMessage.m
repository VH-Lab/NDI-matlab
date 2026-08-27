function [color, message] = testBadgeColorMessage(numTests, numPassedTests, numFailedTests)
% TESTBADGECOLORMESSAGE - decide the tests-badge color and label from counts
%
%   [COLOR, MESSAGE] = nditools.testBadgeColorMessage(NUMTESTS, NUMPASSEDTESTS, NUMFAILEDTESTS)
%
%   Pure decision logic for the CI "tests" badge, factored out of
%   testToolboxNoCloud so it can be unit-tested.
%
%   A suite in which NUMTESTS == 0 (test discovery found nothing -- a renamed
%   tests/ layout, a package-path collision, or an over-broad tag filter on the
%   runner) must NOT produce a green badge: a green "0 passed" badge falsely
%   attests a healthy suite for a build where zero tests executed. Such a case
%   returns a red "no tests" badge.
%
%   Otherwise: green when nothing failed, yellow below a 5% failure rate, red
%   above it.

    arguments
        numTests (1,1) double
        numPassedTests (1,1) double
        numFailedTests (1,1) double
    end

    if numTests == 0
        color = "red";
        message = "no tests";
    elseif numFailedTests == 0
        color = "green";
        message = sprintf("%d passed", numPassedTests);
    elseif numFailedTests / numTests < 0.05
        color = "yellow";
        message = sprintf("%d/%d passed", numPassedTests, numTests);
    else
        color = "red";
        message = sprintf("%d/%d passed", numPassedTests, numTests);
    end
end
