function [isValid, report] = validateStacyDirectory(dirname, options)
% VALIDATESTACYDIRECTORY - Check that an experiment directory is ready for doStacyImport.
%
% [ISVALID, REPORT] = VALIDATESTACYDIRECTORY(DIRNAME, ...)
%
% Examines the experiment directory DIRNAME (for example,
% '/data/ferret_LGN_data/2017-09-29') and checks that it has the files and
% structure that ndi.setup.vhlab and ndi.setup.conv.vhlab.doStacyImport need.
% The directory is only read; nothing is written.
%
% The following are checked:
%   Experiment directory:
%     - 'subject.txt' holds a subject identifier
%     - 'dob.txt' holds a date of birth in the form YYYY-MM-DD
%     - 'testdirinfo.txt' lists the epoch directories and their types, and
%       each type has an entry in the approach mappings (ApproachMappings.json)
%     - 'grating_training_run*.mat' files are present (used to compute the
%       training duration)
%     - 'analysis/experiment' can be read and holds cell* variables, and the
%       name and reference of each cell match an entry in a reference.txt file
%   Each epoch directory (t*) listed in testdirinfo.txt:
%     - has the files of the vhintan and vhvis_spike2 DAQ systems, as given by
%       the 'FileParameters' in ndi_common/daq_systems/vhlab/*.json
%     - has a 'reference.txt' file with name, ref and type columns (a listed
%       directory with no reference.txt is not an epoch: that is a warning,
%       and its other checks are skipped, since renaming reference.txt is
%       how an epoch is excluded from the import)
%
% ISVALID is true if no errors were found. REPORT is a table with one row per
% problem found and the variables 'level' ("error" or "warning"),
% 'location' (the file or directory, relative to DIRNAME), and 'message'.
% Errors are problems that will stop the import; warnings are problems that
% will leave the import incomplete.
%
% This function also takes name/value pairs that modify its behavior:
% |--------------------------|----------------------------------------------------|
% | 'RequireSubjectFiles'    | Report missing 'subject.txt' and 'dob.txt' as      |
% |   (true)                 | errors. If false, they are not checked.            |
% | 'CheckCells' (true)      | Load 'analysis/experiment' and check the cells.    |
% | 'Verbose' (true)         | Print the report.                                  |
% | 'json_filename'          | The approach mappings file. Default is             |
% |                          | ApproachMappings.json in this package.             |
% |--------------------------|----------------------------------------------------|
%
% Example:
%   [isValid, report] = ndi.setup.conv.vhlab.validateStacyDirectory('/data/ferret_LGN_data/2017-09-29');
%
% See also: ndi.setup.conv.vhlab.importStacyExperiment, ndi.setup.conv.vhlab.doStacyImport

    arguments
        dirname (1,:) char {mustBeFolder}
        options.RequireSubjectFiles (1,1) logical = true
        options.CheckCells (1,1) logical = true
        options.Verbose (1,1) logical = true
        options.json_filename (1,:) char = fullfile(ndi.toolboxdir, '+ndi', '+setup', '+conv', '+vhlab', 'ApproachMappings.json')
    end

    report = table('Size', [0 3], 'VariableTypes', {'string', 'string', 'string'}, ...
        'VariableNames', {'level', 'location', 'message'});

    function addProblem(level, location, message)
        report(end+1, :) = {string(level), string(location), string(message)};
    end

    [~, expName] = fileparts(dirname);
    if isempty(regexp(expName, '^\d{4}-\d{2}-\d{2}$', 'once'))
        addProblem('warning', '.', ['Directory name ''' expName ''' is not a date in the form YYYY-MM-DD; it is used as the non-survival experiment time.']);
    end

    % --- Subject files ---

    if options.RequireSubjectFiles
        subject_file = fullfile(dirname, 'subject.txt');
        if ~isfile(subject_file)
            addProblem('error', 'subject.txt', 'File is missing.');
        else
            subjectIdentifier = strtrim(fileread(subject_file));
            if isempty(subjectIdentifier)
                addProblem('error', 'subject.txt', 'File is empty.');
            elseif isempty(regexp(subjectIdentifier, '^ferret_\d+\.\d+@vhlab\.org$', 'once'))
                addProblem('warning', 'subject.txt', ['Subject identifier ''' subjectIdentifier ''' is not of the form ferret_LLL.NNNN@vhlab.org.']);
            end
        end

        dob_file = fullfile(dirname, 'dob.txt');
        if ~isfile(dob_file)
            addProblem('error', 'dob.txt', 'File is missing.');
        else
            dateOfBirth = strtrim(fileread(dob_file));
            if isempty(regexp(dateOfBirth, '^\d{4}-\d{2}-\d{2}$', 'once'))
                addProblem('error', 'dob.txt', ['Date of birth ''' dateOfBirth ''' is not of the form YYYY-MM-DD.']);
            end
        end
    end

    % --- Training files ---

    if isempty(dir(fullfile(dirname, 'grating_training_run*.mat')))
        addProblem('warning', '.', 'No grating_training_run*.mat files; the training duration will be NaN.');
    end

    % --- testdirinfo.txt and the epoch directories ---

    epochids = {};
    testdirinfo_file = fullfile(dirname, 'testdirinfo.txt');
    if ~isfile(testdirinfo_file)
        addProblem('error', 'testdirinfo.txt', 'File is missing.');
    else
        try
            % read the file the same way as ndi.setup.conv.vhlab.approachMappingTable
            opts = detectImportOptions(testdirinfo_file, 'FileType', 'text', 'Delimiter', '\t');
            opts = setvartype(opts, 'char');
            opts.VariableNamesLine = 1; % the first line holds the column titles
            opts.DataLines = [2 Inf];
            epochInfo = readtable(testdirinfo_file, opts);
            if width(epochInfo) ~= 2
                error('Expected 2 tab-delimited columns (testdir, types) but found %d.', width(epochInfo));
            end
            epochInfo.Properties.VariableNames = {'epochid', 'type'};
            epochids = cellstr(string(epochInfo.epochid));
            types = cellstr(string(epochInfo.type));
        catch ME
            addProblem('error', 'testdirinfo.txt', ['Could not be read: ' ME.message]);
            types = {};
        end

        if isfile(options.json_filename)
            mappings = jsondecode(fileread(options.json_filename));
            knownTypes = {mappings.approachMappings.name};
            for i = 1:numel(types)
                theseTypes = strtrim(strsplit(types{i}, ','));
                unknown = setdiff(theseTypes, knownTypes);
                if all(~ismember(theseTypes, knownTypes))
                    addProblem('warning', 'testdirinfo.txt', ['Epoch ' epochids{i} ' has no type with an approach mapping (' types{i} '); it will get no stimulus approach documents.']);
                elseif ~isempty(unknown)
                    addProblem('warning', 'testdirinfo.txt', ['Epoch ' epochids{i} ' has types with no approach mapping: ' strjoin(unknown, ', ') '.']);
                end
            end
        else
            addProblem('error', options.json_filename, 'Approach mapping file is missing.');
        end
    end

    % epoch directories on disk that are not in testdirinfo.txt
    d = dir(fullfile(dirname, 't*'));
    diskEpochs = {d([d.isdir]).name};
    notListed = setdiff(diskEpochs, epochids);
    if ~isempty(notListed)
        addProblem('warning', 'testdirinfo.txt', ['Epoch directories not listed (they will get no stimulus approaches): ' strjoin(notListed, ', ') '.']);
    end

    % file patterns of the DAQ systems used by doStacyImport
    daqFolder = fullfile(ndi.common.PathConstants.CommonFolder, 'daq_systems', 'vhlab');
    daqNames = {'vhintan', 'vhvis_spike2'};
    daqPatterns = cell(size(daqNames));
    for k = 1:numel(daqNames)
        daqInfo = jsondecode(fileread(fullfile(daqFolder, [daqNames{k} '.json'])));
        daqPatterns{k} = cellstr(daqInfo.FileParameters);
    end

    references = struct('name', {}, 'ref', {});
    for i = 1:numel(epochids)
        epochDir = fullfile(dirname, epochids{i});
        if ~isfolder(epochDir)
            addProblem('error', epochids{i}, 'Epoch directory listed in testdirinfo.txt does not exist.');
            continue;
        end
        if ~isfile(fullfile(epochDir, 'reference.txt'))
            % without reference.txt the directory is not an epoch: it is how an
            % epoch is excluded from the import (e.g. by renaming reference.txt)
            addProblem('warning', epochids{i}, ['Listed in testdirinfo.txt but has no reference.txt, ' ...
                'so it is not an epoch and is excluded from the import.']);
            continue;
        end
        f = dir(epochDir);
        filenames = {f(~[f.isdir]).name};
        for k = 1:numel(daqNames)
            for p = 1:numel(daqPatterns{k})
                if ~any(~cellfun(@isempty, regexp(filenames, ['^' daqPatterns{k}{p} '$'], 'once')))
                    renameNote = '';
                    if startsWith(daqPatterns{k}{p}, 'vhintan_') && ...
                            any(strcmp(filenames, strrep(daqPatterns{k}{p}, 'vhintan_', 'vhlv_')))
                        renameNote = [' A ' strrep(daqPatterns{k}{p}, 'vhintan_', 'vhlv_') ' file is present and may need to be renamed.'];
                    end
                    addProblem('error', epochids{i}, ['Missing file matching ''' daqPatterns{k}{p} ...
                        ''' needed by DAQ system ' daqNames{k} '.' renameNote]);
                end
            end
        end
        reference_file = fullfile(epochDir, 'reference.txt');
        if isfile(reference_file)
            try
                r = vlt.file.loadStructArray(reference_file);
                if ~all(isfield(r, {'name', 'ref', 'type'}))
                    error('Expected columns name, ref and type.');
                end
                for j = 1:numel(r)
                    references(end+1) = struct('name', r(j).name, 'ref', r(j).ref); %#ok<AGROW>
                end
            catch ME
                addProblem('error', fullfile(epochids{i}, 'reference.txt'), ['Could not be read: ' ME.message]);
            end
        end
    end

    % --- analysis/experiment and its cells ---

    experiment_file = fullfile(dirname, 'analysis', 'experiment');
    if ~isfile(experiment_file)
        addProblem('error', fullfile('analysis', 'experiment'), 'File is missing.');
    elseif options.CheckCells
        try
            g = load(experiment_file, '-mat', 'cell*');
            cellnames = fieldnames(g);
            if isempty(cellnames)
                addProblem('error', fullfile('analysis', 'experiment'), 'File has no cell* variables.');
            end
            for j = 1:numel(cellnames)
                % cell names are cell_NAME_REF_INDEX_YYYY_MM_DD; NAME may contain underscores
                try
                    [refName, refNumber] = ndi.setup.conv.vhlab.parseCellName(cellnames{j});
                catch
                    addProblem('error', fullfile('analysis', 'experiment'), ['Cell ' cellnames{j} ' does not have a name of the form cell_NAME_REF_INDEX_YYYY_MM_DD.']);
                    continue;
                end
                match = strcmp({references.name}, refName) & ([references.ref] == refNumber);
                if ~any(match)
                    addProblem('error', fullfile('analysis', 'experiment'), ['Cell ' cellnames{j} ' has name ''' refName ''' and reference ' int2str(refNumber) ', which are in no reference.txt file.']);
                end
            end
        catch ME
            addProblem('error', fullfile('analysis', 'experiment'), ['Could not be read: ' ME.message]);
        end
    end

    isValid = ~any(report.level == "error");

    if options.Verbose
        if isempty(report)
            disp(['Directory ' dirname ' passed all checks.']);
        else
            fprintf('Directory %s: %d error(s), %d warning(s).\n', dirname, ...
                sum(report.level == "error"), sum(report.level == "warning"));
            disp(report);
        end
    end
end
