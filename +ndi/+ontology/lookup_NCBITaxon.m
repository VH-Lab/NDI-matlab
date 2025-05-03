function [id, name, definition, synonyms] = lookup_NCBITaxon(term_or_id_or_name)
% LOOKUP_NCBITAXON - Look up a taxon in NCBI Taxonomy by ID or exact scientific name.
%
%   [ID, NAME, DEFINITION, SYNONYMS] = ndi.ontology.lookup_NCBITaxon(TERM_OR_ID_OR_NAME)
%
%   Looks up a specific taxon in the NCBI Taxonomy database using either its
%   unique Taxonomy ID (TaxID, e.g., '9606') or its exact scientific name
%   (e.g., 'Homo sapiens'). Case sensitivity for names depends on the NCBI API.
%
%   If a numeric TaxID is provided, it directly queries the NCBI E-utilities
%   efetch tool for that taxon record.
%   If a scientific name is provided, it uses the NCBI E-utilities esearch tool
%   to find TaxIDs matching that exact scientific name. If exactly one TaxID
%   is found, its full details are retrieved using efetch. If zero or more than
%   one TaxID is found by name, an error is thrown.
%
%   Inputs:
%       TERM_OR_ID_OR_NAME - The TaxID (numeric string, e.g., '9606') OR the
%                            exact scientific name (e.g., 'Homo sapiens').
%                            Provided as a character array or string.
%
%   Outputs:
%       ID           - The TaxID of the taxon (char).
%       NAME         - The scientific name of the taxon (char).
%       DEFINITION   - Always empty ('') for NCBI Taxonomy lookups, as standard
%                      definitions are not typically part of the core record.
%       SYNONYMS     - A cell array of character vectors listing common names
%                      and other alternative names found, if available.
%                      Returns empty cell ({}) if none are found.
%
%   Error Conditions:
%     - Throws an error if input is empty, not text, or not convertible to char.
%     - Throws an error if a TaxID is provided but not found via efetch (e.g., invalid ID).
%     - Throws an error if a name is provided but does not result in exactly one
%       match for '[Scientific Name]' via esearch.
%     - Throws an error if the NCBI E-utilities API request fails (e.g., network error, server error).
%     - Throws an error if the API response (XML) cannot be parsed as expected.
%
%   Requires:
%     - MATLAB R2019b or later (for arguments block).
%     - Internet connection to reach the NCBI E-utilities API.
%     - MATLAB's URL encoding functions and regexp.
%
%   Example:
%     % Lookup by TaxID
%     [id1, name1, def1, syn1] = ndi.ontology.lookup_NCBITaxon('9606');
%     % Expected (approximate): id1='9606', name1='Homo sapiens', def1='', syn1={'human', ...}
%
%     % Lookup by exact Scientific Name
%     [id2, name2, def2, syn2] = ndi.ontology.lookup_NCBITaxon('Homo sapiens');
%     % Expected (approximate): id2='9606', name2='Homo sapiens', def2='', syn2={'human', ...}
%
%     % Example of name lookup failure (not unique or not found)
%     try
%        ndi.ontology.lookup_NCBITaxon('cellular organisms'); % Not specific enough
%     catch ME
%        disp(ME.message)
%     end

arguments
    % Input TaxID (numeric string) or exact scientific name
    term_or_id_or_name (1,:) char {mustBeNonempty}
end

% Check if the input is purely numeric (a TaxID)
isNumericID = ~isempty(regexp(term_or_id_or_name, '^\d+$', 'once'));

if isNumericID
    % --- Path 1: Input looks like a TaxID ---
    taxid = term_or_id_or_name;
    try
        [id, name, definition, synonyms] = performNcbiTaxonIdLookup(taxid);
    catch ME
        % Add context if the error is specific to ID lookup failure
        if strcmp(ME.identifier, 'ndi:ontology:lookup_NCBITaxon:IDNotFound') % Specific error from helper
             error('ndi:ontology:lookup_NCBITaxon:TaxIDNotFound', ...
                   'NCBI Taxon with TaxID "%s" not found via E-utilities efetch.', taxid);
        elseif contains(ME.identifier, 'APIError') || contains(ME.identifier, 'APITimeout') || contains(ME.identifier,'InvalidResponse')
             % Pass through API/response errors from helper
             rethrow(ME)
        else % Other unexpected errors from helper
             error('ndi:ontology:lookup_NCBITaxon:TaxIDLookupFailed', ...
                   'Failed to look up NCBI TaxID "%s". Reason: %s', taxid, ME.message);
        end
    end
else
    % --- Path 2: Input is potentially a Scientific Name ---
    scientific_name = term_or_id_or_name;
    taxid_from_search = '';

    % Construct Search URL for E-utilities esearch
    eutils_base = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/';
    esearch_script = 'esearch.fcgi';
    db = 'taxonomy';
    % Construct the search term for exact scientific name match
    search_term = [scientific_name '[Scientific Name]'];
    encoded_term = urlencode(search_term);
    search_url = [eutils_base, esearch_script, '?db=', db, '&term=', encoded_term, '&retmode=xml'];

    % Set Web Options
    searchOptions = weboptions('Timeout', 30); % ContentType defaults usually ok for XML

    try
        % Perform E-utilities search
        xml_response = webread(search_url, searchOptions);

        % Parse XML response to find TaxIDs using regexp
        % Look for content within <Id>...</Id> tags inside <IdList>
        id_matches = regexp(xml_response, '<IdList>.*?<Id>(\d+)</Id>.*?</IdList>', 'tokens');

        % Check search results
        if ~isempty(id_matches)
             numFound = numel(id_matches); % Each cell in id_matches contains one ID match

             if numFound == 1
                 % Exactly one match found, extract the TaxID
                 taxid_from_search = id_matches{1}{1}; % First match, first token
             else % numFound > 1
                 error('ndi:ontology:lookup_NCBITaxon:NameNotUnique', ...
                      'Scientific name "%s" matched multiple (%d) TaxIDs. Lookup requires a unique exact match or TaxID.', scientific_name, numFound);
             end
        else
             % No <Id> found in <IdList> - check for error messages or assume not found
             if contains(xml_response, '<ErrorList>') || contains(xml_response, '<PhraseNotFound>')
                 error('ndi:ontology:lookup_NCBITaxon:NameNotFound', ...
                       'Scientific name "%s" not found in NCBI Taxonomy via E-utilities esearch.', scientific_name);
             elseif contains(xml_response, '<Count>0</Count>')
                 error('ndi:ontology:lookup_NCBITaxon:NameNotFound', ...
                       'Scientific name "%s" not found in NCBI Taxonomy via E-utilities esearch (Count=0).', scientific_name);
             else
                 % Unexpected response format if no IDs and no clear error
                 error('ndi:ontology:lookup_NCBITaxon:InvalidSearchResponse', ...
                       'Received an unexpected or empty search response from E-utilities esearch for name "%s".', scientific_name);
             end
        end

    catch ME
        % Handle webread or parsing errors
         error('ndi:ontology:lookup_NCBITaxon:SearchAPIError', ...
               'Failed to search for exact NCBI Taxonomy name "%s". E-utilities esearch failed: %s (URL: %s)', ...
               scientific_name, ME.message, search_url);
    end

    % --- If unique match found via search, perform ID lookup using the found TaxID ---
    if ~isempty(taxid_from_search)
        try
            % Use the dedicated ID lookup logic for consistency and full details
            [id, name, definition, synonyms] = performNcbiTaxonIdLookup(taxid_from_search);
        catch ME
             % Error during the second lookup (should be rare if search found it)
             error('ndi:ontology:lookup_NCBITaxon:PostSearchLookupFailed', ...
                   'Found unique name "%s" (TaxID: %s) via search, but failed subsequent detail lookup. Reason: %s', ...
                   scientific_name, taxid_from_search, ME.message);
        end
    else
        % This part should not be reached if logic above is correct
         error('ndi:ontology:lookup_NCBITaxon:InternalError', ...
               'Internal error after searching for name "%s". Could not proceed to final lookup.', scientific_name);
    end

end % End of main if/else (Numeric vs Name)

end % End of main function


% --- Helper function for the actual NCBI Taxonomy ID Lookup via efetch ---
function [id, name, definition, synonyms] = performNcbiTaxonIdLookup(taxid)
    % This function fetches and parses the record for a given TaxID.

    % Initialize outputs
    id = ''; name = ''; definition = ''; synonyms = {};

    % Construct API URL for E-utilities efetch
    eutils_base = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/';
    efetch_script = 'efetch.fcgi';
    db = 'taxonomy';
    fetch_url = [eutils_base, efetch_script, '?db=', db, '&id=', taxid, '&retmode=xml'];

    % Set Web Options
    fetchOptions = weboptions('Timeout', 30);

    try
        % Send the API request
        xml_response = webread(fetch_url, fetchOptions);

        % Check for basic error indicators in response
        if contains(xml_response, '<Error>') || isempty(xml_response) || ~contains(xml_response, '<Taxon>')
             % Could be an invalid ID or other API error
             error('ndi:ontology:lookup_NCBITaxon:IDNotFound', 'No valid Taxon record found or error returned by efetch for TaxID "%s".', taxid);
        end

        % --- Extract Information using Regular Expressions ---
        % ID (confirm TaxId matches input)
        id_match = regexp(xml_response, '<TaxId>(\d+)</TaxId>', 'tokens', 'once');
        if ~isempty(id_match)
            id = id_match{1};
            if ~strcmp(id, taxid)
                warning('ndi:ontology:lookup_NCBITaxon:IDMismatch', 'Returned TaxID "%s" does not match queried TaxID "%s". Using queried ID.', id, taxid);
                id = taxid; % Use the one we queried with
            end
        else
            id = taxid; % Fallback if tag not found, though unlikely if <Taxon> exists
        end

        % Name (Scientific Name)
        name_match = regexp(xml_response, '<ScientificName>(.*?)</ScientificName>', 'tokens', 'once');
        if ~isempty(name_match)
            name = name_match{1};
        else
            name = ''; % Should generally exist if record is valid
        end

        % Definition (Set to empty as per function spec)
        definition = '';

        % Synonyms (Combine Common Names and Other Names)
        syn_list = {};
        % Common Names
        common_name_matches = regexp(xml_response, '<CommonName>(.*?)</CommonName>', 'tokens');
        if ~isempty(common_name_matches)
            syn_list = [syn_list; cellfun(@(x) x{1}, common_name_matches, 'UniformOutput', false)];
        end
        % Other Names (look for <Name> within <OtherNames><DispName> structure)
        other_name_matches = regexp(xml_response, '<OtherNames>.*?<Name>.*?<DispName>(.*?)</DispName>.*?</Name>.*?</OtherNames>', 'tokens');
         if ~isempty(other_name_matches)
             % This regex might capture multiple OtherNames blocks; flatten the cell array of cell arrays
             all_other_names = {};
             for k=1:length(other_name_matches)
                 % Extract DispName within each OtherNames block found
                 disp_names_in_block = regexp(other_name_matches{k}{1}, '<DispName>(.*?)</DispName>', 'tokens');
                 if ~isempty(disp_names_in_block)
                    all_other_names = [all_other_names; cellfun(@(x) x{1}, disp_names_in_block(:), 'UniformOutput', false)];
                 end
             end
             syn_list = [syn_list; all_other_names];
         end

        % Alternative regex for Other Names (simpler, might miss some structure)
        % other_name_matches = regexp(xml_response, '<DispName>(.*?)</DispName>', 'tokens');
        % if ~isempty(other_name_matches)
        %    syn_list = [syn_list; cellfun(@(x) x{1}, other_name_matches, 'UniformOutput', false)];
        % end


        % Remove duplicates and ensure cell array
        if ~isempty(syn_list)
            synonyms = unique(syn_list, 'stable'); % Keep original order roughly
            % Filter out empty strings if any crept in
            synonyms = synonyms(~cellfun('isempty', synonyms));
             if isempty(synonyms)
                 synonyms = {}; % Ensure empty cell if all were empty
             end
        else
            synonyms = {};
        end


    catch ME
        % Handle webread or parsing errors
        % Add specific error IDs based on the context
        if strcmp(ME.identifier, 'ndi:ontology:lookup_NCBITaxon:IDNotFound')
            rethrow(ME); % Rethrow the specific error from above check
        else
            error('ndi:ontology:lookup_NCBITaxon:FetchAPIError', ...
                  'Failed to fetch or parse NCBI Taxonomy record for TaxID "%s". E-utilities efetch failed: %s (URL: %s)', ...
                  taxid, ME.message, fetch_url);
        end
    end
end % End of helper function performNcbiTaxonIdLookup


