% Location: +ndi/+ontology/lookup_CL.m
% Changes: Calls the two new helper functions. Much simpler main body.

function [id, name, definition, synonyms] = lookup_CL(term_or_id_or_name)
% LOOKUP_CL - Look up a term in the Cell Ontology (CL) by ID or exact name.
%
%   [ID, NAME, DEFINITION, SYNONYMS] = ndi.ontology.lookup_CL(TERM_OR_ID_OR_NAME)
%
%   Looks up a specific cell type or concept in the CL ontology using
%   either its unique numeric identifier part (e.g., '0000000' for cell), its
%   prefixed ID (e.g., 'CL:0000000'), or its exact primary label (e.g., 'cell').
%
%   This function preprocesses the input using ndi.ontology.preprocessLookupInput
%   and then performs the OLS search and subsequent IRI lookup using
%   ndi.ontology.searchOLSAndPerformIRILookup.
%
%   Inputs:
%       TERM_OR_ID_OR_NAME - The CL numeric ID part (e.g., '0000000'),
%                            a prefixed ID (e.g., 'CL: 0000000'), OR the
%                            exact term label (e.g., 'cell').
%                            Provided as a character array or string.
%
%   Outputs:
%       ID           - The full CL ID (e.g., 'CL:0000000') (char).
%       NAME         - The primary label of the term (char).
%       DEFINITION   - The first text definition found for the term, if available (char).
%       SYNONYMS     - A cell array of character vectors listing synonyms, if available.
%
%   Error Conditions:
%     - Propagates errors from preprocessing (invalid format) or the main
%       search/lookup function (not found, not unique, API errors, etc.).
%
%   Requires:
%     - MATLAB R2019b or later (for arguments block).
%     - ndi.ontology.preprocessLookupInput function.
%     - ndi.ontology.searchOLSAndPerformIRILookup function.
%     - ndi.ontology.performIriLookup function (called internally).
%
%   Example:
%     [id, name, def, syn] = ndi.ontology.lookup_CL('0000000'); % cell
%     [id, name, def, syn] = ndi.ontology.lookup_CL('CL:0000540'); % neuron
%     [id, name, def, syn] = ndi.ontology.lookup_CL('neuron');

arguments
    % Input CL ID (numeric, prefixed) or exact name
    term_or_id_or_name (1,:) char {mustBeNonempty}
end

% Define ontology specifics
ontology_prefix = 'CL';
ontology_name_ols = 'cl';

% --- Step 1: Preprocess Input ---
try
    [search_query, search_field, lookup_type_msg, ~] = ndi.ontology.preprocessLookupInput(term_or_id_or_name, ontology_prefix);
catch ME
    % Rethrow preprocessing errors immediately
    rethrow(ME);
end

% --- Step 2: Perform Search and IRI Lookup ---
try
    [id, name, definition, synonyms] = ndi.ontology.searchOLSAndPerformIRILookup(...
        search_query, search_field, ontology_name_ols, ontology_prefix, lookup_type_msg);
catch ME
    % Rethrow errors from the search/lookup process
    rethrow(ME);
end

end % End of function lookup_CL
