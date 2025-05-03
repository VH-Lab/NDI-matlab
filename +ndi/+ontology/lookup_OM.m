% Location: +ndi/+ontology/lookup_OM.m
% Refactored AGAIN to use generic helper functions, relying on specific
% logic within preprocessLookupInput for OM.

function [id, name, definition, synonyms] = lookup_OM(term_or_id_or_name)
% LOOKUP_OM - Look up a unit in the Ontology of Units of Measure (OM) by name/term.
%
%   [ID, NAME, DEFINITION, SYNONYMS] = ndi.ontology.lookup_OM(TERM_OR_ID_OR_NAME)
%
%   Looks up a specific unit or concept in the OM ontology (version 2).
%   Input is processed by ndi.ontology.preprocessLookupInput, which applies
%   OM-specific heuristics (rejects numeric IDs, derives likely label from input term,
%   always sets search field to 'label'). The search and IRI lookup are then
%   performed by ndi.ontology.searchOLSAndPerformIRILookup.
%
%   NOTE: Lookup by purely numeric ID (e.g., '182') or prefixed numeric ID
%   (e.g., 'OM:182') is NOT supported and will throw an error during preprocessing.
%
%   Inputs:
%       TERM_OR_ID_OR_NAME - The term label or prefixed term (e.g., 'metre', 'OM:Metre').
%                            Provided as a character array or string.
%
%   Outputs:
%       ID           - The full OM ID (e.g., 'OM:Metre'). Extracted from the result.
%       NAME         - The primary label of the term (char). Often lowercase for OM.
%       DEFINITION   - The first text definition found, if available (char).
%       SYNONYMS     - A cell array of synonyms, if available.
%
%   Error Conditions:
%     - Propagates errors from preprocessing (invalid format, numeric rejected) or
%       the main search/lookup function (not found, not unique, API errors, etc.).
%
%   Requires:
%     - MATLAB R2019b or later.
%     - ndi.ontology.preprocessLookupInput function (with OM logic).
%     - ndi.ontology.searchOLSAndPerformIRILookup function.
%     - ndi.ontology.performIriLookup function (called internally).
%
%   Example:
%     [id1, name1] = ndi.ontology.lookup_OM('metre');       % Should work
%     [id2, name2] = ndi.ontology.lookup_OM('OM:metre');     % Should work
%     [id3, name3] = ndi.ontology.lookup_OM('OM:Metre');     % Should work
%     [id4, name4] = ndi.ontology.lookup_OM('MolarVolumeUnit'); % Should work
%     try; ndi.ontology.lookup_OM('182'); catch ME; disp(ME.message); end % Fails

arguments
    % Input OM term name or prefixed name/ID
    term_or_id_or_name (1,:) char {mustBeNonempty}
end

% Define ontology specifics
ontology_prefix = 'OM';
ontology_name_ols = 'om';

% --- Step 1: Preprocess Input (using updated preprocessor with OM logic) ---
try
    [search_query, search_field, lookup_type_msg, ~] = ndi.ontology.preprocessLookupInput(term_or_id_or_name, ontology_prefix);
    % For OM, search_field will always be 'label' and search_query the derived label
catch ME
    rethrow(ME);
end

% --- Step 2: Perform Search and IRI Lookup (using existing generic function) ---
try
    % This function already handles the non-exact search + filter logic needed when search_field is 'label'
    [id, name, definition, synonyms] = ndi.ontology.searchOLSAndPerformIRILookup(...
        search_query, search_field, ontology_name_ols, ontology_prefix, lookup_type_msg);
catch ME
    rethrow(ME);
end

end % End of function lookup_OM