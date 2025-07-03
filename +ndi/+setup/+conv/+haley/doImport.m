function [] = doImport(dataParentDir,options)

% Input argument validation
arguments
    dataParentDir (1,:) char {mustBeFolder}
    options.Overwrite (1,1) logical = false
end

% Initialize progress bar
ndi.gui.component.ProgressBarWindow('Import Dataset');

% Get data path
dataPath = fullfile(dataParentDir,'haley');

% Get mat files
fileList = vlt.file.manifest(dataPath);
fileList(~contains(fileList,'.mat')) = [];

%% Process tables (experimentInfo, data, encounter)
for i = 1:numel(fileList)

    % Load current table
    dataTable = load(fullfile(dataParentDir,fileList{i}));
    fields = fieldnames(dataTable);
    dataTable = dataTable.(fields{1});

    % 
    dataTable
    
end

end