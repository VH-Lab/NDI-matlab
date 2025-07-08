function [] = doImport(dataParentDir,options)

% Input argument validation
arguments
    dataParentDir (1,:) char {mustBeFolder}
    options.Overwrite (1,1) logical = false
end

% Initialize progress bar
ndi.gui.component.ProgressBarWindow('Import Dataset');

%% Step 1: FILES. Get data path and files.

labName = 'haley';
dataPath = fullfile(dataParentDir,labName);

% Get .mat files
fileList = vlt.file.manifest(dataPath);
fileList(~contains(fileList,'.mat')) = [];

% Get files by type
infoFiles = fileList(contains(fileList,'experimentInfo'));
dataFiles = fileList(contains(fileList,'midpoint') | ...
    contains(fileList,'head') | contains(fileList,'tail'));
encounterFiles = fileList(contains(fileList,'encounter'));

%% Step 2: SESSIONS. Build the session.

% Create sessionMaker
SessionRef = {'Haley_2025'};
SessionPath = {labName};
sessionMaker = ndi.setup.NDIMaker.sessionMaker(dataParentDir,...
    table(SessionRef,SessionPath),'Overwrite',options.Overwrite);

% Get the session object
session = sessionMaker.sessionIndices; session = session{1};

%% Step 3. SUBJECTMAKER AND TABLEDOCMAKER.

% Create subjectMaker
subjectMaker = ndi.setup.NDIMaker.subjectMaker();

% Create tableDocMaker
tableDocMaker = ndi.setup.NDIMaker.tableDocMaker(session,labName);

%% Step 4. INFO DOCUMENTS.

% We will have one ontologyTableRow document for each experiment, plate,
% patch, video, and worm. Below, we define which info table variables will 
% get  stored under which ontologyTableRow document type
experimentVariables = {'expNum','growthBacteriaSpecies','growthBacteriaStrain',...
    'OD600Real','CFU','growthOD600','growthTimeSeed','growthTimeColdRoom',...
    'growthTimeRoomTemp','growthTimePicked'};
plateVariables = {'experiment_id','plateNum','exclude','strainID','satiety',...
    'condition','OD600Label','growthCondition','peptone',...
    'bacteriaSpecies','bacteria','OD600','timeSeed','timeColdRoom','timeRoomTemp',...
    'lawnVolume','lawnSpacing','temp','humidity'};
    %'firstFrame_id','arenaMask_id','patchMask_id','closestPatch_id','closestOD600_id'};
patchVariables = {'plate_id','lawnCenters','lawnRadii','lawnCircularity'};
videoVariables = {'plate_id','videoNum','timeRecord','pixelWidth','pixelHeight','frameRate','numFrames'};
wormVariables = {'plate_id','wormNum','subject_id'};

for i = 1:numel(infoFiles)

    % Load current table
    dataTable = load(fullfile(dataParentDir,infoFiles{i}));
    fields = fieldnames(dataTable);
    tableType = fields{1};
    dataTable = dataTable.(tableType);

    % A. EXPERIMENT ontologyTableRow

    % Add missing variables
    dataTable{:,'growthBacteriaSpecies'} = {'E. coli ontology'};
    dataTable.growthBacteriaStrain = dataTable.bacteria;

    % Compile data table with 1 row for each unique experiment day
    % and condition
    experimentTable = ndi.fun.table.join({dataTable(:,experimentVariables)},...
        'UniqueVariables',{'expNum','growthOD600'});

    % Create ontologyTableRow documents
    experimentDocs = tableDocMaker(experimentTable,{'expNum','growthOD600'},...
        'Overwrite',options.Overwrite);
    experimentTable.experiment_id = cellfun(@(d) d.id,experimentDocs);
    % experimentTable{:,'experiment_id'} = (1:height(experimentTable))';
    dataTable = ndi.fun.table.join({dataTable,...
        experimentTable(:,{'expNum','growthOD600','experiment_id'})});

    % B. PLATE ontologyTableRow

    % Add missing variables
    dataTable{:,'satiety'} = {'well-fed'};
    indSatiety = ndi.fun.table.identifyMatchingRows(dataTable,'strainName',...
        {'well-fed','food-deprived'});
    dataTable(indSatiety,'satiety') = dataTable.strainName(indSatiety);
    dataTable.bacteriaSpecies =  dataTable.growthBacteriaSpecies;

    % Compile data table with 1 row for each unique plate
    plateTable = ndi.fun.table.join({dataTable(:,plateVariables)},...
        'UniqueVariables',{'experiment_id','plateNum'});

    % Create ontologyTableRow documents
    plateDocs = tableDocMaker(plateTable,{'expNum','growthOD600'},...
        'Overwrite',options.Overwrite);
    plateTable.plate_id = cellfun(@(d) d.id,plateDocs);
    % plateTable{:,'plate_id'} = (1:height(plateTable))';
    dataTable = ndi.fun.table.join({dataTable,...
        plateTable(:,{'plateNum','plate_id'})});

    % C. PATCH ontologyTableRow

    % Compile data table with 1 row for each unique patch
    plate_id = cell(height(dataTable),1);
    patchNum = cell(height(dataTable),1);
    patchCenterX = cell(height(dataTable),1);
    patchCenterY = cell(height(dataTable),1);
    patchRadius = cell(height(dataTable),1);
    patchCircularity = cell(height(dataTable),1);
    for j = 1:height(dataTable)
        plateRow = dataTable(j,patchVariables);
        patchCenterX{j} = plateRow.lawnCenters{1}(:,1);
        patchCenterY{j} = plateRow.lawnCenters{1}(:,2);
        patchRadius{j} = plateRow.lawnRadii{1};
        patchCircularity{j} = plateRow.lawnCircularity{1};
        numPatch = numel(patchCenterX{j});
        plate_id{j} = repmat(plateRow.plate_id,numPatch,1);
        patchNum{j} = (1:numPatch)';
    end
    plate_id = vertcat(plate_id{:});
    patchNum = vertcat(patchNum{:});
    patchCenterX = vertcat(patchCenterX{:});
    patchCenterY = vertcat(patchCenterY{:});
    patchRadius = vertcat(patchRadius{:});
    patchCircularity = vertcat(patchCircularity{:});
    patchTable = table(plate_id,patchNum,patchCenterX,patchCenterY,...
        patchRadius,patchCircularity);

    % Create ontologyTableRow documents
    patchDocs = tableDocMaker(patchTable,{'plate_id','patchNum'},...
        'Overwrite',options.Overwrite);

    % D. VIDEO ontologyTableRow

    % Add missing variables
    dataTable.pixelWidth = cellfun(@(p) p(1),dataTable.pixels);
    dataTable.pixelHeight = cellfun(@(p) p(2),dataTable.pixels);

    % Compile data table with 1 row for each unique video
    videoTable = ndi.fun.table.join({dataTable(:,videoVariables)},...
        'UniqueVariables',{'plate_id','videoNum'});

    % Create ontologyTableRow documents
    videoDocs = tableDocMaker(videoTable,{'plate_id','videoNum'},...
        'Overwrite',options.Overwrite);

    % E. WORM subject and ontologyTableRow

    % Compile data table with 1 row for each unique worm
    plate_id = cell(height(dataTable),1);
    wormNum = cell(height(dataTable),1);
    for j = 1:height(dataTable)
        wormNum{j} = dataTable{j,'wormNum'}{1}';
        numWorm = numel(wormNum{j});
        plate_id{j} = repmat(dataTable{j,'plate_id'},numWorm,1);
    end
    plate_id = vertcat(plate_id{:});
    wormNum = vertcat(wormNum{:});
    wormTable = table(plate_id,wormNum);

    % Create subject string
    wormTable{:,'sessionID'} = {session.id};
    dirName = split(fileList{i},filesep); dirName = dirName{end-1};
    wormTable{:,'subjectName'} = arrayfun(@(wormNum) ...
        [dirName,'_',num2str(wormNum,'%04.f')],wormTable.wormNum,...
        'UniformOutput',false);

    % Create subject documents
    [subjectInfo,wormTable.subjectID] = ...
        subjectMaker.getSubjectInfoFromTable(wormTable,...
        @ndi.setup.conv.haley.createSubjectInformation);
    subDocStruct = subjectMaker.makeSubjectDocuments(subjectInfo);
    subjectMaker.addSubjectsToSessions({session}, subDocStruct.documents);
    wormTable.subject_id = cellfun(@(d) d.id,subDocStruct.documents);
    % wormTable{:,'subject_id'} = (1:height(wormTable))';

    % Create ontologyTableRow documents
    wormDocs = tableDocMaker(wormTable(:,wormVariables),{'subject_id'},...
        'Overwrite',options.Overwrite);
end

%% Step 5. DATA DOCUMENTS.

for i = 1:numel(dataFiles)

    % Load current table
    dataTable = load(fullfile(dataParentDir,dataFiles{i}));
    fields = fieldnames(dataTable);
    tableType = fields{1};
    dataTable = dataTable.(tableType);

    % A. EXPERIMENT ontologyTableRow
end

%% Step 6. ENCOUNTER DOCUMENTS.

end