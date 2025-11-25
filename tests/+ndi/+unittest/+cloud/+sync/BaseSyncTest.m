classdef (Abstract) BaseSyncTest < matlab.unittest.TestCase
    %BaseSyncTest Base class for sync tests with common setup/teardown

    properties
        testDir
        ndiDataset
        syncDir
        mockDir
    end

    methods(TestMethodSetup)
        function createTestDataset(testCase)
            global MOCK_CALLS;
            MOCK_CALLS = struct();

            testCase.testDir = tempname;
            mkdir(testCase.testDir);
            testCase.ndiDataset = ndi.session.dir(testCase.testDir, 1);
            testCase.syncDir = fullfile(testCase.testDir, '.ndi', 'sync');
            if ~exist(testCase.syncDir, 'dir'), mkdir(testCase.syncDir); end
            testCase.mockDir = fullfile(testCase.testDir, 'mocks');
            mkdir(testCase.mockDir);
            addpath(testCase.mockDir);
        end
    end

    methods(TestMethodTeardown)
        function removeTestDataset(testCase)
            global MOCK_CALLS;
            rmpath(testCase.mockDir);
            if exist(testCase.testDir, 'dir')
                rmdir(testCase.testDir, 's');
            end
            clear global MOCK_CALLS;
        end
    end

    methods(Access = protected)
        function addDocument(testCase, name, value)
            if nargin < 3, value = ''; end
            doc = ndi.document('ndi_document_test.json');
            doc = doc.set_properties('test.name', name, 'test.value', value);
            testCase.ndiDataset.database_add(doc);
        end

        function createMock(testCase, functionName, functionBody)
            [~, name, ~] = fileparts(functionName);
            packageParts = strsplit(functionName, '.');

            currentPath = testCase.mockDir;
            for i = 1:numel(packageParts)-1
                if startsWith(packageParts{i}, '+')
                    currentPath = fullfile(currentPath, packageParts{i});
                else
                    currentPath = fullfile(currentPath, ['+' packageParts{i}]);
                end
                if ~exist(currentPath, 'dir')
                    mkdir(currentPath);
                end
            end

            fid = fopen(fullfile(currentPath, [name '.m']), 'w');
            fprintf(fid, '%s', functionBody);
            fclose(fid);
        end
    end
end
