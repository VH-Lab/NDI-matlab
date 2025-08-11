function T = treatmentTable(S)
% TREATMENTTABLE - Creates a table of experimental treatments for an NDI session.
%
% T = TREATMENTTABLE(S)
%
% Creates a table with variables 'treatment', 'stringValue', 'numericValue',
% 'subjectIdentifier', and 'sessionPath'. The table will contain multiple rows,
% one for each treatment type.
%
% This function performs the following steps:
%   1. Calculates the duration of grating stimulation from 'grating_training_run*.mat' files.
%   2. Reads the date of birth from 'dob.txt'.
%   3. Extracts the experiment date from the session directory name.
%   4. Reads the subject identifier from 'subject.txt'.
%
% It takes an ndi.session.dir object 'S' as input.
%
% Example:
%   % Assuming 'mySession' is a valid ndi.session.dir object
%   mySession = ndi.session.dir('/path/to/my/2018-07-01');
%   treat_table = treatmentTable(mySession);
%   disp(treat_table);
%

    % --- File Paths and Initial Data Reading ---
    sessionPath = S.getpath();
    subject_file = fullfile(sessionPath, 'subject.txt');
    dob_file = fullfile(sessionPath, 'dob.txt');

    % Verify required files exist
    if ~exist(subject_file, 'file')
        error('Subject file not found: %s', subject_file);
    end
    if ~exist(dob_file, 'file')
        error('Date of birth file not found: %s', dob_file);
    end

    % Read common information
    subjectIdentifier = strtrim(fileread(subject_file));
    dateOfBirth = strtrim(fileread(dob_file));

    % --- 1. Calculate Grating Exposure Duration ---
    
    % Find all grating training files
    training_files = dir(fullfile(sessionPath, 'grating_training_run*.mat'));
    
    duration_hours = NaN; % Default to NaN
    
    if ~isempty(training_files)
        min_time = Inf;
        max_time = -Inf;
        
        % Loop through files to find the min and max datenum
        for i = 1:numel(training_files)
            try
                z = load(fullfile(training_files(i).folder, training_files(i).name));
                if isfield(z, 'currenttime')
                    min_time = min(min_time, z.currenttime);
                    max_time = max(max_time, z.currenttime);
                end
            catch ME
                warning('Could not load or process file %s: %s', training_files(i).name, ME.message);
            end
        end
        
        % Calculate duration in hours if we found valid times
        if isfinite(min_time) && isfinite(max_time)
            duration_days = max_time - min_time;
            duration_hours = duration_days * 24;
        end
    else
        warning('No grating_training_run*.mat files found in %s.', sessionPath);
    end

    % --- 2. Get Experiment Date from Directory Name ---
    [~, sessionDirName, ~] = fileparts(sessionPath);


    % --- 3. Assemble the Table ---

    % Create data for each row
    % Row 1: Grating stimulation
    row1 = {'EMPTY:Treatment: Grating direction-of-motion visual stimulation', "", duration_hours};
    
    % Row 2: Date of birth
    row2 = {'EMPTY:Treatment: Date of birth', string(dateOfBirth), NaN};
    
    % Row 3: Experiment time
    row3 = {'EMPTY:Treatment: Non-survival experiment time', string(sessionDirName), NaN};
    
    % Combine rows into a cell array
    table_data_cell = [row1; row2; row3];
    
    % Convert cell to a preliminary table
    T_prelim = cell2table(table_data_cell, 'VariableNames', {'treatment', 'stringValue', 'numericValue'});
    
    % Add the constant columns for subject and session path
    T_prelim.subjectIdentifier = repmat(string(subjectIdentifier), height(T_prelim), 1);
    T_prelim.sessionPath = repmat(string(sessionPath), height(T_prelim), 1);
    
    % Reorder columns to the final desired order
    T = T_prelim(:, {'sessionPath', 'subjectIdentifier', 'treatment', 'stringValue', 'numericValue'});

end
