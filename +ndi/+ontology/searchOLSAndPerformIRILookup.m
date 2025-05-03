function [id, name, definition, synonyms] = searchOLSAndPerformIRILookup(search_query, search_field, ontology_name_ols, ontology_prefix, lookup_type_msg)
%SEARCHOLSANDPERFORMIRILOOKUP Searches OLS and looks up unique result by IRI.
%
%   [ID, NAME, DEFINITION, SYNONYMS] = ndi.ontology.searchOLSAndPerformIRILookup(...
%           SEARCH_QUERY, SEARCH_FIELD, ONTOLOGY_NAME_OLS, ONTOLOGY_PREFIX, LOOKUP_TYPE_MSG)
%
%   Performs a search on the EBI OLS API using the provided query and
%   field. If searching by 'obo_id', an exact match is required. If searching
%   by 'label', an exact match is NOT strictly enforced by the API query due
%   to observed inconsistencies, but the function verifies if exactly one
%   result is returned AND its label matches the query case-insensitively.
%   If a unique valid match is found, it extracts the term's IRI and calls
%   ndi.ontology.performIriLookup to retrieve the full details.
%
%   Inputs:
%       SEARCH_QUERY      - The query string for OLS search 'q' parameter.
%       SEARCH_FIELD      - The OLS field to search ('obo_id' or 'label').
%       ONTOLOGY_NAME_OLS - Lowercase OLS ontology ID (e.g., 'cl', 'om').
%       ONTOLOGY_PREFIX   - Standard uppercase prefix (e.g., 'CL', 'OM').
%       LOOKUP_TYPE_MSG   - Description of the original input type for errors.
%
%   Outputs:
%       ID           - The standard prefixed ID (e.g., 'CL:0000000').
%       NAME         - The term label.
%       DEFINITION   - The first term definition.
%       SYNONYMS     - Cell array of synonyms.
%
%   Error Conditions:
%     - Throws errors if search fails, does not find exactly one valid match,
%       or if the subsequent IRI lookup fails.
%
%   Requires:
%     - MATLAB R2019b or later.
%     - Internet connection to reach the EBI OLS API.
%     - MATLAB's webread function.
%     - ndi.ontology.performIriLookup function.

arguments
    search_query (1,:) char {mustBeNonempty}
    search_field (1,:) char {mustBeMember(search_field, {'obo_id','label'})}
    ontology_name_ols (1,:) char {mustBeNonempty}
    ontology_prefix (1,:) char {mustBeNonempty}
    lookup_type_msg (1,:) char % Allow empty for internal calls if needed
end

term_iri = ''; % Initialize IRI

% --- Perform OLS Search ---
ols_search_url = 'https://www.ebi.ac.uk/ols/api/search';
searchOptions = weboptions('ContentType', 'json', 'Timeout', 30, 'HeaderFields', {'Accept', 'application/json'});

% Construct base parameters for webread
params = {'q', search_query, 'ontology', ontology_name_ols, 'queryFields', search_field};

% Add 'exact' parameter ONLY if searching by ID, not by label
% Omit exact=true for label searches due to observed OLS inconsistencies (e.g., with OM)
if strcmp(search_field, 'obo_id')
    params = [params, {'exact', 'true'}];
end

try
    % Perform search
    search_response = webread(ols_search_url, params{:}, searchOptions); % Pass params as name-value pairs

    % Check search results
    if isfield(search_response, 'response') && isfield(search_response.response, 'numFound')
        numFound = search_response.response.numFound;

        if numFound == 1
            doc = search_response.response.docs(1);

            % ** Additional check for label search **
            % If we searched by label (non-exact query), verify the single result's label matches case-insensitively
            if strcmp(search_field,'label')
                 if ~(isfield(doc,'label') && strcmpi(doc.label, search_query))
                      % Found one result, but its label doesn't match the query case-insensitively
                      label_found = '[Label Missing]';
                      if isfield(doc,'label'), label_found = doc.label; end
                      error('ndi:ontology:searchOLSAndPerformIRILookup:MismatchOnSingleResult',...
                            'Search for name "%s" returned a single result, but its label ("%s") does not exactly match (case-insensitive).', ...
                            search_query, label_found);
                 end
            end
            % ** End additional check **

            % Extract IRI if label match (or ID match) is confirmed
            if isfield(doc, 'iri') && ~isempty(doc.iri)
                term_iri = char(doc.iri);
            else
                 error('ndi:ontology:searchOLSAndPerformIRILookup:MissingIRIInSearchResult',...
                       'Found unique valid term matching %s, but could not extract its IRI from OLS search results.', lookup_type_msg);
            end

        elseif numFound == 0
             error('ndi:ontology:searchOLSAndPerformIRILookup:NotFound', ...
                  'Term matching %s not found in "%s" ontology via OLS search.', lookup_type_msg, ontology_name_ols);

        else % numFound > 1
             % If search was by label (non-exact), try to find unique exact match manually among results
             if strcmp(search_field, 'label')
                 docs_array = search_response.response.docs;
                 % Find indices where label matches query case-insensitively
                 match_indices = find(arrayfun(@(x) isfield(x,'label') && strcmpi(x.label, search_query), docs_array));

                 if numel(match_indices) == 1
                     % Found exactly one document with case-insensitive label match
                     doc = docs_array(match_indices);
                     if isfield(doc, 'iri') && ~isempty(doc.iri)
                          term_iri = char(doc.iri);
                     else
                           error('ndi:ontology:searchOLSAndPerformIRILookup:MissingIRIInSearchResult',...
                                 'Found unique name matching %s among multiple results, but could not extract its IRI.', lookup_type_msg);
                     end
                 elseif numel(match_indices) == 0
                      error('ndi:ontology:searchOLSAndPerformIRILookup:NotFound', ... % No exact match found among multiple results
                           'Term matching %s not found as an exact match (case-insensitive) among %d results in "%s" ontology via OLS search.', lookup_type_msg, numFound, ontology_name_ols);
                 else % numel(match_indices) > 1
                      error('ndi:ontology:searchOLSAndPerformIRILookup:NotUnique', ... % Multiple exact matches found
                          'Term matching %s resulted in multiple (%d) exact matches (case-insensitive) in "%s" ontology. Lookup requires a unique match.', lookup_type_msg, numel(match_indices), ontology_name_ols);
                 end
             else % If search was by obo_id and numFound > 1 (should not happen with exact=true)
                 error('ndi:ontology:searchOLSAndPerformIRILookup:NotUnique', ...
                      'Term matching %s resulted in multiple (%d) exact matches in "%s" ontology. Lookup requires a unique match.', lookup_type_msg, numFound, ontology_name_ols);
             end
        end % End numFound check

    else % Invalid response structure
        error('ndi:ontology:searchOLSAndPerformIRILookup:InvalidSearchResponse', ...
              'Received an invalid or incomplete search response structure from the OLS API when searching for %s in "%s".', lookup_type_msg, ontology_name_ols);
    end

catch ME
    % Handle webread errors
    if contains(ME.message, 'Timeout')
        error('ndi:ontology:searchOLSAndPerformIRILookup:SearchAPITimeout', ...
              'OLS API search timed out while searching for %s in "%s".', lookup_type_msg, ontology_name_ols);
    else % Other webread errors or parsing issues
         error('ndi:ontology:searchOLSAndPerformIRILookup:SearchAPIError', ...
               'Failed to search for exact term matching %s in "%s". OLS API search failed: %s', ...
               lookup_type_msg, ontology_name_ols, ME.message);
    end
end

% --- Perform IRI Lookup ---
if ~isempty(term_iri)
    try
        % Call the reusable IRI lookup function
        [id, name, definition, synonyms] = ndi.ontology.performIriLookup(term_iri, ontology_name_ols, ontology_prefix);
    catch ME
         % Catch errors specifically from performIriLookup and add context
         original_cause = ME.cause;
         base_msg = sprintf('Failed IRI lookup for term identified by %s (IRI: %s).', lookup_type_msg, term_iri);
         detail_msg = ME.message;
         if ~isempty(original_cause) && iscell(original_cause) && ~isempty(original_cause{1})
              detail_msg = original_cause{1}.message;
         end
         % Rethrow with combined message and original identifier if possible
         newME = MException(sprintf('ndi:ontology:searchOLSAndPerformIRILookup:PostSearchLookupFailed:%s', ME.identifier), ...
                            '%s Reason: %s', base_msg, detail_msg);
         if ~isempty(ME.cause)
             newME = addCause(newME, ME); % Preserve cause if possible
         end
         throw(newME);
    end
else
     % Error must have been thrown already if IRI is empty after search logic
     % This line is defensive coding / should not be reached.
     error('ndi:ontology:searchOLSAndPerformIRILookup:InternalError', ...
           'Internal error after searching for %s. Could not proceed to final IRI lookup.', lookup_type_msg);
end

end % End of function searchOLSAndPerformIRILookup