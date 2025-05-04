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
variableTable = variableTable(1:100,:);

%% Create NDI sessions
S = ndi.setup.NDIMaker.sessionMaker(myPath,variableTable);
[sessionArray,variableTable.sessionInd] = S.sessionIndices;

%% Add DAQ system
navigator = ndi.file.navigator(sessionArray{1}, ...
    {'#.mat', '#.epochprobemap.txt'}, ...
    'ndi.epoch.epochprobemap_daqsystem','#.epochprobemap.txt');
reader = ndi.daq.reader.mfdaq.ndr('dabrowska');
daqName = 'dabrowska_mat';
S.addDaqSystem(daqName,reader,navigator);

%% hangers on

L1 = (cellfun(@(x) ~isequaln(x,NaN), t.IsExpMatFile)) & cellfun(@(x) isequaln(x,NaN), t.BathConditionString);


 % need to add table constant elements, join 
 % epochprobmap_daqsystem: dabrowska_intracell
 % probes: dabrowska_current: patch-I
 %    dabrowska_voltage: patch-V
 %    dabrowska_stimulator: stimulator

bath_background
