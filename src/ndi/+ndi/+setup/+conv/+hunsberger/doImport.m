function [] = doImport(dataParentDir,options)

% Input argument validation
arguments
    dataParentDir (1,:) char {mustBeFolder} = fullfile(userpath,'data')
    options.Overwrite (1,1) logical = true
end

% Initialize progress bar
progressBar = ndi.gui.component.ProgressBarWindow('Import Dataset');
progressBar.setTimeout(hours(1));

%% Step 1: FILES. Get data path and files.

% Get data path
labName = 'hunsberger';
dataPath = fullfile(dataParentDir,labName);

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
    ~contains(fileList,'.ndi') & ~contains(fileList,'.DS_Store') & ...
    ~endsWith(fileList,'epochprobemap.txt') & ~endsWith(fileList,'.epochid.ndi') & ...
    ~endsWith(fileList,'.zip');
fileList = fileList(include);

%% Step 2: SESSIONS. Build the session.

% Build variableTable
subjectTable = cell2table({labName,labName}, ...
    'VariableNames',{'SessionRef','SessionPath'});

% Employ the sessionMaker
SM = ndi.setup.NDIMaker.sessionMaker(dataParentDir,subjectTable,...
    'Overwrite',options.Overwrite);
[sessionArray,subjectTable.sessionInd,subjectTable.sessionID] = SM.sessionIndices;
session = sessionArray{1}; % only 1 session

%% Step 3. DATA. Get data tables

dataTables = cell(size(fileList));
for i = 1:numel(fileList)
    fileName = fullfile(dataParentDir,fileList{i});
    opts = detectImportOptions(fileName);
    opts.VariableTypes{strcmp(opts.VariableNames,'ID')} = 'char';
    dataTables{i} = readtable(fileName,opts);
end

%% Step 4: SUBJECTS. Build subject documents.

% Create subject table
subjectCellTag = dataTables{1}(:,[1,2,4]);
subjectBehavior = dataTables{4}(:,2:8);
subjectCFC = dataTables{2}(:,2:8);
subject1 = innerjoin(subjectCellTag,subjectBehavior); % same cohort
subject2 = outerjoin(subjectCFC,subject1,'MergeKeys',true); % overlapping cohorts
subject2{:,'StrainType'} = {'ArcCreERT2 x eYFP'};
subjectState = renamevars(dataTables{3}(:,[1,3:17]), ...
    {'Age_months_','InitialWeightTraining'},{'Age_Months_','InitialWeight_g_'}); 
subjectState{:,'StrainType'} = {'129S6/SvEv'};
subjectTable = ndi.fun.table.vstack({subject2,subjectState});

% Add experiment date
ind = isnat(subjectTable.Today);
subjectTable.AgeDays = round(subjectTable.Age_Months_.*30.5); % reverse formula used by lab
subjectTable.Today(ind) = subjectTable.DOB(ind) + subjectTable.AgeDays(ind);

% Create subjectMaker
subjectMaker = ndi.setup.NDIMaker.subjectMaker();
subjectCreator = ndi.setup.conv.hunsberger.SubjectInformationCreator();

% Create subjects
[~,subjectTable.SubjectLocalIdentifier,subjectTable.SubjectDocumentIdentifier] = ...
    subjectMaker.addSubjectsFromTable(session, subjectTable, subjectCreator);

%% Add measurements and drug treatments

% Create treatment creator and maker
treatmentCreator = ndi.setup.conv.hunsberger.TreatmentCreator();
treatmentMaker = ndi.setup.NDIMaker.treatmentMaker();

% Create DOB and weight measurement tables
dobTable = treatmentCreator.create(subjectTable, session, 'DOB');
weightTable = treatmentCreator.create(subjectTable, session, 'InitialWeight_g_');

% Create drug treatment tables
injection1Table = treatmentCreator.create(subjectTable, session, 'InjectionTime');
injection2Table = treatmentCreator.create(subjectTable, session, 'injectionTimeDay2');

% Create treatment documents
treatmentTable = [dobTable;weightTable;injection1Table;injection2Table];
treatmentMaker.addTreatmentsFromTable(session, treatmentTable);

%% Step 5. TABLES. Create ontologyTableRow docs.

% Initialize tableDocMaker
tableDocMaker = ndi.setup.NDIMaker.tableDocMaker(session,labName);

% Helper function
varMatch = @(dataTable,s) dataTable(contains(dataTable,s));

%% Cell count table

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
cellTable = innerjoin(cellTable,subjectBehavior);
cellTable = innerjoin(cellTable,subjectTable,'Keys',{'ID','Condition','Sex','BoxNumber'}, ...
    'RightVariables',{'SubjectLocalIdentifier','SubjectDocumentIdentifier'});

% Add brain region ontology ids
brainRegions = {'dDG','dCA3','dCA1','vDG','vCA3','vCA1'};
brainRegionNames = {'dorsal dentate gyrus of hippocampal formation',...
    'dorsal CA3','dorsal CA1',...
    'ventral dentate gyrus of hippocampal formation',...
    'ventral CA3','ventral CA1'};
brainRegionOntology = {'EMPTY:00000289','EMPTY:00000291','EMPTY:00000293',...
    'EMPTY:00000290','EMPTY:00000292','EMPTY:00000294'};
for i = 1:numel(brainRegions)
    ind = strcmp(cellTable.BrainRegion,brainRegions{i});
    cellTable(ind,'BrainRegionName') = brainRegionNames(i);
    cellTable(ind,'BrainRegionOntology') = brainRegionOntology(i);
end

% Create cellTag table docs
cellTagVars = {'SubjectLocalIdentifier','SubjectDocumentIdentifier',...
    'BrainRegionName','BrainRegionOntology','eYFPAvg','cFosAvg',...
    'eYFPEngramAvg','cFosEngramAvg'};
tableDocMaker.table2ontologyTableRowDocs(cellTable(:,cellTagVars),...
    {'SubjectDocumentIdentifier','BrainRegionName'},...
    'Overwrite',options.Overwrite);

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
    {'ID','Condition','Sex','BoxNumber','DOB'}, ...
    'RightVariables',{'SubjectLocalIdentifier','SubjectDocumentIdentifier'});

% Add CFC time and duration
cfcTable{:,'CFCDuration'} = 60; % 60 s blocks
cfcTable.CFCSeconds = cfcTable.CFCDuration.*(cfcTable.CFCFreezing./100);

% Convert age in months to days
cfcTable.AgeDays = round(cfcTable.Age_Months_.*30.5); % reverse formula used by lab
cfcTable.ExperimentDate = cfcTable.DOB + cfcTable.AgeDays;
cfcTable.ExperimentDate = cellstr(string(cfcTable.ExperimentDate,'yyyy-MM-dd'));

% Create CFC table docs
cfcVars = {'SubjectLocalIdentifier','SubjectDocumentIdentifier',...
    'ExperimentDate','AgeDays','BlockType','BlockMinute',...
    'CFCSeconds','CFCDuration','CFCFreezing'};
tableDocMaker.table2ontologyTableRowDocs(cfcTable(:,cfcVars),...
    {'SubjectDocumentIdentifier','BlockType','BlockMinute'},...
    'Overwrite',options.Overwrite);

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
    {'ID','Condition','Sex','BoxNumber','Tg'}, ...
    'RightVariables',{'SubjectLocalIdentifier','SubjectDocumentIdentifier'});

% Convert age in months to days
stateTable.AgeDays = round(stateTable.Age_months_.*30.5); % reverse formula used by lab

% Add cfc timestamp
indTrain = ndi.fun.table.identifyMatchingRows(stateTable,'BlockType','Training');
indReExp = ndi.fun.table.identifyMatchingRows(stateTable,'BlockType','Re-exposure');
stateTable.ExperimentDate(indTrain) = stateTable.Today(indTrain) + ...
    days(fillmissing(stateTable.CFCDay1_time_(indTrain),'constant',0));
stateTable.ExperimentDate(indReExp) = stateTable.Today(indReExp) + ...
    days(5 + fillmissing(stateTable.CFCDay2(indReExp),'constant',0));

% Format timestamp
stateTable.ExperimentDate = cellstr(string(stateTable.ExperimentDate,'yyyy-MM-dd') + ...
    "T" + string(stateTable.ExperimentDate,'hh:mm:ss'));
stateTable.ExperimentDate = replace(stateTable.ExperimentDate,'T12:00:00','');

% Add CFC time and duration
stateTable{:,'CFCDuration'} = 60; % 60 s blocks
stateTable.CFCSeconds = stateTable.CFCDuration.*(stateTable.CFCFreezing./100);

% Create CFC table docs
stateVars = {'SubjectLocalIdentifier','SubjectDocumentIdentifier',...
    'ExperimentDate','AgeDays','BlockType','BlockMinute',...
    'CFCSeconds','CFCDuration','CFCFreezing'};
tableDocMaker.table2ontologyTableRowDocs(stateTable(:,stateVars),...
    {'SubjectDocumentIdentifier','BlockType','BlockMinute'},...
    'Overwrite',options.Overwrite);

%% Behavior table (redundant with CFC table)

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

% Add CFC time and duration
behaviorTable{:,'CFCDuration'} = 60; % 60 s blocks
behaviorTable.CFCSeconds = behaviorTable.CFCDuration.*(behaviorTable.CFCFreezing./100);

% Add subjects
behaviorTable = innerjoin(behaviorTable,subjectTable,'Keys',...
    {'ID','Condition','Sex','BoxNumber','DOB'}, ...
    'RightVariables',{'SubjectLocalIdentifier','SubjectDocumentIdentifier'});

% Create behavior table docs
% behaviorVars = {'SubjectLocalIdentifier','SubjectDocumentIdentifier',...
%     'BlockType','BlockMinute','CFCFreezing'};
% tableDocMaker.table2ontologyTableRowDocs(behaviorTable(:,behaviorVars),...
%     {'SubjectDocumentIdentifier','BlockType','BlockMinute'},...
%     'Overwrite',options.Overwrite);

%% Step 6. Make dataset

% Create dataset
datasetName = [labName,'_2025'];
datasetDir = fullfile(dataPath,datasetName);
if ~exist(datasetDir,'dir')
    mkdir(datasetDir);
elseif options.Overwrite
    rmdir(datasetDir,'s');
    mkdir(datasetDir);
end
dataset = ndi.dataset.dir(datasetName,datasetDir);

% Ingest and add sessions
for i = 1:numel(sessionArray)
    sessionDatabaseDir = fullfile(sessionArray{i}.path,'.ndi');
    if options.Overwrite && exist([sessionDatabaseDir,'_'],'dir')
        rmdir([sessionDatabaseDir,'_'],'s');
    end
    copyfile(sessionDatabaseDir,[sessionDatabaseDir,'_']);
    sessionArray{i}.ingest;
    dataset.add_ingested_session(sessionArray{i});
end

% Compress dataset
zip([datasetDir,'.zip'],datasetDir);