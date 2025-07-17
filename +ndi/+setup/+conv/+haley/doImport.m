function [] = doImport(dataParentDir,options)

% Input argument validation
arguments
    dataParentDir (1,:) char {mustBeFolder} = fullfile(userpath,'data')
    options.Overwrite (1,1) logical = true
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
bacteriaFiles = fileList(contains(fileList,'bacteria'));

%% Step 2: SESSIONS. Build the session.

% Create sessionMaker
SessionRef = {'Haley_2025_Celegans';'Haley_2025_Ecoli'};
SessionPath = {fullfile(labName,'celegans');fullfile(labName,'ecoli')};
sessionMaker = ndi.setup.NDIMaker.sessionMaker(dataParentDir,...
    table(SessionRef,SessionPath),'Overwrite',options.Overwrite);

% Get the session object
sessions = sessionMaker.sessionIndices; session = sessions{1};
session.cache.clear;

%% Step 3. SUBJECTMAKER AND TABLEDOCMAKER.

% Create subjectMaker
subjectMaker = ndi.setup.NDIMaker.subjectMaker();

% Create tableDocMaker
tableDocMaker = ndi.setup.NDIMaker.tableDocMaker(session,labName);
tableDocMaker_ecoli = ndi.setup.NDIMaker.tableDocMaker(sessions{2},labName);

% Create imageDocMaker
imageDocMaker = ndi.setup.NDIMaker.imageDocMaker(session);

%% Step 4. BACTERIA. Create openMINDS documents for bacterial food

% E. coli
species = openminds.controlledterms.Species;
species.name = 'Escherichia coli';
species.preferredOntologyIdentifier = 'NCBITaxon:562';
species.definition = 'Escherichia coli is a species of bacteria.';
species.synonym = 'E. coli';

% OP50
OP50 = openminds.core.research.Strain;
OP50.name = 'Escherichia coli OP50';
OP50.species = species;
OP50.ontologyIdentifier = 'NCBITaxon:637912';
OP50.description = 'OP50 is a strain of E. coli.';
OP50.geneticStrainType = 'wild type';

% Add documents to database
strainDoc = ndi.database.fun.openMINDSobj2ndi_document(OP50,session.id);
session.database_add(strainDoc);

%% Step 5. INFO DOCUMENTS.

% We will have one ontologyTableRow document for each experiment, plate,
% patch, video, and worm. Below, we define which info table variables will 
% get  stored under which ontologyTableRow document type
experimentVariables = {'expNum','growthBacteriaStrain',...
   'growthOD600','growthTimeSeed','growthTimeColdRoom',...
    'growthTimeRoomTemp','growthTimePicked', 'OD600Real','CFU'};
plateVariables = {'experiment_id','plateNum','exclude',...
    'condition','OD600Label','growthCondition','peptoneFlag',...
    'bacteriaStrain','timeSeed','timeColdRoom','timeRoomTemp',...
    'lawnGrowth','lawnVolume','lawnSpacing','arenaDiameter','temp','humidity'};
patchVariables = {'plate_id','OD600','lawnCenters','lawnRadii','lawnCircularity'};
videoVariables = {'plate_id','videoNum','timeRecord','pixelWidth','pixelHeight',...
    'frameRate','numFrames','bitDepth','scale'};
wormVariables = {'plate_id','wormNum','subject_id'};

for i = 1:numel(infoFiles)

    % Load current table
    dataTable = load(fullfile(dataParentDir,infoFiles{i}));
    fields = fieldnames(dataTable);
    tableType = fields{1};
    dataTable = dataTable.(tableType);
    dirName = split(infoFiles{i},filesep); dirName = dirName{end-1};

    % Check for correct exclusion
    dataTable.exclude = dataTable.exclude | ...
        ~ndi.fun.table.identifyValidRows(dataTable,'growthCondition');

    % A. EXPERIMENT ontologyTableRow

    % Add missing variables
    dataTable{:,'growthBacteriaStrain'} = {strainDoc{1}.id};

    % Compile data table with 1 row for each unique experiment day and condition
    experimentTable = ndi.fun.table.join({dataTable(:,experimentVariables)},...
        'UniqueVariables',{'expNum','growthOD600'});
    experimentTable = movevars(experimentTable,'growthOD600','After','growthBacteriaStrain');

    % Create ontologyTableRow documents
    info.(dirName).experimentDocs = tableDocMaker.table2ontologyTableRowDocs(...
        experimentTable,{'expNum','growthOD600'},'Overwrite',options.Overwrite);
    experimentTable.experiment_id = cellfun(@(d) d.id,...
        info.(dirName).experimentDocs,'UniformOutput',false);
    dataTable = ndi.fun.table.join({dataTable,...
        experimentTable(:,{'expNum','growthOD600','experiment_id'})});
    info.(dirName).experimentTable = experimentTable;

    % B. PLATE ontologyTableRow

    % Add missing variables
    dataTable.bacteriaStrain = dataTable.growthBacteriaStrain;
    [strainNames,~,indStrain] = unique(dataTable.strainID);
    strainIDs = cellfun(@(s) ndi.ontology.lookup(['WBStrain:',s]),strainNames,'UniformOutput',false);
    dataTable.strain = strainIDs(indStrain);
    dataTable{:,'peptoneFlag'} = true;
    indWithout = ndi.fun.table.identifyMatchingRows(dataTable,'peptone','without');
    dataTable{indWithout,'peptoneFlag'} = false;

    % Compile data table with 1 row for each unique plate
    plateTable = ndi.fun.table.join({dataTable(:,plateVariables)},...
        'UniqueVariables',{'experiment_id','plateNum'});

    % Create ontologyTableRow documents
    info.(dirName).plateDocs = tableDocMaker.table2ontologyTableRowDocs(...
        plateTable,{'experiment_id','plateNum'},'Overwrite',options.Overwrite);
    plateTable.plate_id = cellfun(@(d) d.id,info.(dirName).plateDocs,'UniformOutput',false);
    dataTable = ndi.fun.table.join({dataTable,plateTable(:,{'plateNum','plate_id'})});
    info.(dirName).plateTable = plateTable;

    % C. PATCH ontologyTableRow

    % Compile data table with 1 row for each unique patch
    plate_id = cell(height(dataTable),1);
    patchNum = cell(height(dataTable),1);
    patchOD600 = cell(height(dataTable),1);
    patchCenterX = cell(height(dataTable),1);
    patchCenterY = cell(height(dataTable),1);
    patchRadius = cell(height(dataTable),1);
    patchCircularity = cell(height(dataTable),1);
    for j = 1:height(dataTable)
        plateRow = dataTable(j,patchVariables);
        try
            patchCenterX{j} = plateRow.lawnCenters{1}(:,1);
            patchCenterY{j} = plateRow.lawnCenters{1}(:,2);
            patchRadius{j} = plateRow.lawnRadii{1};
            patchCircularity{j} = plateRow.lawnCircularity{1};
        catch
            patchCenterX{j} = NaN(numPatch,1);
            patchCenterY{j} = NaN(numPatch,1);
            patchRadius{j} = NaN(numPatch,1);
            patchCircularity{j} = NaN(numPatch,1);
            dataTable.pixels{j} = [NaN,NaN];
        end
        numPatch = numel(patchCenterX{j});
        if contains(dirName,'Matching')
            patchOD600{j} = plateRow.OD600{1}';
        elseif contains(dirName,'Mutants') || contains(dirName,'Sensory')
            patchOD600{j} = repmat(plateRow.OD600{1}(1),numPatch,1);
        else
            patchOD600{j} = repmat(plateRow.OD600,numPatch,1);
        end
        plate_id{j} = repmat(plateRow.plate_id,numPatch,1);
        patchNum{j} = (1:numPatch)';
    end
    plate_id = vertcat(plate_id{:});
    patchNum = vertcat(patchNum{:});
    patchOD600 = vertcat(patchOD600{:});
    if contains(dirName,'Matching') || contains(dirName,'Mutants') || ...
            contains(dirName,'Sensory')
        patchOD600(patchOD600 == 0) = [];
    end
    patchCenterX = vertcat(patchCenterX{:});
    patchCenterY = vertcat(patchCenterY{:});
    patchRadius = vertcat(patchRadius{:});
    patchCircularity = vertcat(patchCircularity{:});
    patchTable = table(plate_id,patchNum,patchOD600,patchCenterX,patchCenterY,...
        patchRadius,patchCircularity);

    % Create ontologyTableRow documents
    info.(dirName).patchDocs = tableDocMaker.table2ontologyTableRowDocs(...
        patchTable,{'plate_id','patchNum'},'Overwrite',options.Overwrite);
    patchTable.patch_id = cellfun(@(d) d.id,info.(dirName).patchDocs,'UniformOutput',false);
    patchTable{:,'dirName'} = {dirName};
    info.(dirName).patchTable = patchTable;

    % D. VIDEO ontologyTableRow

    % Add missing variables
    dataTable.pixelWidth = cellfun(@(p) p(1),dataTable.pixels);
    dataTable.pixelHeight = cellfun(@(p) p(2),dataTable.pixels);
    dataTable.bitDepth = cellfun(@(ff) class(ff),dataTable.firstFrame,'UniformOutput',false);

    % Compile data table with 1 row for each unique video
    videoTable = ndi.fun.table.join({dataTable(:,videoVariables)},...
        'UniqueVariables',{'plate_id','videoNum'});

    % Create ontologyTableRow documents
    info.(dirName).videoDocs = tableDocMaker.table2ontologyTableRowDocs(...
        videoTable,{'plate_id','videoNum'},'Overwrite',options.Overwrite);
    info.(dirName).videoTable = videoTable;

    % E. WORM subject, ontologyTableRow, and treatment

    % Compile data table with 1 row for each unique worm
    [~,ind] = unique(dataTable.plate_id);
    plate_id = cell(numel(ind),1);
    wormNum = cell(numel(ind),1);
    expTime = cell(numel(ind),1);
    for j = 1:numel(ind)
        wormNum{j} = dataTable{ind(j),'wormNum'}{1}';
        numWorm = numel(wormNum{j});
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
        plateTable(:,{'plate_id','condition'}),...
        dataTable(:,{'plate_id','strain'})},...
        'uniqueVariables',{'plate_id','wormNum'});
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
    info.(dirName).wormDocs = tableDocMaker.table2ontologyTableRowDocs(wormTable(:,wormVariables),...
        {'subject_id'},'Overwrite',options.Overwrite);
    info.(dirName).wormTable = wormTable;

    % Create treatment documents
    if any(ismember(dataTable.Properties.VariableNames,'starvedTime')) && ...
            any(dataTable.starvedDuration > 0)
        wormTable = ndi.fun.table.join({wormTable,...
            dataTable(:,{'plate_id','strainName','starvedTime','timeRecord'})},...
            'uniqueVariables',{'plate_id','wormNum'});
        ind = find(ndi.fun.table.identifyMatchingRows(wormTable,'strainName','food-deprived'));
        onsetDocs = cell(numel(ind),1);
        offsetDocs = cell(numel(ind),1);
        for j = 1:numel(ind)
            % Food deprivation onset
            [ontologyID,name] = ndi.ontology.lookup('EMPTY:Treatment: food restriction onset time');
            treatment = struct('ontologyName',ontologyID,...
                'name',name,...
                'numeric_value',[],...
                'string_value',wormTable.starvedTime{ind(j)});
            onsetDocs{j} = ndi.document('treatment',...
                'treatment', treatment) + session.newdocument;
            onsetDocs{j} = onsetDocs{j}.set_dependency_value(...
                'subject_id', wormTable.subject_id{ind(j)});

            % Food deprivation offset
            [ontologyID,name] = ndi.ontology.lookup('EMPTY:Treatment: food restriction offset time');
            treatment = struct('ontologyName',ontologyID,...
                'name',name,...
                'numeric_value',[],...
                'string_value',wormTable.timeRecord{ind(j)});
            offsetDocs{j} = ndi.document('treatment',...
                'treatment', treatment) + session.newdocument;
            offsetDocs{j} = offsetDocs{j}.set_dependency_value(...
                'subject_id', wormTable.subject_id{ind(j)});
        end
        session.database_add(onsetDocs);
        session.database_add(offsetDocs);
    end

    % F. PLATE ontologyImage
    [~,ind] = unique(dataTable.plate_id);
    info.(dirName).firstFrameDocs = imageDocMaker.array2imageDocs(...
        dataTable.firstFrame(ind),...
        'EMPTY:C. elegans behavioral assay: first frame image',...
        'ontologyTableRow_id',dataTable.plate_id(ind),...
        'Overwrite',options.Overwrite);
    info.(dirName).arenaMaskDocs = imageDocMaker.array2imageDocs(...
        dataTable.arenaMask(ind),...
        'EMPTY:C. elegans behavioral assay: arena mask',...
        'ontologyTableRow_id',dataTable.plate_id(ind),...
        'Overwrite',options.Overwrite);
    info.(dirName).bacteriaMaskDocs = imageDocMaker.array2imageDocs(...
        dataTable.lawnMask(ind),...
        'EMPTY:C. elegans behavioral assay: bacteria mask',...
        'ontologyTableRow_id',dataTable.plate_id(ind),...
        'Overwrite',options.Overwrite);
    info.(dirName).closestPatchDocs = imageDocMaker.array2imageDocs(...
        dataTable.lawnClosest(ind),...
        'EMPTY:C. elegans behavioral assay: closest patch identifier map',...
        'ontologyTableRow_id',dataTable.plate_id(ind),...
        'Overwrite',options.Overwrite);
    info.(dirName).closestOD600Docs = imageDocMaker.array2imageDocs(...
        dataTable.lawnClosestOD600(ind),...
        'EMPTY:C. elegans behavioral assay: closest patch OD600 map',...
        'ontologyTableRow_id',dataTable.plate_id(ind),...
        'Overwrite',options.Overwrite);
end

%% Step 6. DATA DOCUMENTS.

% Create progress bar
progressBar = ndi.gui.component.ProgressBarWindow('Import Dataset','Overwrite',false);

for i = 1:numel(dataFiles)

    % Load current table
    dataTable = load(fullfile(dataParentDir,dataFiles{i}));
    fields = fieldnames(dataTable);
    tableType = fields{1};
    dataTable = dataTable.(tableType);
    dirName = split(dataFiles{i},filesep); dirName = dirName{end-1};
    progressBar = progressBar.addBar('Label', 'Creating Position and Distance Element(s)',...
        'Tag', dirName);

    % Get ontology terms
    [~,bodyPart] = fileparts(dataFiles{i});
    bodyPartID = ndi.ontology.lookup(['EMPTY:C. elegans ' bodyPart]);
    subjectDocID = ndi.ontology.lookup('EMPTY:Subject document identifier');
    patchDocID = ndi.ontology.lookup('EMPTY:C. elegans assay: patch parameter document identifier');

    % Loop through each worm (subject)
    wormNums = unique(dataTable.wormNum);
    positionMetadataDocs = cell(size(wormNums));
    distanceMetadataDocs = cell(size(wormNums));
    for j = 1:numel(wormNums)

        % Get indices
        indWorm = info.(dirName).wormTable.wormNum == wormNums(j);
        plate_id = info.(dirName).wormTable.plate_id(indWorm);
        subject_id = info.(dirName).wormTable.subject_id{indWorm};
        indPatch = strcmp(info.(dirName).patchTable.plate_id,plate_id);
        indData = dataTable.wormNum == wormNums(j);
        wormName = strsplit(info.(dirName).wormTable.subjectName{indWorm},'@');
        wormName = wormName{1};

        % Get relevant data
        time = dataTable.timeOffset(indData);
        position = dataTable{indData,{'xPosition','yPosition'}};
        distance = [dataTable{indData,'distanceLawnEdge'},...
            ones(sum(indData),1),dataTable{indData,'closestLawnID'}];
        t0_t1_local = prctile(dataTable.timeOffset(indData),[0 100]);
        t0_t1_global = convertTo(datetime(info.(dirName).wormTable.expTime{indWorm}) + ...
            seconds(t0_t1_local),'datenum');

        % A. POSITION elements and metadata

        % Create position element and add epoch
        positionElement = ndi.element.timeseries(session,...
            [wormName,'_',bodyPart,'_position'],1,'position',[],0,subject_id);
        positionElement.addepoch([wormName,'_',bodyPart,'_position'],...
            'dev_local_time,exp_global_time',...
            [t0_t1_local;t0_t1_global], time, position);

        % Create position_metadata structure
        position_metadata.ontologyNode = bodyPartID; % C. elegans head, midpoint, or tail
        position_metadata.units = 'NCIT:C48367'; % pixels
        position_metadata.dimensions = 'NCIT:C44477,NCIT:C44478'; % X-coordinate, Y-coordinate
        
        % Create position_metadata document
        positionMetadataDocs{j} = ndi.document('position_metadata',...
            'position_metadata', position_metadata) + session.newdocument;
        positionMetadataDocs{j} = positionMetadataDocs{j}.set_dependency_value(...
            'element_id', positionElement.id);

        % B. DISTANCE elements and metadata

        % Create distance element and add epoch
        distanceElement = ndi.element.timeseries(session,...
            [wormName,'_',bodyPart,'_distance'],1,'distance',[],0,subject_id);
        distanceElement.addepoch([wormName,'_',bodyPart,'_distance'],...
            'dev_local_time,exp_global_time',...
            [t0_t1_local;t0_t1_global], time, distance);

        % Create distance_metadata structure
        distance_metadata.ontologyNode_A = subjectDocID; % subject document id
        distance_metadata.integerIDs_A = 1;
        distance_metadata.ontologyNumericValues_A = [];
        distance_metadata.ontologyStringValues_A = subject_id;
        distance_metadata.ontologyNode_B = patchDocID; % patch ontologyTableRow document id
        distance_metadata.integerIDs_B = info.(dirName).patchTable.patchNum(indPatch)';
        distance_metadata.ontologyNumericValues_B = [];
        distance_metadata.ontologyStringValues_B = strjoin(info.(dirName).patchTable.patch_id(indPatch),',');
        distance_metadata.units = 'NCIT:C48367'; % pixels

        % Create distance_metadata document
        distanceMetadataDocs{j} = ndi.document('distance_metadata',...
            'distance_metadata', distance_metadata) + session.newdocument;
        distanceMetadataDocs{j} = distanceMetadataDocs{j}.set_dependency_value(...
            'element_id', distanceElement.id);

        progressBar = progressBar.updateBar(dirName, j / numel(wormNums));
    end

    % Add documents to database
    session.database_add(positionMetadataDocs);
    session.database_add(distanceMetadataDocs);
end

%% Step 7. ENCOUNTER DOCUMENTS.

encounterVariables = {'subject_id','encounterNum','patch_id',...
    'timeEnter','timeExit',....
    'decelerate','velocityOnMin','velocityBeforeEnter','velocityAfterEnter',...
    'exploitPosterior','sensePosterior',...
    'density','densityGrowth'};

% Load encounter table
dataTable = load(fullfile(dataParentDir,encounterFiles{1}));
fields = fieldnames(dataTable);
tableType = fields{1};
dataTable = dataTable.(tableType);

% Add density and densityGrowth
[G,GID] = findgroups(dataTable(:,{'expName','lawnVolume',...
    'growthCondition','OD600Label','strainName','strainID'}));
borderAmp = splitapply(@(X) mean(X,'omitnan'),dataTable.borderAmplitude,G);
borderAmp10 = borderAmp(strcmp(GID.expName,'foragingConcentration') & ...
    strcmp(GID.OD600Label,'10.00') & GID.lawnVolume == 0.5);
borderAmp0 = 1e-2; % assign 0 to 0.01
dataTable.density = log10(max(10*dataTable.borderAmplitude./borderAmp10,borderAmp0));
dataTable.densityGrowth = log10(10*dataTable.borderAmplitudeGrowth/borderAmp10);

% Add subject_id and patch_id
fields = fieldnames(info);
wormTable = table();
patchTable = table();
for i = 1:numel(fields)
    wormTable = ndi.fun.table.vstack({wormTable,info.(fields{i}).wormTable});
    patchTable = ndi.fun.table.vstack({patchTable,info.(fields{i}).patchTable});
end
dataTable = renamevars(dataTable,{'expName','id','lawnID'},{'dirName','encounterNum','patchNum'});
dataTable = ndi.fun.table.join({dataTable,...
    wormTable(:,{'wormNum','dirName','subject_id','plate_id'}),...
    patchTable(:,{'patchNum','dirName','plate_id','patch_id'})});

% Create ontologyTableRow documents
indEncounter = dataTable.encounterNum > 0;
encounterDocs = tableDocMaker.table2ontologyTableRowDocs(...
    dataTable(indEncounter,encounterVariables),...
    {'subject_id','encounterNum'},'Overwrite',options.Overwrite);

%% Step 8. BACTERIA DOCUMENTS.

% Get the session object
session = sessions{2};
session.cache.clear;

% OP50-GFP
OP50GFP = openminds.core.research.Strain;
OP50GFP.name = 'OP50-GFP';
OP50GFP.species = species;
OP50GFP.ontologyIdentifier = 'WBStrain:00041972';
OP50GFP.description = 'A strain of OP50 that contains a GFP plasmid (pFPV25.1) that is very fluorescent. Resistant to ampicillin.';
OP50GFP.geneticStrainType = 'transgenic';
OP50GFP.backgroundStrain = OP50;

% Add OpenMinds documents to database
strainDoc = ndi.database.fun.openMINDSobj2ndi_document(OP50GFP,session.id);
session.database_add(strainDoc);

% Get data from .mat
dataTable = load(fullfile(dataParentDir,bacteriaFiles{1}),'lawnAnalysis');
dataTable = dataTable.lawnAnalysis;

% List the variables for each document type
experimentVariables = {'expNum','bacteria','OD600Real','CFU'};
plateVariables = {'experiment_id','plateNum','OD600','lawnVolume',...
    'peptoneFlag','timePoured','timePouredColdRoom',...
    'timeSeed','timeSeedColdRoom','timeRoomTemp'};
imageVariables = {'plate_id','imageNum','acquisitionTime',...
    'xPixels','yPixels','exposureTime','bitDepth','scale',...
    'minValue','maxValue','meanValue'};
patchVariables = {'image_id','patchNum',...
    'xPeak','yPeak','xOuterEdge','yOuterEdge',...
    'xHalfMaxOuter','xHalfMaxInner','yHalfMax','FWHM',...
    'lawnRadius','circularity',...
    'borderAmplitude','meanAmplitude','centerAmplitude','borderCenterRatio'};

% A. EXPERIMENT ontologyTableRow

% Add missing variables
dataTable{:,'bacteria'} = {strainDoc{1}.id};

% Compile data table with 1 row for each unique experiment day
experimentTable = ndi.fun.table.join({dataTable(:,experimentVariables)},...
    'UniqueVariables','expNum');

% Create ontologyTableRow documents
experimentDocs = tableDocMaker_ecoli.table2ontologyTableRowDocs(...
    experimentTable,{'expNum'},'Overwrite',options.Overwrite);
experimentTable.experiment_id = cellfun(@(d) d.id,experimentDocs,'UniformOutput',false);
dataTable = ndi.fun.table.join({dataTable,experimentTable(:,{'expNum','experiment_id'})});

% B. PLATE ontologyTableRow

% Add missing variables
dataTable{:,'peptoneFlag'} = true;
indWithout = ndi.fun.table.identifyMatchingRows(dataTable,'peptone','without');
dataTable{indWithout,'peptoneFlag'} = false;

% Compile data table with 1 row for each unique plate
plateTable = ndi.fun.table.join({dataTable(:,plateVariables)},...
    'UniqueVariables',{'experiment_id','plateNum'});

% Create ontologyTableRow documents
plateDocs = tableDocMaker_ecoli.table2ontologyTableRowDocs(...
    plateTable,{'experiment_id','plateNum'},'Overwrite',options.Overwrite);
plateTable.plate_id = cellfun(@(d) d.id,plateDocs,'UniformOutput',false);
dataTable = ndi.fun.table.join({dataTable,plateTable(:,{'experiment_id','plateNum','plate_id'})});

% C. IMAGE ontologyTableRow documents

% Compile data table with 1 row for each unique image
imageTable = ndi.fun.table.join({dataTable(:,imageVariables)},...
    'UniqueVariables',{'plate_id','imageNum'});

% Create ontologyTableRow documents
imageDocs = tableDocMaker_ecoli.table2ontologyTableRowDocs(...
    imageTable,{'plate_id','imageNum'},'Overwrite',options.Overwrite);
imageTable.image_id = cellfun(@(d) d.id,imageDocs,'UniformOutput',false);
dataTable = ndi.fun.table.join({dataTable,imageTable(:,{'plate_id','imageNum','image_id'})});

% D. PATCH ontologyTableRow documents

% Add missing variables
dataTable.patchNum = (1:height(dataTable))';

% Compile data table with 1 row for each unique patch per image
patchTable = ndi.fun.table.join({dataTable(:,patchVariables)},...
    'UniqueVariables',{'image_id','patchNum'});

% Create ontologyTableRow documents
patchDocs = tableDocMaker_ecoli.table2ontologyTableRowDocs(...
    patchTable,{'image_id','patchNum'},'Overwrite',options.Overwrite);
end