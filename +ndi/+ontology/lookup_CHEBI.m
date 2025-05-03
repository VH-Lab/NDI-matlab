function [id, name, definition, synonyms] = lookup_CHEBI(term_or_id_or_name)
% LOOKUP_CHEBI - Look up a chemical entity in ChEBI by ID or exact name.
%
%   [ID, NAME, DEFINITION, SYNONYMS] = ndi.ontology.lookup_CHEBI(TERM_OR_ID_OR_NAME)
%
%   Looks up a specific chemical entity in the ChEBI ontology using either its
%   unique numeric identifier (e.g., '15377' for water), its prefixed ID
%   (e.g., 'CHEBI:15377'), or its exact primary name (e.g., 'water').
%   The 'CHEBI:' prefix is case-insensitive and surrounding whitespace is ignored.
%
%   This function preprocesses the input using ndi.ontology.preprocessLookupInput
%   and then performs the OLS search and subsequent IRI lookup using
%   ndi.ontology.searchOLSAndPerformIRILookup.
%
%   Inputs:
%       TERM_OR_ID_OR_NAME - The ChEBI numeric ID (e.g., '15377'),
%                            a prefixed ID (e.g., 'CHEBI: 15377'), OR the
%                            exact chemical name (e.g., 'water').
%                            Provided as a character array or string.
%
%   Outputs:
%       ID           - The full ChEBI ID (e.g., 'CHEBI:15377') (char).
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
%     [id1, name1, def1, syn1] = ndi.ontology.lookup_CHEBI('15377');
%     % Expected (approximate): id1='CHEBI:15377', name1='water', def1='An oxygen hydride...', syn1={'H2O', ...}
%
%     % Lookup by prefixed ID
%     [id2, name2, def2, syn2] = ndi.ontology.lookup_CHEBI('CHEBI:15377');
%     % Expected (approximate): id2='CHEBI:15377', name2='water', ...
%
%     % Lookup by exact Name
%     [id3, name3, def3, syn3] = ndi.ontology.lookup_CHEBI('water');
%     % Expected (approximate): id3='CHEBI:15377', name3='water', ...
%
%     % Example of name lookup failure (not found)
%     try
%        ndi.ontology.lookup_CHEBI('NoSuchChemical');
%     catch ME
%        disp(ME.message)
%     end

arguments
    % Input ChEBI ID (numeric, prefixed) or exact name
    term_or_id_or_name (1,:) char {mustBeNonempty}
end

% Define ontology specifics
ontology_prefix = 'CHEBI';
ontology_name_ols = 'chebi';

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

end % End of function lookup_CHEBI
