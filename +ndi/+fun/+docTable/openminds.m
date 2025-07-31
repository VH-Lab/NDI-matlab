function [openMINDsTable,docIDs] = openminds(session,type)
% OPENMINDS Gathers OpenMINDS document properties into a table.
%
%   [openMINDsTable, docIDs] = OPENMINDS(session,type) retrieves
%   OpenMINDS documents of a specified 'type' from an NDI session and
%   organizes their key properties into a MATLAB table. For each document
%   of the specified type, it extracts its name and associated ontology.
%   Additionally, it identifies and includes properties from any directly
%   linked OpenMINDS documents (dependencies), such as their names and
%   ontologies.
%
%   Inputs:
%     session {ndi.session.dir, ndi.dataset.dir} - An NDI session or dataset
%       directory object from which to retrieve OpenMINDS documents.
%     type {char, string} - The OpenMINDS type to search for, as a
%       character array or string. This should correspond to the last part
%       of the OpenMINDS type URI (e.g., 'Strain', 'BiologicalSex').
%
%   Outputs:
%     openMINDsTable {table} - A MATLAB table where each row represents a
%       unique OpenMINDS document of the specified 'type'. The table
%       includes columns for the primary document's name and ontology (e.g.,
%       'StrainName', 'StrainOntology'), and similar columns for any
%       dependent OpenMINDS documents (e.g., 'SpeciesName', 'SpeciesOntology').
%       Duplicate entries based on the primary document's name are removed.
%     docIDs {cell} - A cell array of character vectors, where each element
%       is the unique ID of the OpenMINDS document corresponding to the
%       rows in 'openMINDsTable', in the same order.
%
%   See also: ndi.query, ndi.session.dir, ndi.dataset.dir, ndi.fun.table.vstack

% Input argument validation
arguments
    session {mustBeA(session,{'ndi.session.dir','ndi.dataset.dir'})}
    type {mustBeText}
end

% Check type class
type = cellstr(type); 
if ~isscalar(type)
    error('openMINDsDocTable:InvalidType',...
        'The type input must be a single character array or string.');
else
    type = type{1};
end

% Get all openminds documents matching that in the session
query = ndi.query('openminds.openminds_type','exact_string',...
    ['https://openminds.om-i.org/types/',type]);
typeDocs = session.database_search(query);
typeDocs_id = cellfun(@(d) d.id,typeDocs,'UniformOutput',false);

% Get all openminds documents
query = ndi.query('','isa', 'openminds');
allDocs = session.database_search(query);
allDocs_id = cellfun(@(d) d.id,allDocs,'UniformOutput',false);

% Initialize table
openMINDsTable = cell(size(typeDocs));

for i = 1:numel(typeDocs)

    openMINDsRow = table();
    
    % Get document properties
    docProp = typeDocs{i}.document_properties;

    % Find the onotology field name
    fieldNames = fields(docProp.openminds.fields);
    ontologyField = fieldNames{contains(fieldNames,'ontology','IgnoreCase',true)};

    % Append the data to the table row
    openMINDsRow.([type,'Name']) = {docProp.openminds.fields.name};
    openMINDsRow.([type,'Ontology']) = {docProp.openminds.fields.(ontologyField)};

    % Get dependent doc ids and types
    openminds_fields = fields(docProp.openminds.fields);
    dependentDocs = {};
    dependentTypes = {};
    for j = 1:numel(openminds_fields)
        fieldName = openminds_fields{j};
        openminds_field = docProp.openminds.fields.(fieldName);
        if iscell(openminds_field) && contains(openminds_field,'ndi')
            dependentDocs(end+1) = regexp(openminds_field, '[^/]*$', 'match', 'once');
            dependentTypes(end+1) = {[upper(fieldName(1)),fieldName(2:end)]};
        end
    end

    for j = 1:numel(dependentDocs)
        
        % Get document properties
        dependentDoc = allDocs{strcmp(allDocs_id,dependentDocs{j})};
        docProp = dependentDoc.document_properties;

        % Find the onotology field name
        fieldNames = fields(docProp.openminds.fields);
        ontologyField = fieldNames{contains(fieldNames,'ontology','IgnoreCase',true)};

        % Append the data to the table row
        openMINDsRow.([dependentTypes{j},'Name']) = {docProp.openminds.fields.name};
        openMINDsRow.([dependentTypes{j},'Ontology']) = {docProp.openminds.fields.(ontologyField)};
    end

    openMINDsTable(i) = {openMINDsRow};
end

% Stack table
openMINDsTable = ndi.fun.table.vstack(openMINDsTable);
docIDs = typeDocs_id';