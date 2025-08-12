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
echoFolders = unique(fileparts(fileList(contains(fileList,'.bimg'))));

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

for i = 1:numel(diaFiles)

    % Read DIA report
    diaFile = diaFiles{i};
    diaSheetNames = sheetnames(diaFile);
    allDataSheetInd = contains(diaSheetNames,'All data');
    diaAllData = readtable(diaFile,'Sheet',diaSheetNames{allDataSheetInd});

    % Get subject IDs from last sheet
    diaVars = diaAllData.Properties.VariableNames;
    diaSubjectVars = diaVars(startsWith(diaVars,'x'))';
    diaTable = table();
    for j = 1:numel(diaSubjectVars)
        idInfo = strsplit(diaSubjectVars{j},'_');
        diaTable{j,'DataLabelRaw'} = {[num2str(str2double(idInfo{5}),'%.4i'),...
            '-',num2str(str2double(idInfo{3}),'%.2i'),'-',num2str(str2double(idInfo{4}),'%.2i')]};
    end
    diaTable = ndi.fun.table.join({diaTable},'uniqueVariables','DataLabelRaw');
    diaTable{:,'diaFile'} = {diaFile};

% How do we want to deal with matching each DIA report with the subjects?
% Are we creating a copy of the DIA report for each subject? What kind of
% document are we attaching it to? generic_file.json?

%% Step 5. Process SVS files

% Get cage #s
pattern = '\w+(?:-\w+)+';
allIdentifiers = regexp(svsFiles, pattern, 'match');
cageIdentifiers = cell(size(allIdentifiers));
animalIdentifiers = cell(size(allIdentifiers));
subjectIdentifiers = cell(size(allIdentifiers));
svsIdentifiers = cell(size(allIdentifiers));
for i = 1:numel(svsFiles)
    for j = 1:numel(allIdentifiers{i})
        lastHyphenIndex = find(allIdentifiers{i}{j} == '-', 1, 'last');
        cageIdentifiers{i}{j} = allIdentifiers{i}{j}(1:lastHyphenIndex-1);
        animalIdentifiers{i}{j} = allIdentifiers{i}{j}(lastHyphenIndex+1:end);
        svsIdentifiers{i}{j} = svsFiles{i};
    end
end
svsTable = table([cageIdentifiers{:}]',[svsIdentifiers{:}]',...
    'VariableNames',{'Cage','svsFile'});

% Same as DIA report. Need to figure out how to best add these files and alert
% user to subjects missing svs files and svs files missing subjects.

%% Step 6. Process echo files

pattern = '(?<=/)\d+[A-Z]?';
cageIdentifiers = regexp(echoFolders, pattern, 'match');
echoTable = table([cageIdentifiers{:}]',echoFolders,...
    'VariableNames',{'Cage','echoFolder'});

% Compress each echo data folder
% zip([echoFolder,'.zip'],echoFolderPath);

%%

summaryTable = ndi.fun.table.join({subjectTable,diaTable,svsTable,echoTable},...
    'uniqueVariables',{'Animal','Cage'})

% Note: there can be more than one svsFiles per subject