function testToolboxNoCloud(varargin)
%testToolboxNoCloud Run the NDI test suite excluding the cloud package.
%
%   This mirrors matbox.tasks.testToolbox but filters out tests that
%   live in tests/+ndi/+unittest/+cloud so the cloud-specific tests can
%   be run in a separate workflow.

    import matlab.unittest.TestSuite
    import matlab.unittest.TestRunner
    import matlab.unittest.plugins.CodeCoveragePlugin
    import matlab.unittest.plugins.XMLPlugin
    import matlab.unittest.plugins.codecoverage.CoberturaFormat
    import matlab.unittest.selectors.HasTag

    options = parseOptions(varargin{:});

    projectRootDir = nditools.projectdir();
    matbox.installRequirements(fullfile(projectRootDir, 'tests'))

    testFolder = fullfile(projectRootDir, "tests");
    codeFolder = fullfile(projectRootDir, "src");
    oldpath = addpath(genpath(testFolder), genpath(codeFolder));
    finalize = onCleanup(@()(path(oldpath))); %#ok<NASGU>

    outputDirectory = fullfile(projectRootDir, "docs", "reports");
    if ~isfolder(outputDirectory)
        mkdir(outputDirectory)
    end

    suite = TestSuite.fromPackage("ndi.unittest", "IncludingSubpackages", true);

    suite = excludeCloudTests(suite);

    if isenv('GITHUB_ACTIONS') && strcmp(getenv('GITHUB_ACTIONS'), 'true')
        suite = suite.selectIf(~HasTag("Graphical"));
    end

    runner = TestRunner.withTextOutput("Verbosity", options.Verbosity);

    codecoverageFileName = fullfile(outputDirectory, "codecoverage.xml");
    mfileListing = dir(fullfile(codeFolder, '**', '*.m'));
    codecoverageFileList = fullfile({mfileListing.folder}, {mfileListing.name});

    runner.addPlugin(XMLPlugin.producingJUnitFormat(fullfile(outputDirectory, 'test-results.xml')));
    runner.addPlugin(CodeCoveragePlugin.forFile(codecoverageFileList, ...
        'Producing', CoberturaFormat(codecoverageFileName)));

    results = runner.run(suite);

    createTestResultBadge(results, projectRootDir)
    displayTestResultSummary(results)

    results.assertSuccess();
end

function suite = excludeCloudTests(suite)
    if isempty(suite)
        return
    end
    names = string({suite.Name});
    keep = ~startsWith(names, "ndi.unittest.cloud.");
    suite = suite(keep);
end

function options = parseOptions(varargin)
    p = inputParser();
    p.addParameter("Verbosity", "Terse");
    p.KeepUnmatched = true;
    p.parse(varargin{:});
    options = p.Results;
end

function createTestResultBadge(results, projectRootDir)
    numTests = numel(results);
    numPassedTests = sum([results.Passed]);
    numFailedTests = sum([results.Failed]);

    if numFailedTests == 0
        color = "green";
        message = sprintf("%d passed", numPassedTests);
    elseif numFailedTests / numTests < 0.05
        color = "yellow";
        message = sprintf("%d/%d passed", numPassedTests, numTests);
    else
        color = "red";
        message = sprintf("%d/%d passed", numPassedTests, numTests);
    end
    matbox.utility.createBadgeSvg("tests", message, color, projectRootDir)
end

function displayTestResultSummary(testResults)
    fprintf(['Test result summary:\n', ...
        '   %d Passed, %d Failed, %d Incomplete.\n', ...
        '   %.04f seconds testing time.\n'], ...
        sum([testResults.Passed]), ...
        sum([testResults.Failed]), ...
        sum([testResults.Incomplete]), ...
        sum([testResults.Duration]))
end
