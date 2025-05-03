% Location: +ndi/+ontology/preprocessLookupInput.m
% Revised: Added specific handling for OM ontology.

function [search_query, search_field, lookup_type_msg, original_input] = preprocessLookupInput(term_or_id_or_name, ontology_prefix)
%PREPROCESSLOOKUPINPUT Processes input for ontology lookup functions.
%
%   [SEARCH_QUERY, SEARCH_FIELD, LOOKUP_TYPE_MSG, ORIGINAL_INPUT] = ...
%       ndi.ontology.preprocessLookupInput(TERM_OR_ID_OR_NAME, ONTOLOGY_PREFIX)
%
%   Takes the raw input string for an ontology lookup, trims it, and determines
%   if it represents a numeric ID, a prefixed ID, or a name. Returns the
%   appropriate query string and search field for OLS search.
%   Includes special handling for OM ontology (rejects numeric, always derives label).
%
%   Inputs:
%       TERM_OR_ID_OR_NAME - The raw input (char row vector). Assumed non-empty.
%       ONTOLOGY_PREFIX    - The standard uppercase prefix for the ontology
%                            (e.g., 'CL', 'OM', 'CHEBI'). (char row vector).
%
%   Outputs:
%       SEARCH_QUERY      - The string to use as the 'q' parameter in OLS search.
%       SEARCH_FIELD      - The OLS field to search ('obo_id' or 'label').
%       LOOKUP_TYPE_MSG   - A descriptive string about the input type for errors.
%       ORIGINAL_INPUT    - The original, untrimmed input string.
%
%   Error Conditions:
%     - Throws error if input starts with prefix but invalid format follows.
%     - Throws error for OM if input is numeric/prefixed numeric.
%     - Throws error if heuristic label derivation fails for OM.
%
%   Requires:
%     - MATLAB R2019b or later (for startsWith).
%     - MATLAB's regexp function.

arguments
    term_or_id_or_name (1,:) char {mustBeNonempty}
    ontology_prefix (1,:) char {mustBeNonempty}
end

original_input = term_or_id_or_name; % Keep original
processed_input = strtrim(original_input); % Trim input
prefix_with_colon = [ontology_prefix ':'];

% --- Ontology Specific Handling ---
is_om_ontology = strcmpi(ontology_prefix, 'OM');

if is_om_ontology
    % --- Special Handling for OM ---

    % Reject purely numeric input
    if ~isempty(regexp(processed_input, '^\d+$', 'once'))
        error('ndi:ontology:preprocessLookupInput:NumericIDUnsupported_OM', ...
              'Lookup by purely numeric ID ("%s") is not supported for OM. Use term name (e.g., ''metre'', ''OM:Metre'').', original_input);
    end

    term_component = '';
    % Extract term component, checking for OM:Numeric rejection
    if startsWith(processed_input, prefix_with_colon, 'IgnoreCase', true)
        remainder = strtrim(processed_input(numel(prefix_with_colon)+1:end));
        if ~isempty(regexp(remainder, '^\d+$', 'once')) % Check if remainder is numeric - disallow
            error('ndi:ontology:preprocessLookupInput:NumericIDUnsupported_OM', ...
                  'Lookup by prefixed numeric ID ("%s") is not supported for OM. Use term name (e.g., ''metre'', ''OM:Metre'').', original_input);
        elseif isempty(remainder)
             error('ndi:ontology:preprocessLookupInput:InvalidPrefixFormat_OM', ...
                   'Input "%s" has prefix "%s" but is missing the term component.', original_input, prefix_with_colon);
        else
            term_component = remainder; % e.g., Metre, MolarVolumeUnit
        end
    else
        % No prefix, assume the whole input is the term component/name
        term_component = processed_input; % e.g., metre, MolarVolumeUnit
    end

    % Convert term component to likely label format using heuristic
    try
        likely_label = convertComponentToLabel_OMHeuristic(term_component); % Call local helper
    catch ME_regexp
         error('ndi:ontology:preprocessLookupInput:HeuristicError_OM', ...
               'Failed to convert OM term component "%s" to searchable label format. Error: %s', term_component, ME_regexp.message);
    end
    if isempty(likely_label)
         error('ndi:ontology:preprocessLookupInput:HeuristicError_OM', ...
               'Derived empty search label from OM term component "%s".', term_component);
    end

    % For OM, always search the label field with the derived label
    search_query = likely_label;
    search_field = 'label';
    lookup_type_msg = sprintf('input "%s" (searching label as "%s")', original_input, likely_label);

else
    % --- Standard Handling for Other Ontologies ---

    % Check for prefix (case-insensitive)
    if startsWith(processed_input, prefix_with_colon, 'IgnoreCase', true)
        remainder = strtrim(processed_input(numel(prefix_with_colon)+1:end));
        if ~isempty(regexp(remainder, '^\d+$', 'once')) % Numeric ID part
            numeric_id = remainder;
            search_query = [ontology_prefix ':' numeric_id]; % Use full standard ID for search
            search_field = 'obo_id';
            lookup_type_msg = sprintf('prefixed ID "%s"', original_input);
        elseif isempty(remainder)
             error('ndi:ontology:preprocessLookupInput:InvalidPrefixFormat', ...
                   'Input "%s" has prefix "%s" but is missing the term/ID component.', original_input, prefix_with_colon);
        else % Prefixed, but not numeric -> treat remainder as name/term component for label search
             search_query = remainder;
             search_field = 'label';
             lookup_type_msg = sprintf('prefixed name "%s"', original_input);
        end
    % Check if the whole input is purely numeric
    elseif ~isempty(regexp(processed_input, '^\d+$', 'once'))
        numeric_id = processed_input;
        search_query = [ontology_prefix ':' numeric_id]; % Use full standard ID for search
        search_field = 'obo_id';
        lookup_type_msg = sprintf('numeric ID "%s"', original_input);
    else
        % Not prefixed and not purely numeric -> treat as a name lookup
        search_query = processed_input;
        search_field = 'label';
        lookup_type_msg = sprintf('name "%s"', original_input);
    end

end % End if/else for OM ontology check

end % End of main function preprocessLookupInput


% --- Local Helper Function for OM Heuristic ---
function likely_label = convertComponentToLabel_OMHeuristic(comp)
    % Heuristic to convert CamelCase/PascalCase component to space-separated lowercase label
    try
        spaced = regexprep(comp,'([a-z])([A-Z])','$1 $2');
        likely_label = lower(strtrim(spaced));
    catch err
        warning('ndi:ontology:preprocessLookupInput:ConversionHelperWarning', ...
            'Error in OM heuristic for "%s": %s. Using lower(comp).', comp, err.message);
        likely_label = lower(comp); % Fallback
    end
end