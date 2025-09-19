%% GUI Workflow

% 1. Update nansen viewer to match cloud dataset
% 2. Ask for all the parent directories where new data files are located or
%       allow drag and drop.
% 3. Validate data files.
%       - If a file labeled animal_mapping is in the parent directories, 
%           use that automatically and indicate that new subjects were
%           detected.
%       - If subjects are missing from the database, prompt user to add 
%           those subjects now (choose spreadsheets(s)) or add manually. 
%           If not added, skip those subjects and their associated files.
%       - Show them what new subjects are being added to the database if
%           they already exist, are there any discrepencies that need to be
%           resolved
%       - Show user what datafiles are being added, what their file type is
%           and any files of unknown file type (but known subject).
%       - If a data files are already in the database, ask user if they 
%           want to skip or replace.
% 4. Ingest data
% 5. Sync data to cloud
% 6. Update nansen viewer to match cloud dataset

%% 0. Get directories

% Get directory (probably want to allow users to specify multiple paths)
dataParentDir = fullfile(userpath,'data');
labName = 'pulakat';
dataPath = fullfile(dataParentDir,labName);
%dataPath = uigetdir([],'Select directory of files to ingest.');

% project = ndi.internal.project.pulakat(dataPath);

%% 1. Load ingested data from Nansen (skipping for now)

% Create subject table from files
subjectFiles = {'/Users/jhaley/Documents/MATLAB/data/pulakat/animal_mapping_1.csv'};
subjectTable_nansen = ndi.setup.conv.pulakat.importSubjectFiles(subjectFiles);
subjectTable_nansen{:,'Ingested'} = true;

dataFiles = {'/Users/jhaley/Documents/MATLAB/data/pulakat/20220526_164841_Lakshmi-Alex_RatHeartsFeb2022-DIA_Report.xlsx'};
dataTable_nansen = ndi.setup.conv.pulakat.importDataFiles(dataFiles);
dataTable_nansen{:,'Ingested'} = true;
% need to replace this with loading from Nansen

%% 2. Query for new files

% Get list of files corresponding to one session
[fileList,indDir] = vlt.file.manifest(dataPath,'ReturnFullPath',1);

% Create session (how to properly handle this)?
sessionName = 'Session1';
sessionTable = cell2table({sessionName,labName},'VariableNames',...
    {'SessionRef','SessionPath'});
sessionMaker = ndi.setup.NDIMaker.sessionMaker(dataParentDir,...
    sessionTable,'Overwrite',true);
sessions = sessionMaker.sessionIndices;

% Narrow file list to possible subject and data files
indHiddenFiles = contains(fileList,'/.');
indSubjectFiles = contains(fileList,'animal_mapping');
subjectFiles = fileList(~indHiddenFiles & indSubjectFiles);
dataFiles = fileList(~indHiddenFiles & ~indDir & ~indSubjectFiles);

%% 3. Import new subjects that were auto-detected

% Import all subjects in given directories
subjectTable_new = ndi.setup.conv.pulakat.importSubjectFiles(subjectFiles);
subjectTable = ndi.fun.table.vstack({subjectTable_nansen,subjectTable_new});
subjectTable = ndi.fun.table.join({subjectTable},'uniqueVariables', ...
    {'Animal','Cage','Label','subjectFile'});
indNew = ~ndi.fun.table.identifyValidRows(subjectTable,'Ingested');
subjectTable{indNew,'Ingested'} = false;

%% 4. Import new data files

% Import all new data files in given directories
dataTable_new = ndi.setup.conv.pulakat.importDataFiles(dataFiles);
dataTable = ndi.fun.table.vstack({dataTable_nansen,dataTable_new});
dataTable = ndi.fun.table.join({dataTable},'uniqueVariables', ...
    {'Animal','Cage','Label','fileName'});
indNew = ~ndi.fun.table.identifyValidRows(dataTable,'Ingested');
dataTable{indNew,'Ingested'} = false;

% Match data files with existing subjects
[indSubjects,numSubjects] = ndi.setup.conv.pulakat.matchData2Subjects(dataTable,subjectTable);
dataTable_matching = dataTable(numSubjects == 1,:);
dataTable_matching.indSubject = [indSubjects{numSubjects == 1}]';
dataTable_missing = dataTable(numSubjects == 0,:);
dataTable_multiple = dataTable(numSubjects > 1,:);

%% 5. Prompt user for missing subject mapping

% Query user for new files
subjectTable_new = ndi.setup.conv.pulakat.importSubjectFiles();
subjectTable = ndi.fun.table.vstack({subjectTable,subjectTable_new});
subjectTable = ndi.fun.table.join({subjectTable},'uniqueVariables', ...
    {'Animal','Cage','Label','subjectFile'});
indNew = ~ndi.fun.table.identifyValidRows(subjectTable,'Ingested');
subjectTable{indNew,'Ingested'} = false;

% Match data files with subjects again
[indSubjects,numSubjects] = ndi.setup.conv.pulakat.matchData2Subjects(dataTable,subjectTable);

% need more guidance on how we want to deal with missing files

%% 6. Ingest new subjects and data

subjectTable = ndi.setup.conv.pulakat.importSubjects(subjectTable);
dataTable = ndi.setup.conv.pulakat.importData(dataTable);