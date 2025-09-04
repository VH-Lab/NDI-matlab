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

labName = 'haley';
dataPath = fullfile(dataParentDir,labName);

% Get files
fileList = vlt.file.manifest(dataPath);

% If overwriting, delete NDI docs
if options.Overwrite
    ndiFiles = fileList(endsWith(fileList,'.ndi'));
    for i = 1:numel(ndiFiles)
        rmdir(fullfile(dataParentDir,ndiFiles{i}),'s');
    end
end

% Get files by type
matFiles = fileList(endsWith(fileList,'.mat'));
mp4Files = fileList(endsWith(fileList,'.mp4'));
tiffFiles = fileList(endsWith(fileList,'.tiff'));
infoFiles = matFiles(contains(matFiles,'experimentInfo'));
dataFiles = matFiles(contains(matFiles,'midpoint') | ...
    contains(matFiles,'head') | contains(matFiles,'tail'));
encounterFiles = matFiles(contains(matFiles,'encounter'));
bacteriaFiles = matFiles(contains(matFiles,'bacteria'));
imageFiles = tiffFiles(contains(tiffFiles,'images'));
maskFiles = tiffFiles(contains(tiffFiles,'labeled'));

%% Step 2: SESSIONS. Build the session.

% Create sessionMaker
SessionRef = {'haley_2025_Celegans';'haley_2025_Ecoli'};
SessionPath = {fullfile(labName,'celegans');fullfile(labName,'ecoli')};
sessionMaker = ndi.setup.NDIMaker.sessionMaker(dataParentDir,...
    table(SessionRef,SessionPath),'Overwrite',options.Overwrite);

% Get the session object
sessions = sessionMaker.sessionIndices;
if options.Overwrite
    sessions{1}.cache.clear;
    sessions{2}.cache.clear;
end
session = sessions{1};

%% Step 3. SUBJECTMAKER AND TABLEDOCMAKER.

% Create subjectMaker
subjectMaker = ndi.setup.NDIMaker.subjectMaker();
subjectCreator = ndi.setup.conv.haley.SubjectInformationCreator();

% Create tableDocMaker
tableDocMaker = ndi.setup.NDIMaker.tableDocMaker(session,labName);
tableDocMaker_ecoli = ndi.setup.NDIMaker.tableDocMaker(sessions{2},labName);

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

% We will have one ontologyTableRow document for each cultivation plate, 
% behavior plate, patch, and worm. Below, we define which info table 
% variables will get stored under which ontologyTableRow document type
cultivationPlateVariables = {'expID',...
   'growthOD600Label',...
   'bacteriaStrain','growthTimeSeed','growthTimeColdRoom',...
   'growthTimeRoomTemp','growthAge','growthTimePicked','growthLawnGrowthDuration',...
   'OD600Real','CFU',...
   'growthOD600'};
behaviorPlateVariables = {'expID','assayPhase','plateID','assayType','exclude',...
    'OD600Label','growthConditionLabel','peptoneFlag',...
    'bacteriaStrain','timeSeed','timeColdRoom',...
    'timeRoomTemp','age','timePicked','lawnGrowthDuration',...
    'OD600Real','CFU',...
    'arenaDiameter','lawnSpacing','temp','humidity'};
patchVariables = {'plateID','OD600','lawnVolume','lawnCenters','lawnRadii','lawnCircularity'};
wormVariables = {'wormID','subjectName','subject_id'};
progressBar.addBar('Label', 'Importing info file(s)','Tag', 'infoFiles');

for i = 1:numel(infoFiles)

    % Load current table
    dataTable = load(fullfile(dataParentDir,infoFiles{i}));
    fields = fieldnames(dataTable);
    tableType = fields{1};
    dataTable = dataTable.(tableType);
    dirName = split(infoFiles{i},filesep); dirName = dirName{end-1};

    % Create unique experiment number
    switch dirName
        case 'foragingConcentration'
            expType = 0;
        case 'foragingMini'
            expType = 1;
            indError = find(dataTable.expNum == 24); % small error in .mat file
            dataTable.growthTimeRoomTemp(indError) = dataTable.growthTimeRoomTemp(indError(end));
            dataTable.growthLawnGrowth(indError) = dataTable.growthLawnGrowth(indError(end));
        case 'foragingMatching'
            expType = 2;
        case 'foragingMutants'
            expType = 3;
            indError = 1;
            dataTable.arenaDiameter(indError) = 30; % small error in .mat file
        case 'foragingSensory'
            expType = 4;
    end

    % Add assay type
    for j = 1:height(dataTable)
        if strcmp(dataTable.condition{j},'grid')
            if strcmp(dirName,'foragingMatching')
                dataTable.assayType{j} = {'MultiDensityMultiPatch'};
            else
                dataTable.assayType{j} = {'SingleDensityMultiPatch'};
            end
        elseif strcmp(dataTable.condition{j},'single')
            if strcmp(dirName,'foragingMini')
                dataTable.assayType{j} = {'SmallSinglePatch'};
            else
                dataTable.assayType{j} = {'LargeSinglePatch'};
            end
        end
    end

    % Convert CFU to CFU/mL of OD600 = 1 solution (standard)
    dataTable.CFU =  2*10^6*dataTable.CFU;

    % Check for correct exclusion
    dataTable.exclude = dataTable.exclude | ...
        ~ndi.fun.table.identifyValidRows(dataTable,'growthCondition');

    % Add missing variables
    dataTable{:,'bacteriaStrain'} = {strainDoc{1}.id};
    dataTable{:,'expID'} = arrayfun(@(x) num2str(x + expType*1000,'%.4i'),dataTable.expNum,'UniformOutput',false);
    dataTable.plateID = arrayfun(@(x) num2str(x + expType*1000,'%.4i'),dataTable.plateNum,'UniformOutput',false);
    dataTable{:,'growthLawnGrowthDuration'} = hours(...
        (dataTable.growthTimeColdRoom - dataTable.growthTimeSeed) + ...
        (dataTable.growthTimePicked - dataTable.growthTimeRoomTemp));
    dataTable.growthOD600Label = arrayfun(@(x) num2str(x,'%.2f'),dataTable.growthOD600,'UniformOutput',false);
    dataTable{:,'growthAge'} = {'L4'};
    [~,~,ind] = unique(dataTable.plateNum);
    dataTable.timePicked = dataTable.timeRecord(ind);
    dataTable.lawnGrowthDuration = hours(dataTable.lawnGrowth);

    % A. CULTIVATIONPLATE ontologyTableRow

    % Compile data table with 1 row for each unique experiment day and condition
    cultivationPlateTable = ndi.fun.table.join({dataTable(:,cultivationPlateVariables)},...
        'UniqueVariables',{'expID','growthOD600Label','growthTimePicked'});
    cultivationPlateTable.growthTimePicked = cellstr(cultivationPlateTable.growthTimePicked);

    % Add missing variables
    cultivationPlateTable{:,'assayPhase'} = {'cultivation'};
    cultivationPlateTable.plateID = arrayfun(@(x) num2str(x + expType*1000 + 900,'%.4i'),1:height(cultivationPlateTable),'UniformOutput',false)';
    cultivationPlateTable{:,'exclude'} = false;
    cultivationPlateTable{:,'growthConditionLabel'} = {'24'};
    cultivationPlateTable{:,'peptoneFlag'} = true;
    cultivationPlateTable{:,'arenaDiameter'} = 90;
    cultivationPlateTable{:,'lawnSpacing'} = 0;
    cultivationPlateTable{:,'temp'} = 20;
    cultivationPlateTable{:,'patchID'} = {'0001'};
    cultivationPlateTable{:,'lawnVolume'} = 200;
    cultivationPlateTable = ndi.fun.table.moveColumnsLeft(cultivationPlateTable,...
        {'expID','assayPhase','plateID','exclude','growthOD600Label',...
        'growthConditionLabel','peptoneFlag','bacteriaStrain'});
    cultivationPlateTable = movevars(cultivationPlateTable,'growthOD600','After','patchID');

    % Create ontologyTableRow documents
    info.(dirName).cultivationPlateDocs = tableDocMaker.table2ontologyTableRowDocs(...
        cultivationPlateTable,{'expID','assayPhase','plateID'},'Overwrite',options.Overwrite);
    info.(dirName).cultivationPlateTable = cultivationPlateTable;
    [~,~,indPlate] = unique(dataTable(:,{'expID','growthOD600Label','growthTimePicked'}));
    for j = 1:height(cultivationPlateTable)
        dataTable{indPlate == j,'lastPlateID'} = cultivationPlateTable.plateID(j);
    end
    cultivationPlateTable.lastPlate_id = cellfun(@(d) d.id,info.(dirName).cultivationPlateDocs,'UniformOutput',false);
    cultivationPlateTable = renamevars(cultivationPlateTable,'plateID','lastPlateID');
    dataTable = ndi.fun.table.join({dataTable,cultivationPlateTable(:,{'lastPlateID','lastPlate_id'})});
    
    % B. BEHAVIORPLATE ontologyTableRow

    % Add missing variables
    dataTable{:,'assayPhase'} = {'behavior'};
    dataTable{:,'peptoneFlag'} = true;
    dataTable{:,'growthConditionLabel'} = arrayfun(@num2str,dataTable.growthCondition,'UniformOutput',false);
    indWithout = ndi.fun.table.identifyMatchingRows(dataTable,'peptone','without');
    dataTable{indWithout,'peptoneFlag'} = false;
    [strainNames,~,indStrain] = unique(dataTable.strainID);
    if strcmp(dirName,'foragingMutants')
        strainNames{strcmp(strainNames,'CB1112')} = '00004246'; % not available for lookup
        strainNames{strcmp(strainNames,'CX6448')} = '00005280'; % not available for lookup
        strainNames{strcmp(strainNames,'MT15434')} = '00027519'; % not available for lookup
    end
    strainIDs = cellfun(@(s) ndi.ontology.lookup(['WBStrain:',s]),strainNames,'UniformOutput',false);
    dataTable.strain = strainIDs(indStrain);

    % Compile data table with 1 row for each unique plate
    ind = dataTable.videoNum == 1;
    behaviorPlateTable = ndi.fun.table.join({dataTable(ind,behaviorPlateVariables)},...
        'UniqueVariables',{'expID','assayPhase','plateID'});

    % Create ontologyTableRow documents
    info.(dirName).behaviorPlateDocs = tableDocMaker.table2ontologyTableRowDocs(...
        behaviorPlateTable,{'expID','assayPhase','plateID'},'Overwrite',options.Overwrite);
    behaviorPlateTable.plate_id = cellfun(@(d) d.id,info.(dirName).behaviorPlateDocs,'UniformOutput',false);
    dataTable = ndi.fun.table.join({dataTable,behaviorPlateTable(:,{'plateID','plate_id'})});
    info.(dirName).behaviorPlateTable = behaviorPlateTable;

    % C. PATCH ontologyTableRow

    % Compile data table with 1 row for each unique patch
    plateID = cell(height(dataTable),1);
    patchNum = cell(height(dataTable),1);
    patchOD600 = cell(height(dataTable),1);
    lawnVolume = cell(height(dataTable),1);
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
        plateID{j} = repmat(plateRow.plateID,numPatch,1);
        lawnVolume{j} = repmat(plateRow.lawnVolume,numPatch,1);
        patchNum{j} = (1:numPatch)';
    end
    plateID = vertcat(plateID{:});
    patchNum = vertcat(patchNum{:});
    patchOD600 = vertcat(patchOD600{:});
    if contains(dirName,'Matching') || contains(dirName,'Mutants') || ...
            contains(dirName,'Sensory')
        patchOD600(patchOD600 == 0) = [];
    end
    lawnVolume = vertcat(lawnVolume{:});
    patchCenterX = vertcat(patchCenterX{:});
    patchCenterY = vertcat(patchCenterY{:});
    patchRadius = vertcat(patchRadius{:});
    patchCircularity = vertcat(patchCircularity{:});
    patchID = arrayfun(@(x) num2str(x,'%.4i'),patchNum,'UniformOutput',false);
    patchTable = ndi.fun.table.join({table(plateID,patchID,patchOD600,...
        lawnVolume,patchCenterX,patchCenterY,patchRadius,patchCircularity)},...
        'uniqueVariables',{'plateID','patchID'});
    
    % Create ontologyTableRow documents
    info.(dirName).patchDocs = tableDocMaker.table2ontologyTableRowDocs(...
        patchTable,{'plateID','patchID'},'Overwrite',options.Overwrite);
    patchTable.patch_id = cellfun(@(d) d.id,info.(dirName).patchDocs,'UniformOutput',false);
    info.(dirName).patchTable = patchTable;

    % D. WORM subject, ontologyTableRow, and treatment

    % Compile data table with 1 row for each unique worm
    [~,ind] = unique(dataTable.plateID);
    plate_id = cell(numel(ind),1);
    lastPlate_id = cell(numel(ind),1);
    wormNum = cell(numel(ind),1);
    expTime = cell(numel(ind),1);
    for j = 1:numel(ind)
        wormNum{j} = dataTable{ind(j),'wormNum'}{1}';
        numWorm = numel(wormNum{j});
        plate_id{j} = repmat(dataTable{ind(j),'plate_id'},numWorm,1);
        lastPlate_id{j} = repmat(dataTable{ind(j),'lastPlate_id'},numWorm,1);
        expTime{j} = repmat(dataTable{ind(j),'timeRecord'},numWorm,1);
    end
    plate_id = vertcat(plate_id{:});
    lastPlate_id = vertcat(lastPlate_id{:});
    wormNum = vertcat(wormNum{:});
    wormID = arrayfun(@(x) num2str(x + expType*1000,'%.4i'),wormNum,'UniformOutput',false);
    expTime = vertcat(expTime{:});
    wormTable = table(plate_id,lastPlate_id,wormNum,wormID,expTime);

    % Add subject string info
    wormTable{:,'sessionID'} = {session.id};
    wormTable = ndi.fun.table.join({wormTable,...
        behaviorPlateTable(:,{'plate_id','assayType'}),...
        dataTable(:,{'plate_id','strain'})},...
        'uniqueVariables',{'plate_id','wormID'});
    wormTable{:,'expType'} = {num2str(expType)};

    % Create subject documents
    [~,wormTable.subjectName,wormTable.subject_id] = subjectMaker.addSubjectsFromTable( ...
        session, wormTable, subjectCreator);

    % Create subject_group documents
    for j = 1:height(behaviorPlateTable)
        ind = find(strcmp(wormTable.plate_id,behaviorPlateTable.plate_id{j}));
        if isscalar(ind)
            behaviorPlateTable.subjectGroup_id{j} = wormTable.subject_id{ind};
        else
            subject_group_doc = ndi.document('subject_group') + session.newdocument();
            for k = 1:numel(ind)
                subject_group_doc = subject_group_doc.add_dependency_value_n(...
                    'subject_id',wormTable.subject_id{ind(k)});
            end
            session.database_add(subject_group_doc);
            behaviorPlateTable.subjectGroup_id{j} = subject_group_doc.id;
        end
    end

    % Create ontologyTableRow documents
    info.(dirName).wormDocs = tableDocMaker.table2ontologyTableRowDocs(wormTable(:,wormVariables),...
        {'subject_id'},'Overwrite',options.Overwrite);
    info.(dirName).wormTable = wormTable;

    % Create treatment documents
    if any(ismember(dataTable.Properties.VariableNames,'starvedTime')) && ...
            any(dataTable.starvedDuration > 0)
        wormTable = ndi.fun.table.join({wormTable,...
            dataTable(:,{'plate_id','strainName','starvedTime','timeRecord'})},...
            'uniqueVariables',{'plate_id','wormID'});
        ind = find(ndi.fun.table.identifyMatchingRows(wormTable,'strainName','food-deprived'));
        onsetDocs = cell(numel(ind),1);
        offsetDocs = cell(numel(ind),1);
        for j = 1:numel(ind)
            % Food deprivation onset
            [ontologyID,name] = ndi.ontology.lookup('EMPTY:treatment: food restriction onset time');
            treatment = struct('ontologyName',ontologyID,...
                'name',name,...
                'numeric_value',[],...
                'string_value',wormTable.starvedTime{ind(j)});
            onsetDocs{j} = ndi.document('treatment',...
                'treatment', treatment) + session.newdocument;
            onsetDocs{j} = onsetDocs{j}.set_dependency_value(...
                'subject_id', wormTable.subject_id{ind(j)});

            % Food deprivation offset
            [ontologyID,name] = ndi.ontology.lookup('EMPTY:treatment: food restriction offset time');
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

    % E. VIDEO imageStack

    % Create imageStack documents
    videoDocs = cell(height(dataTable),1);
    videoLabels = cell(height(dataTable),1);
    arenaMaskDocs = cell(height(dataTable),1);
    arenaMaskLabels = cell(height(dataTable),1);
    bacteriaMaskDocs = cell(height(dataTable),1);
    bacteriaMaskLabels = cell(height(dataTable),1);
    closestPatchDocs = cell(height(dataTable),1);
    closestPatchLabels = cell(height(dataTable),1);
    for p = 1:height(dataTable)
        if ~isempty(dataTable.firstFrame{p})
            
            % Define imageStack_parameters
            dataType = class(dataTable.firstFrame{p});
            imageStack_parameters = struct('dimension_order','YXT',...
                'dimension_labels','height,width,time',...
                'dimension_size',[dataTable.pixels{p},dataTable.numFrames(p)],...
                'dimension_scale',[dataTable.scale(p),dataTable.scale(p),1/dataTable.frameRate(p)],...
                'dimension_scale_units','micrometer,micrometer,second',...
                'data_type',dataType,...
                'data_limits',[intmin(dataType) intmax(dataType)],...
                'timestamp',convertTo(dataTable.timeRecord(p),'datenum'),...
                'clocktype','exp_global_time');
            
            % Create imageStack document
            imageStack = struct('label',...
                'A video recording capturing the behavior of C. elegans during an experimental assay.',...
                'formatOntology','NCIT:C190180');
            videoDocs{p} = ndi.document('imageStack', ...
                'imageStack',imageStack,...
                'imageStack_parameters', imageStack_parameters) + ...
                session.newdocument;

            % Add dependencies
            ind = strcmp(behaviorPlateTable.plate_id,dataTable.plate_id{p});
            subjectGroup_id = behaviorPlateTable.subjectGroup_id{ind};
            videoDocs{p} = videoDocs{p}.set_dependency_value( ...
                'document_id',dataTable.plate_id{p});
            videoDocs{p} = videoDocs{p}.set_dependency_value( ...
                'subject_id',subjectGroup_id);

            % Add file
            [~,videoFileName] = fileparts(dataTable.videoFileName{p});
            ind = contains(mp4Files,videoFileName);
            if ~any(ind)
                error('no video file found');
            end
            videoFileName = fullfile(dataParentDir,mp4Files{ind});
            videoDocs{p} = videoDocs{p}.add_file('imageStack',videoFileName,'delete_original',0);

            % Add ontologyLabel
            ontologyLabel = struct('ontologyNode','EMPTY:00000226');
            videoLabels{p} = ndi.document('ontologyLabel', ...
                'ontologyLabel',ontologyLabel) + session.newdocument;
            videoLabels{p} = videoLabels{p}.set_dependency_value( ...
                'document_id',videoDocs{p}.id);

            % Arena mask imageStack
            imageStack_parameters.dimension_order = 'YX';
            imageStack_parameters.dimension_labels = 'height,width';
            imageStack_parameters.dimension_size = dataTable.pixels{p};
            imageStack_parameters.dimension_scale = [dataTable.scale(p), dataTable.scale(p)];
            imageStack_parameters.dimension_scale_units = 'micrometer,micrometer';
            dataType = class(dataTable.arenaMask{p});
            imageStack_parameters.data_type = dataType;
            imageStack_parameters.data_limits = [0 1];
            imageStack.label = 'A binary image (logical matrix) where pixels within the experimental arena for C. elegans are marked (true) and pixels outside are unmarked (false). This mask defines the region of interest for worm tracking and behavioral analysis.';
            imageStack.formatOntology = 'NCIT:C85437';
            arenaMaskDocs{p} = ndi.document('imageStack','imageStack',imageStack,...
                'imageStack_parameters', imageStack_parameters) + session.newdocument;
            arenaMaskDocs{p} = arenaMaskDocs{p}.set_dependency_value( ...
                'document_id',dataTable.plate_id{p});
            arenaMaskDocs{p} = arenaMaskDocs{p}.set_dependency_value( ...
                'subject_id',subjectGroup_id);
            imageFileName = ndi.file.temp_name;
            imwrite(dataTable.arenaMask{p},imageFileName,'png');
            arenaMaskDocs{p} = arenaMaskDocs{p}.add_file('imageStack',imageFileName);
            ontologyLabel = struct('ontologyNode','EMPTY:00000227');
            arenaMaskLabels{p} = ndi.document('ontologyLabel', ...
                'ontologyLabel',ontologyLabel) + session.newdocument;
            arenaMaskLabels{p} = arenaMaskLabels{p}.set_dependency_value( ...
                'document_id',arenaMaskDocs{p}.id);

            % Bacteria mask imageStack
            imageStack.label = 'A binary image mask representing the union of all individually detected bacterial food patch areas on the C. elegans assay plate. This mask defines all food-containing regions.';
            bacteriaMaskDocs{p} = ndi.document('imageStack','imageStack',imageStack,...
                'imageStack_parameters', imageStack_parameters) + session.newdocument;
            bacteriaMaskDocs{p} = bacteriaMaskDocs{p}.set_dependency_value( ...
                'document_id',dataTable.plate_id{p});
            bacteriaMaskDocs{p} = bacteriaMaskDocs{p}.set_dependency_value( ...
                'subject_id',subjectGroup_id);
            imageFileName = ndi.file.temp_name;
            imwrite(dataTable.lawnMask{p},imageFileName,'png');
            bacteriaMaskDocs{p} = bacteriaMaskDocs{p}.add_file('imageStack',imageFileName);
            ontologyLabel = struct('ontologyNode','EMPTY:00000228');
            bacteriaMaskLabels{p} = ndi.document('ontologyLabel', ...
                'ontologyLabel',ontologyLabel) + session.newdocument;
            bacteriaMaskLabels{p} = bacteriaMaskLabels{p}.set_dependency_value( ...
                'document_id',bacteriaMaskDocs{p}.id);

            % Closest patch imageStack
            dataType = 'uint8';
            imageStack_parameters.data_type = dataType;
            imageStack_parameters.data_limits = [intmin(dataType) intmax(dataType)];
            imageStack.label = 'An image or map where each pixels value is the identifier of the bacterial food patch closest to that pixels location.';
            closestPatchDocs{p} = ndi.document('imageStack','imageStack',imageStack,...
                'imageStack_parameters', imageStack_parameters) + session.newdocument;
            closestPatchDocs{p} = closestPatchDocs{p}.set_dependency_value( ...
                'document_id',dataTable.plate_id{p});
            closestPatchDocs{p} = closestPatchDocs{p}.set_dependency_value( ...
                'subject_id',subjectGroup_id);
            imageFileName = ndi.file.temp_name;
            imwrite(uint8(dataTable.lawnClosest{p}),imageFileName,'png');
            closestPatchDocs{p} = closestPatchDocs{p}.add_file('imageStack',imageFileName);
            ontologyLabel = struct('ontologyNode','EMPTY:00000229');
            closestPatchLabels{p} = ndi.document('ontologyLabel', ...
                'ontologyLabel',ontologyLabel) + session.newdocument;
            closestPatchLabels{p} = closestPatchLabels{p}.set_dependency_value( ...
                'document_id',closestPatchDocs{p}.id);
        end
    end
    videoDocs(cellfun(@isempty,videoDocs)) = [];
    videoLabels(cellfun(@isempty,videoLabels)) = [];
    arenaMaskDocs(cellfun(@isempty,arenaMaskDocs)) = [];
    arenaMaskLabels(cellfun(@isempty,arenaMaskLabels)) = [];
    bacteriaMaskDocs(cellfun(@isempty,bacteriaMaskDocs)) = [];
    bacteriaMaskLabels(cellfun(@isempty,bacteriaMaskLabels)) = [];
    closestPatchDocs(cellfun(@isempty,closestPatchDocs)) = [];
    closestPatchLabels(cellfun(@isempty,closestPatchLabels)) = [];
    session.database_add(videoDocs); session.database_add(videoLabels);
    session.database_add(arenaMaskDocs); session.database_add(arenaMaskLabels);
    session.database_add(bacteriaMaskDocs); session.database_add(bacteriaMaskLabels);
    session.database_add(closestPatchDocs); session.database_add(closestPatchLabels);
    info.(dirName).videoDocs = videoDocs;
    info.(dirName).arenaMaskDocs = arenaMaskDocs;
    info.(dirName).bacteriaMaskDocs = bacteriaMaskDocs;
    info.(dirName).closestPatchDocs = closestPatchDocs;

    % F. PLATE-SUBJECT ontologyTableRow
    plateSubjectTable1 = wormTable(:,{'subject_id','plate_id'});
    plateSubjectTable2 = renamevars(wormTable(:,{'subject_id','lastPlate_id'}),...
        'lastPlate_id','plate_id');
    plateSubjectTable = [plateSubjectTable1;plateSubjectTable2];
    info.(dirName).plateSubjectDocs = tableDocMaker.table2ontologyTableRowDocs(plateSubjectTable,...
        {'subject_id','plate_id'},'Overwrite',options.Overwrite);
    info.(dirName).plateSubjectTable = plateSubjectTable;

    progressBar.updateBar('infoFiles', i / numel(infoFiles));
end

%% Step 6. DATA DOCUMENTS.

progressBar.addBar('Label', 'Importing data file(s)','Tag', 'dataFiles');

for i = 1:numel(dataFiles)

    % Load current table
    dataTable = load(fullfile(dataParentDir,dataFiles{i}));
    fields = fieldnames(dataTable);
    tableType = fields{1};
    dataTable = dataTable.(tableType);
    dirName = split(dataFiles{i},filesep); dirName = dirName{end-1};
    progressBar.addBar('Label', 'Creating Position and Distance Element(s)',...
        'Tag', 'position');

    % Get ontology terms
    [~,bodyPart] = fileparts(dataFiles{i});
    bodyPartID = ndi.ontology.lookup(['EMPTY:C. elegans ' bodyPart]);
    subjectDocID = ndi.ontology.lookup('EMPTY:subject document identifier');
    patchDocID = ndi.ontology.lookup('EMPTY:bacterial patch document identifier');

    % Loop through each worm (subject)
    wormNums = unique(dataTable.wormNum);
    positionMetadataDocs = cell(size(wormNums));
    distanceMetadataDocs = cell(size(wormNums));
    for j = 1:numel(wormNums)

        % Get indices
        indWorm = ndi.fun.table.identifyMatchingRows(info.(dirName).wormTable,'wormNum',wormNums(j));
        plate_id = info.(dirName).wormTable.plate_id{indWorm};
        indPlate = ndi.fun.table.identifyMatchingRows(info.(dirName).behaviorPlateTable,'plate_id',plate_id);
        plateID = info.(dirName).behaviorPlateTable.plateID{indPlate};
        subject_id = info.(dirName).wormTable.subject_id{indWorm};
        indPatch = strcmp(info.(dirName).patchTable.plateID,plateID);
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
            [t0_t1_local;t0_t1_global]', time, position);

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
            [t0_t1_local;t0_t1_global]', time, distance);

        % Create distance_metadata structure
        distance_metadata.ontologyNode_A = subjectDocID; % subject document id
        distance_metadata.integerIDs_A = 1;
        distance_metadata.ontologyNumericValues_A = [];
        distance_metadata.ontologyStringValues_A = subject_id;
        distance_metadata.ontologyNode_B = patchDocID; % patch ontologyTableRow document id
        distance_metadata.integerIDs_B = cellfun(@str2num,info.(dirName).patchTable.patchID(indPatch))';
        distance_metadata.ontologyNumericValues_B = [];
        distance_metadata.ontologyStringValues_B = strjoin(info.(dirName).patchTable.patch_id(indPatch),',');
        distance_metadata.units = 'NCIT:C48367'; % pixels

        % Create distance_metadata document
        distanceMetadataDocs{j} = ndi.document('distance_metadata',...
            'distance_metadata', distance_metadata) + session.newdocument;
        distanceMetadataDocs{j} = distanceMetadataDocs{j}.set_dependency_value(...
            'element_id', distanceElement.id);

        progressBar.updateBar('position', j / numel(wormNums));
    end

    % Add documents to database
    session.database_add(positionMetadataDocs);
    session.database_add(distanceMetadataDocs);

    progressBar.updateBar('dataFiles', i / numel(dataFiles));
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
plateTable = table();
patchTable = table();
for i = 1:numel(fields)
    info.(fields{i}).wormTable{:,'dirName'} = fields(i);
    info.(fields{i}).behaviorPlateTable{:,'dirName'} = fields(i);
    info.(fields{i}).patchTable{:,'dirName'} = fields(i);
    wormTable = ndi.fun.table.vstack({wormTable,info.(fields{i}).wormTable});
    plateTable = ndi.fun.table.vstack({plateTable,info.(fields{i}).behaviorPlateTable});
    patchTable = ndi.fun.table.vstack({patchTable,info.(fields{i}).patchTable});
end
dataTable = renamevars(dataTable,{'expName','id'},{'dirName','encounterNum'});
dataTable.patchID = arrayfun(@(x) num2str(x,'%.4i'),dataTable.lawnID,'UniformOutput',false);
dataTable = ndi.fun.table.join({dataTable,...
    wormTable(:,{'wormNum','wormID','dirName','subject_id','plate_id'}),...
    plateTable(:,{'plateID','dirName','plate_id'}),...
    patchTable(:,{'plateID','dirName','patchID','patch_id'})});

% Create ontologyTableRow documents
tableDocMaker.table2ontologyTableRowDocs(dataTable(:,encounterVariables),...
    {'subject_id','encounterNum'},'Overwrite',options.Overwrite);

%% Step 8. BACTERIA DOCUMENTS.

% Get the session object
session = sessions{2};

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
plateVariables = {'expID','plateID',...
    'OD600Label','peptoneFlag','timePoured','timePouredColdRoom',...
    'bacteriaStrain','timeSeed','timeSeedColdRoom','timeRoomTemp',...
    'OD600Real','CFU','OD600','lawnVolume'};
imageVariables = {'plateID','imageID',...
    'lawnGrowthDuration','exposureTime'};
patchVariables = {'imageID','patchID',...
    'lawnRadius','circularity',...
    'yPeak','yOuterEdge',...
    'borderAmplitude','meanAmplitude','centerAmplitude','borderCenterRatio'};

% A. PLATE ontologyTableRow

% Add missing variables
dataTable{:,'expID'} = arrayfun(@(x) num2str(x,'%.4i'),dataTable.expNum,'UniformOutput',false);
dataTable{:,'plateID'} = arrayfun(@(x) num2str(x,'%.4i'),dataTable.plateNum,'UniformOutput',false);
dataTable.OD600Label = arrayfun(@(x) num2str(x,'%.2f'),dataTable.OD600,'UniformOutput',false);
dataTable{:,'peptoneFlag'} = true;
indWithout = ndi.fun.table.identifyMatchingRows(dataTable,'peptone','without');
dataTable{indWithout,'peptoneFlag'} = false;
dataTable{:,'bacteriaStrain'} = {strainDoc{1}.id};

% Compile data table with 1 row for each unique plate
plateTable = ndi.fun.table.join({dataTable(:,plateVariables)},...
    'UniqueVariables','plateID');

% Create ontologyTableRow documents
plateDocs = tableDocMaker_ecoli.table2ontologyTableRowDocs(...
    plateTable,{'plateID'},'Overwrite',options.Overwrite);
plateTable.plate_id = cellfun(@(d) d.id,plateDocs,'UniformOutput',false);
dataTable = ndi.fun.table.join({dataTable,plateTable(:,{'plateID','plate_id'})});

% C. IMAGE ontologyTableRow documents

% Add missing variables
dataTable{:,'imageID'} = arrayfun(@(x) num2str(x,'%.4i'),dataTable.imageNum,'UniformOutput',false);
dataTable.lawnGrowthDuration = hours(dataTable.growthTimeTotal);

% Compile data table with 1 row for each unique image
imageTable = ndi.fun.table.join({dataTable(:,imageVariables)},...
    'UniqueVariables',{'plateID','imageID'});

% Create ontologyTableRow documents
imageDocs = tableDocMaker_ecoli.table2ontologyTableRowDocs(...
    imageTable,{'plateID','imageID'},'Overwrite',options.Overwrite);
imageTable.image_id = cellfun(@(d) d.id,imageDocs,'UniformOutput',false);
dataTable = ndi.fun.table.join({dataTable,imageTable(:,{'imageID','image_id'})});

% B. IMAGE imageStack_parameters

% Compile data table with 1 row for each unique image
imageTable = ndi.fun.table.join({dataTable},...
    'UniqueVariables',{'plateID','imageID'});

% Create imageStack documents
imageDocs = cell(height(imageTable),1);
imageLabels = cell(height(imageTable),1);
maskDocs = cell(height(imageTable),1);
maskLabels = cell(height(imageTable),1);
for p = 1:height(imageTable)
    dataType = imageTable.bitDepth{p};
    imageStack = struct('label','normalized fluorescence image of OP50-GFP',...
        'formatOntology','NCIT:C70631');
    imageStack_parameters = struct('dimension_order','YX',...
        'dimension_labels','height,width',...
        'dimension_size',[imageTable.xPixels(p),imageTable.yPixels(p)],...
        'dimension_scale',[imageTable.scale(p),imageTable.scale(p)],...
        'dimension_scale_units','micrometer,micrometer',...
        'data_type',dataType,...
        'data_limits',[intmin(dataType) intmax(dataType)],...
        'timestamp',convertTo(datetime(imageTable.acquisitionTime{p}),'datenum'),...
        'clocktype','exp_global_time');
    imageDocs{p} = ndi.document('imageStack', ...
        'imageStack', imageStack, ...
        'imageStack_parameters', imageStack_parameters) + ...
        session.newdocument;
    imageDocs{p} = imageDocs{p}.set_dependency_value(...
        'document_id',imageTable.image_id{p});
    ind = contains(imageFiles,imageTable.imageID{p});
    imageFileName = fullfile(dataParentDir,imageFiles{ind});
    imageDocs{p} = imageDocs{p}.add_file('imageStack',imageFileName,'delete_original',0);
    ontologyLabel = struct('ontologyNode','');
    imageLabels{p} = ndi.document('ontologyLabel', ...
        'ontologyLabel',ontologyLabel) + session.newdocument;
    imageLabels{p} = imageLabels{p}.set_dependency_value( ...
        'document_id',imageDocs{p}.id);
end
session.database_add(imageDocs);
session.database_add(imageLabels);

% Add mask documents, add ontologyLabel to empty

% D. PATCH ontologyTableRow documents

% Add missing variables
[imageNum,~,indImage] = unique(dataTable.imageNum);
for i = 1:numel(imageNum)
    ind = find(indImage == i);
    dataTable{ind,'patchID'} = arrayfun(@(x) num2str(x,'%.4i'),(1:numel(ind))','UniformOutput',false);
end

% Compile data table with 1 row for each unique patch per image
patchTable = ndi.fun.table.join({dataTable(:,patchVariables)},...
    'UniqueVariables',{'imageID','patchID'});

% Create ontologyTableRow documents
tableDocMaker_ecoli.table2ontologyTableRowDocs(...
    patchTable,{'imageID','patchID'},'Overwrite',options.Overwrite);

%% Step 9. Make dataset

% Create dataset
datasetDir = fullfile(dataPath,'haley_2025');
if ~exist(datasetDir,'dir')
    mkdir(datasetDir);
elseif options.Overwrite
    rmdir(datasetDir,'s');
    mkdir(datasetDir);
end
dataset = ndi.dataset.dir('haley_2025',datasetDir);

% Ingest and add sessions
for i = 1:numel(sessions)
    sessionDatabaseDir = fullfile(sessions{i}.path,'.ndi');
    if options.Overwrite && exist([sessionDatabaseDir,'_'],'dir')
        rmdir([sessionDatabaseDir,'_'],'s');
    end
    copyfile(sessionDatabaseDir,[sessionDatabaseDir,'_']);
    sessions{i}.ingest;
    dataset.add_ingested_session(sessions{i});
end

% Compress dataset
zip([datasetDir,'.zip'],datasetDir);