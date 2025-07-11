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

% Create imageDocMaker
imageDocMaker = ndi.setup.NDIMaker.imageDocMaker(session);

%% Step 4. INFO DOCUMENTS.

% We will have one ontologyTableRow document for each experiment, plate,
% patch, video, and worm. Below, we define which info table variables will 
% get  stored under which ontologyTableRow document type
experimentVariables = {'expNum','growthBacteriaStrain',...
   'growthOD600','growthTimeSeed','growthTimeColdRoom',...
    'growthTimeRoomTemp','growthTimePicked', 'OD600Real','CFU'};
plateVariables = {'experiment_id','plateNum','exclude','strain','hoursFoodDeprived',...
    'condition','OD600Label','growthCondition','peptoneFlag',...
    'bacteriaStrain','OD600','timeSeed','timeColdRoom','timeRoomTemp',...
    'lawnGrowth','lawnVolume','lawnSpacing','arenaDiameter','temp','humidity'};
    %'firstFrame_id','arenaMask_id','patchMask_id','closestPatch_id','closestOD600_id'};
patchVariables = {'plate_id','lawnCenters','lawnRadii','lawnCircularity'};
videoVariables = {'plate_id','videoNum','timeRecord','pixelWidth','pixelHeight',...
    'frameRate','numFrames','scale'};
wormVariables = {'plate_id','wormNum','subject_id'};

for i = 1:numel(infoFiles)

    % Load current table
    dataTable = load(fullfile(dataParentDir,infoFiles{i}));
    fields = fieldnames(dataTable);
    tableType = fields{1};
    dataTable = dataTable.(tableType);
    dirName = split(infoFiles{i},filesep); dirName = dirName{end-1};

    % A. EXPERIMENT ontologyTableRow

    % Add missing variables
    dataTable{:,'growthBacteriaStrain'} = {'NCBITaxon:637912'};

    % Compile data table with 1 row for each unique experiment day
    % and condition
    experimentTable = ndi.fun.table.join({dataTable(:,experimentVariables)},...
        'UniqueVariables',{'expNum','growthOD600'});
    experimentTable = movevars(experimentTable,'growthOD600','After','growthBacteriaStrain');

    % Create ontologyTableRow documents
    % info.(dirName).experimentDocs = tableDocMaker(experimentTable,{'expNum','growthOD600'},...
    %     'Overwrite',options.Overwrite);
    % experimentTable.experiment_id = cellfun(@(d) d.id,info.(dirName).experimentDocs);
    experimentTable{:,'experiment_id'} = (1:height(experimentTable))';
    dataTable = ndi.fun.table.join({dataTable,...
        experimentTable(:,{'expNum','growthOD600','experiment_id'})});
    info.(dirName).experimentTable = experimentTable;

    % B. PLATE ontologyTableRow

    % Add missing variables
    dataTable{:,'hoursFoodDeprived'} = 0;
    indSatiety = ndi.fun.table.identifyMatchingRows(dataTable,'strainName',...
        'food-deprived');
    dataTable{indSatiety,'hoursFoodDeprived'} = 3;
    dataTable.bacteriaStrain =  dataTable.growthBacteriaStrain;
    indN2 = ndi.fun.table.identifyMatchingRows(dataTable,'strainID','N2');
    dataTable{indN2,'strain'} = {'WBStrain:00000001'};
    indMEC4 = ndi.fun.table.identifyMatchingRows(dataTable,'strainID','mec-4');
    dataTable{indMEC4,'strain'} = {'WBStrain:00035037'};
    indOSM6 = ndi.fun.table.identifyMatchingRows(dataTable,'strainID','osm-6');
    dataTable{indOSM6,'strain'} = {'WBStrain:00030796'};
    dataTable{:,'peptoneFlag'} = true;
    indWithout = ndi.fun.table.identifyMatchingRows(dataTable,'peptone','without');
    dataTable{indWithout,'peptoneFlag'} = false;

    % Compile data table with 1 row for each unique plate
    plateTable = ndi.fun.table.join({dataTable(:,plateVariables)},...
        'UniqueVariables',{'experiment_id','plateNum'});

    % Create ontologyTableRow documents
    % info.(dirName).plateDocs = tableDocMaker(plateTable,{'expNum','growthOD600'},...
    %     'Overwrite',options.Overwrite);
    % plateTable.plate_id = cellfun(@(d) d.id,info.(dirName).plateDocs);
    plateTable{:,'plate_id'} = (1:height(plateTable))';
    dataTable = ndi.fun.table.join({dataTable,...
        plateTable(:,{'plateNum','plate_id'})});
    info.(dirName).plateTable = plateTable;

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
    % info.(dirName).patchDocs = tableDocMaker(patchTable,{'plate_id','patchNum'},...
    %     'Overwrite',options.Overwrite);
    info.(dirName).patchTable = patchTable;

    % D. VIDEO ontologyTableRow

    % Add missing variables
    dataTable.pixelWidth = cellfun(@(p) p(1),dataTable.pixels);
    dataTable.pixelHeight = cellfun(@(p) p(2),dataTable.pixels);

    % Compile data table with 1 row for each unique video
    videoTable = ndi.fun.table.join({dataTable(:,videoVariables)},...
        'UniqueVariables',{'plate_id','videoNum'});

    % Create ontologyTableRow documents
    % info.(dirName).videoDocs = tableDocMaker(videoTable,{'plate_id','videoNum'},...
    %     'Overwrite',options.Overwrite);
    info.(dirName).videoTable = videoTable;

    % E. WORM subject and ontologyTableRow

    % Compile data table with 1 row for each unique worm
    [~,ind] = unique(dataTable.plate_id);
    plate_id = cell(numel(ind),1);
    wormNum = cell(numel(ind),1);
    expTime = cell(numel(ind),1);
    for j = 1:numel(ind)
        wormNum{j} = dataTable{ind(j),'wormNum'}{1}';
        numWorm = numel(wormNum{ind(j)});
        plate_id{j} = repmat(dataTable{ind(j),'plate_id'},numWorm,1);
        expTime{j} = repmat(dataTable{ind(j),'timeRecord'},numWorm,1);
    end
    plate_id = vertcat(plate_id{:});
    wormNum = vertcat(wormNum{:});
    expTime = vertcat(expTime{:});
    wormTable = table(plate_id,wormNum,expTime);

    % Add subject string info
    wormTable{:,'sessionID'} = {session.id};
    wormTable = ndi.fun.table.join({wormTable,...
        plateTable(:,{'plate_id','strain','condition'})});
    wormTable{:,'dirName'} = {dirName};

    % Create subject documents
    [subjectInfo,wormTable.subjectName] = ...
        subjectMaker.getSubjectInfoFromTable(wormTable,...
        @ndi.setup.conv.haley.createSubjectInformation);
    subDocStruct = subjectMaker.makeSubjectDocuments(subjectInfo);
    subjectMaker.addSubjectsToSessions({session}, subDocStruct.documents);
    info.(dirName).subjectDocs = subDocStruct.documents;
    wormTable.subject_id = cellfun(@(d) d{1}.id,info.(dirName).subjectDocs,'UniformOutput',false);

    % Create ontologyTableRow documents
    % info.(dirName).wormDocs = tableDocMaker(wormTable(:,wormVariables),{'subject_id'},...
    %     'Overwrite',options.Overwrite);
    info.(dirName).wormTable = wormTable;

    % F. PLATE ontologyImage
    % [~,ind] = unique(dataTable.plate_id);
    % info.(dirName).firstFrameDocs = imageDocMaker.array2imageDocs(...
    %     dataTable.firstFrame(ind),...
    %     'EMPTY:C. elegans behavioral assay: first frame image',...
    %     'ontologyTableRow_id',dataTable.plate_id(ind),...
    %     'Overwrite',options.Overwrite);
    % info.(dirName).arenaMaskDocs = iimageDocMaker.array2imageDocs(...
    %     dataTable.arenaMask(ind),...
    %     'EMPTY:C. elegans behavioral assay: arena mask',...
    %     'ontologyTableRow_id',dataTable.plate_id(ind),...
    %     'Overwrite',options.Overwrite);
    % info.(dirName).bacteriaMaskDocs = imageDocMaker.array2imageDocs(...
    %     dataTable.lawnMask(ind),...
    %     'EMPTY:C. elegans behavioral assay: bacteria mask',...
    %     'ontologyTableRow_id',dataTable.plate_id(ind),...
    %     'Overwrite',options.Overwrite);
    % info.(dirName).closestPatchDocs = imageDocMaker.array2imageDocs(...
    %     dataTable.lawnClosest(ind),...
    %     'EMPTY:C. elegans behavioral assay: closest patch identifier map',...
    %     'ontologyTableRow_id',dataTable.plate_id(ind),...
    %     'Overwrite',options.Overwrite);
    % info.(dirName).closestOD600Docs = imageDocMaker.array2imageDocs(...
    %     dataTable.lawnClosestOD600(ind),...
    %     'EMPTY:C. elegans behavioral assay: closest patch OD600 map',...
    %     'ontologyTableRow_id',dataTable.plate_id(ind),...
    %     'Overwrite',options.Overwrite);
end

%% Step 5. DATA DOCUMENTS.

for i = 1:numel(dataFiles)

    % Load current table
    dataTable = load(fullfile(dataParentDir,dataFiles{i}));
    fields = fieldnames(dataTable);
    tableType = fields{1};
    dataTable = dataTable.(tableType);
    dirName = split(dataFiles{i},filesep); dirName = dirName{end-1};

    % Loop through each worm (subject)
    wormNums = unique(dataTable.wormNum);
    for j = 1:numel(wormNums)

        % Get indices
        indWorm = info.(dirName).wormTable.wormNum == wormNums(i);
        plate_id = info.(dirName).wormTable.plate_id(indWorm);
        subject_id = info.(dirName).wormTable.subject_id{indWorm};
        indPatch = info.(dirName).patchTable.plate_id == plate_id;
        indData = dataTable.wormNum == wormNums(i);

        % Get relevant data
        time = dataTable.timeOffset(indData);
        position = dataTable{indData,{'xPosition','yPosition'}};
        distance = [dataTable{indData,'distanceLawnEdge'},...
            ones(size(indData)),dataTable{indData,'nearestLawnID'}];
        t0_t1_local = prctile(dataTable.timeOffset(indData),[0 100]);
        t0_t1_global = convertTo(info.(dirName).wormTable.expTime(indWorm) + ...
            seconds(t0_t1_local),'datenum');

        % A. POSITION elements and metadata

        % Create position element and add epoch
        positionElement = ndi.element.timeseries(session,'position',1,'position',[],0,subject_id);
        positionElement.addepoch('position','dev_local_time,exp_global_time', ...
            [t0_t1_local;t0_t1_global], time, position);
        % positionElement.addepoch('position',ndi.time.clocktype('UTC'),t0_t1_local,time,data);
        % [d,t,timeref] = positionElement.readtimeseries('position',-Inf,Inf);

        % Create position_metadata doc
        position_metadata.ontologyNode = 'EMPTY:C. elegans body part'
        position_metadata.ontologyNumericValue = [];
        position_metadata.ontologyStringValue = 'midpoint';
        position_metadata.dimensions
        

        % B. DISTANCE elements and metadata

        % Create distance element and add epoch
        distanceElement = ndi.element.timeseries(session,'distance',1,'distance',[],0,subject_id);
        distanceElement.addepoch('distance','dev_local_time,exp_global_time', ...
            [t0_t1_local;t0_t1_global], time, distance);
    end
    
end

%% Step 6. ENCOUNTER DOCUMENTS.

end