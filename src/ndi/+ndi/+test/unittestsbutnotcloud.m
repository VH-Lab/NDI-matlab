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

% Use a TestRunner with text output to generate the standard report
runner = matlab.unittest.TestRunner.withTextOutput;
runner.run(testsToRun);

end
