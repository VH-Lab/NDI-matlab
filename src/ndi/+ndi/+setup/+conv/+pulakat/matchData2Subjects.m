function [indSubjects,numSubjects,missingSubjects] = matchData2Subjects(dataTable,subjectTable,identifyingVariableNames)
%MATCHDATA2SUBJECTS Matches rows from a data table to a subject metadata table.
%
%   [indSubjects, numSubjects] = MATCHDATA2SUBJECTS(dataTable, subjectTable)
%   matches records between the two tables using the default identifying
%   variables: {'Animal', 'Cage', 'Label'}.
%
%   [indSubjects, numSubjects] = MATCHDATA2SUBJECTS(dataTable, subjectTable, identifyingVariableNames)
%   matches records using the column names specified in
%   'identifyingVariableNames'.
%
%   Description:
%   This function identifies which subject(s) in a subject metadata table
%   (`subjectTable`) correspond to each data entry in a data table
%   (`dataTable`). The matching is performed by finding common values across
%   one or more shared columns, such as subject IDs or cage numbers.
%
%   For each row in `dataTable`, the function returns a list of all unique
%   `subjectTable` row indices that were matched, along with a count of
%   those unique matches.
%
%   Input Arguments:
%   dataTable               - A MATLAB table where each row represents a data
%                             point (e.g., from a file) to be linked to a
%                             subject. It must contain the columns specified
%                             by `identifyingVariableNames`.
%   subjectTable            - A MATLAB table where each row represents a
%                             unique subject. It must also contain the
%                             columns specified by `identifyingVariableNames`.
%   identifyingVariableNames- (Optional) A string array or cell array of
%                             character vectors specifying the column names
%                             to use for matching. If not provided, this
%                             defaults to {'Animal', 'Cage', 'Label'}.
%
%   Output Arguments:
%   indSubjects             - A cell array with the same number of rows as
%                             `dataTable`. Each cell `indSubjects{i}` contains a
%                             numeric vector of unique row indices from
%                             `subjectTable` that match the i-th row of
%                             `dataTable`. The cell is empty if no match is found.
%   numSubjects             - A numeric column vector where each element
%                             `numSubjects(i)` is the number of unique subjects
%                             matched to the i-th row of `dataTable`.
%
%   Example:
%       % Create a data table and a subject table
%       dataT = table({'101'; '102'; 'C3'}, {'C1'; 'C2'; 'C3'}, 'VariableNames', {'Animal', 'Cage'});
%       subjectT = table({'101'; '102'; '103'}, {'C1'; 'C2'; 'C3'}, 'VariableNames', {'Animal', 'Cage'});
%
%       % Match the tables
%       [inds, counts] = matchData2Subjects(dataT, subjectT, {'Animal', 'Cage'});
%
%       % inds will be: {[1]; [2]; [3]}
%       %   - dataT row 1 matches subjectT row 1 via 'Animal'
%       %   - dataT row 2 matches subjectT row 2 via 'Animal'
%       %   - dataT row 3 matches subjectT row 3 via 'Cage'
%       % counts will be: [1; 1; 1]

% Input argument validation
arguments
    dataTable {mustBeA(dataTable,'table')}
    subjectTable {mustBeA(subjectTable,'table')}
    identifyingVariableNames {mustBeText} = {'Animal','Cage','Label'};
end

% Ensure requiredVariableNames is a cell array
identifyingVariableNames = cellstr(identifyingVariableNames);

% Check that both tables have the necessary variables
missingVariableNames = setdiff(identifyingVariableNames,dataTable.Properties.VariableNames);
if ~isempty(missingVariableNames)
    error('matchData2Subjects:missingVariables', ...
        'The data table is missing the required columns: %s', ...
        strjoin(missingVariableNames,', '))
end
missingVariableNames = setdiff(identifyingVariableNames,subjectTable.Properties.VariableNames);
if ~isempty(missingVariableNames)
    error('matchData2Subjects:missingVariables', ...
        'The subject table is missing the required columns: %s', ...
        strjoin(missingVariableNames,', '))
end

% Get the indices of each variable name
indSubjects = zeros(height(dataTable),numel(identifyingVariableNames));
for i = 1:numel(identifyingVariableNames)
    [~,indData,indSubject] = intersect(dataTable(:,identifyingVariableNames{i}), ...
        subjectTable(:,identifyingVariableNames{i}));
    indSubjects(indData,i) = indSubject;
end

% Get unique subject indices per dataTable row
indSubjects = num2cell(indSubjects,2);
indSubjects = cellfun(@(x) unique(x(x > 0)),indSubjects,'UniformOutput',false);

% Get count of unique subjects per dataTable row
numSubjects = cellfun(@numel,indSubjects);

% Get subjects missing from subjectTable but present in dataTable
missingSubjects = dataTable(numSubjects == 0,identifyingVariableNames);
missingSubjects = unique(missingSubjects,'stable');

% need to add documentation for missing subjects and figure out how to
% combine empty values

end