function [dataTables,docIDs] = ontologyTableRowDoc2Table(tableRowDoc,options)
%ONTOLOGYTABLEROWDOC2TABLE Converts NDI ontologyTableRow documents to MATLAB tables.
%
%   [dataTables, docIDs] = ONTOLOGYTABLEROWDOC2TABLE(tableRowDoc)
%   [dataTables, docIDs] = ONTOLOGYTABLEROWDOC2TABLE(tableRowDoc, StackAll=true)
%
%   Extracts tabular data from one or more NDI ontologyTableRow documents.
%   By default, the function separates documents into groups that share common
%   variable names and returns a separate stacked table for each group.
%
%   The function can also stack all data into a single table, regardless of
%   the original variable names.
%
%   Inputs:
%     tableRowDoc - A single NDI document object or a 1xN cell array
%        of NDI document objects. Each document must contain the
%        ontologyTableRow data structure.
%
%   Optional Name-Value Pair Arguments:
%     StackAll (logical) - If set to false (default), the function groups
%        documents by their `variableNames` property and returns a cell array
%        of tables, one for each group. If true, all data is stacked into a
%        single table, returned within a 1x1 cell array.
%
%   Outputs:
%     dataTables (cell) - A cell array of MATLAB tables. If `StackAll` is false
%        (default), this is an Nx1 cell array where N is the number of unique
%        variable sets found. If `StackAll` is true, this is a 1x1 cell array
%        containing a single, combined table.
%
%     docIDs (cell) - A cell array containing the NDI document IDs. The
%        structure mirrors `dataTables`. Each cell contains the document IDs
%        corresponding to the data in the equivalent `dataTables` cell.
%
%   See also: vlt.data.flattenstruct2table, ndi.fun.table.vstack

% Input argument validation
arguments
    tableRowDoc (1,:) {mustBeA(tableRowDoc,{'cell','ndi.document'})}
    options.StackAll logical = false;
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

if options.StackAll
    % Vertically stack all the individual tables into a single output table
    dataTables = {ndi.fun.table.vstack(tableRows)};
    docIDs = {docID};
else
    % Vertically stack all the tables by common variables
    [varNames,~,indGroup] = unique(variableNames);
    dataTables = cell(numel(varNames),1);
    docIDs = cell(numel(varNames),1);
    for i = 1:numel(varNames)
        dataTables{i} = ndi.fun.table.vstack(tableRows(indGroup == i));
        docIDs{i} = docID(indGroup == i);
    end
end

end