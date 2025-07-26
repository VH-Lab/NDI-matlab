function variableName = name2variableName(name)
%NAME2VARIABLENAME Converts a string into a camelCase variable name format.
%
%   variableName = name2variableName(name) takes a character array
%   (char), string array (string), or cell array of char vectors (cellstr)
%   as input and returns a new string suitable for use as a
%   variable name in MATLAB. This version primarily uses cellstr operations.
%
%   This involves:
%   1. Converting the input to a cell array of char vectors for consistent processing.
%   2. Replacing non-alphanumeric characters (except underscore) with spaces.
%   3. Splitting the cleaned string into individual words.
%   4. Capitalizing the first letter of each word and lowercasing the rest.
%   5. Joining all words together without spaces.
%   6. Converting the very first letter of the entire resulting string to lowercase.
%   7. Ensuring the string starts with a letter if it doesn't already
%      (by prepending 'x' if necessary).
%   8. Final cleanup to remove any remaining invalid characters.
%   9. Converting the output back to a char array if the original input was char.
%
%   Input:
%     name - The raw input string (char, string, or cellstr) to be converted.
%
%   Output:
%     variableName - The processed string formatted as a camelCase variable name.
%                   Returns a char array if input was char, otherwise a cellstr.
%

% Input argument validation
arguments
    name {mustBeText}
end

    % Store original input type to determine output type
    wasCharInput = ischar(name);
    wasStringInput = isstring(name); % To handle string array input type

    % Step 1: Ensure input is a cell array of char vectors for consistent processing.
    inputCell = cellstr(name);

    % Process each string in the input cell array (if it was a cellstr or string array)
    outputCell = cell(size(inputCell));

    for k = 1:numel(inputCell)
        currentInputStr = inputCell{k};

        % Handle empty string or string with only spaces for current element
        if isempty(currentInputStr) || all(isspace(currentInputStr))
            outputCell{k} = '';
            continue; % Skip to next element
        end

        % Step 2: Replace select characters with an underscore
        currentInputStr = replace(currentInputStr,':','_');
        currentInputStr = replace(currentInputStr,'-','_');

        % Step 3: Replace non-alphanumeric characters (except underscore) with spaces.
        cleanedChar = regexprep(currentInputStr, '[^a-zA-Z0-9_]', ' ');

        % Step 4: Split the cleaned string into words based on whitespace.
        % 'strsplit' returns a cell array of char vectors.
        words = strsplit(cleanedChar, ' ', 'CollapseDelimiters', true);

        % Initialize an empty cell array to store processed words
        capitalizedWords = cell(size(words));

        % Iterate through each word to capitalize its first letter
        for i = 1:numel(words)
            currentWord = words{i}; % Access as char vector

            % Check if the current word is not empty (e.g., from multiple spaces after cleaning)
            if ~isempty(currentWord)
                % Capitalize the first letter and convert the rest to lowercase
                firstLetter = upper(currentWord(1));
                if length(currentWord) > 1
                    restOfWord = lower(currentWord(2:end));
                else
                    restOfWord = ''; % Word has only one letter
                end
                capitalizedWords{i} = [firstLetter, restOfWord]; % Concatenate char arrays
            else
                capitalizedWords{i} = ''; % Keep empty char vector
            end
        end

        % Step 5: Join the capitalized words back together without spaces.
        tempVariableNameChar = strjoin(capitalizedWords, '');

        % Step 6: Ensure the variable name starts with a letter.
        if ~isempty(tempVariableNameChar) && ~isletter(tempVariableNameChar(1))
            finalVariableNameChar = ['var_', tempVariableNameChar];
        else
            finalVariableNameChar = tempVariableNameChar;
        end

        % Step 7: Final cleanup to remove any remaining non-alphanumeric characters.
        % This regex keeps only letters, numbers, and underscores.
        finalVariableNameChar = regexprep(finalVariableNameChar, '[^a-zA-Z0-9_]', '');

        outputCell{k} = finalVariableNameChar;
    end

    % Step 8: Convert the final output back to the original input type if applicable.
    if wasCharInput
        variableName = outputCell{1}; % If input was char, output is a single char array
    elseif wasStringInput
        variableName = string(outputCell); % If input was string array, convert back to string array
    else
        variableName = outputCell; % If input was cellstr, output is a cellstr
    end

end