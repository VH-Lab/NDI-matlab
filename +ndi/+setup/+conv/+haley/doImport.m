function [] = doImport(dataParentDir)

% Input argument validation
arguments
    dataParentDir (1,:) char {mustBeFolder}
end

% Initialize progress bar
progressBar = ndi.gui.component.ProgressBarWindow('Import Dataset');

% Get data path
dataPath = fullfile(dataParentDir,'haley');

% Get mat files
fileList = vlt.file.manifest(dataPath);
fileList(~contains(fileList,'.mat')) = [];

%% Process tables (experimentInfo, data, encounter)
for i = 1:numel(fileList)
    dataTable = load(fullfile(dataParentDir,fileList{i}));
    fields = fieldnames(dataTable);
    dataTable = dataTable.(fields{1});

    
end

end