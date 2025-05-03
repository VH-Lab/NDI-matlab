function [id, name, definition, synonyms] = lookup_PubChem(term_or_id_or_name)
% LOOKUP_PUBCHEM - Look up a compound in PubChem by CID or exact name.
%
%   [ID, NAME, DEFINITION, SYNONYMS] = ndi.ontology.lookup_PubChem(TERM_OR_ID_OR_NAME)
%
%   Looks up a specific compound in the PubChem database using either its
%   unique Compound ID (CID, e.g., '2244' or 'cid2244') or its exact name
%   (e.g., 'Aspirin'). Case sensitivity for names depends on the PubChem API.
%   The 'cid' prefix is case-insensitive and whitespace around it is ignored.
%
%   If a numeric CID (or 'cid' followed by a numeric ID) is provided, it
%   directly queries the PubChem PUG REST API for that compound's details
%   (name, description, synonyms).
%   If a name is provided (not matching the CID formats), it uses the PUG
%   REST API to search for CIDs matching that exact name. If exactly one CID
%   is found, its full details are retrieved. If zero or more than one CID
%   is found by name, an error is thrown.
%
%   Inputs:
%       TERM_OR_ID_OR_NAME - The CID (numeric string, e.g., '2244'),
%                            a CID with prefix (e.g., 'cid 2244'), OR the
%                            exact compound name (e.g., 'Aspirin').
%                            Provided as a character array or string.
%
%   Outputs:
%       ID           - The CID of the compound (char).
%       NAME         - The primary name (Title property) of the compound (char).
%       DEFINITION   - The first description found for the compound, if available (char).
%                      Returns empty ('') if no description is found.
%       SYNONYMS     - A cell array of character vectors listing synonyms, if available.
%                      Returns empty cell ({}) if none are found.
%
%   Error Conditions:
%     - Throws an error if input is empty, not text, or not convertible to char.
%     - Throws an error if input starts with 'cid' but is not followed by numbers.
%     - Throws an error if a CID is provided but not found via PUG REST (404).
%     - Throws an error if a name is provided but does not result in exactly one
%       CID match via PUG REST name search.
%     - Throws an error if the PUG REST API request fails (e.g., network error, server error).
%     - Throws an error if the API response (JSON) cannot be parsed as expected.
%
%   Requires:
%     - MATLAB R2019b or later (for arguments block, startsWith).
%     - Internet connection to reach the PubChem PUG REST API.
%     - MATLAB's URL encoding functions and regexp.
%
%   Example:
%     % Lookup by CID (numeric string)
%     [id1, name1, def1, syn1] = ndi.ontology.lookup_PubChem('2244');
%     % Expected (approximate): id1='2244', name1='aspirin', ...
%
%     % Lookup by CID (with prefix)
%     [id2, name2, def2, syn2] = ndi.ontology.lookup_PubChem('cid 2244');
%     % Expected (approximate): id2='2244', name2='aspirin', ...
%
%     % Lookup by exact Name
%     [id3, name3, def3, syn3] = ndi.ontology.lookup_PubChem('Aspirin');
%     % Expected (approximate): id3='2244', name3='aspirin', ...
%
%     % Example of name lookup failure (not found)
%     try
%        ndi.ontology.lookup_PubChem('NoSuchCompound');
%     catch ME
%        disp(ME.message) % Should indicate 'NoSuchCompound' not found
%     end

arguments
    % Input CID (numeric string or cid-prefixed) or exact compound name
    term_or_id_or_name (1,:) char {mustBeNonempty}
end

% --- Process Input ---
original_input = term_or_id_or_name; % Keep original for error messages
processed_input = strtrim(original_input); % Trim input
cid_to_lookup = '';
name_to_lookup = '';
is_lookup_by_cid = false;

% Check for 'cid' prefix (case-insensitive) at the beginning
if startsWith(processed_input, 'cid', 'IgnoreCase', true)
    remainder = strtrim(processed_input(4:end)); % Get part after 'cid'
    % Check if remainder is purely numeric
    if ~isempty(regexp(remainder, '^\d+$', 'once'))
        cid_to_lookup = remainder;
        is_lookup_by_cid = true;
    else
        % Starts with 'cid' but not followed by numbers - invalid format
        error('ndi:ontology:lookup_PubChem:InvalidCidPrefixFormat', ...
              'Input "%s" starts with "cid" but is not followed by a valid numeric ID.', original_input);
    end
else
    % No 'cid' prefix, check if the whole input is purely numeric
    if ~isempty(regexp(processed_input, '^\d+$', 'once'))
        cid_to_lookup = processed_input;
        is_lookup_by_cid = true;
    else
        % Not prefixed with 'cid' and not purely numeric -> treat as name
        name_to_lookup = processed_input;
        is_lookup_by_cid = false;
    end
end

% --- Proceed based on lookup type ---
if is_lookup_by_cid
    % --- Path 1: Input is a CID (prefixed or purely numeric) ---
    try
        [id, name, definition, synonyms] = performPubChemCidLookup(cid_to_lookup);
    catch ME
        % Add context using original input string
        if strcmp(ME.identifier, 'ndi:ontology:lookup_PubChem:IDNotFound')
            error('ndi:ontology:lookup_PubChem:CIDNotFound', ...
                  'PubChem compound with CID "%s" (from input "%s") not found via PUG REST API.', cid_to_lookup, original_input);
        elseif contains(ME.identifier, 'APIError') || contains(ME.identifier, 'APITimeout') || contains(ME.identifier,'InvalidResponse')
            % Pass through API/response errors from helper
            rethrow(ME)
        else % Other unexpected errors from helper
             error('ndi:ontology:lookup_PubChem:CIDLookupFailed', ...
                  'Failed to look up PubChem CID "%s" (from input "%s"). Reason: %s', cid_to_lookup, original_input, ME.message);
        end
    end
else
    % --- Path 2: Input is a Compound Name ---
    compound_name = name_to_lookup; % Use the assigned variable
    cid_from_search = '';

    % Construct Search URL for PUG REST name search
    pug_rest_base = 'https://pubchem.ncbi.nlm.nih.gov/rest/pug';
    encoded_name = urlencode(compound_name); % URL encode the name
    search_url = [pug_rest_base, '/compound/name/', encoded_name, '/cids/JSON'];

    % Set Web Options
    searchOptions = weboptions('Timeout', 30, 'ContentType', 'json', 'HeaderFields', {'Accept', 'application/json'});

    try
        % Perform PUG REST name search
        search_response = webread(search_url, searchOptions);

        % Check search results structure
        if isstruct(search_response) && isfield(search_response, 'IdentifierList') && ...
           isfield(search_response.IdentifierList, 'CID') && ~isempty(search_response.IdentifierList.CID)

            cids_found = search_response.IdentifierList.CID;
            numFound = numel(cids_found);

            if numFound == 1
                 % Exactly one match found, extract the CID
                 cid_from_search = num2str(cids_found(1)); % Ensure char
            else % numFound > 1
                 error('ndi:ontology:lookup_PubChem:NameNotUnique', ...
                      'Compound name "%s" matched multiple (%d) CIDs in PubChem. Lookup requires a unique exact match or CID.', compound_name, numFound);
            end
        else
            % Structure different or CID list empty -> Name not found
             error('ndi:ontology:lookup_PubChem:NameNotFound', ...
                   'Compound name "%s" not found or did not return CIDs via PubChem PUG REST search.', compound_name);
        end

    catch ME
        % Handle webread errors, especially 404 for name not found
        if contains(ME.identifier, 'MATLAB:webservices:HTTP') && (contains(ME.message, '404') || contains(ME.message, 'Not Found'))
            error('ndi:ontology:lookup_PubChem:NameNotFound', ...
                  'Compound name "%s" not found via PubChem PUG REST search (404 Error).', compound_name);
        elseif contains(ME.message, 'Timeout')
            error('ndi:ontology:lookup_PubChem:SearchAPITimeout', ...
                  'PubChem PUG REST name search timed out for "%s".', compound_name);
        else % Other webread errors or parsing issues
             error('ndi:ontology:lookup_PubChem:SearchAPIError', ...
                   'Failed to search for exact PubChem name "%s". PUG REST search failed: %s (URL: %s)', ...
                   compound_name, ME.message, search_url);
        end
    end

    % --- If unique match found via search, perform ID lookup using the found CID ---
    if ~isempty(cid_from_search)
        try
            % Use the dedicated ID lookup logic for consistency and full details
            [id, name, definition, synonyms] = performPubChemCidLookup(cid_from_search);
        catch ME
             % Error during the second lookup, include original name for context
             error('ndi:ontology:lookup_PubChem:PostSearchLookupFailed', ...
                   'Found unique name "%s" (CID: %s) via search, but failed subsequent detail lookup. Reason: %s', ...
                   compound_name, cid_from_search, ME.message);
        end
    else
        % Should not be reached if logic above is correct
         error('ndi:ontology:lookup_PubChem:InternalError', ...
               'Internal error after searching for name "%s". Could not proceed to final lookup.', compound_name);
    end

end % End of main if/else (CID vs Name)

end % End of main function


% --- Helper function for the actual PubChem CID Lookup via PUG REST ---
function [id, name, definition, synonyms] = performPubChemCidLookup(cid)
    % Fetches details (name, description, synonyms) for a given CID.

    % Initialize outputs
    id = ''; name = ''; definition = ''; synonyms = {};

    pug_rest_base = 'https://pubchem.ncbi.nlm.nih.gov/rest/pug';
    fetchOptions = weboptions('Timeout', 30, 'ContentType', 'json', 'HeaderFields', {'Accept', 'application/json'});
    api_error_occurred = false; % Flag to track if *any* fetch failed due to potential ID issue

    % --- Fetch Name (Title Property) ---
    name_url = [pug_rest_base, '/compound/cid/', cid, '/property/Title/JSON'];
    try
        name_response = webread(name_url, fetchOptions);
        if isstruct(name_response) && isfield(name_response, 'PropertyTable') && ...
           isfield(name_response.PropertyTable, 'Properties') && ~isempty(name_response.PropertyTable.Properties) && ...
           isfield(name_response.PropertyTable.Properties(1), 'Title')
            name = char(name_response.PropertyTable.Properties(1).Title);
        else
            name = ''; % Name not found or unexpected structure
        end
    catch ME
        warning('ndi:ontology:lookup_PubChem:NameFetchWarn', ...
                'Could not fetch or parse Title property for CID %s: %s', cid, ME.message);
        name = '';
        if contains(ME.identifier, 'MATLAB:webservices:HTTP') && contains(ME.message, '404')
            api_error_occurred = true; % 404 on name fetch suggests ID might be invalid
        end
    end

    % --- Fetch Description ---
    desc_url = [pug_rest_base, '/compound/cid/', cid, '/description/JSON'];
    try
        desc_response = webread(desc_url, fetchOptions);
        if isstruct(desc_response) && isfield(desc_response, 'InformationList') && ...
           isfield(desc_response.InformationList, 'Information') && ~isempty(desc_response.InformationList.Information) && ...
           isfield(desc_response.InformationList.Information(1), 'Description')
            definition = char(desc_response.InformationList.Information(1).Description); % Take the first
        else
            definition = '';
        end
    catch ME
        warning('ndi:ontology:lookup_PubChem:DescriptionFetchWarn', ...
                'Could not fetch or parse description for CID %s: %s', cid, ME.message);
        definition = '';
         if contains(ME.identifier, 'MATLAB:webservices:HTTP') && contains(ME.message, '404')
            api_error_occurred = true;
        end
    end

    % --- Fetch Synonyms ---
    syn_url = [pug_rest_base, '/compound/cid/', cid, '/synonyms/JSON'];
    try
        syn_response = webread(syn_url, fetchOptions);
        if isstruct(syn_response) && isfield(syn_response, 'InformationList') && ...
           isfield(syn_response.InformationList, 'Information') && ~isempty(syn_response.InformationList.Information) && ...
           isfield(syn_response.InformationList.Information(1), 'Synonym')
            syn_list_raw = syn_response.InformationList.Information(1).Synonym;
            if iscell(syn_list_raw)
                 synonyms = cellfun(@char, syn_list_raw, 'UniformOutput', false);
                 synonyms = synonyms(~cellfun('isempty', synonyms));
                 if isempty(synonyms), synonyms = {}; end
            elseif ischar(syn_list_raw) || isstring(syn_list_raw)
                 synonyms = {char(syn_list_raw)};
            else
                 synonyms = {};
            end
        else
            synonyms = {};
        end
    catch ME
        warning('ndi:ontology:lookup_PubChem:SynonymFetchWarn', ...
                'Could not fetch or parse synonyms for CID %s: %s', cid, ME.message);
        synonyms = {};
         if contains(ME.identifier, 'MATLAB:webservices:HTTP') && contains(ME.message, '404')
            api_error_occurred = true;
        end
    end

    % --- Finalize Outputs ---
    id = char(cid); % Ensure ID is char

    if isempty(name) && ~isempty(synonyms)
        name = synonyms{1}; % Use first synonym if Title failed
        warning('ndi:ontology:lookup_PubChem:NameFromSynonym', ...
                'Primary name (Title) not found for CID %s. Using first synonym "%s" as name.', cid, name);
    elseif isempty(name)
         warning('ndi:ontology:lookup_PubChem:NameNotFoundWarn', ...
                 'Could not determine primary name for CID %s.', cid);
    end

    % If any fetch resulted in a 404 or similar API error, assume the ID might be invalid.
    if api_error_occurred && isempty(name) && isempty(definition) && isempty(synonyms)
         error('ndi:ontology:lookup_PubChem:IDNotFound', ...
               'Could not retrieve any data for PubChem CID %s. It may be invalid or inaccessible.', cid);
    elseif isempty(name) && isempty(definition) && isempty(synonyms)
         % No API error detected, but no data found - maybe just lacks description/synonyms
         warning('ndi:ontology:lookup_PubChem:LookupDataMissing', ...
                 'No name, description, or synonyms could be retrieved for CID %s. Data may be unavailable.', cid);
    end

end % End of helper function performPubChemCidLookup
