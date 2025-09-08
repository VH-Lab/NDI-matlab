% Choose the folder where the dataset is (or will be) stored
% (e.g. /Users/myusername/Documents/MATLAB/Datasets)
dataPath = '/Users/ishanadeb/ndiwork/dataset';
savePath = '/Users/ishanadeb/ndiwork/data_download';

% Get dataset
cloudDatasetId = '67f723d574f5f79c6062389d';
datasetPath = fullfile(dataPath,cloudDatasetId);
if isfolder(datasetPath)
    % Load if already downloaded
    dataset = ndi.dataset.dir(datasetPath);
else
    % Download
    if ~isfolder(dataPath), mkdir(dataPath); end
    dataset = ndi.cloud.downloadDataset(cloudDatasetId,dataPath);
end

% Retrieve the session from this dataset
[session_ref_list,session_list] = dataset.session_list();
session = dataset.open_session(session_list{1});

% Create data directory
if ~exist(savePath, 'dir')
    mkdir(savePath);
end

% Create error log
error_file = fullfile(savePath,'error.log');
errorFileID = fopen(error_file, 'a');

% Create BNST Type I data directory
BNST_Type_I_dir = fullfile(savePath, 'BNST_Type_I');
if ~exist(BNST_Type_I_dir, 'dir')
    mkdir(BNST_Type_I_dir);
end

% Create BNST Type III data directory
BNST_Type_III_dir = fullfile(savePath, 'BNST_Type_III');
if ~exist(BNST_Type_III_dir, 'dir')
    mkdir(BNST_Type_III_dir);
end

% Create BNST (undefined type) data directory
BNST_Type_Undefined_dir = fullfile(savePath, 'BNST_Type_Undefined');
if ~exist(BNST_Type_Undefined_dir, 'dir')
    mkdir(BNST_Type_Undefined_dir);
end

% View summary table of all subject metadata
subjectSummary = ndi.fun.docTable.subject(dataset);

% Save the subject summary table to a .mat file
summary_table_file = fullfile(savePath, 'summary_table.mat');
save(summary_table_file, 'subjectSummary');

% Create epoch and probe summary tables
probeSummary = ndi.fun.docTable.probe(dataset);
epochSummary = ndi.fun.docTable.epoch(session); % this will take several minutes

% Combine all metadata into one table
combinedSummary = ndi.fun.table.join({subjectSummary,probeSummary,epochSummary},...
    'uniqueVariables','EpochDocumentIdentifier');
combinedSummary = ndi.fun.table.moveColumnsLeft(combinedSummary,...
    {'SubjectLocalIdentifier','EpochNumber'});

% Loop through each unique probe and download data
[uniqueProbes,~,indProbes] = unique(combinedSummary(:,{'SubjectDocumentIdentifier',...
    'SubjectLocalIdentifier','ProbeName'}));
numProbes = height(uniqueProbes);
fprintf(1, 'Saving data for %i probes.', numProbes);
for i = 1:numProbes
    
    % Search for subject
    subjectID = uniqueProbes.SubjectDocumentIdentifier{i};
    subjectName = uniqueProbes.SubjectLocalIdentifier{i};
    prefixSubjectName = extractBefore(subjectName, '@');

    % Get probe names
    probeNames = strsplit(uniqueProbes.ProbeName{i},',');
    probeName_Vm = probeNames{startsWith(probeNames,'Vm')};
    probeName_I = probeNames{startsWith(probeNames,'I')};
    suffixProbe = probeName_Vm(end);

    % Display progress
    fprintf(1, '%i: Subject Name = %s, Probe Suffix = %s\n', ...
        i, prefixSubjectName, suffixProbe);

    % Get epoch summaries for this probe
    filteredEpochs = combinedSummary(indProbes == i,:);

    % Get cell type
    cellType = unique(filteredEpochs.CellTypeName);

    % Create directory for this probe
    switch cellType{1}
        case ''
            probe_dir = fullfile(BNST_Type_Undefined_dir, [prefixSubjectName,'_',suffixProbe]);
        case 'Type I BNST neuron'
            probe_dir = fullfile(BNST_Type_I_dir, [prefixSubjectName,'_',suffixProbe]);
        case 'Type III BNST neuron'
            probe_dir = fullfile(BNST_Type_III_dir, [prefixSubjectName,'_',suffixProbe]);
    end
    if ~exist(probe_dir, 'dir')
        mkdir(probe_dir);
    end

    % Save the combined summary table for this subject
    save(fullfile(probe_dir, 'summary_table.mat'), 'filteredEpochs');

    % Get the patch-Vm probe
    patchVm = session.getprobes('subject_id',subjectID,'name',probeName_Vm);
    patchVm = patchVm{1};
    
    % Get the patch_I probe
    patchI = session.getprobes('subject_id',subjectID,'name',probeName_I);
    patchI = patchI{1};
    
    % Get timeseries for each of this probe's epochs
    numEpochs = height(filteredEpochs);
    for j = 1:numEpochs

        % Data file name for saving
        data_file_name = fullfile(probe_dir, sprintf('epoch_data_%.2i.mat', j));

        try
            % Read the patch-Vm timeseries
            [dataVm,time] = patchVm.readtimeseries(j,-inf,inf);

            % Read the patch-I timeseries
            [dataI,~] = patchI.readtimeseries(j,-inf,inf);
        

        % Find indices where traces start and end
        traceStarts = find(diff([1;isnan(dataI)]) == -1);
        traceEnds = find(diff([isnan(dataI);0]) == 1);

        % Get number of current steps and number of timepoints per step
        numSteps = numel(traceStarts);
        numTimepoints = max(traceEnds - traceStarts) + 1;

        % Reformat data into a matrix (time x steps)
        timeMatrix = time(1:numTimepoints);
        dataVmMatrix = nan(numTimepoints,numSteps);
        dataIMatrix = nan(numTimepoints,numSteps);
        for z = 1:numSteps
            dataVmMatrix(:,z) = dataVm(traceStarts(z):traceEnds(z));
            dataIMatrix(:,z) = dataI(traceStarts(z):traceEnds(z));
        end

        % Save data file
        % fprintf(1, '    Saving file %s\n', data_file_name);
        save(data_file_name, 'dataVm', 'dataI', 'time', 'dataVmMatrix', 'dataIMatrix', 'timeMatrix');
        catch ME
            fprintf(errorFileID, 'An error occurred with probe %i, epoch %i: %s\n',i,j,data_file_name);
        end
    end
end

fclose(errorFileID);