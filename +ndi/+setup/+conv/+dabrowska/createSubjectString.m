function subjectString = createSubjectString(tableRow)
%CREATESUBJECTSTRING Creates a standardized subject string from table data.
%
%   subjectString = CREATESUBJECTSTRING(tableRow)
%
%   Generates a subject identifier string based on the 'IsWildType' and
%   'RecordingDate' variables within the input table row.
%
%   Args:
%       tableRow (table): A 1-row MATLAB table containing at least the columns
%                         'IsWildType' and 'RecordingDate'. The values in these
%                         columns are expected to be cell arrays containing
%                         either a char array (for successful extraction by a
%                         previous process) or potentially NaN (for failed
%                         extraction).
%
%   Returns:
%       subjectString (char | NaN):
%           - If tableRow.IsWildType contains a non-empty char array, returns
%             a character array string in the format:
%             'sd_rat_wt_YYYY_MM_DD@dabrowska-lab.rosalindfranklin.edu'
%             whereCxxInterop_MM_DD is derived from tableRow.RecordingDate.
%           - Returns numeric NaN if tableRow.IsWildType contains NaN, is empty,
%             or is not a character array.
%           - Returns numeric NaN if tableRow.RecordingDate is not a valid
%             date string when IsWildType is valid.

    arguments
        tableRow (1,:) table {mustBeNonempty, mustHaveRequiredColumns}
    end

    % --- Extract and Validate Required Values ---

    % Access cell content using {} assuming results from processFileManifest
    % could be char or NaN stored in cells.
    try
        isWildTypeValue = tableRow.IsWildType{1};
    catch ME_AccessWT
        error('createSubjectString:AccessError', ...
              'Could not access content of IsWildType column. Is it a cell? Error: %s', ME_AccessWT.message);
    end

    try
        recordingDateValue = tableRow.RecordingDate{1};
    catch ME_AccessDate
        error('createSubjectString:AccessError', ...
              'Could not access content of RecordingDate column. Is it a cell? Error: %s', ME_AccessDate.message);
    end

    % --- Check IsWildType validity ---
    % A valid 'IsWildType' means the previous regex matched, returning the text.
    % We check if it's a non-empty character array.
    isWtValid = ischar(isWildTypeValue) && ~isempty(isWildTypeValue);

    if ~isWtValid
        subjectString = NaN; % Return NaN if IsWildType is not valid text
        return;
    end

    % --- Process RecordingDate if IsWildType is valid ---
    if ~(ischar(recordingDateValue) && ~isempty(recordingDateValue))
         warning('createSubjectString:InvalidDateInput', ...
                 'RecordingDate is not valid text for IsWildType="%s". Returning NaN.', char(isWildTypeValue));
         subjectString = NaN;
         return;
    end

    % --- Convert Date Format ---
    try
        % Define expected input format (e.g., 'MMM dd year')
        inputDateFormat = 'MMM dd yyyy'; % Corrected year format specifier
        datetimeObj = datetime(recordingDateValue, 'InputFormat', inputDateFormat);

        % Define desired output format
        outputDateFormat = 'yyyy_mm_dd';
	formattedDate = datestr(datetimeObj, outputDateFormat);

    catch ME_DateFormat
        warning('createSubjectString:DateFormatError', ...
                'Could not parse RecordingDate "%s" with format "%s". Error: %s. Returning NaN.', ...
                recordingDateValue, inputDateFormat, ME_DateFormat.message);
        subjectString = NaN;
        return;
    end

    % --- Construct the Subject String ---
    prefix = 'sd_rat_wt_';
    suffix = '@dabrowska-lab.rosalindfranklin.edu';

    % Use string concatenation which is often cleaner now
    subjectString = string(prefix) + formattedDate + string(suffix);

    % Convert final result explicitly to char array as requested
    subjectString = char(subjectString);

end

% --- Custom Validation Function ---
function mustHaveRequiredColumns(t)
% Checks if the input table t has the required columns

    requiredCols = {'IsWildType', 'RecordingDate'};
    actualCols = t.Properties.VariableNames;

    missingCols = setdiff(requiredCols, actualCols);

    if ~isempty(missingCols)
        error('Validation:MissingColumns', ...
              'Input table is missing required column(s): %s', ...
              strjoin(missingCols, ', '));
    end
end


