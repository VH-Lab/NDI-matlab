function testCloudApi(varargin)
    matbox.installRequirements(fullfile(projectRootDir, 'tests'))

    import matlab.unittest.TestSuite;
    import matlab.unittest.TestRunner;
    
    suite = TestSuite.fromPackage('ndi.unittest.cloud', ...
        'IncludingSubpackages', true);

    runner = TestRunner.withTextOutput('OutputDetail', 'Terse');
    results = runner.run(suite);
    results.assertSuccess()
end
