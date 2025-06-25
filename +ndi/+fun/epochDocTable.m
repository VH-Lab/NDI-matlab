function [epochTable] = epochDocTable(session)
%EPOCHDOCTABLE Creates a summary table of epochs and their associated metadata.
%
%   epochTable = epochDocTable(SESSION)
%
%   This function queries an NDI session to find all stimulator probes and their
%   corresponding epochs. For each epoch, it extracts timing information (local
%   and global timestamps). It then associates each epoch with relevant
%   'stimulus_bath' and 'openminds_stimulus' documents based on their epoch IDs,
%   aggregating properties such as mixture names, mixture ontologies, approach
%   names, and approach ontologies into a single summary table.
%
%   Each row in the output table represents a single stimulus epoch, and the
%   columns contain epoch identifiers, subject ID, timing information, and
%   comma-separated lists of unique properties from associated stimulus bath
%   and approach documents.
%
%   Inputs:
%       SESSION - An active and connected ndi.session object.
%
%   Outputs:
%       epochTable - A MATLAB table where each row is a stimulus epoch and
%                       columns are dynamically generated based on the data found.
%                       Common columns include:
%                       - 'epoch_number': The epoch number within the stimulator.
%                       - 'epoch_id': The unique identifier for the epoch.
%                       - 'subject_id': The ID of the subject associated with the stimulator.
%                       - 'local_t0', 'local_t1': Start and end times in local clock units.
%                       - 'global_t0', 'global_t1': Start and end times as datetime objects
%                                                    in global time (if available).
%                       - 'mixtureName': Comma-separated list of unique mixture names
%                                        from associated stimulus_bath documents.
%                       - 'mixtureOntology': Comma-separated list of unique mixture
%                                            ontology names from associated stimulus_bath documents.
%                       - 'approachName': Comma-separated list of unique approach names
%                                         from associated openminds_stimulus documents.
%                       - 'approachOntology': Comma-separated list of unique approach
%                                             ontology identifiers from associated openminds_stimulus documents.
%
%   See also: ndi.session, ndi.query, table, struct2table, ndi.fun.table.vstack

% Input argument validation
arguments
    session {mustBeA(session,{'ndi.session.dir'})}
end

% Find all stimulator probes
stimulators = session.getprobes('type','stimulator');

% Initialize table
stimulusArray = cell(numel(stimulators),1);

% Find all stimulus bath documents
queryStimulusBath = ndi.query('','isa','stimulus_bath');
stimulusBathDocs = session.database_search(queryStimulusBath);

% Find all stimulus approach documents
queryStimulusApproach = ndi.query('','isa','openminds_stimulus');
stimulusApproachDocs = session.database_search(queryStimulusApproach);

% Loop through each stimulator
for i = 1:numel(stimulators)

    % Get stimulator and its epochtable
    stimulator = stimulators{i};
    epochtable = struct2table(stimulator.epochtable);

    % Add epoch info to epochTable
    stimulusArray{i} = epochtable(:,{'epoch_number','epoch_id'});
    stimulusArray{i}.subject_id(:) = {stimulator.subject_id};
    for k = 1:height(epochtable)
        ecs = cellfun(@(c) c.type,epochtable.epoch_clock(k,:),'UniformOutput',false);
        clock_local_ind = find(contains(ecs,'dev_local_time'));
        clock_global_ind = find(cellfun(@(c) ndi.time.clocktype.isGlobal(c),epochtable.epoch_clock(k,:)));
        stimulusArray{i}.local_t0(k) = epochtable.t0_t1{k,clock_local_ind}(1);
        stimulusArray{i}.local_t1(k) = epochtable.t0_t1{k,clock_local_ind}(2);
        if ~isempty(clock_global_ind)
            stimulusArray{i}.global_t0(k) = datetime(epochtable.t0_t1{k,clock_global_ind}(1),...
                'convertFrom','datenum');
            stimulusArray{i}.global_t1(k) = datetime(epochtable.t0_t1{k,clock_global_ind}(2),...
                'convertFrom','datenum');
        end
    end
end

% Concatenate stimulus table
epochTable = ndi.fun.table.vstack(stimulusArray);

% Add stimulus bath and approach document info
epochid_SB = cellfun(@(sb) sb.document_properties.epochid.epochid,stimulusBathDocs,'UniformOutput',false);
epochid_SA = cellfun(@(sb) sb.document_properties.epochid.epochid,stimulusApproachDocs,'UniformOutput',false);
for i = 1:height(epochTable)

    % Find corresponding stimulus bath docs
    ind = find(strcmpi(epochid_SB,epochTable.epoch_id(i)));
    
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
        epochTable.mixtureName(i) = join(mixtures.name,',');
        epochTable.mixtureOntology(i) = join(mixtures.ontologyName,',');
    end

    % Find corresponding stimulus approach docs
    ind = find(strcmpi(epochid_SA,epochTable.epoch_id(i)));
    
    if ~isempty(ind)
        % Get approaches from all corresponding stimulus approach docs
        approaches = table();
        for j = 1:numel(ind)
            openminds = struct2table(stimulusApproachDocs{ind(j)}.document_properties.openminds.fields,'AsArray',true);
            approaches = ndi.fun.table.vstack({approaches,openminds});
        end
        approaches = unique(approaches,'stable');

        % Add approach to epoch table
        epochTable.approachName(i) = join(approaches.name,',');
        epochTable.approachOntology(i) = join(approaches.preferredOntologyIdentifier,',');
    end
end

end