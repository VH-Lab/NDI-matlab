% Location: +ndi/+ontology/lookup_uberon.m
% Refactored to use generic helper functions

function [id, name, definition, synonyms] = lookup_uberon(term_or_id_or_name)
% LOOKUP_UBERON - Look up a term in the Uberon ontology by ID or exact name.
%
%   [ID, NAME, DEFINITION, SYNONYMS] = ndi.ontology.lookup_uberon(TERM_OR_ID_OR_NAME)
%
%   Looks up a specific term in the Uberon multi-species anatomy ontology using
%   either its unique numeric identifier part (e.g., '0000948' for heart), its
%   prefixed ID (e.g., 'UBERON:0000948'), or its exact primary label (e.g., 'heart').
%   The 'UBERON:' prefix is case-insensitive and surrounding whitespace is ignored.
%
%   This function preprocesses the input using ndi.ontology.preprocessLookupInput
%   and then performs the OLS search and subsequent IRI lookup using
%   ndi.ontology.searchOLSAndPerformIRILookup.
%
%   Inputs:
%       TERM_OR_ID_OR_NAME - The Uberon numeric ID part (e.g., '0000948'),
%                            a prefixed ID (e.g., 'UBERON: 0000948'), OR the
%                            exact term label (e.g., 'heart').
%                            Provided as a character array or string.
%
%   Outputs:
%       ID           - The full Uberon ID (e.g., 'UBERON:0000948') (char).
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
%     % Lookup by numeric ID
%     [id1, name1, def1, syn1] = ndi.ontology.lookup_uberon('0000948');
%     % Expected (approximate): id1='UBERON:0000948', name1='heart', def1='Organ that drives the circulation...', syn1={'cor', ...}
%
%     % Lookup by prefixed ID
%     [id2, name2, def2, syn2] = ndi.ontology.lookup_uberon('UBERON:0000948');
%     % Expected (approximate): id2='UBERON:0000948', name2='heart', ...
%
%     % Lookup by exact Name
%     [id3, name3, def3, syn3] = ndi.ontology.lookup_uberon('heart');
%     % Expected (approximate): id3='UBERON:0000948', name3='heart', ...
%
%     % Example of name lookup failure (not found)
%     try
%        ndi.ontology.lookup_uberon('NoSuchAnatomicalEntity');
%     catch ME
%        disp(ME.message)
%     end

arguments
    % Input Uberon ID (numeric, prefixed) or exact name
    term_or_id_or_name (1,:) char {mustBeNonempty}
end

% Define ontology specifics
ontology_prefix = 'UBERON';
ontology_name_ols = 'uberon';

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

end % End of function lookup_uberon
