function [dataTable] = validateDataFiles(dataFiles)
%VALIDATEDATAFILES Processes data files to extract subject identifiers and metadata.
%
%   dataTable = VALIDATEDATAFILES() opens a user interface dialog to allow
%   the user to select multiple data files. It then processes these files
%   to extract subject, cage, and animal identifiers based on file type
%   and naming conventions.
%
%   dataTable = VALIDATEDATAFILES(dataFiles) processes the specified list
%   of files provided in the 'dataFiles' argument.
%
%   Description:
%   This function serves as a centralized validator and information
%   extractor for a variety of experimental data files. It categorizes
%   input files into known types (schedule, DIA, SVS, echo) and unknown
%   types, then applies specific parsing logic to each category to extract
%   relevant identifiers. All extracted information is compiled into a
%   single, tidy output table.
%
%   Input Arguments:
%   dataFiles   - (Optional) A string array or cell array of character
%                 vectors, where each element is a full path to a data file.
%                 If this argument is empty or not provided, a file selection
%                 dialog will be displayed.
%
%   Output Arguments:
%   dataTable   - A MATLAB table containing the collated information from
%                 all processed files. The table typically includes columns
%                 such as 'Cage', 'Animal', 'Label', 'fileName', and
%                 'fileType', though not all columns will be populated for
%                 every file type.
%
%   File Processing Logic:
%   -   **Schedule Files**: Identifies Excel files with 'schedule' in the
%       name. It reads the first sheet and extracts cage names from
%       predefined columns ('x18Rats', 'x32Rats', 'x25Rats').
%
%   -   **DIA Files**: Identifies Excel files with 'DIA' in the name. It
%       reads the sheet named 'All data' and parses subject labels from
%       the column headers (variable names).
%
%   -   **SVS Files**: Identifies files with the '.svs' extension. It uses
%       the regular expression '\d+[A-Z]?-\d+' to extract cage and animal
%       identifiers directly from the filenames.
%
%   -   **Echo Files**: Identifies a group of files ('.bimg', '.pimg', etc.)
%       related to echocardiography. It extracts a unique cage identifier
%       from their parent folder names using the regex '(?<=/)\d+[A-Z]?'.
%
%   -   **Miscellaneous Files**: Any files not matching the criteria above are
%       processed as 'unknown'. The function attempts to extract cage and
%       animal identifiers from their filenames using the same regex as for
%       SVS files.
%
%   Example:
%       % Allow user to select files via dialog
%       fileInfoTable = validateDataFiles();
%
%       % Process a predefined list of files
%       myFiles = ["C:\data\exp_schedule.xlsx"; "C:\data\images\138B-174.svs"];
%       fileInfoTable = validateDataFiles(myFiles);

% Input argument validation
arguments
    dataFiles = '';
end

% If no data files specified, retrieve them
if isempty(dataFiles)
    [names,paths] = uigetfile('*.*',...
        'Select data files','',...
        'MultiSelect','on');
    if eq(names,0)
        error('validateDataFiles: No file(s) selected.');
    end
    dataFiles = fullfile(paths,names);
end

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
for i = 1:numel(scheduleFiles)
    experimentSchedule = readtable(scheduleFiles{i},'Sheet',1);

    % Process study groups from first sheet of experimentSchedule
    group1 = unique(experimentSchedule.x18Rats); group1(strcmp(group1,'')) = [];
    group2 = unique(experimentSchedule.x32Rats); group2(strcmp(group2,'')) = [];
    group3 = unique(experimentSchedule.x25Rats); group3(strcmp(group3,'')) = [];
    
    scheduleSubjects{i} = table([group1;group2;group3],'VariableNames',{'Cage'});
    scheduleSubjects{i}{:,'fileName'} = scheduleFiles(i);
    scheduleSubjects{i}{:,'fileType'} = {'schedule'};
    
    % Remove spaces from cage names (if applicable)
    scheduleSubjects{i}.Cage = cellfun(@(c) replace(c,' ',''),scheduleSubjects{i}.Cage,...
        'UniformOutput',false);
end
scheduleTable = ndi.fun.table.vstack(scheduleSubjects);
scheduleTable = unique(scheduleTable,'stable');

% Process DIA reports
diaSubjects = cell(size(diaFiles));
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
    diaSubjects{i}{:,'fileName'} = diaFiles(i);
    diaSubjects{i}{:,'fileType'} = {'DIA'};
end
diaTable = ndi.fun.table.vstack(diaSubjects);
diaTable = unique(diaTable,'stable');

% Process SVS files
pattern = '\d+[A-Z]?-\d+';
allIdentifiers = regexp(svsFiles, pattern, 'match');
svsSubjects = cell(size(svsFiles));
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
        'VariableNames',{'Cage','fileName'});
    svsSubjects{i}{:,'fileType'} = {'svs'};
end
svsTable = ndi.fun.table.vstack(svsSubjects);
svsTable = unique(svsTable,'stable');

% Process echo folders
pattern = '(?<=/)\d+[A-Z]?';
cageIdentifiers = regexp(echoFolders, pattern, 'match');
echoSubjects = table([cageIdentifiers{:}]',echoFolders,...
    'VariableNames',{'Cage','fileName'});
echoSubjects{:,'fileType'} = {'echo'};
echoTable = unique(echoSubjects,'stable');

% Process files of unknown type
pattern = '\d+[A-Z]?-\d+';
allIdentifiers = regexp(miscFiles, pattern, 'match');
miscSubjects = cell(size(miscFiles));
for i = 1:numel(miscFiles)
    cageIdentifiers = cell(size(allIdentifiers{i}));
    animalIdentifiers = cell(size(allIdentifiers{i}));
    miscIdentifiers = cell(size(allIdentifiers{i}));
    for j = 1:numel(allIdentifiers{i})

        lastHyphenIndex = find(allIdentifiers{i}{j} == '-', 1, 'last');
        cageIdentifiers{j} = allIdentifiers{i}{j}(1:lastHyphenIndex-1);
        animalIdentifiers{j} = allIdentifiers{i}{j}(lastHyphenIndex+1:end);
        miscIdentifiers{j} = miscFiles{i};
    end
    miscSubjects{i} = table(cageIdentifiers',animalIdentifiers',miscIdentifiers',...
        'VariableNames',{'Cage','Animal','fileName'});
    miscSubjects{i}{:,'fileType'} = {'unknown'};
end
miscTable = ndi.fun.table.vstack(miscSubjects);
miscTable = unique(miscTable,'stable');

% Collate all data
dataTable = ndi.fun.table.vstack({scheduleTable,diaTable, ...
    svsTable,echoTable,miscTable});

end