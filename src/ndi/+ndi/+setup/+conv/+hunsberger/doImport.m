options.Overwrite = true;

%% Step 1: FILES. Get data path and files.

% Get data path
dataParentDir = fullfile(userpath,'data');
dataPath = fullfile(dataParentDir,'hunsberger');

% If overwriting, delete NDI docs
fileList = vlt.file.manifest(dataPath);
if options.Overwrite
    ndiFiles = fileList(endsWith(fileList,'.ndi') | contains(fileList,'.epoch'));
    for i = 1:numel(ndiFiles)
        fileName = fullfile(dataParentDir,ndiFiles{i});
        if isfolder(fileName)
            rmdir(fileName,'s');
        else
            delete(fileName);
        end
    end
end

% Get file list
[dirList,isDir] = vlt.file.manifest(dataPath);
fileList = dirList(~isDir);
include = ~contains(fileList,'/._') & ~startsWith(fileList,'._') & ...
    ~contains(fileList,'.DS_Store') & ~endsWith(fileList,'epochprobemap.txt') & ~endsWith(fileList,'.epochid.ndi');
fileList = fileList(include);

%% Step 2: SESSIONS. Build the session.

% Build variableTable
variableTable = cell2table({'Hunsberger','hunsberger'}, ...
    'VariableNames',{'SessionRef','SessionPath'});

% Employ the sessionMaker
SM = ndi.setup.NDIMaker.sessionMaker(dataParentDir,variableTable,...
    'Overwrite',options.Overwrite);
[sessionArray,variableTable.sessionInd,variableTable.sessionID] = SM.sessionIndices;

%% Step 3. DATA. Get data tables

dataTables = cell(size(fileList));
variableNames = {};
for i = 1:numel(fileList)
    dataTables{i} = readtable(fullfile(dataParentDir,fileList{i}));
end

%% Step 4: SUBJECTS. Build subject documents.

% Add cell tagging subjects
subjectCellTag = dataTables{1}(:,{'ID','Sex','Condition'});
subjectCellTag{:,'StrainType'} = 'ArcCreERT2';
subjectCFC = ndi.fun.table.vstack({dataTables{2}(:,1:8), ...
    renamevars(dataTables{3}(:,1:17),'Age_months_','Age_Months_'), ...
    dataTables{4}(:,1:8)});
subjectCFC{:,'StrainType'} = '129S6/SvEv';
subjectTable = ndi.fun.table.vstack({subjectCellTag,subjectCFC});

% Are the animals in data table 3 "ArcCreERT2" or '129S6/SvEv'?


%%

% 1. Instantiate the subjectMaker and the lab-specific SubjectInformationCreator
subM = ndi.setup.NDIMaker.subjectMaker();
creator = ndi.setup.conv.dabrowska.SubjectInformationCreator();

% 2. Call a single function to extract subject info, create documents, and add to the session.
%    This also returns the subject string for each row of the variableTable, which is
%    essential for linking other documents later.
[~, variableTable.SubjectString] = ...
    subM.addSubjectsFromTable(sessionArray{1}, variableTable, creator);

%%

varMatch = @(dataTable,s) dataTable(contains(dataTable,s));

%% Cell count table

cellTable = dataTables{1};

% Fix efyp > eyfp
cellTable = renamevars(cellTable,'vDGefypAvg','vDGeyfpAvg');

% Stack values
cellVariables = cellTable.Properties.VariableNames;
eyfpVariables = varMatch(cellVariables,'eyfpAvg');
cfosVariables = varMatch(cellVariables,'cfosAvg');
eyfpEngramVariables = varMatch(cellVariables,'eyfpEngramAvg');
cfosEngramVariables = varMatch(cellVariables,'c_fosEngramAvg');

eyfpTable = stack(cellTable,eyfpVariables,...
    'NewDataVariableName','eYFPAvg',...
    'IndexVariableName', 'BrainRegion');
eyfpTable.BrainRegion = cellstr(replace(string(eyfpTable.BrainRegion),'eyfpAvg',''));
eyfpTable = eyfpTable(:,[1:5,24:25]);

cfosTable = stack(cellTable,cfosVariables,...
    'NewDataVariableName','cFosAvg',...
    'IndexVariableName', 'BrainRegion');
cfosTable.BrainRegion = cellstr(replace(string(cfosTable.BrainRegion),'cfosAvg',''));
cfosTable = cfosTable(:,[1:5,24:25]);

eyfpEngramTable = stack(cellTable,eyfpEngramVariables,...
    'NewDataVariableName','eYFPEngramAvg',...
    'IndexVariableName', 'BrainRegion');
eyfpEngramTable.BrainRegion = cellstr(replace(string(eyfpEngramTable.BrainRegion),'_eyfpEngramAvg_',''));
eyfpEngramTable = eyfpEngramTable(:,[1:5,24:25]);

cfosEngramTable = stack(cellTable,cfosEngramVariables,...
    'NewDataVariableName','cFosEngramAvg',...
    'IndexVariableName', 'BrainRegion');
cfosEngramTable.BrainRegion = cellstr(replace(string(cfosEngramTable.BrainRegion),'_c_fosEngramAvg_',''));
cfosEngramTable = cfosEngramTable(:,[1:5,24:25]);

cellTable = ndi.fun.table.join({eyfpTable,cfosTable,eyfpEngramTable,cfosEngramTable});

% Subjects (species, strain, sex)
% Treatments (need new terms for control/treatment here)
% OntologyTableRows

%% CFC table

cfcTable = dataTables{2};

% Remove average values
avgVariables = varMatch(cfcTable.Properties.VariableNames,'Avg');
cfcTable = removevars(cfcTable,avgVariables);

% Stack values
cfcVariables = varMatch(cfcTable.Properties.VariableNames,'CFC');
cfcTable = stack(cfcTable, cfcVariables, ...
    'NewDataVariableName', 'CFCFreezing', ...
    'IndexVariableName', 'TrainingBlock');
cfcTable.TrainingBlock = cellstr(cfcTable.TrainingBlock);

% Extract block info
pattern = 'CFC(RE_EXPOSE|TRAINING)(\d+)';
extractedData = regexp(cfcTable.TrainingBlock, pattern, 'tokens');
for i = 1:height(cfcTable)
    if ~isempty(extractedData{i})
        cfcTable.BlockType{i} = extractedData{i}{1}{1};
        cfcTable.BlockMinute(i) = str2double(extractedData{i}{1}{2});
    end
end
cfcTable.BlockType = replace(cfcTable.BlockType, 'RE_EXPOSE', 'Re-exposure');
cfcTable.BlockType = replace(cfcTable.BlockType, 'TRAINING', 'Training');

% Subjects (species, strain, sex)
% Measurements (DOB, weight)
% Treatments (condition)

%% State dependent table

stateTable = dataTables{3};

% StackValues
trainingVariables = varMatch(stateTable.Properties.VariableNames,'TrainingMin');
trainingTable = stack(stateTable, trainingVariables, ...
    'NewDataVariableName', 'CFCFreezing', ...
    'IndexVariableName', 'BlockMinute');
trainingTable.BlockMinute = str2double(replace(string(trainingTable.BlockMinute),'TrainingMin',''));
trainingTable = trainingTable(:,[1:17,end-1:end]);
trainingTable{:,'BlockType'} = {'Training'};

reexposureVariables = varMatch(stateTable.Properties.VariableNames,'Re_exposureMin');
reexposureTable = stack(stateTable, reexposureVariables, ...
    'NewDataVariableName', 'CFCFreezing', ...
    'IndexVariableName', 'BlockMinute');
reexposureTable.BlockMinute = str2double(replace(string(reexposureTable.BlockMinute),'Re_exposureMin',''));
reexposureTable = reexposureTable(:,[1:17,end-1:end]);
reexposureTable{:,'BlockType'} = {'Re-exposure'};

stateTable = [trainingTable;reexposureTable];

% drug treatment

%% Behavior table

behaviorTable = dataTables{4};

% Remove average values
avgVariables = varMatch(behaviorTable.Properties.VariableNames,'Avg');
behaviorTable = removevars(behaviorTable,avgVariables);

% Stack values
cfcVariables = varMatch(behaviorTable.Properties.VariableNames,'CFC');
behaviorTable = stack(behaviorTable, cfcVariables, ...
    'NewDataVariableName', 'CFCFreezing', ...
    'IndexVariableName', 'TrainingBlock');

behaviorTable.TrainingBlock = cellstr(behaviorTable.TrainingBlock);

% Extract block info
pattern = 'CFC(RE_EXPOSE|TRAINING)(\d+)';
extractedData = regexp(behaviorTable.TrainingBlock, pattern, 'tokens');
for i = 1:height(behaviorTable)
    if ~isempty(extractedData{i})
        behaviorTable.BlockType{i} = extractedData{i}{1}{1};
        behaviorTable.BlockMinute(i) = str2double(extractedData{i}{1}{2});
    end
end
behaviorTable.BlockType = replace(behaviorTable.BlockType, 'RE_EXPOSE', 'Re-exposure');
behaviorTable.BlockType = replace(behaviorTable.BlockType, 'TRAINING', 'Training');