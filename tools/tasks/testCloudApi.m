function testCloudApi(varargin)
    import matlab.unittest.TestSuite
    import matlab.unittest.TestRunner
    import matlab.unittest.plugins.XMLPlugin

    projectRootDir = nditools.projectdir();
    nditools.installRequirements(fullfile(projectRootDir, 'tests'))

    suite = TestSuite.fromPackage('ndi.unittest.cloud', ...
        'IncludingSubpackages', true);

    runner = TestRunner.withTextOutput('OutputDetail', 'Detailed');
    % The workflows that call this (test-cloud-api.yml,
    % test-cloud-api-crossplatform.yml) publish
    % docs/reports/test-results.xml; write it, as testCloudApiPart and
    % testToolboxNoCloud do (#1026).
    outputDirectory = fullfile(projectRootDir, "docs", "reports");
    if ~isfolder(outputDirectory)
        mkdir(outputDirectory)
    end
    runner.addPlugin(XMLPlugin.producingJUnitFormat(fullfile(outputDirectory, 'test-results.xml')));
    results = runner.run(suite);
    display(results)
    results.assertSuccess()
end
