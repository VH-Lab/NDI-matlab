function datasets = listLocalDatasets()
    % listLocalDatasets Load table (inventory) of local datasets.
    %
    %   Syntax:
    %   datasets = listLocalDatasets() returns a table containing details about
    %   local datasets. The function reads information from a session table file
    %   and extracts dataset names based on the last folder name in the dataset
    %   path.
    %
    %   Output:
    %   datasets - A table with columns representing dataset details such as
    %              the dataset path and name.
    %
    %   Example:
    %   datasets = ndi.database.dataset_viewer.utility.listLocalDatasets();
    %   disp(datasets);

    prefsFolder = fullfile(userpath, 'Preferences', 'NDI');
    filePath = fullfile(prefsFolder, 'local_sessiontable.txt');
    datasets = readtable( filePath, "Delimiter", "tab");

    numDatasets = height(datasets);

    datasetNames = cell(1,numDatasets);

    % Get name: temp: use last folder name
    for i = 1:numDatasets
        [~, datasetNames{i}] = fileparts( datasets{i,"path"}{1} );
    end

    datasets.name = datasetNames';
end