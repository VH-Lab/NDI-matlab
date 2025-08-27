function [fileTable] = importDataFiles(dataFiles)

% Input argument validation
arguments
    dataFiles = '';
end

dataParentDir = fullfile(userpath,'data');
labName = 'pulakat';
dataPath = fullfile(dataParentDir,labName);

% Get files
fileList = vlt.file.manifest(dataPath);

% Need to be able to handle directory and/or individual files

% If no data files specified, retrieve them
if isempty(dataFiles)
    [names,paths] = uigetfile('*.*',...
        'Select data files','',...
        'MultiSelect','on');
    if eq(names,0)
        error('importDataFiles: No file(s) selected.');
    end
    dataFiles = fullfile(paths,names);
end



end