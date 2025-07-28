function [dataTable,docIDs] = ontologyTableRowDoc2Table(tableRowDoc,options)
%ONTOLOGYTABLEROWDOC2TABLE Converts NDI ontologyTableRow documents to a single MATLAB table.
%
%   [dataTable, docIDs] = ONTOLOGYTABLEROWDOC2TABLE(tableRowDoc)
%   [dataTable, docIDs] = ONTOLOGYTABLEROWDOC2TABLE(tableRowDoc, SeparateByType=true)
%
%   Extracts tabular data from one or more NDI ontologyTableRow documents and
%   combines them. By default, all extracted tables are vertically stacked into a
%   single MATLAB table. The function also returns the NDI document IDs
%   corresponding to each row.
%
%   The function can also separate the output into different tables based on the
%   type of data each document represents, as defined by its variable names.
%
%   Inputs:
%     tableRowDoc - A single NDI document object or a 1xN cell array
%        of NDI document objects. Each document must contain the
%        ontology table row data structure.
%
%   Optional Name-Value Pair Arguments:
%     SeparateByType (logical) - If set to true, the function groups the
%        documents by their `variableNames` property. It then stacks each group
%        into a separate table and returns a cell array of tables. If false
%        (default), all data is stacked into a single table.
%
%   Outputs:
%     dataTable (table or cell) - If `SeparateByType` is false, this is a single
%        MATLAB table containing the vertically stacked data from all documents.
%        If `SeparateByType` is true, this is a cell array of tables.
%
%     docIDs (cell) - If `SeparateByType` is false, this is a cell array of NDI
%        document IDs, with each element corresponding to a row in `dataTable`.
%        If `SeparateByType` is true, this is a cell array where each cell
%        contains the document IDs for the corresponding table in `dataTable`.
%
%   See also: vlt.data.flattenstruct2table, ndi.fun.table.vstack

% Input argument validation
arguments
    tableRowDoc (1,:) {mustBeA(tableRowDoc,{'cell','ndi.document'})}
    options.SeparateByType logical = false;
end

% If a single document is passed, wrap it in a cell for uniform processing
if ~iscell(tableRowDoc)
    tableRowDoc = {tableRowDoc};
end

% Pre-allocate a cell array to hold the individual tables from each document
tableRows = cell(size(tableRowDoc));
variableNames = cell(size(tableRowDoc));
docID = cell(size(tableRowDoc));

% Loop through each document provided
for i = 1:numel(tableRowDoc)
    % Extract the data struct, convert it to a table, and store it
    tableRows{i} = vlt.data.flattenstruct2table(tableRowDoc{i}.document_properties.ontologyTableRow.data);
    variableNames{i} = tableRowDoc{i}.document_properties.ontologyTableRow.variableNames;
    docID{i} = tableRowDoc{i}.id;
end

if options.SeparateByType
    % Vertically stack all the tables by common variables
    [varNames,~,indGroup] = unique(variableNames);
    dataTable = cell(numel(varNames),1);
    docIDs = cell(numel(varNames),1);
    for i = 1:numel(varNames)
        dataTable{i} = ndi.fun.table.vstack(tableRows(indGroup == i));
        docIDs{i} = docID(indGroup == i);
    end
else
    % Vertically stack all the individual tables into a single output table
    dataTable = ndi.fun.table.vstack(tableRows);
    docIDs = docID;
end

end