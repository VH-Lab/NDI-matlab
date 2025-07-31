function [openmindsTable,docIDs,dependencyIDs] = openminds(session,type,options)
% OPENMINDS Gathers OpenMINDS document properties into a table.
%
%   [openmindsTable, docIDs, dependencyIDs] = OPENMINDS(SESSION, TYPE, OPTIONS)
%   retrieves OpenMINDS documents of a specified 'TYPE' from an NDI session
%   and organizes their key properties into a MATLAB table. For each
%   document of the specified type, it extracts its name and associated
%   ontology. It also identifies and includes properties from any directly
%   linked OpenMINDS documents (dependencies), such as their names and
%   ontologies.
%
%   The function can optionally identify and return the IDs of documents
%   that the found OpenMINDS documents 'depend on', allowing for further
%   linking (e.g., linking a 'Strain' document to a 'subject' document).
%
%   Input Arguments:
%     session (ndi.session.dir or ndi.dataset.dir) - An NDI session or dataset
%       directory object from which to retrieve OpenMINDS documents.
%     type (char or string) - The OpenMINDS type to search for. This should
%       correspond to the last part of the OpenMINDS type URI (e.g., 'Strain',
%       'BiologicalSex', 'Species'). Must be a single character array or string.
%     options.depends_on (char or string, optional) - Specifies a field name
%       within the OpenMINDS document's 'depends_on' structure to extract
%       dependency IDs. For example, use 'subject_id' to retrieve the IDs of
%       subjects that the OpenMINDS documents depend on. Defaults to an empty
%       string, meaning no specific dependency IDs are extracted unless specified.
%
%   Output Arguments:
%     openmindsTable (table) - A MATLAB table where each row represents a
%       unique OpenMINDS document of the specified 'type'. The table
%       includes columns for the primary document's name and ontology (e.g.,
%       'StrainName', 'StrainOntology'). It also includes similar columns
%       (e.g., 'SpeciesName', 'SpeciesOntology') for any directly linked
%       OpenMINDS documents that are dependencies. Duplicate primary
%       documents, particularly those that are encompassed by another (e.g.,
%       a 'BackgroundStrain' when a 'Strain' document exists), are removed,
%       prioritizing the document with the most dependencies.
%     docIDs (cell) - A cell array of character vectors. Each element is the
%       unique document ID of the OpenMINDS document corresponding to the
%       rows in 'openmindsTable', in the same order.
%     dependencyIDs (cell) - A cell array of character vectors. Each element
%       is the ID of the document that the corresponding OpenMINDS document
%       'depends on', as specified by 'options.depends_on'. If 'depends_on'
%       is not specified or no dependency is found, elements will be empty strings.
%
%   See also: ndi.query, ndi.session.dir, ndi.dataset.dir, ndi.fun.table.vstack

% Input argument validation
arguments
    session {mustBeA(session,{'ndi.session.dir','ndi.dataset.dir'})}
    type {mustBeText}
    options.depends_on {mustBeText} = {''};
end

% Check type class
type = cellstr(type); 
if ~isscalar(type)
    error('openMINDsDocTable:InvalidType',...
        'The type input must be a single character array or string.');
else
    type = type{1};
end

% Check depends_on class
options.depends_on = cellstr(options.depends_on);
if ~isscalar(options.depends_on)
    error('openMINDsDocTable:InvalidType',...
        'The type input must be a single character array or string.');
else
    options.depends_on = options.depends_on{1};
end

% Get all openminds documents matching that in the session
query = ndi.query('openminds.openminds_type','exact_string',...
    ['https://openminds.om-i.org/types/',type]);
typeDocs = session.database_search(query);
docIDs = cellfun(@(d) d.id,typeDocs,'UniformOutput',false)';

% Get all openminds documents
query = ndi.query('','isa', 'openminds');
allDocs = session.database_search(query);
allDocs_id = cellfun(@(d) d.id,allDocs,'UniformOutput',false);

% Initialize table
openmindsCell = cell(size(typeDocs))';
dependencyIDs = cell(size(typeDocs))';
totalDependencies = nan(size(typeDocs))';
alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

for i = 1:numel(typeDocs)

    openMINDsRow = table();
    
    % Get document properties
    docProp = typeDocs{i}.document_properties;
    totalDependencies(i) = numel(docProp.depends_on);

    % Get depends_on (if using)
    try
        dependencyIDs{i} = typeDocs{i}.dependency_value(options.depends_on);
    catch
        dependencyIDs{i} = '';
    end

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
            dependentTypes{end+1} = [upper(fieldName(1)),fieldName(2:end)];
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
        if ~isempty(docProp.openminds.fields.(ontologyField))
            openMINDsRow.([dependentTypes{j},'Ontology']) = {docProp.openminds.fields.(ontologyField)};
        end
    end

    % Add row to cell array
    openmindsCell{i} = openMINDsRow;
end

% Check for encompassing openminds document (e.g. Strain encompasses
% BackgroundStrain and rows containing just a BackgroundStrain should be
% removed)
[~,~,indDepend] = unique(dependencyIDs);
removeRows = false(size(dependencyIDs));
for i = 1:max(indDepend)
    ind = find(indDepend == i);
    [~,indMax] = max(totalDependencies(ind));
    removeRows(setdiff(ind,ind(indMax))) = true;
end
openmindsCell(removeRows) = [];
docIDs(removeRows) = [];
dependencyIDs(removeRows) = [];

% Stack table
openmindsTable = ndi.fun.table.vstack(openmindsCell);

end