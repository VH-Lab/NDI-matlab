% Set paths
myDir = '/Users/jhaley/Documents/MATLAB';
myPath = fullfile(myDir,'data','Dabrowska');

% Get files
[dirList,isDir] = vlt.file.manifest(myPath);
fileList = dirList(~isDir);
% include = ~contains(fileList,'/._') & ~startsWith(fileList,'._') & ...
%     ~contains(fileList,'.DS_Store'); 
% fileList = fileList(include);

% Get variable table
jsonPath = fullfile(myDir,'tools/NDI-matlab/+ndi/+setup/+conv/+dabrowska/dabrowskaDataLocation.json');
j = jsondecode(fileread(jsonPath));
variableTable = ndi.setup.conv.datalocation.processFileManifest(fileList,...
    j,'relativePathPrefix','Dabrowska/');
% variableTable = variableTable(100:200,:);

%% Create NDI sessions
S = ndi.setup.NDIMaker.sessionMaker(myPath,variableTable,...
    'NonNaNVariableNames','IsExpMatFile','Overwrite',true);
[sessionArray,variableTable.sessionInd] = S.sessionIndices;

%% Add DAQ system
labName = 'dabrowskalab';
S.addDaqSystem(labName,'Overwrite',true)