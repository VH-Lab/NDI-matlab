function [treatmentTable,docIDs,dependencyIDs] = treatment(session,options)
% TREATMENT Gathers NDI treatment document properties into a table.
%
%   [treatmentTable, docIDs, dependencyIDs] = TREATMENT(SESSION, OPTIONS)
%   retrieves 'treatment' type documents from an NDI session and organizes
%   their properties into a MATLAB table. For each treatment document, it
%   extracts its numeric and/or string values, interpreting them based on
%   an associated ontology. It also identifies and returns the IDs of
%   documents that the treatment documents 'depend on'.
%
%   Input Arguments:
%     session (ndi.session.dir or ndi.dataset.dir) - An NDI session or dataset
%       directory object from which to retrieve treatment documents.
%     options.depends_on (char or string, optional) - Specifies a field name
%       within the treatment document's 'depends_on' structure to extract
%       dependency IDs. For example, use 'subject_id' to retrieve the IDs of
%       subjects that the treatment documents depend on. Defaults to an empty
%       string, meaning no specific dependency IDs are extracted unless specified.
%
%   Output Arguments:
%     treatmentTable (table) - A MATLAB table where each row represents a
%       treatment document. The table dynamically includes columns based on
%       the `dataType` derived from the treatment's ontology name. These
%       columns may include:
%         - `[dataType]` for numeric or string values.
%         - `[dataType]Name` and `[dataType]Ontology` if the string value
%           is an ontology node.
%         - `[dataType]Number` and `[dataType]String` if both numeric and
%           string values are present.
%       The function attempts to combine treatments that share the same
%       dependency into a single row, concatenating their properties.
%     docIDs (cell) - A cell array of character vectors. Each element is the
%       unique document ID of the treatment document corresponding to the
%       rows in 'treatmentTable', in the same order.
%     dependencyIDs (cell) - A cell array of character vectors. Each element
%       is the ID of the document that the corresponding treatment document
%       'depends on', as specified by 'options.depends_on'. If 'depends_on'
%       is not specified or no dependency is found, elements will be empty strings.
%
%   See also: ndi.query, ndi.session.dir, ndi.dataset.dir, ndi.fun.table.vstack, ndi.ontology.lookup

% Input argument validation
arguments
    session {mustBeA(session,{'ndi.session.dir','ndi.dataset.dir'})}
    options.depends_on {mustBeText} = {''};
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
query = ndi.query('','isa','treatment');
treatmentDocs = session.database_search(query);
docIDs = cellfun(@(d) d.id,treatmentDocs,'UniformOutput',false)';

% Initialize table
treatmentCell = cell(size(treatmentDocs))';
dependencyIDs = cell(size(treatmentDocs))';

for i = 1:numel(treatmentDocs)

    treatmentRow = table();
    
    % Get document properties
    docProp = treatmentDocs{i}.document_properties;

    % Get depends_on (if using)
    try
        dependencyIDs{i} = treatmentDocs{i}.dependency_value(options.depends_on);
    catch
        dependencyIDs{i} = '';
    end

    % Get datatype and values
    [~,~,~,~,~,dataType] = ndi.ontology.lookup(docProp.treatment.ontologyName);
    numericValue = docProp.treatment.numeric_value;
    stringValue = docProp.treatment.string_value;

    % Check if string value is an ontology node
    if contains(stringValue,':')
        try
            [stringOntology,stringName] = ndi.ontology.lookup(stringValue);
        catch
            stringOntology = [];
            stringName = [];
        end
    end

    % Get values
    if ~isempty(numericValue) & isempty(stringValue)
        treatmentRow.(dataType) = numericValue;
    end
    if ~isempty(stringOntology)
        treatmentRow.([dataType,'Name']) = {stringName};
        treatmentRow.([dataType,'Ontology']) = {stringOntology};
    elseif ~isempty(stringValue) & isempty(numericValue)
        treatmentRow.(dataType) = {stringValue};
    elseif ~isempty(stringValue) & ~isempty(numericValue)
        treatmentRow.([dataType,'Number']) = {numericValue};
        treatmentRow.([dataType,'String']) = {stringValue};
    end

    % Add row to cell array
    treatmentCell{i} = treatmentRow;
end

% Check if treatments can be combined on one row
[~,~,indDepend] = unique(dependencyIDs);
removeRows = false(size(dependencyIDs));
for i = 1:max(indDepend)
    ind = find(indDepend == i);
    try
        join(treatmentCell{ind});
    catch
        treatmentCell{ind(1)} = cat(2,treatmentCell{ind});
        removeRows(ind(2:end)) = true;
    end
end
treatmentCell(removeRows) = [];
docIDs(removeRows) = [];
dependencyIDs(removeRows) = [];

% Stack table
if ~isempty(treatmentCell)
    treatmentTable = ndi.fun.table.vstack(treatmentCell);
else
    treatmentTable = table();
end

end