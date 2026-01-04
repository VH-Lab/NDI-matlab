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
subjectTable = cell2table({'Hunsberger','hunsberger'}, ...
    'VariableNames',{'SessionRef','SessionPath'});

% Employ the sessionMaker
SM = ndi.setup.NDIMaker.sessionMaker(dataParentDir,subjectTable,...
    'Overwrite',options.Overwrite);
[sessionArray,subjectTable.sessionInd,subjectTable.sessionID] = SM.sessionIndices;

%% Step 3. DATA. Get data tables

dataTables = cell(size(fileList));
variableNames = {};
for i = 1:numel(fileList)
    dataTables{i} = readtable(fullfile(dataParentDir,fileList{i}));
end

%% Step 4: SUBJECTS. Build subject documents.

% Create subject table
subjectCellTag = dataTables{1}(:,{'ID','Sex','Condition','Tg'});
subjectCellTag{:,'StrainType'} = {'ArcCreERT2 x eYFP'};
subjectCFC = ndi.fun.table.vstack({dataTables{2}(:,1:8), ...
    renamevars(dataTables{3}(:,1:17),'Age_months_','Age_Months_'), ...
    dataTables{4}(:,1:8)});
subjectCFC{:,'StrainType'} = {'129S6/SvEv'};
subjectTable = ndi.fun.table.vstack({subjectCellTag,subjectCFC});

% Create subjectMaker
subjectMaker = ndi.setup.NDIMaker.subjectMaker();
subjectCreator = ndi.setup.conv.hunsberger.SubjectInformationCreator();

% Create subjects
[~, subjectTable.SubjectLocalIdentifier,subjectTable.SubjectDocumentIdentifier] = ...
    subjectMaker.addSubjectsFromTable(sessionArray{1}, subjectTable, subjectCreator);

%% Cell count table

% Helper function
varMatch = @(dataTable,s) dataTable(contains(dataTable,s));

% Get cell count table data
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

% Combine cell count tables
cellTable = ndi.fun.table.join({eyfpTable,cfosTable,eyfpEngramTable,cfosEngramTable});

% Add subjects
cellTable = innerjoin(cellTable,subjectTable,'Keys',{'ID','Condition','Tg','Sex'}, ...
    'RightVariables',{'SubjectLocalIdentifier','SubjectDocumentIdentifier'});

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

% Add subjects
cfcTable = innerjoin(cfcTable,subjectTable,'Keys',...
    {'ID','Cohort','Condition','Sex','BoxNumber','DOB'}, ...
    'RightVariables',{'SubjectLocalIdentifier','SubjectDocumentIdentifier'});
cfcTable =  unique(cfcTable,'rows'); % duplicates for unknown reason

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

% Add subjects
stateTable = innerjoin(stateTable,subjectTable,'Keys',...
    {'Cohort','Today','Condition','Sex','BoxNumber','Tg'}, ...
    'RightVariables',{'SubjectLocalIdentifier','SubjectDocumentIdentifier'});

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

% Add subjects
behaviorTable = innerjoin(behaviorTable,subjectTable,'Keys',...
    {'Cohort','ID','Condition','Sex','BoxNumber','DOB'}, ...
    'RightVariables',{'SubjectLocalIdentifier','SubjectDocumentIdentifier'});
behaviorTable = unique(behaviorTable,'rows'); % duplicates for unknown reason