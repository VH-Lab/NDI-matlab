function results = unittestsbutnotcloud(options)
% NDI.TEST.UNITTESTSBUTNOTCLOUD - Run all unit tests except cloud tests
%
% RESULTS = NDI.TEST.UNITTESTSBUTNOTCLOUD(OPTIONS)
%
% Runs all unit tests in the 'tests' directory, but excludes tests that
% have '.cloud.' in their class name.
%
% This function is useful for running local unit tests without requiring
% cloud connectivity or configuration.
%
% Input Arguments:
%   OPTIONS - Optional name-value pairs:
%       'Verbosity' - Level of detail for output (default: matlab.automation.Verbosity.Concise)
%                     See matlab.automation.Verbosity
%
% Output Arguments:
%   RESULTS - The test results (array of TestResult objects)

arguments
    options.Verbosity (1,1) matlab.automation.Verbosity = matlab.automation.Verbosity.Concise;
end

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
    results = [];
    return;
end

runner = matlab.unittest.TestRunner.withTextOutput('OutputDetail', options.Verbosity);

% Run the tests using the runner, which generates a summary report
results = runner.run(testsToRun);

end
