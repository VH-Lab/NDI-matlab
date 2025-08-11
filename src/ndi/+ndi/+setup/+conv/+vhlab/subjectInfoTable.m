function T = subjectInfoTable(S)
% SUBJECTINFOTABLE - Creates a single-row table with subject information for an NDI session.
%
% T = SUBJECTINFOTABLE(S)
%
% Creates a table with variables 'sessionPath', 'sessionID', 'subjectIdentifier',
% 'BiologicalSex', and 'species'.
%
% This function reads the subject identifier from 'subject.txt' in the session
% directory and combines it with constant values for sex and species. It also
% includes the NDI session ID.
%
% It takes an ndi.session.dir object 'S' as input.
%
% Example:
%   % Assuming 'mySession' is a valid ndi.session.dir object
%   mySession = ndi.session.dir('/path/to/my/session');
%   info_table = subjectInfoTable(mySession);
%   disp(info_table);
%

    % --- File Paths and Data Reading ---
    sessionPath = S.getpath();
    sessionID = S.id(); % Get the session's unique NDI identifier
    subject_file = fullfile(sessionPath, 'subject.txt');

    % Verify the subject file exists
    if ~isfile(subject_file)
        error('Subject file not found: %s', subject_file);
    end

    % Read subject identifier from the file
    subjectIdentifier = strtrim(fileread(subject_file));

    % --- Table Construction ---
    
    % Define constant values
    biologicalSex = 'female';
    species = 'Mustela putorius furo';

    % Create the single-row table directly
    T = table( ...
        string(sessionPath), ...
        string(sessionID), ...
        string(subjectIdentifier), ...
        string(biologicalSex), ...
        string(species), ...
        'VariableNames', {'sessionPath', 'sessionID', 'subjectIdentifier', 'BiologicalSex', 'species'} ...
    );

end
