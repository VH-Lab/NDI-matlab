function [subjectTable] = importSubjectFiles(subjectFiles)
%IMPORTSUBJECTFILES Imports and validates subject metadata from CSV or Excel files.
%
%   subjectTable = IMPORTSUBJECTFILES() opens a user interface dialog to
%   allow the selection of one or more subject metadata files. It then
%   imports, validates, and combines them into a single table.
%
%   subjectTable = IMPORTSUBJECTFILES(subjectFiles) processes the specified
%   list of files provided in the 'subjectFiles' argument.
%
%   Description:
%   This function is designed to read subject information from structured
%   files (e.g., .csv, .xls, .xlsx). It performs two main tasks:
%   1.  Validation: It checks each file to ensure it contains a set of
%       required column headers.
%   2.  Importation: It reads the data from all valid files and
%       consolidates it into a single, tidy MATLAB table.
%   An additional column, 'subjectFile', is added to the output table to
%   trace each record back to its source file.
%
%   Input Arguments:
%   subjectFiles - (Optional) A string array, character vector, or cell
%                  array of character vectors where each element is a full
%                  path to a subject data file. If empty or not provided, a
%                  file selection dialog opens, filtering for '*.csv',
%                  '*.xls', and '*.xlsx' files.
%
%   Output Arguments:
%   subjectTable - A MATLAB table containing the vertically stacked data
%                  from all imported files. The table will have the
%                  following columns plus 'subjectFile':
%                  'Animal', 'Cage', 'Label', 'Species', 'Strain',
%                  'BiologicalSex', 'Treatment'.
%
%   Validation Details:
%   The function validates each file by checking for the presence of the
%   required variable names listed above. If a file is missing one or more
%   of these columns, a warning is issued to the command window.
%
%   Example 1: Select files using the dialog window
%       subjectData = importSubjectFiles();
%
%   Example 2: Provide a list of files to process
%       myFiles = ["C:\data\cohort1_subjects.csv"; "C:\data\cohort2_subjects.xlsx"];
%       subjectData = importSubjectFiles(myFiles);

% Input argument validation
arguments
    subjectFiles = '';
end

% If no subject files specified, retrieve them
if isempty(subjectFiles)
    [names,paths] = uigetfile({'*.csv;*.xls;*.xlsx'},...
        'Select subject mapping files','animal_mapping.csv',...
        'MultiSelect','on');
    if eq(names,0)
        error('importSubjectFiles: No file(s) selected.');
    end
    subjectFiles = fullfile(paths,names);
end

% Convert to cellstr for consistent processing
subjectFiles = cellstr(subjectFiles);

% Validate files
requiredVariableNames = {'Animal','Cage','Label','Species','Strain','BiologicalSex','Treatment'};
for i = 1:numel(subjectFiles)
    subjectFile = subjectFiles{i};
    valid = ndi.setup.conv.pulakat.validateTableFile(subjectFile,requiredVariableNames);
    if ~valid
        warning('importSubjectFiles: %s is not a valid subject file.',subjectFile); % Change to error
    end
end

% Import data from files
subjectTables = cell(size(subjectFiles));
for i = 1:numel(subjectFiles)
    subjectFile = subjectFiles{i};

    % Import current subject table
    importOptions = detectImportOptions(subjectFile);
    importOptions = setvartype(importOptions,requiredVariableNames,'char');
    importOptions.SelectedVariableNames = requiredVariableNames;
    subjectTables{i} = readtable(subjectFile,importOptions);
    subjectTables{i}{:,'subjectFile'} = subjectFile;
end

% Stack subject tables
subjectTable = ndi.fun.table.vstack(subjectTables);

% Remove spaces from cage names (if applicable)
subjectTable.Cage = cellfun(@(c) replace(c,' ',''),subjectTable.Cage,...
    'UniformOutput',false);

end