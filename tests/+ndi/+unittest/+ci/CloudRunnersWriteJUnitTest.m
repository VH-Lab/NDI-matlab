classdef CloudRunnersWriteJUnitTest < matlab.unittest.TestCase
    % CLOUDRUNNERSWRITEJUNITTEST - the cloud test runners write the JUnit XML
    % their workflows publish.
    %
    % Issue #1026: test-cloud-api.yml, test-cloud-api-crossplatform.yml and
    % test-cloud-prod.yml publish docs/reports/test-results.xml with
    % mikepenz/action-junit-report, but testCloudApi wrote no such file, so
    % the published check always read "No test results found!". Each runner
    % those workflows call must create docs/reports and add the JUnit plugin
    % at that path, as testToolboxNoCloud does.

    methods (Test)

        function testEachCloudWorkflowRunnerWritesTheReport(testCase)
            % this repository's root, from this file's place in it
            % (tests/+ndi/+unittest/+ci/): nditools.projectdir resolves to
            % whichever nditools is first on the path, which in CI is an
            % add-on's (ndi-ontology-matlab)
            root = fileparts(fileparts(fileparts(fileparts(fileparts( ...
                mfilename('fullpath'))))));
            testCase.assertTrue(isfolder(fullfile(root, 'tools', 'tasks')), ...
                sprintf('%s is not the NDI-matlab root', root));
            % workflow -> the runner file it calls (testCloudApiProdPart
            % calls testCloudApiPart)
            pairs = { ...
                'test-cloud-api.yml',               'testCloudApi.m'; ...
                'test-cloud-api-crossplatform.yml', 'testCloudApi.m'; ...
                'test-cloud-prod.yml',              'testCloudApiPart.m'};
            for k = 1:size(pairs, 1)
                wf = fileread(fullfile(root, '.github', 'workflows', pairs{k, 1}));
                testCase.assertNotEmpty(strfind(wf, ...
                    'report_paths: ''docs/reports/test-results.xml'''), ...
                    sprintf('%s no longer publishes docs/reports/test-results.xml', pairs{k, 1}));
                src = fileread(fullfile(root, 'tools', 'tasks', pairs{k, 2}));
                testCase.verifyNotEmpty(regexp(src, ...
                    'fullfile\(projectRootDir,\s*"docs",\s*"reports"\)', 'once'), ...
                    sprintf('%s does not use docs/reports', pairs{k, 2}));
                testCase.verifyNotEmpty(regexp(src, 'mkdir\(outputDirectory\)', 'once'), ...
                    sprintf('%s does not create docs/reports', pairs{k, 2}));
                testCase.verifyNotEmpty(regexp(src, ...
                    ['XMLPlugin\.producingJUnitFormat\(fullfile\(outputDirectory,\s*' ...
                     '''test-results\.xml''\)\)'], 'once'), ...
                    sprintf('%s adds no JUnit plugin writing test-results.xml', pairs{k, 2}));
            end
        end
    end
end
