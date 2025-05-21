% Location: +ndi/+ontology/PubChem.m
classdef PubChem < ndi.ontology
% PUBCHEM - NDI Ontology object for the PubChem database.
%   Inherits from ndi.ontology and implements lookupTermOrID for PubChem.

    methods
        function obj = PubChem()
            % PUBCHEM - Constructor for the PubChem ontology object.
            % Implicitly calls the superclass constructor ndi.ontology().
        end % constructor

        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name)
            % LOOKUPTERMORID - Looks up a compound in PubChem by CID or exact name.
            %
            %   [ID, NAME, DEFINITION, SYNONYMS] = lookupTermOrID(OBJ, TERM_OR_ID_OR_NAME)
            %
            %   Overrides the base class method to provide specific lookup
            %   functionality for PubChem using the PUG REST API.
            %
            %   The input TERM_OR_ID_OR_NAME is the part of the original lookup string
            %   after the 'PubChem:' prefix has been removed (e.g., '2244', 'Aspirin', 'cid 2244').
            %
            %   See also: ndi.ontology.lookup (static dispatcher)

            % --- Process Input ---
            original_input_remainder = term_or_id_or_name; % Keep original for error messages
            processed_input = strtrim(original_input_remainder);
            cid_to_lookup = '';
            name_to_lookup = '';
            is_lookup_by_cid = false;

            % Check for 'cid' prefix (case-insensitive) at the beginning of the remainder
            if startsWith(processed_input, 'cid', 'IgnoreCase', true)
                remainder_after_cid = strtrim(processed_input(4:end)); % Get part after 'cid'
                % Check if remainder is purely numeric
                if ~isempty(regexp(remainder_after_cid, '^\d+$', 'once'))
                    cid_to_lookup = remainder_after_cid;
                    is_lookup_by_cid = true;
                else
                    % Starts with 'cid' but not followed by numbers - invalid format
                    error('ndi:ontology:PubChem:InvalidCidPrefixFormat', ...
                          'Input remainder "%s" starts with "cid" but is not followed by a valid numeric ID.', original_input_remainder);
                end
            else
                % No 'cid' prefix, check if the whole remainder is purely numeric
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
                    % Call private static helper within this class
                    [id, name, definition, synonyms] = ndi.ontology.PubChem.performPubChemCidLookup(cid_to_lookup);
                catch ME
                    % Add context using original input remainder
                    if strcmp(ME.identifier, 'ndi:ontology:lookup_PubChem:IDNotFound')
                        error('ndi:ontology:PubChem:CIDNotFound', ...
                              'PubChem compound with CID "%s" (from input "%s") not found via PUG REST API.', cid_to_lookup, original_input_remainder);
                    else % Other unexpected errors from helper re-wrap
                         baseME = MException('ndi:ontology:PubChem:CIDLookupFailed', ...
                              'Failed to look up PubChem CID "%s" (from input "%s").', cid_to_lookup, original_input_remainder);
                         baseME = addCause(baseME, ME);
                         throw(baseME);
                    end
                end
            else
                % --- Path 2: Input is a Compound Name ---
                compound_name = name_to_lookup;
                cid_from_search = '';

                % Construct Search URL
                pug_rest_base = 'https://pubchem.ncbi.nlm.nih.gov/rest/pug';
                encoded_name = urlencode(compound_name);
                search_url = [pug_rest_base, '/compound/name/', encoded_name, '/cids/JSON'];
                searchOptions = weboptions('Timeout', 30, 'ContentType', 'json', 'HeaderFields', {'Accept', 'application/json'});

                try
                    % Perform PUG REST name search
                    search_response = webread(search_url, searchOptions);

                    % Check search results
                    if isstruct(search_response) && isfield(search_response, 'IdentifierList') && ...
                       isfield(search_response.IdentifierList, 'CID') && ~isempty(search_response.IdentifierList.CID)
                        cids_found = search_response.IdentifierList.CID;
                        numFound = numel(cids_found);
                        if numFound == 1
                             cid_from_search = num2str(cids_found(1)); % Ensure char
                        else % numFound > 1
                             error('ndi:ontology:PubChem:NameNotUnique', ...
                                  'Name "%s" matched multiple (%d) CIDs. Requires unique exact match or CID.', compound_name, numFound);
                        end
                    else
                         error('ndi:ontology:PubChem:NameNotFound', ...
                               'Name "%s" not found or did not return CIDs via PUG REST search.', compound_name);
                    end
                catch ME
                    if contains(ME.identifier, 'MATLAB:webservices:HTTP') && (contains(ME.message, '404') || contains(ME.message, 'Not Found'))
                        error('ndi:ontology:PubChem:NameNotFound', ...
                              'Name "%s" not found via PUG REST search (404 Error).', compound_name);
                    elseif contains(ME.message, 'Timeout')
                        error('ndi:ontology:PubChem:SearchAPITimeout', ...
                              'PUG REST name search timed out for "%s".', compound_name);
                    else
                         error('ndi:ontology:PubChem:SearchAPIError', ...
                               'Failed PUG REST search for "%s": %s', compound_name, ME.message);
                    end
                end

                % --- If unique match found, perform ID lookup ---
                if isempty(cid_from_search)
                     error('ndi:ontology:PubChem:InternalError','Could not determine CID for "%s".', compound_name);
                end

                try
                    % Call private static helper within this class
                    [id, name, definition, synonyms] = ndi.ontology.PubChem.performPubChemCidLookup(cid_from_search);
                catch ME
                     baseME = MException('ndi:ontology:PubChem:PostSearchLookupFailed',...
                           'Lookup failed for CID %s found via search for "%s".', cid_from_search, compound_name);
                     baseME = addCause(baseME, ME);
                     throw(baseME);
                end
            end % End if/else (is_lookup_by_cid vs Name)

        end % function lookupTermOrID

    end % methods

    methods (Static, Access = private)
        % --- Helper function for the actual PubChem CID Lookup via PUG REST ---
         function [id, name, definition, synonyms] = performPubChemCidLookup(cid)
            % PERFORMPUBCHEMCIDLOOKUP - Helper to fetch PubChem details by CID.
             arguments, cid (1,:) char {mustBeNonempty}, end
             id = ''; name = ''; definition = ''; synonyms = {}; pug_rest_base = 'https://pubchem.ncbi.nlm.nih.gov/rest/pug'; fetchOptions = weboptions('Timeout', 30, 'ContentType', 'json', 'HeaderFields', {'Accept', 'application/json'}); api_error_occurred = false; name_url = [pug_rest_base, '/compound/cid/', cid, '/property/Title/JSON'];
             try, name_response = webread(name_url, fetchOptions); if isstruct(name_response) && isfield(name_response, 'PropertyTable') && isfield(name_response.PropertyTable, 'Properties') && ~isempty(name_response.PropertyTable.Properties) && isfield(name_response.PropertyTable.Properties(1), 'Title'), name = char(name_response.PropertyTable.Properties(1).Title); else, name = ''; end; catch ME, warning('ndi:ontology:lookup_PubChem:NameFetchWarn','Could not fetch Title for CID %s: %s', cid, ME.message); name = ''; if contains(ME.identifier, 'MATLAB:webservices:HTTP') && contains(ME.message, '404'), api_error_occurred = true; end; end
             desc_url = [pug_rest_base, '/compound/cid/', cid, '/description/JSON'];
             try, desc_response = webread(desc_url, fetchOptions); if isstruct(desc_response) && isfield(desc_response, 'InformationList') && isfield(desc_response.InformationList, 'Information') && ~isempty(desc_response.InformationList.Information) && isfield(desc_response.InformationList.Information(1), 'Description'), definition = char(desc_response.InformationList.Information(1).Description); else, definition = ''; end; catch ME, warning('ndi:ontology:lookup_PubChem:DescriptionFetchWarn','Could not fetch description for CID %s: %s', cid, ME.message); definition = ''; if contains(ME.identifier, 'MATLAB:webservices:HTTP') && contains(ME.message, '404'), api_error_occurred = true; end; end
             syn_url = [pug_rest_base, '/compound/cid/', cid, '/synonyms/JSON'];
             try, syn_response = webread(syn_url, fetchOptions); if isstruct(syn_response) && isfield(syn_response, 'InformationList') && isfield(syn_response.InformationList, 'Information') && ~isempty(syn_response.InformationList.Information) && isfield(syn_response.InformationList.Information(1), 'Synonym'), syn_list_raw = syn_response.InformationList.Information(1).Synonym; if iscell(syn_list_raw), synonyms = cellfun(@char, syn_list_raw, 'UniformOutput', false); synonyms = synonyms(~cellfun('isempty', synonyms)); if isempty(synonyms), synonyms = {}; end; elseif ischar(syn_list_raw) || isstring(syn_list_raw), synonyms = {char(syn_list_raw)}; else, synonyms = {}; end; else, synonyms = {}; end; catch ME, warning('ndi:ontology:lookup_PubChem:SynonymFetchWarn','Could not fetch synonyms for CID %s: %s', cid, ME.message); synonyms = {}; if contains(ME.identifier, 'MATLAB:webservices:HTTP') && contains(ME.message, '404'), api_error_occurred = true; end; end
             id = char(cid); if isempty(name) && ~isempty(synonyms), name = synonyms{1}; warning('ndi:ontology:lookup_PubChem:NameFromSynonym','Title not found for CID %s. Using first synonym "%s".', cid, name); elseif isempty(name), warning('ndi:ontology:lookup_PubChem:NameNotFoundWarn','Could not determine name for CID %s.', cid); end
             if api_error_occurred && isempty(name) && isempty(definition) && isempty(synonyms), error('ndi:ontology:lookup_PubChem:IDNotFound', 'Could not retrieve any data for PubChem CID %s.', cid); elseif isempty(name) && isempty(definition) && isempty(synonyms), warning('ndi:ontology:lookup_PubChem:LookupDataMissing','No name, description, or synonyms found for CID %s.', cid); end
         end

    end % methods (Static, Access = private)

end % classdef PubChem