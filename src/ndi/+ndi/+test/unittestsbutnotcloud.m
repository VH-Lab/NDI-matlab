function unittestsbutnotcloud
% NDI.TEST.UNITTESTSBUTNOTCLOUD - Run all unit tests except cloud tests
%
% NDI.TEST.UNITTESTSBUTNOTCLOUD
%
% Runs all unit tests in the 'tests' directory, but excludes tests that
% have '.cloud.' in their class name.
%
% This function is useful for running local unit tests without requiring
% cloud connectivity or configuration.

unitTestPath = fullfile(ndi.toolboxdir,'..','..','tests','+ndi','+unittest');
TL=matlab.unittest.TestSuite.fromFolder(unitTestPath, 'IncludeSubfolders', true);

% Filter out tests that contain ".cloud." in their name
% We use {TL.Name} to get a cell array of test names.
% Note: Test names usually include the class and method name (e.g., 'pkg.Class/method').
% This is safer than [TL.TestClass] which can be misaligned if some tests are not class-based.
isCloudTest = contains({TL.Name}, '.cloud.');

testsToRun = TL(~isCloudTest);

if isempty(testsToRun)
    warning('No tests found to run (excluding cloud tests).');
    return;
end

% Extract the names of the tests to run
testNames = {testsToRun.Name};

% Run the tests using runtests, which generates a summary report
runtests(testNames);

end
