function [S, report] = importStacyExperiment(dirname, options)
% IMPORTSTACYEXPERIMENT - Import one experiment directory of the Stacy et al. (2023) LGN study.
%
% [S, REPORT] = IMPORTSTACYEXPERIMENT(DIRNAME, ...)
%
% Imports the experiment directory DIRNAME (for example,
% '/data/ferret_LGN_data/2017-09-29') into an NDI session. The steps are:
%   1. Write 'subject.txt' and 'dob.txt' in DIRNAME if they are not already
%      there. The subject identifier and date of birth are taken from
%      ndi.setup.conv.vhlab.stacyExperimentTable, matched by the name of
%      DIRNAME, unless they are given as options.
%   2. Check the directory with ndi.setup.conv.vhlab.validateStacyDirectory.
%      If it reports any errors, stop with an error before anything is
%      written to the session.
%   3. Open (or create) the session with ndi.setup.vhlab, using the
%      directory name as the session reference.
%   4. Import subjects, stimulus approaches, treatments, probe locations and
%      spikes with ndi.setup.conv.vhlab.doStacyImport.
%
% S is the ndi.session.dir object (empty if 'ValidateOnly' is true). REPORT is
% the table of problems returned by validateStacyDirectory.
%
% This function also takes name/value pairs that modify its behavior:
% |--------------------------|----------------------------------------------------|
% | 'SubjectIdentifier' ("") | The subject identifier to write to 'subject.txt'.  |
% |                          | Default is the one in stacyExperimentTable.        |
% | 'DateOfBirth' ("")       | The date of birth (YYYY-MM-DD) to write to         |
% |                          | 'dob.txt'. Default is the one in                   |
% |                          | stacyExperimentTable.                              |
% | 'WriteSubjectFiles'      | Write 'subject.txt' and 'dob.txt' if they are      |
% |   (true)                 | missing. Existing files are never overwritten; if  |
% |                          | they disagree with the expected values, an error   |
% |                          | is generated.                                      |
% | 'ValidateOnly' (false)   | Stop after validation; do not create a session.    |
% |                          | Missing subject files are still written in step 1  |
% |                          | unless 'WriteSubjectFiles' is false.               |
% | 'Overwrite' (false)      | Passed to doStacyImport.                           |
% |--------------------------|----------------------------------------------------|
%
% Example:
%   % check one experiment without importing it
%   [~, report] = ndi.setup.conv.vhlab.importStacyExperiment('/data/ferret_LGN_data/2020-07-16', 'ValidateOnly', true);
%   % import it
%   S = ndi.setup.conv.vhlab.importStacyExperiment('/data/ferret_LGN_data/2020-07-16');
%
% See also: ndi.setup.conv.vhlab.importStacyStudy, ndi.setup.conv.vhlab.validateStacyDirectory,
%   ndi.setup.conv.vhlab.doStacyImport

    arguments
        dirname (1,:) char {mustBeFolder}
        options.SubjectIdentifier (1,1) string = ""
        options.DateOfBirth (1,1) string = ""
        options.WriteSubjectFiles (1,1) logical = true
        options.ValidateOnly (1,1) logical = false
        options.Overwrite (1,1) logical = false
    end

    S = [];
    [~, expName] = fileparts(dirname);

    % --- Step 1: subject files ---

    if options.WriteSubjectFiles
        subjectIdentifier = options.SubjectIdentifier;
        dateOfBirth = options.DateOfBirth;
        if subjectIdentifier == "" || dateOfBirth == ""
            T = ndi.setup.conv.vhlab.stacyExperimentTable();
            row = T(T.experimentDate == expName, :);
            if isempty(row)
                error('ndi:setup:conv:vhlab:importStacyExperiment:UnknownExperiment', ...
                    ['Experiment ''' expName ''' is not in stacyExperimentTable; provide SubjectIdentifier and DateOfBirth.']);
            end
            if subjectIdentifier == ""
                subjectIdentifier = row.subjectIdentifier;
            end
            if dateOfBirth == ""
                dateOfBirth = row.dateOfBirth;
            end
        end
        writeIfMissing(fullfile(dirname, 'subject.txt'), subjectIdentifier);
        writeIfMissing(fullfile(dirname, 'dob.txt'), dateOfBirth);
    end

    % --- Step 2: validation ---

    [isValid, report] = ndi.setup.conv.vhlab.validateStacyDirectory(dirname);
    if options.ValidateOnly
        return;
    end
    if ~isValid
        error('ndi:setup:conv:vhlab:importStacyExperiment:InvalidDirectory', ...
            'Directory %s failed validation with %d error(s); see the report above.', ...
            dirname, sum(report.level == "error"));
    end

    % --- Steps 3 and 4: session and import ---

    S = ndi.setup.vhlab(expName, dirname);
    ndi.setup.conv.vhlab.doStacyImport(S, 'Overwrite', options.Overwrite);
end

function writeIfMissing(filename, value)
% WRITEIFMISSING - Write VALUE to FILENAME unless it exists; check it if it does.
    if isfile(filename)
        existing = strtrim(fileread(filename));
        if ~strcmp(existing, value)
            error('ndi:setup:conv:vhlab:importStacyExperiment:SubjectFileMismatch', ...
                '%s holds ''%s'' but ''%s'' was expected.', filename, existing, value);
        end
    else
        fid = fopen(filename, 'w');
        if fid < 0
            error('ndi:setup:conv:vhlab:importStacyExperiment:WriteFailed', ...
                'Could not open %s for writing.', filename);
        end
        fprintf(fid, '%s\n', value);
        fclose(fid);
    end
end
