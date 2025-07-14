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

%%

% Create openMINDS documents for bacteria

% Species
species = openminds.controlledterms.Species;
species.name = 'Escherichia coli';
species.preferredOntologyIdentifier = 'NCBITaxon:562';
species.definition = 'Escherichia coli is a species of bacteria.';
species.synonym = 'E. coli';

% Strain
strain = openminds.core.research.Strain;
strain.name = 'Escherichia coli OP50';
strain.species = species;
strain.ontologyIdentifier = 'NCBITaxon:637912';
strain.description = 'OP50 is a strain of E. coli.';
strain.geneticStrainType = 'wild type';

% Add documents to database
strainDoc = ndi.database.fun.openMINDSobj2ndi_document(strain,session.id);
session.database_add(strainDoc);

%% Step 4. INFO DOCUMENTS.

% We will have one ontologyTableRow document for each experiment, plate,
% patch, video, and worm. Below, we define which info table variables will 
% get  stored under which ontologyTableRow document type
experimentVariables = {'expNum','growthBacteriaStrain',...
   'growthOD600','growthTimeSeed','growthTimeColdRoom',...
    'growthTimeRoomTemp','growthTimePicked', 'OD600Real','CFU'};
plateVariables = {'experiment_id','plateNum','exclude','strain',...
    'condition','OD600Label','growthCondition','peptoneFlag',...
    'bacteriaStrain','timeSeed','timeColdRoom','timeRoomTemp',...
    'lawnGrowth','lawnVolume','lawnSpacing','arenaDiameter','temp','humidity'};
    %'firstFrame_id','arenaMask_id','patchMask_id','closestPatch_id','closestOD600_id'};
patchVariables = {'plate_id','OD600','lawnCenters','lawnRadii','lawnCircularity'};
videoVariables = {'plate_id','videoNum','timeRecord','pixelWidth','pixelHeight',...
    'frameRate','numFrames','scale'};
wormVariables = {'plate_id','wormNum','subject_id'};

for i = 5:numel(infoFiles)

    % Load current table
    dataTable = load(fullfile(dataParentDir,infoFiles{i}));
    fields = fieldnames(dataTable);
    tableType = fields{1};
    dataTable = dataTable.(tableType);
    dirName = split(infoFiles{i},filesep); dirName = dirName{end-1};

    % Check for correct exclusion
    dataTable.exclude = dataTable.exclude | ~ndi.fun.table.identifyValidRows(dataTable,'growthCondition');

    % A. EXPERIMENT ontologyTableRow

    % Add missing variables
    dataTable{:,'growthBacteriaStrain'} = {strainDoc{1}.id};

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
        elseif contains(dirName,'Mutants')
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
    if contains(dirName,'Matching') || contains(dirName,'Mutants')
        patchOD600(patchOD600 == 0) = [];
    end
    patchCenterX = vertcat(patchCenterX{:});
    patchCenterY = vertcat(patchCenterY{:});
    patchRadius = vertcat(patchRadius{:});
    patchCircularity = vertcat(patchCircularity{:});
    patchTable = table(plate_id,patchNum,patchOD600,patchCenterX,patchCenterY,...
        patchRadius,patchCircularity);

    % Create ontologyTableRow documents
    % info.(dirName).patchDocs = tableDocMaker(patchTable,{'plate_id','patchNum'},...
    %     'Overwrite',options.Overwrite);
    % patchTable.patch_id = cellfun(@(d) d.id,info.(dirName).patchDocs);
    patchTable{:,'patch_id'} = (1:height(patchTable))';
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
    % info.(dirName).wormDocs = tableDocMaker(wormTable(:,wormVariables),...
    %     {'subject_id'},'Overwrite',options.Overwrite);
    info.(dirName).wormTable = wormTable;

    % Create treatment documents
    wormTable = ndi.fun.table.join({wormTable,...
        dataTable(:,{'plate_id','strainName'})},...
        'uniqueVariables',{'plate_id','strainName'});
    ind = find(ndi.fun.table.identifyMatchingRows(wormTable,'strainName','food-deprived'));
    treatmentDocs = cell(numel(subDocStruct),1);
    % for j = 1:numel(ind)
    %     [ontologyID,name] = ndi.ontology.lookup('EMPTY:Treatment: food restriction onset');
    %     treatment = struct('ontologyName',ontologyID,...
    %         'name','Treatment: food restriction onset',...
    %         'numeric_value',[],...
    %         'string_value',anatomy(optoLocation{:}));
    %     treatmentDocs{i} = ndi.document('treatment',...
    %         'treatment', treatment) + sessionArray{1}.newdocument();
    %     treatmentDocs{i} = treatmentDocs{i}.set_dependency_value(...
    %         'subject_id', subject_id);
    % end

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
            ones(sum(indData),1),dataTable{indData,'closestLawnID'}];
        t0_t1_local = prctile(dataTable.timeOffset(indData),[0 100]);
        t0_t1_global = convertTo(info.(dirName).wormTable.expTime(indWorm) + ...
            seconds(t0_t1_local),'datenum');

        % A. POSITION elements and metadata

        % Create position element and add epoch
        positionElement = ndi.element.timeseries(session,'position',1,'position',[],0,subject_id);
        positionElement.addepoch('position','dev_local_time,exp_global_time', ...
            [t0_t1_local;t0_t1_global], time, position);
        % positionElement.addepoch('position',ndi.time.clocktype('UTC'),t0_t1_local,time,position);
        [d,t,timeref] = positionElement.readtimeseries('position',-Inf,Inf);

        % Create position_metadata structure
        position_metadata.ontologyNode = 'EMPTY:0000XX'; % C. elegans head, midpoint, or tail
        position_metadata.units = 'NCIT:C48367'; % pixels
        position_metadata.dimensions = 'NCIT:C44477,NCIT:C44478'; % X-coordinate, Y-coordinate
        
        % Create position_metadata document
        positionMetadataDocs{j} = ndi.document('position_metadata',...
            'position_metadata', position_metadata) + session.newdocument();
        positionMetadataDocs{j} = positionMetadataDocs{j}.set_dependency_value(...
            'element_id', positionElement.id);

        % B. DISTANCE elements and metadata

        % Create distance element and add epoch
        distanceElement = ndi.element.timeseries(session,'distance',1,'distance',[],0,subject_id);
        distanceElement.addepoch('distance','dev_local_time,exp_global_time', ...
            [t0_t1_local;t0_t1_global], time, distance);

        % Create distance_metadata structure
        distance_metadata.ontologyNode_A = 'EMPTY:0000XX'; % subject document id
        distance_metadata.integerIDs_A = 1;
        distance_metadata.ontologyNumericValues_A = [];
        distance_metadata.ontologyStringValues_A = subject_id;
        distance_metadata.ontologyNode_B = 'EMPTY:0000XX'; % patch ontologyTableRow document id
        distance_metadata.integerIDs_B = info.(dirName).patchTable.patchNum(indPatch)';
        distance_metadata.ontologyNumericValues_B = [];
        distance_metadata.ontologyStringValues_B = strjoin(info.(dirName).patchTable.patch_id(indPatch),',');
        distance_metadata.units = 'NCIT:C48367'; % pixels

        % Create distance_metadata document
        distanceMetadataDocs{j} = ndi.document('distance_metadata',...
            'distance_metadata', distance_metadata) + session.newdocument();
        distanceMetadataDocs{j} = distanceMetadataDocs{j}.set_dependency_value(...
            'element_id', distanceElement.id);
    end

    % Add documents to database
    % session.database_add(positionMetadataDocs);
    % session.database_add(distanceMetadataDocs);
end

%% Step 6. ENCOUNTER DOCUMENTS.

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
    patchTable(:,{'patchNum','dirName','plate_id'})});

% Create ontologyTableRow documents
indEncounter = dataTable.id > 0;
encounterDocs = tableDocMaker(dataTable(indEncounter,encounterVariables),...
    {'subject_id','id'},'Overwrite',options.Overwrite);

end