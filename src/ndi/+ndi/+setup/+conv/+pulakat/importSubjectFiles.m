function [subjectTable] = importSubjectFiles(subjectFiles)

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
        % error('importSubjectFiles: %s is not a valid subject file: %s.',subjectFile);
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
end

% Stack subject tables
subjectTable = ndi.fun.table.vstack(subjectTables);

% Remove spaces from cage names (if applicable)
subjectTable.Cage = cellfun(@(c) replace(c,' ',''),subjectTable.Cage,...
    'UniformOutput',false);

end