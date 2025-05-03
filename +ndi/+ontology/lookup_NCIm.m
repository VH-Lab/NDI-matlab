% Location: +ndi/+ontology/lookup_NCIm.m
% Corrected parsing of EVS search response

function [id, name, definition, synonyms] = lookup_NCIm(term_or_id_or_name)
% LOOKUP_NCIM - Look up a term in NCI Metathesaurus by CUI or exact name.
%
%   [ID, NAME, DEFINITION, SYNONYMS] = ndi.ontology.lookup_NCIm(TERM_OR_ID_OR_NAME)
%
%   Looks up a specific concept in the NCI Metathesaurus (NCIm) using either
%   its Concept Unique Identifier (CUI, e.g., 'C0018787') or its exact
%   primary name (e.g., 'Heart').
%
%   If a CUI (matching format C#######) is provided, it directly queries the
%   NCI EVS REST API for that concept.
%   If a name is provided, it searches the EVS API for a unique concept with
%   that exact name within the NCIm terminology. If exactly one match is found,
%   its details are retrieved using its CUI. If zero or more than one exact
%   match is found by name, an error is thrown.
%
%   Inputs:
%       TERM_OR_ID_OR_NAME - The CUI (e.g., 'C0018787') OR the exact term name
%                            (e.g., 'Heart'). Case sensitivity for names may
%                            depend on the API's 'match' behavior.
%                            Provided as a character array or string.
%
%   Outputs:
%       ID           - The CUI of the concept (char).
%       NAME         - The preferred name of the concept (char).
%       DEFINITION   - The first definition found for the concept, if available (char).
%                      Returns empty ('') if no definition is found.
%       SYNONYMS     - A cell array of character vectors listing synonyms, if available.
%                      Returns empty cell ({}) if no synonyms are found.
%
%   Error Conditions:
%     - Throws an error if input is empty, not text, or not convertible to char.
%     - Throws an error if a CUI is provided but not found via EVS API (404).
%     - Throws an error if a name is provided but does not result in exactly one
%       exact match ('type=match') in NCIm via EVS API search.
%     - Throws an error if the EVS API request fails (e.g., network error, server error).
%     - Throws an error if the API response structure is unexpected.
%
%   Requires:
%     - MATLAB R2019b or later (for arguments block).
%     - Internet connection to reach the NCI EVS REST API.
%
%   Example:
%     % Lookup by CUI
%     [id1, name1, def1, syn1] = ndi.ontology.lookup_NCIm('C0018787');
%     % Expected (approximate): id1='C0018787', name1='Heart', ...
%
%     % Lookup by exact Name
%     [id2, name2, def2, syn2] = ndi.ontology.lookup_NCIm('Heart');
%     % Expected (approximate): id2='C0018787', name2='Heart', ...
%
%     % Example of name lookup failure (not unique or not found)
%     try
%        ndi.ontology.lookup_NCIm('Blood Cell'); % May not be unique exact match
%     catch ME
%        disp(ME.message)
%     end

arguments
    % Input CUI or exact term name
    term_or_id_or_name (1,:) char {mustBeNonempty}
end

% Define the regex pattern for a typical CUI
cui_pattern = '^C\d{7}$';

% Check if the input matches the CUI pattern
isCUI = ~isempty(regexp(term_or_id_or_name, cui_pattern, 'once'));

if isCUI
    % --- Path 1: Input looks like a CUI ---
    cui = term_or_id_or_name;
    try
        [id, name, definition, synonyms] = performNcimIdLookup(cui);
    catch ME
        % Add context if the error is specific to ID lookup failure
        if strcmp(ME.identifier, 'ndi:ontology:lookup_NCIm:IDNotFound') % Specific error from helper
             error('ndi:ontology:lookup_NCIm:CUINotFound', ...
                   'NCIm concept with CUI "%s" not found via EVS API.', cui);
        elseif contains(ME.identifier, 'APIError') || contains(ME.identifier, 'APITimeout') || contains(ME.identifier,'InvalidResponse')
             % Pass through API/response errors from helper
             rethrow(ME)
        else % Other unexpected errors from helper
             error('ndi:ontology:lookup_NCIm:CUILookupFailed', ...
                   'Failed to look up NCIm CUI "%s". Reason: %s', cui, ME.message);
        end
    end
else
    % --- Path 2: Input is potentially a Term Name ---
    term_name = term_or_id_or_name;
    cui_from_search = '';

    % Construct Search URL
    evs_search_url = 'https://api-evsrest.nci.nih.gov/api/v1/concept/search';
    terminology = 'ncim';

    % Set Web Options
    searchOptions = weboptions('ContentType', 'json', 'Timeout', 30, 'HeaderFields', {'Accept', 'application/json'});

    try
        % Perform exact search ('type=match')
        search_response = webread(evs_search_url, ...
            'term', term_name, ...
            'terminology', terminology, ...
            'type', 'match', ...       % Use 'match' for exact matching
            'include', 'minimal', ... % Only need CUI and maybe name from search
            searchOptions);

        % *** Corrected Search Result Parsing Logic Starts Here ***
        if isstruct(search_response) && isfield(search_response, 'total') % Check for expected fields

            numFound = search_response.total; % Use the 'total' field provided by the API

            if numFound == 1
                % Check if the concepts array exists, is a struct, and has one element
                if isfield(search_response, 'concepts') && isstruct(search_response.concepts) && numel(search_response.concepts) == 1
                    concept = search_response.concepts(1); % Access the concept struct

                    % Now check for the 'code' field within this concept struct
                    if isfield(concept, 'code') && ~isempty(concept.code)
                        % Validate CUI format found
                        if ~isempty(regexp(concept.code, cui_pattern, 'once'))
                            cui_from_search = char(concept.code);
                        else
                            error('ndi:ontology:lookup_NCIm:UnexpectedIDFormat',...
                                  'Found unique term "%s", but its Code "%s" from search has an unexpected format.', term_name, concept.code);
                        end
                    else
                         % This error means 'code' field was missing INSIDE the found concept struct
                        error('ndi:ontology:lookup_NCIm:MissingIDInSearchResult',...
                              'Found unique term "%s", but could not extract its Code (CUI) from the EVS concept data structure.', term_name);
                    end
                else
                     % This error means the API reported total=1 but the concepts array was missing/empty/wrong size
                     error('ndi:ontology:lookup_NCIm:ConceptDataMismatch',...
                           'API reported 1 result for "%s", but the "concepts" data array is missing or invalid.', term_name);
                end
            elseif numFound == 0
                error('ndi:ontology:lookup_NCIm:NameNotFound', ...
                      'Term "%s" not found as an exact match in NCIm (total=0).', term_name);
            else % numFound > 1
                error('ndi:ontology:lookup_NCIm:NameNotUnique', ...
                      'Term "%s" resulted in multiple (%d) exact matches in NCIm. Lookup requires a unique match or CUI.', term_name, numFound);
            end
        else
            % search_response wasn't a struct or didn't have 'total' field
            error('ndi:ontology:lookup_NCIm:InvalidSearchResponse', ...
                  'Received an invalid or unexpected search response structure from the EVS API for term "%s".', term_name);
        end
        % *** Corrected Search Result Parsing Logic Ends Here ***

    catch ME
        % Handle specific webread errors if possible, otherwise general error
        if contains(ME.message, '400') % Bad Request often means invalid parameters
            error('ndi:ontology:lookup_NCIm:SearchAPIError', ...
                  'Failed to search for exact NCIm term "%s". EVS API search failed (possibly invalid request): %s', ...
                  term_name, ME.message);
        else % Other errors (timeout, network, 500, etc.)
             error('ndi:ontology:lookup_NCIm:SearchAPIError', ...
                   'Failed to search for exact NCIm term "%s". EVS API search failed: %s', ...
                   term_name, ME.message);
        end
    end

    % --- If unique match found via search, perform ID lookup using the found CUI ---
    if ~isempty(cui_from_search)
        try
            % Use the dedicated ID lookup logic for consistency and full details
            [id, name, definition, synonyms] = performNcimIdLookup(cui_from_search);
        catch ME
             % Error during the second lookup (should be rare if search found it)
             error('ndi:ontology:lookup_NCIm:PostSearchLookupFailed', ...
                   'Found unique term "%s" (CUI: %s) via search, but failed subsequent detail lookup. Reason: %s', ...
                   term_name, cui_from_search, ME.message);
        end
    else
        % This part should not be reached if logic above is correct
         error('ndi:ontology:lookup_NCIm:InternalError', ...
               'Internal error after searching for term "%s". Could not proceed to final lookup.', term_name);
    end

end % End of main if/else (CUI vs Term Name)

end % End of main function


% --- Helper function for the actual NCIm CUI Lookup ---
function [id, name, definition, synonyms] = performNcimIdLookup(cui)
    % This contains the logic previously in lookup_NCIm for CUI lookup

    % Initialize outputs
    id = ''; name = ''; definition = ''; synonyms = {};

    % Construct API URL
    base_url = 'https://api-evsrest.nci.nih.gov/api/v1/concept/ncim/';
    encoded_cui = urlencode(cui); % Should not be necessary for CUIs, but safe
    url = [base_url encoded_cui '?include=full']; % Request full details

    % Set Web Options
    options = weboptions('ContentType', 'json', 'Timeout', 30, 'HeaderFields', {'Accept', 'application/json'});

    try
        % Send the API request
        data = webread(url, options);

        % Extract Information
        if ~isstruct(data) || isempty(fieldnames(data))
            error('ndi:ontology:lookup_NCIm:InvalidResponse', 'Received invalid response from EVS Concept API for CUI "%s".', cui);
        end

        % ID
        if isfield(data, 'code') && ~isempty(data.code), id = char(data.code); else, id = cui; end % Fallback
        % Check consistency
        if ~strcmp(id, cui)
            warning('ndi:ontology:lookup_NCIm:IDMismatch', 'Returned code "%s" does not match queried CUI "%s". Using queried CUI.', id, cui);
            id = cui;
        end

        % Name
        if isfield(data, 'name') && ~isempty(data.name), name = char(data.name); else, name = ''; end

        % Definition
        if isfield(data, 'definitions') && isstruct(data.definitions) && ~isempty(data.definitions)
            if isfield(data.definitions(1), 'definition') && ~isempty(data.definitions(1).definition)
                definition = char(data.definitions(1).definition); % Take first
            else, definition = ''; end
        else, definition = ''; end

        % Synonyms
        if isfield(data, 'synonyms') && isstruct(data.synonyms) && ~isempty(data.synonyms)
            if isfield(data.synonyms(1), 'name')
                syn_names = arrayfun(@(x) char(x.name), data.synonyms, 'UniformOutput', false);
                synonyms = syn_names(~cellfun('isempty', syn_names));
                if isempty(synonyms), synonyms = {}; end
            else, synonyms = {}; end
        else, synonyms = {}; end

    catch ME
        % Handle errors during webread
        if contains(ME.message, 'Timeout')
             error('ndi:ontology:lookup_NCIm:APITimeout', 'EVS Concept API timeout for CUI "%s".', cui);
        elseif contains(ME.message, '404') || contains(ME.message, 'Not Found')
             % Specific CUI not found
             error('ndi:ontology:lookup_NCIm:IDNotFound', 'EVS Concept API 404 Not Found for CUI "%s".', cui);
        else
             % General API error
             error('ndi:ontology:lookup_NCIm:APIError', 'EVS Concept API request failed for CUI "%s": %s', cui, ME.message);
        end
    end
end % End of helper function performNcimIdLookup