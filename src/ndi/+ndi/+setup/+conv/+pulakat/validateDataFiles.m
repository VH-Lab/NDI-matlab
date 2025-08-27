function [] = validateDataFiles(subjectTable,dataFiles)

% for every dataFile, what are the relevant subjects? dataSubjects
% What subjects are missing from the subjectTable? 

% % Input argument validation
% arguments
%     dataFiles = '';
% end

% % If no data files specified, retrieve them
% if isempty(dataFiles)
%     [names,paths] = uigetfile('*.*',...
%         'Select data files','',...
%         'MultiSelect','on');
%     if eq(names,0)
%         error('validateDataFiles: No file(s) selected.');
%     end
%     dataFiles = fullfile(paths,names);
% end

% Get known file types
scheduleFiles =  dataFiles(contains(dataFiles,'schedule','IgnoreCase',true));
diaFiles = dataFiles(contains(dataFiles,'DIA'));
svsFiles = dataFiles(endsWith(dataFiles,'.svs'));
echoFiles = dataFiles(contains(dataFiles,'.bimg') | contains(dataFiles,'.pimg') | ...
    contains(dataFiles,'.mxml') | contains(dataFiles,'.vxml'));
echoFolders = unique(fileparts(echoFiles));
indKnownFiles = contains(dataFiles,[scheduleFiles;diaFiles;svsFiles;echoFolders]);
miscFiles = dataFiles(~indKnownFiles); % how to handle these?

% Process experiment schedule files
scheduleSubjects = cell(size(scheduleFiles));
missingScheduleSubjects = cell(size(scheduleFiles));
for i = 1:numel(scheduleFiles)
    experimentSchedule = readtable(scheduleFiles{i},'Sheet',1);

    % Process study groups from first sheet of experimentSchedule
    group1 = unique(experimentSchedule.x18Rats); group1(strcmp(group1,'')) = [];
    group2 = unique(experimentSchedule.x32Rats); group2(strcmp(group2,'')) = [];
    group3 = unique(experimentSchedule.x25Rats); group3(strcmp(group3,'')) = [];
    
    scheduleSubjects{i} = table([group1;group2;group3],'VariableNames',{'Cage'});
    
    % Remove spaces from cage names (if applicable)
    scheduleSubjects{i}.Cage = cellfun(@(c) replace(c,' ',''),scheduleSubjects{i}.Cage,...
        'UniformOutput',false);

    % Find subjects listed in the experiment schedule that are not in the subjectTable
    missingScheduleSubjects{i} = setdiff(scheduleSubjects{i}.Cage,subjectTable.Cage);
    if ~isempty(missingScheduleSubjects{i})
        warning(['validateDataFiles: Subjects with the following cage #s are listed in the file %s, ' ...
            'but have not yet been added to the dataset: %s.'],...
            scheduleFiles{i},strjoin(missingScheduleSubjects{i},', '))
    end
end
allScheduleSubjects = ndi.fun.table.vstack(scheduleSubjects);
allScheduleSubjects = unique(allScheduleSubjects,'stable');
missingSubjectSchedules = setdiff(subjectTable.Cage,allScheduleSubjects.Cage);
if ~isempty(missingSubjectSchedules)
    warning(['validateDataFiles: Subjects with the following cage #s do not, ' ...
        'have an associated experiment schedule: %s.'],...
        strjoin(missingSubjectSchedules,', '))
end

% Process DIA reports
diaSubjects = cell(size(diaFiles));
missingDIASubjects = cell(size(diaFiles));
for i = 1:numel(diaFiles)
    
    % Read DIA report
    diaSheetNames = sheetnames(diaFiles{i});
    allDataSheetInd = contains(diaSheetNames,'All data');
    diaAllData = readtable(diaFiles{i},'Sheet',diaSheetNames{allDataSheetInd});

    % Get subject IDs from last sheet
    diaVars = diaAllData.Properties.VariableNames;
    diaSubjectVars = diaVars(startsWith(diaVars,'x'))';
    diaSubjects{i} = table();
    for j = 1:numel(diaSubjectVars)
        idInfo = strsplit(diaSubjectVars{j},'_');
        diaSubjects{i}{j,'Label'} = {[num2str(str2double(idInfo{5}),'%.3i'),...
            '-',num2str(str2double(idInfo{3}),'%.2i'),'-',num2str(str2double(idInfo{4}),'%.2i')]};
    end
    diaSubjects{i} = unique(diaSubjects{i});

    % Find subjects listed in the DIA report that are not in the subjectTable
    missingDIASubjects{i} = setdiff(diaSubjects{i}.Label,subjectTable.Label);
    if ~isempty(missingDIASubjects{i})
        warning(['validateDataFiles: Subjects with the following labels are listed in the file %s, ' ...
            'but have not yet been added to the dataset: %s.'],...
            diaFiles{i},strjoin(missingDIASubjects{i},', '))
    end
end
allDIASubjects = ndi.fun.table.vstack(diaSubjects);
allDIASubjects = unique(allDIASubjects,'stable');
missingSubjectDIA = setdiff(subjectTable.Label,allDIASubjects.Label);
if ~isempty(missingSubjectDIA)
    warning(['validateDataFiles: Subjects with the following labels do not, ' ...
        'have an associated DIA report: %s.'],...
        strjoin(missingSubjectDIA,', '))
end

% Process SVS files
pattern = '\w+(?:-\w+)+';
allIdentifiers = regexp(svsFiles, pattern, 'match');
svsSubjects = cell(size(svsFiles));
missingSVSSubjects = cell(size(svsFiles));
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
    svsSubjects{i} = table(cageIdentifiers',svsIdentifiers',...
        'VariableNames',{'Cage','svsFile'});

    % Find subjects listed in the experiment schedule that are not in the subjectTable
    missingSVSSubjects{i} = setdiff(svsSubjects{i}.Cage,subjectTable.Cage);
    if ~isempty(missingSVSSubjects{i})
        warning(['validateDataFiles: Subjects with the following cage #s are in the filename %s, ' ...
            'but have not yet been added to the dataset: %s.'],...
            svsFiles{i},strjoin(missingSVSSubjects{i},', '))
    end
end
allSVSSubjects = ndi.fun.table.vstack(svsSubjects);
allSVSSubjects = unique(allSVSSubjects,'stable');
missingSubjectSVS = setdiff(subjectTable.Cage,allSVSSubjects.Cage);
if ~isempty(missingSubjectSVS)
    warning(['validateDataFiles: Subjects with the following labels do not, ' ...
        'have any associated svs files: %s.'],...
        strjoin(missingSubjectSVS,', '))
end

% Process echo folders
pattern = '(?<=/)\d+[A-Z]?';
cageIdentifiers = regexp(echoFolders, pattern, 'match');
echoSubjects = table([cageIdentifiers{:}]',echoFolders,...
    'VariableNames',{'Cage','echoFolder'});

% Find subjects listed in the echo folders that are not in the subjectTable
missingEchoSubjects = setdiff(echoSubjects.Cage,subjectTable.Cage);
if ~isempty(missingEchoSubjects)
    warning(['validateDataFiles: Subjects with the following cage #s are in echo directory names, ' ...
        'but have not yet been added to the dataset: %s.'],...
        strjoin(missingEchoSubjects,', '))
end
allEchoSubjects = unique(echoSubjects,'stable');
missingSubjectEcho = setdiff(subjectTable.Cage,allEchoSubjects.Cage);
if ~isempty(missingSubjectEcho)
    warning(['validateDataFiles: Subjects with the following labels do not, ' ...
        'have any associated echo files: %s.'],...
        strjoin(missingSubjectEcho,', '))
end

warning('validateDataFiles: The following files are of unknown type: %s',...
    strjoin(miscFiles,', '));

end