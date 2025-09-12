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

%% 1. Load ingested data from Nansen (skipping for now)

% Create subject table from files
subjectFiles = {'/Users/jhaley/Documents/MATLAB/data/pulakat/animal_mapping_1.csv'};
subjectTable = ndi.setup.conv.pulakat.importSubjectFiles(subjectFiles);

%% 2. Query for new files

% Get directory (probably want to allow users to specify multiple paths)
dataParentDir = fullfile(userpath,'data');
labName = 'pulakat';
dataPath = fullfile(dataParentDir,labName);
%dataPath = uigetdir([],'Select directory of files to ingest.');

% Get list of files
[fileList,indDir] = vlt.file.manifest(dataPath,'ReturnFullPath',1);

% Narrow file list to possible data files
indHiddenFiles = contains(fileList,'/.');
indSubjectFiles = contains(fileList,'animal_mapping');
dataFiles = fileList(~indHiddenFiles & ~indDir & ~indSubjectFiles);

% Validate data files
dataTable = ndi.setup.conv.pulakat.importDataFiles(dataFiles);

%% Create subject table from files
subjectFiles = {'/Users/jhaley/Documents/MATLAB/data/pulakat/animal_mapping_2.csv'};
subjectTable = ndi.setup.conv.pulakat.importSubjectFiles(subjectFiles);
dataFiles = setdiff(dataFiles,subjectFiles);

% need more guidance on how we want to deal with missing files

%%
missingScheduleSubjects = cell(size(scheduleFiles));
% Find subjects listed in the experiment schedule that are not in the subjectTable
    missingScheduleSubjects{i} = setdiff(scheduleSubjects{i}.Cage,subjectTable.Cage);
    if ~isempty(missingScheduleSubjects{i})
        warning(['validateDataFiles: Subjects with the following cage #s are listed in the file %s, ' ...
            'but have not yet been added to the dataset: %s.'],...
            scheduleFiles{i},strjoin(missingScheduleSubjects{i},', '))
    end
    missingSubjectSchedules = setdiff(subjectTable.Cage,allScheduleSubjects.Cage);
if ~isempty(missingSubjectSchedules)
    warning(['validateDataFiles: Subjects with the following cage #s do not, ' ...
        'have an associated experiment schedule: %s.'],...
        strjoin(missingSubjectSchedules,', '))
end

missingDIASubjects = cell(size(diaFiles));
    % Find subjects listed in the DIA report that are not in the subjectTable
    missingDIASubjects{i} = setdiff(diaSubjects{i}.Label,subjectTable.Label);
    if ~isempty(missingDIASubjects{i})
        warning(['validateDataFiles: Subjects with the following labels are listed in the file %s, ' ...
            'but have not yet been added to the dataset: %s.'],...
            diaFiles{i},strjoin(missingDIASubjects{i},', '))
    end
    missingSubjectDIA = setdiff(subjectTable.Label,allDIASubjects.Label);
if ~isempty(missingSubjectDIA)
    warning(['validateDataFiles: Subjects with the following labels do not, ' ...
        'have an associated DIA report: %s.'],...
        strjoin(missingSubjectDIA,', '))
end

missingSVSSubjects = cell(size(svsFiles));

    % Find subjects listed in the experiment schedule that are not in the subjectTable
    missingSVSSubjects{i} = setdiff(svsSubjects{i}.Cage,subjectTable.Cage);
    if ~isempty(missingSVSSubjects{i})
        warning(['validateDataFiles: Subjects with the following cage #s are in the filename %s, ' ...
            'but have not yet been added to the dataset: %s.'],...
            svsFiles{i},strjoin(missingSVSSubjects{i},', '))
    end
    missingSubjectSVS = setdiff(subjectTable.Cage,allSVSSubjects.Cage);
if ~isempty(missingSubjectSVS)
    warning(['validateDataFiles: Subjects with the following labels do not, ' ...
        'have any associated svs files: %s.'],...
        strjoin(missingSubjectSVS,', '))
end

% Find subjects listed in the echo folders that are not in the subjectTable
missingEchoSubjects = setdiff(echoSubjects.Cage,subjectTable.Cage);
if ~isempty(missingEchoSubjects)
    warning(['validateDataFiles: Subjects with the following cage #s are in echo directory names, ' ...
        'but have not yet been added to the dataset: %s.'],...
        strjoin(missingEchoSubjects,', '))
end
missingSubjectEcho = setdiff(subjectTable.Cage,allEchoSubjects.Cage);
if ~isempty(missingSubjectEcho)
    warning(['validateDataFiles: Subjects with the following labels do not, ' ...
        'have any associated echo files: %s.'],...
        strjoin(missingSubjectEcho,', '))
end