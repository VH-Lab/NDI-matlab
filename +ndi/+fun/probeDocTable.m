function [probeTable] = probeDocTable(session)
%STIMULUSDOCTABLE Creates a summary table of stimulus epochs and their associated metadata.
%
%   stimulusTable = stimulusDocTable(SESSION)
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
%       stimulusTable - A MATLAB table where each row is a stimulus epoch and
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

% Find all probes
probes = session.getprobes;
probeType = cellfun(@(p) p.type,probes,'UniformOutput',false);
probeSubjectID = cellfun(@(p) p.subject_id,probes,'UniformOutput',false);
probeID = cellfun(@(p) p.identifier,probes,'UniformOutput',false);
stimulators = probes(strcmpi(probeType,'stimulator'));

% Initialize table
probeTable = table();

% Find all probe location documents
queryProbeLocation = ndi.query('','isa','probe_location');
probeLocationDocs = session.database_search(queryProbeLocation);
probeID_probeLocation = cellfun(@(pld) dependency_value(pld,'probe_id'),...
    probeLocationDocs,'UniformOutput',false);

% Find all cell type documents
queryCellType = ndi.query('','isa','openminds_element');
cellTypeDocs = session.database_search(queryCellType);
probeID_cellType = cellfun(@(ctd) dependency_value(ctd,'element_id'),...
    cellTypeDocs,'UniformOutput',false);

% Loop through each stimulator
for i = 1:numel(stimulators)

    % Get stimulator and its epochtable
    stimulator = stimulators{i};
    subject_id = stimulator.subject_id;

    % Find probes with matching subject
    probeInd = strcmpi(probeSubjectID,stimulator.subject_id); % this is WRONG; probes could have different cells same subject how to deal with?

    % Initialize temporary structs to aggregate data for the current subject
    probeLocation = struct();   % For 'probe_location' document type
    cellType = struct();        % For 'openminds_element' document type

    % Find probe location documents corresponding to this subject
    [~,ind] = intersect(probeID_probeLocation,probeID(probeInd));
    for k = 1:numel(ind)

        % Initialize the fields
        if ~isfield(probeLocation, 'name')
            probeLocation.name = {};
            probeLocation.ontology = {};
        end
        
        % Append the probe location name and type to our temporary struct
        probeLocation.name{end+1} = probeLocationDocs{ind(k)}.document_properties.probe_location.name;
        probeLocation.ontology{end+1} = probeLocationDocs{ind(k)}.document_properties.probe_location.ontology_name;
    end

    % Find cell type documents corresponding to this subject
    [~,ind] = intersect(probeID_cellType,probeID(probeInd));
    for k = 1:numel(ind)

        % Initialize the fields
        if ~isfield(cellType, 'name')
            cellType.name = {};
            cellType.ontology = {};
        end
        
        % Append the probe location name and type to our temporary struct
        cellType.name{end+1} = cellTypeDocs{ind(k)}.document_properties.openminds.fields.name;
        cellType.ontology{end+1} = cellTypeDocs{ind(k)}.document_properties.openminds.fields.preferredOntologyIdentifier;
    end

    % Process the aggregated probeLocation data
    names = probeLocation.name(~cellfun('isempty', probeLocation.name));
    ontologys = probeLocation.ontology(~cellfun('isempty', probeLocation.ontology));
    probeTable(i,'probeLocationName') = {strjoin(unique(names,'stable'), ', ')};
    probeTable(i,'probeLocationOntology') = {strjoin(unique(ontologys,'stable'), ', ')};

    % Process the aggregated cellType data
    names = cellType.name(~cellfun('isempty', cellType.name));
    ontologys = cellType.ontology(~cellfun('isempty', cellType.ontology));

    % Create comma-separated strings and assign to the table.
    probeTable(i,'cellTypeName') = {strjoin(unique(names,'stable'), ', ')};
    probeTable(i,'cellTypeOntology') = {strjoin(unique(ontologys,'stable'), ', ')};
end

end