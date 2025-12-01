% 1. Download or sync local dataset with NDI Cloud

% Define the directory where the dataset is (or will be) stored
dataPath = fullfile(userpath,'Datasets');
if ~isfolder(dataPath)
    mkdir(dataPath);
end

% Define the dataset id and its local path
cloudDatasetId = '682e7772cdf3f24938176fac';
datasetPath = fullfile(dataPath,cloudDatasetId);

% Load/download dataset
if isfolder(datasetPath)
    % Load if already downloaded and sync with cloud
    dataset = ndi.dataset.dir(datasetPath);
    % dataset = ndi.cloud.sync.downloadNew(dataset);
else
    % Download from cloud
    dataset = ndi.cloud.downloadDataset(cloudDatasetId,dataPath);
end

% Add to path
addpath(genpath(datasetPath));

% Retrieve the sessions from this dataset
[session_ref,session_list] = dataset.session_list();
session_Celegans = dataset.open_session(session_list{contains(session_ref,'Celegans')});
session_Ecoli = dataset.open_session(session_list{contains(session_ref,'Ecoli')});

% 2. Generate tables from dataset

% Get session table
sessionTable = pulakat.metatable.sessions(dataset,false);

% Get documents/table
query = ndi.query('','isa','ontologyTableRow');
docs = session_Celegans.database_search(query);
[dataTables,docIDs] = ndi.fun.doc.ontologyTableRowDoc2Table(docs); % this may take a minute

% Add relevant document identifiers
dataTables{1} = addvars(dataTables{1},docIDs{1}',...
    'NewVariableNames','BacterialPatchDocumentIdentifier'); % add patch document identifier
dataTables{2} = addvars(dataTables{2},docIDs{2}',...
    'NewVariableNames','BacterialPlateDocumentIdentifier'); % add plate document identifier
dataTables{3} = addvars(dataTables{3},docIDs{3}',...
    'NewVariableNames','BacterialPlateDocumentIdentifier'); % add plate document identifier

% Get tables
subjectSummary = ndi.fun.docTable.subject(session_Celegans); % this will take a minute
subjectTable = ndi.fun.table.join({dataTables{6},subjectSummary}); % adds subject metadata to subject table
behaviorPlateTable = ndi.fun.table.join(dataTables(1:2)); % add patch data to behavior plates
cultivationPlateTable = dataTables{3}; % cultivation plate data
subjectPlateTable = dataTables{4}; % subject to plate mapping

% Add cloud tag
sessionTable{:,'Cloud'} = true;
subjectTable{:,'Cloud'} = true;
behaviorPlateTable{:,'Cloud'} = true;
cultivationPlateTable{:,'Cloud'} = true;
subjectPlateTable{:,'Cloud'} = true;

% 3. Create/update nansen project

% Load pulakat project from nansen project manager
projectName = 'haley';
nansenRepoPath = fullfile(datasetPath,'nansen');
projectPath = fullfile(nansenRepoPath,projectName);
projectManager = nansen.ProjectManager(); 

% Import the project from the repo if that hasn't already been done
if ~projectManager.containsProject(projectName)
    projectManager.importProject(projectPath);
end

% Open project
project = projectManager.getProjectObject(projectName);

% 4. Add metatables to project and launch nansen viewer

% Create (or replace) metatables
metaTable = nansen.metadata.MetaTable(sessionTable, ...
    'MetaTableClass', 'Session', ...
    'ItemClassName', 'table2struct', ...
    'MetaTableIdVarname', 'SessionDocumentIdentifier');
project.addMetaTable(metaTable);
metaTable = nansen.metadata.MetaTable(subjectTable, ...
    'MetaTableClass', 'Subject', ...
    'ItemClassName', 'table2struct', ...
    'MetaTableIdVarname', 'SubjectDocumentIdentifier');
project.addMetaTable(metaTable);
% metaTable = nansen.metadata.MetaTable(behaviorPlateTable, ...
%     'MetaTableClass', 'BehaviorPlates', ...
%     'ItemClassName', 'table2struct', ...
%     'MetaTableIdVarname', 'BacterialPlateDocumentIdentifier');
% project.addMetaTable(metaTable);
% metaTable = nansen.metadata.MetaTable(cultivationPlateTable, ...
%     'MetaTableClass', 'CultivationPlates', ...
%     'ItemClassName', 'table2struct', ...
%     'MetaTableIdVarname', 'BacterialPlateDocumentIdentifier');
% project.addMetaTable(metaTable);

% Ensure 'haley' is the current project
projectManager.changeProject(projectName)

% Launch nansen
nansen