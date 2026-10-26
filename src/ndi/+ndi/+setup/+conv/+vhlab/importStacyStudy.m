function results = importStacyStudy(prefix, options)
% IMPORTSTACYSTUDY - Import all experiments of the Stacy et al. (2023) LGN study.
%
% RESULTS = IMPORTSTACYSTUDY(PREFIX, ...)
%
% Calls ndi.setup.conv.vhlab.importStacyExperiment for each experiment in
% ndi.setup.conv.vhlab.stacyExperimentTable, where PREFIX is the directory
% that holds the experiment directories (for example,
% '/data/ferret_LGN_data'). An error in one experiment is recorded and the
% loop moves on to the next.
%
% RESULTS is a table with one row per experiment and the variables
% 'experimentDate', 'status' ("imported", "valid", "invalid", "missing" or
% "failed"), 'errors' and 'warnings' (counts from validation), and 'message'.
%
% This function also takes name/value pairs that modify its behavior:
% |--------------------------|----------------------------------------------------|
% | 'Experiments' ([])       | A string array of experiment dates to process.     |
% |                          | Default is all experiments in the table.           |
% | 'OnlyContributedCells'   | Only process the experiments that contributed      |
% |   (false)                | cells to the paper.                                |
% | 'ValidateOnly' (false)   | Only validate each directory.                      |
% | 'Overwrite' (false)      | Passed to importStacyExperiment.                   |
% |--------------------------|----------------------------------------------------|
%
% Example:
%   results = ndi.setup.conv.vhlab.importStacyStudy('/data/ferret_LGN_data', 'ValidateOnly', true);
%
% See also: ndi.setup.conv.vhlab.importStacyExperiment, ndi.setup.conv.vhlab.stacyExperimentTable

    arguments
        prefix (1,:) char {mustBeFolder}
        options.Experiments string = string.empty
        options.OnlyContributedCells (1,1) logical = false
        options.ValidateOnly (1,1) logical = false
        options.Overwrite (1,1) logical = false
    end

    T = ndi.setup.conv.vhlab.stacyExperimentTable();
    if options.OnlyContributedCells
        T = T(T.contributedCells, :);
    end
    if ~isempty(options.Experiments)
        T = T(ismember(T.experimentDate, options.Experiments), :);
    end

    n = height(T);
    results = table(T.experimentDate, repmat("", n, 1), zeros(n, 1), zeros(n, 1), repmat("", n, 1), ...
        'VariableNames', {'experimentDate', 'status', 'errors', 'warnings', 'message'});

    for i = 1:n
        dirname = fullfile(prefix, char(T.experimentDate(i)));
        disp(['Experiment ' int2str(i) ' of ' int2str(n) ': ' dirname]);
        if ~isfolder(dirname)
            results.status(i) = "missing";
            results.message(i) = "Directory does not exist.";
            continue;
        end
        try
            [~, report] = ndi.setup.conv.vhlab.importStacyExperiment(dirname, ...
                'ValidateOnly', true);
            results.errors(i) = sum(report.level == "error");
            results.warnings(i) = sum(report.level == "warning");
            if options.ValidateOnly
                if results.errors(i) == 0
                    results.status(i) = "valid";
                else
                    results.status(i) = "invalid";
                end
                continue;
            end
            if results.errors(i) > 0
                results.status(i) = "invalid";
                results.message(i) = "Not imported; failed validation.";
                continue;
            end
            ndi.setup.conv.vhlab.importStacyExperiment(dirname, 'Overwrite', options.Overwrite);
            results.status(i) = "imported";
        catch ME
            results.status(i) = "failed";
            results.message(i) = string(ME.message);
        end
    end

    disp(results);
end
