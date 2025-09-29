function T = docCellArray2Table(doc_cell_array)
%DOCCELLARRAY2TABLE Convert a cell array of ndi.document objects to a single table.
%   T = DOCCELLARRAY2TABLE(DOC_CELL_ARRAY) takes a cell array of
%   ndi.document objects, converts each to a table using its `to_table`
%   method, and then vertically stacks them into a single table.
%
%   DESCRIPTION:
%   This function serves as a convenient wrapper to process a batch of
%   ndi.document objects. It first iterates through the input cell array,
%   calling the `to_table()` method on each document. The resulting list of
%   tables is then passed to `ndi.fun.table.vstack`, which intelligently
%   merges them, handling any discrepancies in columns (fields) across
%   the different documents.
%
%   INPUTS:
%   doc_cell_array - A 1xN cell array where each element is an object of
%                    class `ndi.document`.
%
%   OUTPUTS:
%   T - A single MATLAB table representing the combined data from all input
%       documents. If the input cell array is empty, an empty table is
%       returned.
%
%   EXAMPLE:
%   % Assume doc1 and doc2 are valid ndi.document objects.
%   % doc1 might produce a table with columns {'name', 'value'}
%   % doc2 might produce a table with columns {'name', 'timestamp'}
%   doc_list = {doc1, doc2};
%   combined_table = ndi.fun.docTable.docCellArray2Table(doc_list);
%   % combined_table will have columns {'name', 'value', 'timestamp'},
%   % with appropriate fill values (e.g., NaN, <missing>) for absent data.
%
%   SEE ALSO:
%   ndi.document, ndi.document/to_table, ndi.fun.table.vstack

arguments
    doc_cell_array (1,:) cell
end

% Handle the trivial case of an empty input cell array.
if isempty(doc_cell_array)
    T = table();
    return;
end

% Validate that all elements in the cell array are of the correct class.
% The subsequent 'to_table' call would error if they weren't, but this
% provides a more direct and informative error message to the user.
if ~all(cellfun(@(x) isa(x, 'ndi.document'), doc_cell_array))
    error('ndi:fun:docTable:docCellArray2Table:InvalidInput', ...
          'All elements in the input cell array must be of class ndi.document.');
end

% Step 1: Convert each ndi.document object into a table.
% We use cellfun for a concise way to apply the to_table method to each
% element of doc_cell_array. 'UniformOutput' is set to false because the
% output is a cell array containing table objects.
tablesCellArray = cellfun(@(doc) doc.to_table(), doc_cell_array, 'UniformOutput', false);

% Step 2: Use the provided vstack function to combine the individual tables.
% This function is specifically designed to handle the case where different
% tables might have different sets of columns, creating a unified table.
T = ndi.fun.table.vstack(tablesCellArray);

end