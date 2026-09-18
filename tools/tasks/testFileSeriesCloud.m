function results = testFileSeriesCloud(environment, className)
%testFileSeriesCloud Run one cloud test class against one API environment.
%
%   testFileSeriesCloud() runs ndi.unittest.cloud.FileSeriesRoundTripTest
%   against the DEV API.
%
%   testFileSeriesCloud("prod") runs it against prod instead.
%
%   testFileSeriesCloud(ENV, CLASSNAME) runs any cloud test class.
%
%   Why this exists rather than testCloudApiDev: the whole cloud suite takes
%   several minutes and creates, uploads to and deletes a dataset per test
%   method. When the question is one class -- "does a series member survive
%   the round trip against the API I just deployed?" -- everything else is
%   wall time and synthetic datasets in someone's organization.
%
%   BEFORE RUNNING, set your credentials:
%
%       setenv NDI_CLOUD_USERNAME  you@example.com
%       setenv NDI_CLOUD_PASSWORD  ...
%
%   Without them the cloud tests SKIP themselves -- the class-level
%   assumption in FileSeriesRoundTripTest reports Incomplete, not Failed --
%   so a credential-less run looks quiet rather than wrong. This function
%   refuses to start instead of letting that happen.
%
%   The environment is left set on exit, deliberately: a later run in the
%   same MATLAB session should not silently go somewhere else. Clear it with
%   setenv('CLOUD_API_ENVIRONMENT','') to return to the prod default.
%
%   See also: testCloudApiDev, testCloudApiProd, ndi.cloud.api.url

    arguments
        environment (1,1) string {mustBeMember(environment, ["dev", "prod"])} = "dev"
        className   (1,1) string = "ndi.unittest.cloud.FileSeriesRoundTripTest"
    end

    import matlab.unittest.TestSuite
    import matlab.unittest.TestRunner

    requiredVars = ["NDI_CLOUD_USERNAME", "NDI_CLOUD_PASSWORD"];
    for i = 1:numel(requiredVars)
        if isempty(getenv(requiredVars(i)))
            error('NDI:Test:MissingCloudCredential', ...
                ['%s is not set. The cloud tests skip themselves without ' ...
                 'credentials and report Incomplete rather than Failed, ' ...
                 'which reads like success. Set it and run again.'], ...
                requiredVars(i));
        end
    end

    setenv("CLOUD_API_ENVIRONMENT", char(environment))

    projectRootDir = nditools.projectdir();
    nditools.installRequirements(fullfile(projectRootDir, 'tests'))

    fprintf('Running %s against the %s API.\n', className, environment);

    suite = TestSuite.fromClass(meta.class.fromName(char(className)));
    runner = TestRunner.withTextOutput('OutputDetail', 'Detailed');
    results = runner.run(suite);
    display(results)

    % Incomplete is worth calling out separately from Failed: it means the
    % tests never ran (a class-level assumption closed), which no failure
    % count will tell you.
    if any([results.Incomplete])
        warning('NDI:Test:IncompleteCloudRun', ...
            ['%d of %d tests were Incomplete -- they did not run. That is ' ...
             'an assumption closing, not a failure; check credentials and ' ...
             'the class-level assumptions before reading the result.'], ...
            sum([results.Incomplete]), numel(results));
    end
end
