function [elementTable] = element(session)
%ELEMENT Creates a summary table of element documents and their associated metadata.
%
%   elementTable = element(SESSION)
%
%   This function retrieves all 'ndi_element' documents from a session using
%   session.getelements(). It then dynamically discovers all metadata document
%   types that are associated with elements. For each element, it finds all
%   linked metadata documents and aggregates their properties into a single summary
%   table.
%
%   Each row in the output table represents a single element. The first few columns
%   contain the element's core properties (ID, name, etc.). Subsequent columns are
%   dynamically generated based on the metadata found. These columns contain
%   comma-separated lists of unique values for each property from the associated
%   metadata documents.
%
%   Inputs:
%       SESSION - An active and connected ndi.session or ndi.dataset object.
%
%   Outputs:
%       elementTable - A MATLAB table where each row is an element. Columns are
%                    dynamically generated based on the data found.
%                    Core columns include:
%                    - 'subject_id': The ID of the subject associated with the element.
%                    - 'element_id': The unique identifier for the element.
%                    - 'element_name': The name of the element.
%                    - 'element_type': The type of the element.
%                    - 'element_reference': The reference identifier for the element.
%                    Dynamic columns are created for each metadata property found.
%                    The naming convention is 'DocumentTypePropertyName', for example:
%                    - 'PositionName': From 'position_metadata' documents.
%                    - 'ProbeLocationOntology': From 'probe_location' documents.
%
%   See also: ndi.session, ndi.query, ndi.fun.table.vstack, ndi.fun.name2variableName

% Input argument validation
arguments
    session {mustBeA(session,{'ndi.session.dir','ndi.dataset.dir'})}
end

% Get all element documents in the session
elementDocs = session.getelements;

% Find all associated metadata document types
document_path = ndi.common.PathConstants.DocumentFolder;
document_types = cat(1,...
    vlt.file.findfilegroups(fullfile(document_path,'element'), {'.*\.json\>'}),...
    vlt.file.findfilegroups(fullfile(document_path,'probe'), {'.*\.json\>'}),...
    vlt.file.findfilegroups(fullfile(document_path,'metadata'), {'.*\element.json\>'}));

% Retrieve metadatadocuments
metadataDocs = {};
for i = 1:numel(document_types)
    % Get document type name
    [~,a] = fileparts(document_types{i});
    document_types{i} = a{1};

    % Query documents in the database
    query = ndi.query('','isa',document_types{i});
    metadataDocs = cat(2,metadataDocs,session.database_search(query));
end
elementID_metadata = cellfun(@(d) dependency_value(d,'element_id'),...
    metadataDocs,'UniformOutput',false);

% Initialize a struct to hold all data
numElements = numel(elementDocs);
if numElements == 0
    elementTable = table();
    return;
end

% Pre-allocate base fields
data.subject_id = cell(numElements, 1);
data.element_id = cell(numElements, 1);
data.element_name = cell(numElements, 1);
data.element_type = cell(numElements, 1);
data.element_reference = cell(numElements, 1);

%% Loop through each element
for i = 1:numel(elementDocs)
    
    % Get element and subject id
    element = elementDocs{i};
    data.subject_id{i} = element.subject_id;
    data.element_id{i} = element.id;
    data.element_name{i} = element.name;
    data.element_type{i} = element.type;
    data.element_reference{i} = element.reference;
    
    % Initialize temporary struct to aggregate data for the current element
    metadata = struct();   % For metadata documents
    
    % Find element location documents corresponding to this element
    [~,ind] = intersect(elementID_metadata,element.id);
    for k = 1:numel(ind)
        docProp = metadataDocs{ind(k)}.document_properties;
        dataType = docProp.document_class.class_name;
        
        % Initialize the fields
        if ~isfield(metadata, dataType)
            metadata.(dataType).name = {};
            metadata.(dataType).ontology = {};
        end
        
        % Append the name and ontology node to our temporary struct
        if strcmp(dataType,'position_metadata')
            [metadata.(dataType).ontology{end+1},metadata.(dataType).name{end+1}] = ...
                ndi.ontology.lookup(docProp.(dataType).ontologyNode);
            % Could add more of the metadata here
        elseif strcmp(dataType,'distance_metadata')
            [metadata.(dataType).ontology{end+1},metadata.(dataType).name{end+1}] = ...
                ndi.ontology.lookup(docProp.(dataType).ontologyNode_A);
            [metadata.(dataType).ontology{end+1},metadata.(dataType).name{end+1}] = ...
                ndi.ontology.lookup(docProp.(dataType).ontologyNode_B);
            % Could add more of the metadata here
        else
            try
                metadata.(dataType).name{end+1} = docProp.(dataType).name;
                metadata.(dataType).ontology{end+1} = docProp.(dataType).ontology_name;
            catch ME
                error('NDIFUNDOCTTABLEELEMENT:InvalidParameters',...
                    ['Current support only for documents of type "position_metadata", ' ...
                    '"distance_metadata", "openminds_element", and "probe_location".' ...
                    'Modifications may be needed for other document types.' ME])
            end
        end

    end
    
    % Process the aggregated metadata
    metadataTypes = fieldnames(metadata);
    for k = 1:numel(metadataTypes)
        currentType = metadataTypes{k};
        valueTypes = fieldnames(metadata.(currentType));
        for j = 1:numel(valueTypes)
            currentValue = valueTypes{j};

            % Get unique, non-empty values
            ind = ~cellfun('isempty', metadata.(currentType).(valueTypes{j}));
            values = metadata.(currentType).(valueTypes{j})(ind);

            % Make variable name
            variableName = replace(currentType,'metadata','');
            variableName = replace(variableName,'_',' ');
            variableName = ndi.fun.name2variableName([variableName,' ',currentValue]);

            % If the field doesn't exist in our data struct, initialize it
            if ~isfield(data, variableName)
                data.(variableName) = cell(numElements, 1);
            end

            % Create comma-separated strings and assign to the data struct
            data.(variableName){i} = strjoin(unique(values,'stable'), ', ');
        end
    end
end

% Convert the struct to a table
elementTable = struct2table(data);

% Remove empty columns
indEmpty = cellfun(@(t) isempty(t),elementTable.Variables);
elementTable(:,all(indEmpty)) = [];
end