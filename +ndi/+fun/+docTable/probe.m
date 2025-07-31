function [probeTable] = probe(session)
%PROBEDOCTABLE Creates a summary table of probe documents and their associated metadata.
%
%   probeTable = probeDocTable(SESSION)
%
%   This function queries an NDI session to find all 'probe' documents. For each
%   probe, it extracts core properties such as its ID, name, type, and
%   reference. It then associates each probe with relevant 'probe_location' and
%   'openminds_element' (representing cell types) documents based on their
%   dependencies, aggregating properties such as location names, location
%   ontologies, cell type names, and cell type ontologies into a single summary
%   table.
%
%   Each row in the output table represents a single probe document, and the
%   columns contain probe identifiers, subject ID, and comma-separated lists of
%   unique properties from associated probe location and cell type documents.
%
%   Inputs:
%       SESSION - An active and connected ndi.session or ndi.dataset object.
%
%   Outputs:
%       probeTable - A MATLAB table where each row is a probe and columns are
%                    dynamically generated based on the data found.
%                    Common columns include:
%                    - 'subject_id': The ID of the subject associated with the probe.
%                    - 'probe_id': The unique identifier for the probe.
%                    - 'probe_name': The name of the probe.
%                    - 'probe_type': The type of the probe.
%                    - 'probe_reference': The reference identifier for the probe.
%                    - 'probeLocationName': Comma-separated list of unique probe
%                                           location names from associated
%                                           'probe_location' documents.
%                    - 'probeLocationOntology': Comma-separated list of unique
%                                               probe location ontology names
%                                               from associated 'probe_location' documents.
%                    - 'cellTypeName': Comma-separated list of unique cell type
%                                      names from associated 'openminds_element' documents.
%                    - 'cellTypeOntology': Comma-separated list of unique cell
%                                          type ontology identifiers from
%                                          associated 'openminds_element' documents.
%
%   See also: ndi.session, ndi.query, ndi.fun.table.vstack

% Input argument validation
arguments
    session {mustBeA(session,{'ndi.session.dir','ndi.dataset.dir'})}
end

% Get all probe documents in the session
query = ndi.query('element.ndi_element_class','contains_string','probe');
probeDocs = session.database_search(query);

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
for i = 1:numel(probeDocs)

    % Get probe and subject id
    probe = probeDocs{i};
    probeTable.SubjectDocumentIdentifier{i} = dependency_value(probe,'subject_id');
    probeTable.ProbeDocumentIdentifier{i} = probe.id;
    probeTable.ProbeName{i} = probe.document_properties.element.name;
    probeTable.ProbeType{i} = probe.document_properties.element.type;
    probeTable.ProbeReference{i} = probe.document_properties.element.reference;

    % Initialize temporary structs to aggregate data for the current probe
    probeLocation = struct();   % For 'probe_location' document type
    cellType = struct();        % For 'openminds_element' document type

    % Find probe location documents corresponding to this probe
    [~,ind] = intersect(probeID_probeLocation,probe.id);
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

    % Find cell type documents corresponding to this probe
    [~,ind] = intersect(probeID_cellType,probe.id);
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

    % Process the aggregated ProbeLocation data
    if isfield(probeLocation,'name')
        names = probeLocation.name(~cellfun('isempty', probeLocation.name));
        ontologys = probeLocation.ontology(~cellfun('isempty', probeLocation.ontology));
        probeTable(i,'ProbeLocationName') = {strjoin(unique(names,'stable'), ', ')};
        probeTable(i,'ProbeLocationOntology') = {strjoin(unique(ontologys,'stable'), ', ')};
    else
        probeTable(i,'ProbeLocationName') = {''};
        probeTable(i,'ProbeLocationOntology') = {''};
    end

    % Process the aggregated CellType data
    if isfield(cellType,'name')
        names = cellType.name(~cellfun('isempty', cellType.name));
        ontologys = cellType.ontology(~cellfun('isempty', cellType.ontology));
        probeTable(i,'CellTypeName') = {strjoin(unique(names,'stable'), ', ')};
        probeTable(i,'CellTypeOntology') = {strjoin(unique(ontologys,'stable'), ', ')};
    else
        probeTable(i,'CellTypeName') = {''};
        probeTable(i,'CellTypeOntology') = {''};
    end
end

% Remove empty columns
indEmpty = cellfun(@(t) isempty(t),probeTable.Variables);
probeTable(:,all(indEmpty)) = [];

end