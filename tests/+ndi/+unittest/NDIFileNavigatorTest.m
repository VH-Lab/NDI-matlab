classdef NDIFileNavigatorTest < matlab.unittest.TestCase
    % TestNDIFileNavigator - A class to unit test the ndi_filenavigator functionality
    %
    %   This class contains unit tests for ndi_filenavigator class.

    properties
        MyDirectory
        Session
        FileNavigator
    end

    methods (TestMethodSetup)
        function createTestSession(testCase)
            % Method setup to initialize the test environment

            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            createFolderStructure(3)

            % Create dummy files
            createFolderStructureWithFiles(3, 2, 'dummy', {'.ext'})
            createFolderStructureWithFiles(3, 2, 'myfile', {'.ext1', '.ext2'});

            disp(['Working on directory ' testCase.MyDirectory '...']);
            testCase.Session = ndi.session.dir('mysession', pwd);
            testCase.FileNavigator = ndi.file.navigator(testCase.Session, {'myfile_#.ext1', 'myfile_#.ext2'});
        end
    end

    methods (Test)
        function testNumberOfEpochs(testCase)
            % Test to verify the number of epochs

            n = numepochs(testCase.FileNavigator);
            testCase.verifyGreaterThan(n, 0, 'Expected at least one epoch.');
            disp(['Number of epochs are ' num2str(n) '.']);
        end

        function testEpochFiles(testCase)
            % Test to verify file paths for a specific epoch

            epochNum = 2;
            f = getepochfiles(testCase.FileNavigator, epochNum);

            testCase.assertNotEmpty(f, 'Expected non-empty file paths for epoch.');
            disp(['File paths of epoch ' num2str(epochNum) ' are as follows:']);
            disp(f);
        end

        function testFileNavigatorFields(testCase)
            % Test to verify the fields of the ndi.file.navigator object

            disp('The ndi.file.navigator object fields:');
            disp(testCase.FileNavigator);

            testCase.assertNotEmpty(fields(testCase.FileNavigator), 'Expected non-empty object fields.');
        end

        function testEpochTableEntries(testCase)
            % Test to verify the epoch table entries

            disp('The epoch table entries:');
            et = epochtable(testCase.FileNavigator);

            testCase.assertNotEmpty(et, 'Expected non-empty epoch table entries.');
            for i = 1:numel(et)
                disp(et(i));
            end
        end

        function testFilesForSpecificEpoch(testCase)
            % Test to verify file paths for a specific epoch

            et = epochtable(testCase.FileNavigator);

            if numel(et) >= 2
                epochID = et(2).epoch_id;
                disp(['File paths of epoch ' num2str(epochID) ' are as follows:']);
                f = getepochfiles(testCase.FileNavigator, epochID);

                testCase.assertNotEmpty(f, 'Expected non-empty file paths for the specific epoch.');
                disp(f);
            else
                testCase.fail('Test requires at least 2 epochs.');
            end
        end
    end
end

function createFolderStructure(numSubdirs)
    % Create a specified folder structure with configurable subdirectories and files
    %
    % Inputs:
    %   numSubdirs     - Number of subdirectories to create (e.g., 3 for mysubdir1, mysubdir2, mysubdir3)
    %   numFiles       - Number of files per subdirectory (for each base name and extensions)
    %   fileBaseName   - Base name for the files (e.g., 'myfile')
    %   fileExtensions - Cell array of file extensions (e.g., {'.ext1', '.ext2'})

    % Loop through the number of subdirectories
    for i = 1:numSubdirs
        subdirName = sprintf('mysubdir%s', num2str(i)); % e.g., mysubdir1, mysubdir2, etc.

        % Create the subdirectory if it doesn't exist
        if ~isfolder(subdirName)
            mkdir(subdirName);
        end
    end
end

function createFolderStructureWithFiles(numSubdirs, numFiles, fileBaseName, fileExtensions)
    % Create a specified folder structure with configurable subdirectories and files
    %
    % Inputs:
    %   numSubdirs     - Number of subdirectories to create (e.g., 3 for mysubdir1, mysubdir2, mysubdir3)
    %   numFiles       - Number of files per subdirectory (for each base name and extensions)
    %   fileBaseName   - Base name for the files (e.g., 'myfile')
    %   fileExtensions - Cell array of file extensions (e.g., {'.ext1', '.ext2'})

    arguments
        numSubdirs
        numFiles
        fileBaseName char
        fileExtensions cell
    end

    % Loop through the number of subdirectories
    for i = 1:numSubdirs
        subdirName = ['mysubdir' num2str(i)]; % e.g., mysubdir1, mysubdir2, etc.

        % Create the subdirectory if it doesn't exist
        if ~exist(subdirName, 'dir')
            mkdir(subdirName);
        end

        % Loop through the number of files per subdirectory
        for j = 1:numFiles
            for k = 1:length(fileExtensions)
                % Generate the file name based on base name, index, and extension
                fileName = [fileBaseName '_' num2str(j) fileExtensions{k}];
                filePath = fullfile(subdirName, fileName);

                % Create the empty file
                fileID = fopen(filePath, 'w'); % Create an empty file
                fclose(fileID);
            end
        end
    end

    disp('Folder structure and files created successfully.');
end
