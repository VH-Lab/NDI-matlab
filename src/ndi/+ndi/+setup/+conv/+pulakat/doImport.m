% function [outputArg1,outputArg2] = doImport(inputArg1,inputArg2)

dataParentDir = fullfile(userpath,'data');
options.Overwrite = true;

%% Step 1: FILES. Get data path and files.

labName = 'pulakat';
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

% Get file types
subjectFiles = fileList(contains(fileList,'animal_mapping'));
diaFiles = fileList(contains(fileList,'DIA'));
svsFiles = fileList(endsWith(fileList,'.svs'));
echoFiles = fileList(contains(fileList,'.bimg') | contains(fileList,'.pimg') | ...
    contains(fileList,'.mxml') | contains(fileList,'.vxml'));
[echoFolderNames,echoFileNames] = fileparts(echoFiles);
echoSessions = unique(fullfile(echoFolderNames,echoFileNames));
echoFolders = unique(echoFolderNames);

%% Step 2: SESSIONS. Build the session.

% Create sessionMaker
SessionRef = {'pulakat_2025'};
SessionPath = {fullfile(labName)};
sessionMaker = ndi.setup.NDIMaker.sessionMaker(dataParentDir,...
    table(SessionRef,SessionPath),'Overwrite',options.Overwrite);

% Get the session object
session = sessionMaker.sessionIndices; session = session{1};
if options.Overwrite
    session.cache.clear;
end

% We're going to want to think of how to name a session and coordinate each
% mapping file with it's relevant session?

%% Step 3. SUBJECTS. Create subject documents

subjectTable = table();
for i = 1:numel(subjectFiles)

    % Get subject metadata
    subjectFile = fullfile(dataParentDir,subjectFiles{i});
    theseSubjects = readtable(subjectFile);

    % Rename vars
    theseSubjects = renamevars(theseSubjects,{'Animal_','Cage_'},{'Animal','Cage'});

    % Remove rows missing values and warn user
    theseSubjects.DataLabelRaw = cellstr(theseSubjects.DataLabelRaw);
    missingDataLabelInd = ndi.fun.table.identifyMatchingRows(theseSubjects,'DataLabelRaw','NaT');
    if any(missingDataLabelInd)
        warning('%i subjects missing DataLabelRaw value. Skipping these subject(s).', ...
            sum(missingDataLabelInd))
        theseSubjects(missingDataLabelInd,:) = [];
    end

    % Add missing information
    for j = 1:height(theseSubjects)
        treatment = strsplit(theseSubjects.Treatment{j},' ');
        theseSubjects.Strain{j} = treatment{1};
        theseSubjects.ExperimentalGroup{j} = treatment{2};
    end
    theseSubjects{:,'sessionID'} = session.id;

    % Vertically stack subjectTable
    subjectTable = ndi.fun.table.vstack({subjectTable,theseSubjects});
end
subjectTable.Cage = cellfun(@(c) replace(c,' ',''),subjectTable.Cage,'UniformOutput',false);
subjectTable.Cage = cellfun(@(c) replace(c,'/','-'),subjectTable.Cage,'UniformOutput',false);

% Create subjectMaker
subjectMaker = ndi.setup.NDIMaker.subjectMaker();

% Create subject documents
[subjectInfo,theseSubjects.SubjectName] = ...
    subjectMaker.getSubjectInfoFromTable(theseSubjects,...
    @ndi.setup.conv.pulakat.createSubjectInformation);
subDocStruct = subjectMaker.makeSubjectDocuments(subjectInfo);
subjectMaker.addSubjectsToSessions({session}, subDocStruct.documents);
subjectTable.SubjectDocumentIdentifier = cellfun(@(d) d{1}.id,subDocStruct.documents,'UniformOutput',false);

%% Step 4. Process DIA reports

diaTable = table();
for i = 1:numel(diaFiles)

    % Read DIA report
    diaFile = diaFiles{i};
    diaSheetNames = sheetnames(diaFile);
    allDataSheetInd = contains(diaSheetNames,'All data');
    diaAllData = readtable(diaFile,'Sheet',diaSheetNames{allDataSheetInd});

    % Get subject IDs from last sheet
    diaVars = diaAllData.Properties.VariableNames;
    diaSubjectVars = diaVars(startsWith(diaVars,'x'))';
    thisDiaTable = table();
    for j = 1:numel(diaSubjectVars)
        idInfo = strsplit(diaSubjectVars{j},'_');
        thisDiaTable{j,'DataLabelRaw'} = {[num2str(str2double(idInfo{5}),'%.4i'),...
            '-',num2str(str2double(idInfo{3}),'%.2i'),'-',num2str(str2double(idInfo{4}),'%.2i')]};
    end
    thisDiaTable = ndi.fun.table.join({thisDiaTable},'uniqueVariables','DataLabelRaw');

    % Add subject IDs
    thisDiaTable = ndi.fun.table.join({subjectTable,thisDiaTable},...
        'uniqueVariables',{'Animal','Cage'});

    % Add subject_group to database
    subject_group_doc = ndi.document('subject_group') + session.newdocument();
    for j = 1:height(thisDiaTable)
        subject_group_doc = subject_group_doc.add_dependency_value_n(...
            'subject_id',thisDiaTable.SubjectDocumentIdentifier{j});
    end
    session.database_add(subject_group_doc);

    % Add DIA file to database
    generic_file = struct('fileName',diaFile,...
        'fileFormatOntology','format:3620');
    generic_file_doc = ndi.document('generic_file','generic_file',generic_file) + ...
        session.newdocument();
    generic_file_doc = generic_file_doc.add_file('generic_file.ext', ...
        fullfile(dataParentDir,diaFile),'delete_original',0);
    generic_file_doc = generic_file_doc.set_dependency_value('document_id', subject_group_doc.id);
    session.database_add(generic_file_doc);

    % Combine data
    thisDiaTable{:,'diaFile'} = {diaFile};
    thisDiaTable{:,'diaFile_id'} = {generic_file_doc.id};
    diaTable = [diaTable;thisDiaTable];
end

% How do we want to deal with matching each DIA report with the subjects?
% Are we creating a copy of the DIA report for each subject?

%% Step 5. Process SVS files

% Get cage #s
pattern = '\w+(?:-\w+)+';
allIdentifiers = regexp(svsFiles, pattern, 'match');
svsTable = table();
for i = 1:numel(svsFiles)
    cageIdentifiers = cell(size(allIdentifiers{i}));
    animalIdentifiers = cell(size(allIdentifiers{i}));
    svsIdentifiers = cell(size(allIdentifiers{i}));
    for j = 1:numel(allIdentifiers{i})
        lastHyphenIndex = find(allIdentifiers{i}{j} == '-', 1, 'last');
        cageIdentifiers{j} = allIdentifiers{i}{j}(1:lastHyphenIndex-1);
        animalIdentifiers{j} = allIdentifiers{i}{j}(lastHyphenIndex+1:end);
        svsIdentifiers{j} = svsFiles{i};
    end
    thisSvsTable = table(cageIdentifiers',svsIdentifiers',...
        'VariableNames',{'Cage','svsFile'});
    thisSvsTable = ndi.fun.table.join({subjectTable,thisSvsTable},...
        'uniqueVariables',{'Animal','Cage'});
    if isempty(thisSvsTable)
        warning('no subject found matching the files: %s',svsFiles{i});
        continue
    end

    % Add subject_group to database
    if height(thisSvsTable) > 1
        subject_group_doc = ndi.document('subject_group') + session.newdocument();
        for j = 1:numel(allIdentifiers{i})
            subject_group_doc = subject_group_doc.add_dependency_value_n(...
                'subject_id',thisSvsTable.SubjectDocumentIdentifier{j});
        end
        session.database_add(subject_group_doc);
        subject_id = subject_group_doc.id;
    else
        subject_id = thisSvsTable.SubjectDocumentIdentifier{1};
    end

    % Add SVS file to database
    generic_file = struct('fileName',svsFiles{i},...
        'fileFormatOntology','NCIT:C172214');
    generic_file_doc = ndi.document('generic_file','generic_file',generic_file) + ...
        session.newdocument();
    generic_file_doc = generic_file_doc.add_file('generic_file.ext', ...
        fullfile(dataParentDir,svsFiles{i}),'delete_original',0);
    generic_file_doc = generic_file_doc.set_dependency_value('document_id', subject_id);
    session.database_add(generic_file_doc);

    svsTable = [svsTable;thisSvsTable];
end

% Same as DIA report. Need to figure out how to best add these files and alert
% user to subjects missing svs files and svs files missing subjects.

%% Step 6. Process echo files

pattern = '(?<=/)\d+[A-Z]?';
cageIdentifiers = regexp(echoFolders, pattern, 'match');
echoTable = table([cageIdentifiers{:}]',echoFolders,...
    'VariableNames',{'Cage','echoFolder'});
echoTable = ndi.fun.table.join({subjectTable,echoTable},...
        'uniqueVariables',{'Animal','Cage'});

for i = 1:numel(echoSessions)
   
    % Get files in the echo session
    echoFiles = fileList(contains(fileList,echoSessions{i}));

    % Get matching subject
    ind = ndi.fun.table.identifyMatchingRows(echoTable,'echoFolder',...
        fileparts(echoSessions{i}));
    if ~any(ind)
        warning('no subject found matching the files: %s',echoSessions{i});
        continue
    end
    subject_id = echoTable.SubjectDocumentIdentifier{ind};
    
    % Zip files in the echo session
    zipFile = fullfile(dataParentDir,[echoSessions{i},'.zip']);
    if ~exist(zipFile,'file')
        zip(zipFile, fullfile(dataParentDir,echoFiles));
    end

    % Add echo zip file to database
    generic_file = struct('fileName',[echoSessions{i},'.zip'],...
        'fileFormatOntology','format:3987');
    generic_file_doc = ndi.document('generic_file','generic_file',generic_file) + ...
        session.newdocument();
    generic_file_doc = generic_file_doc.add_file('generic_file.ext', zipFile);
    generic_file_doc = generic_file_doc.set_dependency_value('document_id', subject_id);
    session.database_add(generic_file_doc);
end

%% Ingestion

datasetDir = fullfile(dataPath,'pulakat_2025');
if ~exist(datasetDir,'dir')
    mkdir(datasetDir);
elseif options.Overwrite
    rmdir(datasetDir,'s');
    mkdir(datasetDir);
end
dataset = ndi.dataset.dir('pulakat_2025',datasetDir);

% Ingest and add sessions
sessions = {session};
for i = 1:numel(sessions)
    sessionDatabaseDir = fullfile(sessions{i}.path,'.ndi');
    sessions{i}.ingest;
    dataset.add_ingested_session(sessions{i});
end

%% Retrieve files

subjectSummary = ndi.fun.docTable.subject(dataset);

ind = 3;

subject_id = subjectSummary.SubjectDocumentIdentifier{ind};
subjectName = subjectSummary.SubjectLocalIdentifier{ind}
queryDependency = ndi.query('','depends_on','',subject_id);
docs = dataset.database_search(queryDependency);
docs_check = docs;
while numel(docs_check) > 0
    queryDependency = ndi.query('','depends_on','',docs_check{1}.id);
    docs_new = dataset.database_search(queryDependency);
    docs = [docs,docs_new];
    docs_check = [docs_check,docs_new];
    docs_check(1) = [];
end
docClass = cellfun(@doc_class,docs,'UniformOutput',false)';

fileDocs = docs(strcmp(docClass,'generic_file'));
fileDocNames = cellfun(@(d) d.document_properties.generic_file.fileName,fileDocs,'UniformOutput',false)'