function [epochTable] = epoch(session)
%EPOCH Creates a summary table of epochs and their associated metadata.
%
%   epochTable = epoch(SESSION)
%
%   This function queries an NDI session to find all stimulator probes and their
%   corresponding epochs. For each epoch, it extracts timing information (local
%   and global timestamps). It then associates each epoch with relevant
%   'stimulus_bath' and 'openminds_stimulus' documents based on their epoch IDs.
%   The function aggregates properties from these associated documents, such as
%   mixture names, mixture ontologies, stimulus approach names, and approach
%   ontologies, into a single comprehensive summary table.
%
%   Each row in the output table represents a unique stimulus epoch. The columns
%   contain epoch identifiers, subject ID, timing information, and aggregated,
%   comma-separated lists of unique properties from associated stimulus bath
%   and stimulus approach documents. Empty columns (those with no data across
%   any epochs) are removed, and empty string cells are standardized.
%
%   Inputs:
%       SESSION (ndi.session.dir) - An active and connected NDI session object.
%
%   Outputs:
%       epochTable (table) - A MATLAB table where each row corresponds to a
%                       stimulus epoch. Common columns include:
%                       - 'EpochNumber': The epoch number within the stimulator.
%                       - 'EpochDocumentIdentifier': The unique identifier for the epoch.
%                       - 'ProbeDocumentIdentifier': The unique identifier for the probe that generated the epoch.
%                       - 'SubjectDocumentIdentifier': The ID of the subject associated with the probe.
%                       - 'local_t0', 'local_t1': Start and end times in local clock units (numeric).
%                       - 'global_t0', 'global_t1': Start and end times as datetime objects
%                                                    in global time (if available, otherwise empty).
%                       - 'MixtureName': Comma-separated list of unique mixture names
%                                        from associated stimulus_bath documents.
%                       - 'MixtureOntology': Comma-separated list of unique mixture
%                                            ontology names from associated stimulus_bath documents.
%                       - 'ApproachName': Comma-separated list of unique approach names
%                                         from associated openminds_stimulus documents.
%                       - 'ApproachOntology': Comma-separated list of unique approach
%                                             ontology identifiers from associated openminds_stimulus documents.
%
%   See also: ndi.session, ndi.query, ndi.fun.table.vstack

% Input argument validation
arguments
    session {mustBeA(session,{'ndi.session.dir'})}
end

% Find all probes
probes = session.getprobes;
ndi.probe.buildmultipleepochtables(probes); % build epoch tables en mass

% Initialize table
probeArray = cell(numel(probes),1);

% Find all stimulus bath documents
queryStimulusBath = ndi.query('','isa','stimulus_bath');
stimulusBathDocs = session.database_search(queryStimulusBath);

% Find all stimulus approach documents
queryStimulusApproach = ndi.query('','isa','openminds_stimulus');
stimulusApproachDocs = session.database_search(queryStimulusApproach);

% Loop through each stimulator
for i = 1:numel(probes)

    % Get stimulator and its epochtable
    probe = probes{i};
    epochtable = struct2table(probe.epochtable);

    % Add epoch info to probeArray
    probeArray{i} = table;
    probeArray{i}.EpochNumber = num2cell(epochtable.epoch_number);
    probeArray{i}.EpochDocumentIdentifier = epochtable.epoch_id;
    probeArray{i}.ProbeDocumentIdentifier(:) = {probe.identifier};
    probeArray{i}.SubjectDocumentIdentifier(:) = {probe.subject_id};
    for k = 1:height(epochtable)
        ecs = cellfun(@(c) c.type,epochtable.epoch_clock(k,:),'UniformOutput',false);
        clock_local_ind = find(contains(ecs,'dev_local_time'));
        clock_global_ind = find(cellfun(@(c) ndi.time.clocktype.isGlobal(c),epochtable.epoch_clock(k,:)));
        probeArray{i}.local_t0{k} = epochtable.t0_t1{k,clock_local_ind}(1);
        probeArray{i}.local_t1{k} = epochtable.t0_t1{k,clock_local_ind}(2);
        if ~isempty(clock_global_ind)
            probeArray{i}.global_t0{k} = datetime(epochtable.t0_t1{k,clock_global_ind}(1),...
                'convertFrom','datenum');
            probeArray{i}.global_t1{k} = datetime(epochtable.t0_t1{k,clock_global_ind}(2),...
                'convertFrom','datenum');
        end
    end
end

% Concatenate stimulus table
epochTable = ndi.fun.table.vstack(probeArray);

% Add stimulus bath and approach document info
epochid_SB = cellfun(@(sb) sb.document_properties.epochid.epochid,stimulusBathDocs,'UniformOutput',false);
epochid_SA = cellfun(@(sb) sb.document_properties.epochid.epochid,stimulusApproachDocs,'UniformOutput',false);
for i = 1:height(epochTable)

    % Find corresponding stimulus bath docs
    ind = find(strcmpi(epochid_SB,epochTable.EpochDocumentIdentifier(i)));
    
    if ~isempty(ind)
        % Get mixtures from all corresponding stimulus bath docs
        mixtures = table();
        for j = 1:numel(ind)
            mixture = stimulusBathDocs{ind(j)}.document_properties.stimulus_bath.mixture_table;
            mixture = ndi.database.fun.readtablechar(mixture,'.txt','Delimiter',',');
            mixtures = ndi.fun.table.vstack({mixtures,mixture});
        end
        mixtures = unique(mixtures,'stable');

        % Add mixture to epoch table
        epochTable.MixtureName(i) = join(mixtures.name,',');
        epochTable.MixtureOntology(i) = join(mixtures.ontologyName,',');
    end

    % Find corresponding stimulus approach docs
    ind = find(strcmpi(epochid_SA,epochTable.EpochDocumentIdentifier(i)));
    
    if ~isempty(ind)
        % Get approaches from all corresponding stimulus approach docs
        approaches = table();
        for j = 1:numel(ind)
            openminds = struct2table(stimulusApproachDocs{ind(j)}.document_properties.openminds.fields,'AsArray',true);
            approaches = ndi.fun.table.vstack({approaches,openminds});
        end
        approaches = unique(approaches,'stable');

        % Add approach to epoch table
        epochTable.ApproachName(i) = join(approaches.name,',');
        epochTable.ApproachOntology(i) = join(approaches.preferredOntologyIdentifier,',');
    end
end

% Remove empty columns and convert empty double to string to match column datatype
indEmpty = cellfun(@(t) isempty(t),epochTable.Variables);
stringColumn = arrayfun(@(c) ischar([epochTable{~indEmpty(:,c),c}{:}]), 1:width(epochTable));
[rowConvert,colConvert] = find(indEmpty.*stringColumn);
epochTable(rowConvert,colConvert) = {''};
epochTable(:,all(indEmpty)) = [];

end