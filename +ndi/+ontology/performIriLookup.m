function [id, name, definition, synonyms] = performIriLookup(term_iri, ontology_name_ols, ontology_prefix)
%PERFORMIRILOOKUP Fetches ontology term details from EBI OLS using its IRI.
%
%   [ID, NAME, DEFINITION, SYNONYMS] = ndi.ontology.performIriLookup(TERM_IRI, ...
%                                       ONTOLOGY_NAME_OLS, ONTOLOGY_PREFIX)
%
%   Looks up a specific ontology term using its full IRI via the EBI OLS API
%   /terms endpoint. This function is designed to be called by higher-level
%   lookup functions after they have identified the unique IRI for a term.
%
%   Inputs:
%       TERM_IRI          - The full IRI of the term to look up (e.g.,
%                           'http://purl.obolibrary.org/obo/CL_0000000'). (char/string)
%       ONTOLOGY_NAME_OLS - The lowercase ontology identifier used in the OLS API
%                           URL (e.g., 'cl', 'om', 'chebi', 'uberon'). (char/string)
%       ONTOLOGY_PREFIX   - The standard prefix used for constructing the output ID
%                           (e.g., 'CL', 'OM', 'CHEBI', 'UBERON'). (char/string)
%
%   Outputs:
%       ID           - The standard prefixed ID (e.g., 'CL:0000000'). Extracted or constructed.
%       NAME         - The primary label of the term (char).
%       DEFINITION   - The first text definition found for the term, if available (char).
%       SYNONYMS     - A cell array of character vectors listing synonyms (from obo_synonym),
%                      if available. Empty cell ({}) if none are found.
%
%   Error Conditions:
%     - Throws errors for IRI encoding failures, API timeouts, 404 Not Found,
%       other API errors, invalid/empty responses, or failure to extract a valid ID.
%
%   Requires:
%     - MATLAB R2019b or later.
%     - Internet connection to reach the EBI OLS API.
%     - MATLAB's URL encoding functions.

arguments
    term_iri (1,:) char {mustBeNonempty}
    ontology_name_ols (1,:) char {mustBeNonempty}
    ontology_prefix (1,:) char {mustBeNonempty}
end

% Initialize outputs
id = ''; name = ''; definition = ''; synonyms = {};

% --- Double URL Encode the IRI for OLS API ---
try
    encoded_iri_once = urlencode(term_iri);
    encoded_iri_twice = urlencode(encoded_iri_once);
catch ME_encode
    error('ndi:ontology:performIriLookup:EncodingError', ...
          'Failed to URL encode IRI "%s": %s', term_iri, ME_encode.message);
end

% --- Construct API URL ---
ols_base_url = 'https://www.ebi.ac.uk/ols4/api/ontologies/'; % Changed ols to ols4
url = [ols_base_url ontology_name_ols '/terms/' encoded_iri_twice];

% --- Set Web Options ---
options = weboptions('ContentType', 'json', 'Timeout', 30, 'HeaderFields', {'Accept', 'application/json'});

try
    % Send the API request
    data = webread(url, options);

    % --- Extract Information from Response Data ---
    if ~isstruct(data) || isempty(fieldnames(data))
         error('ndi:ontology:performIriLookup:InvalidResponse', ...
               'Received an invalid or empty response structure from the OLS Term API for ontology "%s", IRI "%s".', ...
               ontology_name_ols, term_iri);
    end

    % ID (Attempt to extract/validate using obo_id or short_form)
    if isfield(data, 'obo_id') && ~isempty(data.obo_id) && startsWith(data.obo_id, [ontology_prefix ':'], 'IgnoreCase', true)
        id = char(data.obo_id);
    elseif isfield(data, 'short_form') && ~isempty(data.short_form)
         id_temp = char(data.short_form); % e.g., CL_0000000 or OM_182
         expected_prefix_us = [ontology_prefix '_']; % e.g., CL_
         % Check if it starts with the expected prefix and underscore
         if startsWith(id_temp, expected_prefix_us, 'IgnoreCase', true)
              id = strrep(id_temp, '_', ':'); % Convert to standard format
         else
              % Maybe it's just the numeric part? Or already correct?
              if ~isempty(regexp(id_temp,'^\d+$','once')) % Just numbers
                 id = [ontology_prefix ':' id_temp];
              elseif startsWith(id_temp, [ontology_prefix ':'], 'IgnoreCase', true) % Already correct
                 id = id_temp;
              else
                 id = ''; % Cannot determine ID
              end
         end
    else
        id = ''; % Cannot determine ID from response
    end

    % If ID extraction failed, issue a warning or error
    if isempty(id)
        warning('ndi:ontology:performIriLookup:IDExtractionFailed', ...
                'Could not extract a valid ID (e.g., %s:123) from OLS response for ontology "%s", IRI "%s". Returning empty ID.', ...
                ontology_prefix, ontology_name_ols, term_iri);
        % Or make it an error:
        % error('ndi:ontology:performIriLookup:IDExtractionFailedFinal', ...
        %       'Failed to determine the prefixed ID (e.g., %s:123) from the OLS response for ontology "%s", IRI "%s".', ...
        %       ontology_prefix, ontology_name_ols, term_iri);
    end

    % Name (Label)
    if isfield(data, 'label') && ~isempty(data.label)
        name = char(data.label);
    else
         warning('ndi:ontology:performIriLookup:MissingField', ...
                 'Field "label" not found in OLS API response for ontology "%s", IRI "%s".', ontology_name_ols, term_iri);
        name = '';
    end

    % Definition (Take the first non-empty one from 'description' cell array)
    if isfield(data, 'description') && ~isempty(data.description) && iscell(data.description)
        non_empty_defs = data.description(~cellfun('isempty', data.description));
        if ~isempty(non_empty_defs)
            definition = char(non_empty_defs{1});
        else
            definition = '';
        end
    else
        definition = '';
    end

    % Synonyms (Extract 'name' from 'obo_synonym' struct array if available)
    % Note: OLS sometimes uses 'label' instead of 'name' inside obo_synonym
    synonyms = {}; % Initialize as empty cell
    if isfield(data, 'obo_synonym') && ~isempty(data.obo_synonym) && isstruct(data.obo_synonym)
        syn_field_name = '';
        if isfield(data.obo_synonym(1), 'name')
            syn_field_name = 'name';
        elseif isfield(data.obo_synonym(1), 'label') % Fallback check
             syn_field_name = 'label';
        end

        if ~isempty(syn_field_name)
            syn_names = arrayfun(@(x) char(x.(syn_field_name)), data.obo_synonym, 'UniformOutput', false);
            synonyms = syn_names(~cellfun('isempty', syn_names)); % Filter empty
            if isempty(synonyms), synonyms = {}; end % Ensure empty cell
        end
    end


catch ME
    % Handle errors during the webread call or parsing
    if contains(ME.message, 'Timeout')
         error('ndi:ontology:performIriLookup:APITimeout', ...
              'OLS Term API request timed out while looking up IRI "%s" in ontology "%s". (URL: %s)', ...
              term_iri, ontology_name_ols, url);
    elseif contains(ME.identifier, 'MATLAB:webservices:HTTP') && (contains(ME.message, '404') || contains(ME.message, 'Not Found'))
         % This specific IRI was not found
         error('ndi:ontology:performIriLookup:IRINotFound', ...
               'IRI "%s" not found via OLS Term API for ontology "%s" (404 Error). (URL: %s)', ...
               term_iri, ontology_name_ols, url);
    elseif strcmp(ME.identifier, 'ndi:ontology:performIriLookup:EncodingError') ...
        || strcmp(ME.identifier, 'ndi:ontology:performIriLookup:InvalidResponse') ...
        || strcmp(ME.identifier, 'ndi:ontology:performIriLookup:IDExtractionFailedFinal') % If changed from warning
        % Rethrow errors generated within this function
         rethrow(ME);
    else % General API or parsing error
         error('ndi:ontology:performIriLookup:APIError', ...
               'Failed to look up IRI "%s" in ontology "%s". OLS Term API request failed: %s (URL: %s)', ...
               term_iri, ontology_name_ols, ME.message, url);
    end
end

end % End of function performIriLookup
