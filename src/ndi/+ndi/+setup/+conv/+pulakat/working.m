%% GUI Workflow

% Create subject table from files
subjectFiles = {'/Users/jhaley/Documents/MATLAB/data/pulakat/animal_mapping_JH.csv'};
subjectTable = ndi.setup.conv.pulakat.importSubjectFiles(subjectFiles);

% ADD SUBJECTS ALREADY IN DATABASE (indicate which are new)

% Get files (probably want to have users specify paths)
dataParentDir = fullfile(userpath,'data');
options.Overwrite = true;
labName = 'pulakat';
dataPath = fullfile(dataParentDir,labName);
fileList = fullfile(dataParentDir,vlt.file.manifest(dataPath));

% Narrow file list to possible data files
indHiddenFiles = contains(fileList,'/.');
indDir = isfolder(fileList);
dataFiles = fileList(~indHiddenFiles & ~indDir);
dataFiles = setdiff(dataFiles,subjectFiles);

% Validate data files
ndi.setup.conv.pulakat.validateDataFiles(subjectTable,dataFiles);

%% ARCHIVED

theseSubjects{:,'experimentType'} = {'protein'};
theseSubjects = renamevars(theseSubjects,'DataLabelGroup','StudyGroup');

% Read experimentSchedule
experimentScheduleFileName = fullfile(dataParentDir,fileList{contains(fileList,'ExperimentSchedule')});
experimentScheduleSheetNames = sheetnames(experimentScheduleFileName);
experimentScheduleCell = cell(size(experimentScheduleSheetNames));
for i = 1:numel(experimentScheduleSheetNames)
    experimentScheduleCell{i} = readtable(experimentScheduleFileName,...
        'Sheet',experimentScheduleSheetNames{i});
end

% Process study groups from first sheet of experimentSchedule
group1 = unique(experimentScheduleCell{1}.x18Rats); group1(strcmp(group1,'')) = [];
group2 = unique(experimentScheduleCell{1}.x32Rats); group2(strcmp(group2,'')) = [];
group3 = unique(experimentScheduleCell{1}.x25Rats); group3(strcmp(group3,'')) = [];
subjectGroups = table([group1;group2;group3],...
    [ones(size(group1));2*ones(size(group2));3*ones(size(group3))],...
    'VariableNames',{'Cage_','StudyGroup'});
subjectGroups{:,'PairInCage'} = {''};
subjectGroups{endsWith(subjectGroups.Cage_,'A','IgnoreCase',true),'PairInCage'} = {'A'};
subjectGroups{endsWith(subjectGroups.Cage_,'B','IgnoreCase',true),'PairInCage'} = {'B'};
subjectGroups.CageID = subjectGroups.Cage_; removeLetters = {' ','a','A','b','B'};
for i = 1:numel(removeLetters)
    subjectGroups.CageID = replace(subjectGroups.CageID,removeLetters{i},'');
end

% Process experiment timeline from first sheet of experimentSchedule
% Looks like experimentSchedule sheet 2 has redundant info. Checking with
% lab which version is correct
experimentScheduleCell{1} = renamevars(experimentScheduleCell{1},'StudyGroup1Schedule','Date');
group1 = renamevars(experimentScheduleCell{1}(:,{'Date','Var8','Var9'}),...
    {'Var8','Var9'},{'Week','Action'}); group1{:,'StudyGroup'} = 1;
group2 = renamevars(experimentScheduleCell{1}(:,{'Date','StudyGroup2Schedule','Var11'}),...
    {'StudyGroup2Schedule','Var11'},{'Week','Action'}); group2{:,'StudyGroup'} = 2;
group3 = renamevars(experimentScheduleCell{1}(:,{'Date','StudyGroup3Schedule','Var14'}),...
    {'StudyGroup3Schedule','Var14'},{'Week','Action'}); group3{:,'StudyGroup'} = 3;
experimentTimeline = ndi.fun.table.vstack({group1,group2,group3});
indValid = ndi.fun.table.identifyValidRows(experimentTimeline,{'Date','Week'},{NaT,NaN});
experimentTimeline = experimentTimeline(indValid,:);

% Process subject info from third sheet of experimentSchedule
subjectInfo = renamevars(experimentScheduleCell{3},{'ID_','Cage_'},...
    {'Animal_','CageNum'});
subjectInfo.CageID = arrayfun(@num2str,subjectInfo.CageNum,'UniformOutput',false);
indValid = ndi.fun.table.identifyValidRows(subjectInfo,{'Animal_'});
subjectInfo = subjectInfo(indValid,:);
subjectInfo{:,'experimentType'} = {'echo'};

% Combine subject tables
theseSubjects = ndi.fun.table.vstack({theseSubjects,...
    outerjoin(subjectGroups,subjectInfo,'MergeKeys',true)});
theseSubjects = ndi.fun.table.moveColumnsLeft(theseSubjects,...
    {'experimentType','StudyGroup','ExperimentalGroup'});

%% Step . Process DIA report

diaFileName = fileList{contains(fileList,'DIA')};

% Read DIA report
diaSheetNames = sheetnames(diaFileName);
diaCell = cell(size(diaSheetNames));
for i = 1:numel(diaSheetNames)
    diaCell{i} = readtable(diaFileName,...
        'Sheet',diaSheetNames{i});
end

% Get subject IDs from last sheet
diaVars = diaCell{5}.Properties.VariableNames;
commonVars = diaVars(~startsWith(diaVars,'x'))';
diaSubjectVars = diaVars(startsWith(diaVars,'x'))';
diaIDTable = table();
for i = 1:numel(diaSubjectVars)
    idInfo = strsplit(diaSubjectVars{i},'_');
    diaIDTable{i,'animalCount1'} = idInfo(2);
    diaIDTable{i,'StudyGroup'} = idInfo(3);
    diaIDTable{i,'animalCount2'} = idInfo(4);
    diaIDTable{i,'Animal_'} = idInfo(5);
    diaIDTable{i,'Variable'} = idInfo(end);
    diaIDTable{i,'DataLabelRaw'} = {[num2str(str2double(idInfo{5}),'%.4i'),...
        '-',num2str(str2double(idInfo{3}),'%.2i'),'-',num2str(str2double(idInfo{4}),'%.2i')]};
    diaIDTable{i,'Prefix'} = join(idInfo(1:end-1),'_');
end
rawVariables = unique(diaIDTable.Variable);
diaIDTable = ndi.fun.table.join({diaIDTable},'uniqueVariables','animalCount1');

% Get all (unfiltered) data from last sheet
rawTableCommon = diaCell{5}(:,commonVars);

% Loop through all subjects
for i = 1:height(diaIDTable)

    % Create table for this subject
    theseVars = diaVars(contains(diaVars,diaIDTable.Prefix{i}));
    rawTable = diaCell{5}(:,theseVars);
    for j = 1:numel(theseVars)
        varName = strsplit(theseVars{j},'_');
        rawTable = renamevars(rawTable,theseVars{j},varName{end});
    end
    rawTable = [rawTableCommon,rawTable];

    % Create table row documents
    tableDocMaker.table2ontologyTableRowDocs(...
        rawTable,{'SubjectDocumentID'},'Overwrite',options.Overwrite);
    
end

%% Step . Process SVS files 

% Get .svs files
svsFiles = fileList(endsWith(fileList,'.svs'));

% Initialize documents
imageCollectionDocs = cell(size(svsFiles));
imageDocs = cell(numel(svsFiles),7);
ontologyLabelDocs = cell(numel(svsFiles),8);

for i = 1:numel(svsFiles)

    % Get image file info
    fileName = fullfile(dataParentDir,svsFiles{i});
    fileInfo = imfinfo(fileName);

    % Create image collection documents
    [~,fileLabel,fileFormat] = fileparts(fileName);
    imageCollection = struct(...
        'label',fileLabel,...
        'format',replace(fileFormat,'.',''));
    imageCollectionDocs{i} = ndi.document('imageCollection',...
        'imageCollection',imageCollection) + session.newdocument();
    imageCollectionDocs{i} = imageCollectionDocs{i}.set_dependency_value(...
        'subject_id',subject_id);

    % Create ontology label document
    ontologyLabel = struct('ontologyNode','UBERON:');
    ontologyLabelDoc = ndi.document('ontologyLabel',...
        'ontologyLabel',ontologyLabel) + session.newdocument();
    ontologyLabelDocs{i,1} = ontologyLabelDoc.set_dependency_value(...
        'labeledDoc_id',imageCollectionDocs{i}.id);

    for j = 1:numel(fileInfo)

        info = fileInfo(j);

        % Get data class (without reading image)
        if strcmp(info.ColorType,'truecolor')
            dataType = ['uint',num2str(info.BitsPerSample(1))];
        end

        % Create image documents
        imageStack_parameters = struct(...
            'dimension_order','YXC',...
            'dimension_labels','height,width,color',...
            'dimension_size',[info.Height,info.Width,numel(info.BitsPerSample)],...
            'dimension_scale',[NaN,NaN,NaN],...
            'dimension_scale_units',strjoin([repmat({info.ResolutionUnit},1,2),{'RGB'}],','),...
            'data_type',class(im),...
            'data_limits',[info.MinSampleValue(1) info.MaxSampleValue(1)],...
            'timestamp',convertTo(datetime(info.FileModDate),'datenum'),...
            'clocktype','exp_global_time');
        image = struct(...
            'label',info.ImageDescription,...
            'format',info.Format,...
            'compression',info.Compression);
        imageDocs{i,j} = ndi.document('imageDocs','image',image,...
            'imageStack_parameters',imageStack_parameters) + session.newdocument();
        imageDocs{i,j} = doc.add_file('imageFile', filepath);
        imageDocs{i,j} = imageDocs{i,j}.set_dependency_value(...
            'subject_id',subject_id,...
            'imageCollection_id',imageCollectionDocs{i}.id);

        % Add ontologyLabel
        ontologyLabelDocs{i,j+1} = ontologyLabelDoc.set_dependency_value(...
            'labeledDoc_id',imageDocs{i,j}.id);
    end
end

% Add documents to database
session.database_add(imageCollectionDocs{:});
session.database_add(imageDocs{:});
session.database_add(ontologyLabelDocs{:});