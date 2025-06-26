function dataTable = ontologyTableRowDoc2Table(tableRowDoc)
%ONTOLOGYTABLEROWDOC2TABLE Converts one or more ontologyTableRow documents to a single MATLAB table.
%
%   dataTable = ONTOLOGYTABLEROWDOC2TABLE(tableRowDoc)
%
%   Extracts tabular data from the nested structure of one or more NDI
%   ontologyTableRow documents and concatenates them into a single MATLAB table.
%   The function is designed to handle either a single document object or a
%   cell array of multiple document objects.
%
%   For each document, it navigates to the path:
%   'document_properties.ontologyTableRow.data'
%   and uses `vlt.data.flattenstruct2table` to convert the data struct at
%   that location into a table. All resulting tables are then stacked
%   vertically.
%
%   Inputs:
%     tableRowDoc - A single NDI document object or a 1xN cell array
%        of NDI document objects. Each document must contain the
%        ontology table row data structure.
%
%   Outputs:
%     dataTable (table) - A single MATLAB table containing the vertically
%        stacked data from all processed input documents.
%
%   See also: vlt.data.flattenstruct2table, ndi.fun.table.vstack

% Input argument validation
arguments
    tableRowDoc (1,:) {mustBeA(tableRowDoc,{'cell','ndi.document'})}
end

% If a single document is passed, wrap it in a cell for uniform processing
if ~iscell(tableRowDoc)
    tableRowDoc = {tableRowDoc};
end

% Pre-allocate a cell array to hold the individual tables from each document
tableRows = cell(size(tableRowDoc));

% Loop through each document provided
for i = 1:numel(tableRowDoc)
    % Extract the data struct, convert it to a table, and store it
    tableRows{i} = vlt.data.flattenstruct2table(tableRowDoc{i}.document_properties.ontologyTableRow.data);
end

% Vertically stack all the individual tables into a single output table
dataTable = ndi.fun.table.vstack(tableRows);

end