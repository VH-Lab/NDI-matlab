function testCloudApi(varargin)
    import matlab.unittest.TestSuite
    import matlab.unittest.TestRunner
     
    projectRootDir = nditools.projectdir();
    matbox.installRequirements(fullfile(projectRootDir, 'tests'))

    suite = TestSuite.fromPackage('ndi.unittest.cloud', ...
        'IncludingSubpackages', true);

    %runner = TestRunner.withTextOutput('OutputDetail', 'Terse');
    runner = TestRunner.withTextOutput('Verbosity', 'Terse');
    results = runner.run(suite);
    display(results)
    results.assertSuccess()
end
