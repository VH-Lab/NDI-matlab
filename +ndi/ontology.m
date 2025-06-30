% Location: +ndi/ontology.m
classdef ontology
% ONTOLOGY - Base class for NDI ontology objects and lookup operations.
%
%   Provides static methods for ontology lookups and data management,
%   and defines the interface for specific ontology subclass lookups.
%
%   Usage:
%   ------
%   Typically, users interact with the static lookup method:
%   [id, name, prefix, def, syn] = ndi.ontology.lookup('PREFIX:TermOrID');
%
%   This static method determines the correct ontology subclass based on PREFIX,
%   instantiates it, and calls the specific lookupTermOrID method implemented
%   by that subclass.
%
%   Caching:
%   --------
%   For efficiency, this class caches the contents of the main ontology
%   list JSON file ('ontology_list.json') in persistent memory after the
%   first time it's accessed within a MATLAB session. The NDIC lookup
%   function ('ndi.ontology.lookup_NDIC') separately caches its data file.
%
%   To force the system to re-read the ontology list JSON file and the
%   NDIC ontology file from disk (e.g., if they have been updated),
%   use the static clearCache method:
%
%       ndi.ontology.clearCache();
%
%   Alternatively, using MATLAB's 'clear classes' or 'clear functions'
%   commands will also clear this persistent data, but will affect more
%   than just this cache.
%

% Note: Uses persistent variables within static methods for caching.

properties (Constant, Hidden)
    ONTOLOGY_FILENAME = 'ontology_list.json';
    ONTOLOGY_SUBFOLDER_JSON = 'ontology'; % Subfolder for JSON relative to CommonFolder
    ONTOLOGY_SUBFOLDER_NDIC = 'controlled_vocabulary'; % Subfolder for NDIC.txt
    NDIC_FILENAME = 'NDIC.txt';
end

methods
    function obj = ontology()
        % ONTOLOGY - Constructor for the base ontology class.
        % Does not require arguments. Intended primarily for subclassing.
    end

    function [id, name, definition, synonyms, shortName] = lookupTermOrID(obj, term_or_id_or_name)
        % LOOKUPTERMORID - Base implementation for looking up a term within a specific ontology instance.
        %
        %   [ID, NAME, DEFINITION, SYNONYMS, SHORTNAME] = lookupTermOrID(OBJ, TERM_OR_ID_OR_NAME)
        %
        %   This base class method should be overridden by specific ontology subclasses
        %   (e.g., ndi.ontology.CL, ndi.ontology.OM). It defines the standard interface
        %   for ontology-specific lookups after the prefix has been removed.
        %
        %   The TERM_OR_ID_OR_NAME input here is the 'remainder' after the
        %   prefix has been stripped by the main static ndi.ontology.lookup function
        %   (e.g., '0000000' for CL, 'metre' for OM, 'C0018787' for NCIm).
        %
        %   This base implementation returns empty values and issues a warning.
        %
        warning('ndi:ontology:ontology:BaseMethodCalled', ...
            'lookupTermOrID called on the base ndi.ontology class for input "%s". Subclass should override this method. Returning empty.', ...
            term_or_id_or_name);
        id = '';
        name = '';
        definition = '';
        synonyms = {};
        shortName = '';
    end

end % methods

methods (Static)

    % --------------------------------------------------------------------
    % Main Static Lookup Function (Dispatcher)
    % --------------------------------------------------------------------
    function [id, name, prefix, definition, synonyms, shortName] = lookup(lookupString)
        % LOOKUP - Look up a term in an ontology using a prefixed string.
        %
        %   [ID, NAME, PREFIX, DEFINITION, SYNONYMS, SHORTNAME] = ndi.ontology.lookup(LOOKUPSTRING)
        %
        %   Looks up a term using a prefixed string (e.g., 'CL:0000000', 'OM:metre').
        %   It identifies the ontology from the prefix using the mappings in
        %   'ontology_list.json', instantiates the specific ndi.ontology.ONTOLOGYNAME
        %   class (e.g., ndi.ontology.CL), and calls its lookupTermOrID instance method,
        %   passing the remainder of the string (after the prefix).
        %
        %   Outputs:
        %     ID           - The canonical identifier for the term.
        %     NAME         - The primary name or label for the term.
        %     PREFIX       - The ontology prefix used in the lookup.
        %     DEFINITION   - A textual definition, if available.
        %     SYNONYMS     - A cell array of synonyms, if available.
        %     SHORTNAME    - The short name for the term.
        %
        %   Examples:
        %       % Lookup neuron in Cell Ontology by ID
        %       [id, name, prefix] = ndi.ontology.lookup('CL:0000540');
        %       % Expected: id='CL:0000540', name='neuron', prefix='CL'
        %
        %       % Lookup ethanol in ChEBI by ID
        %       [id, name, prefix] = ndi.ontology.lookup('CHEBI:16236');
        %       % Expected: id='CHEBI:16236', name='ethanol', prefix='CHEBI'
        %
        %       % Lookup Heart in NCI Metathesaurus by CUI
        %       [id, name, prefix, def] = ndi.ontology.lookup('NCIm:C0018787');
        %       % Expected: id='C0018787', name='Heart', prefix='NCIm', def contains definition
        %
        %       % Lookup Aspirin in PubChem by name
        %       [id, name, prefix] = ndi.ontology.lookup('PubChem:Aspirin');
        %       % Expected: id='2244', name='aspirin', prefix='PubChem'
        %
        %       % Lookup Homo sapiens using alternative taxonomy prefix
        %       [id, name, prefix] = ndi.ontology.lookup('taxonomy:9606');
        %       % Expected: id='9606', name='Homo sapiens', prefix='taxonomy'
        %
        %       % Example of a failed lookup (non-existent term)
        %       try
        %           ndi.ontology.lookup('CL:NoSuchTerm');
        %       catch ME
        %           disp(ME.identifier); % e.g., 'ndi:ontology:lookup_CL:NotFound' or similar
        %           disp(ME.message);
        %       end
        %
        %   See also: ndi.ontology.lookupTermOrID (instance method to be overridden)

        % Initialize outputs
        id = ''; name = ''; prefix = ''; definition = ''; synonyms = {}; shortName = '';

        % 1. Get Ontology Name and Remainder from Prefix
        try
            [ontologyName, remainder] = ndi.ontology.getOntologyNameFromPrefix(lookupString);
            if isempty(ontologyName)
                error('ndi:ontology:lookup:PrefixMappingFailed', ...
                    'Failed to map prefix from "%s" to a known ontology name.', lookupString);
            end
        catch ME
             baseME = MException('ndi:ontology:lookup:PrefixError', ...
                 'Error processing prefix for input "%s".', lookupString);
             baseME = addCause(baseME, ME);
             throw(baseME);
        end

        % 2. Extract Prefix (for output)
        colonPos = strfind(lookupString, ':');
        if isempty(colonPos)
             error('ndi:ontology:lookup:MissingColon', ...
                   'Input string "%s" lacks the required "prefix:term" format for lookup.', lookupString);
        else
            prefix = strtrim(lookupString(1:colonPos(1)-1));
        end

        % 3. Construct Specific Class Name
        className = ['ndi.ontology.' ontologyName];

        % 4. Instantiate Specific Ontology Object
        try
            ontologyObj = feval(className); % Call constructor (must take 0 args)
        catch ME_inst
             baseME = MException('ndi:ontology:lookup:InstantiationError', ...
                 'Failed to instantiate ontology class "%s". Check constructor.', className);
             baseME = addCause(baseME, ME_inst);
             throw(baseME);
        end

        % 5. Call the Instance Method lookupTermOrID
        try
            [id, name, definition, synonyms] = lookupTermOrID(ontologyObj, remainder);
        catch ME_lookup
            baseME = MException('ndi:ontology:lookup:SpecificLookupError', ...
                'Error occurred during lookupTermOrID call for class "%s" with input remainder "%s".', className, remainder);
            baseME = addCause(baseME, ME_lookup_4);
            throw(baseME);
        end

        % 6. Creat shortName (valid MATLAB variable name)
        shortName = ndi.fun.name2variableName(name);

        % 7. Return results

    end % function lookup

    % --------------------------------------------------------------------
    % Static Helper Functions (Moved from namespace)
    % --------------------------------------------------------------------

    function [id, name, definition, synonyms] = performIriLookup(term_iri, ontology_name_ols, ontology_prefix)
        %PERFORMIRILOOKUP Fetches ontology term details from EBI OLS using its IRI.
        %   Used by OLS-based lookup implementations (CL, OM, CHEBI, UBERON).
        %   [...] = ndi.ontology.performIriLookup(...)
        arguments
            term_iri (1,:) char {mustBeNonempty}
            ontology_name_ols (1,:) char {mustBeNonempty}
            ontology_prefix (1,:) char {mustBeNonempty}
        end
        id = ''; name = ''; definition = ''; synonyms = {};
        try
            encoded_iri_once = urlencode(term_iri);
            encoded_iri_twice = urlencode(encoded_iri_once);
        catch ME_encode
            error('ndi:ontology:performIriLookup:EncodingError', 'Failed to URL encode IRI "%s": %s', term_iri, ME_encode.message);
        end
        ols_base_url = 'https://www.ebi.ac.uk/ols4/api/ontologies/'; % Use ols4
        url = [ols_base_url ontology_name_ols '/terms/' encoded_iri_twice];
        options = weboptions('ContentType', 'json', 'Timeout', 30, 'HeaderFields', {'Accept', 'application/json'});
        try
            data = webread(url, options);
            if ~isstruct(data) || isempty(fieldnames(data))
                 error('ndi:ontology:performIriLookup:InvalidResponse', 'Received invalid/empty response from OLS Term API for ontology "%s", IRI "%s".', ontology_name_ols, term_iri);
            end
            if isfield(data, 'obo_id') && ~isempty(data.obo_id) && startsWith(data.obo_id, [ontology_prefix ':'], 'IgnoreCase', true), id = char(data.obo_id);
            elseif isfield(data, 'short_form') && ~isempty(data.short_form), id_temp = char(data.short_form); expected_prefix_us = [ontology_prefix '_']; if startsWith(id_temp, expected_prefix_us, 'IgnoreCase', true), id = strrep(id_temp, '_', ':'); else, if ~isempty(regexp(id_temp,'^\d+$','once')), id = [ontology_prefix ':' id_temp]; elseif startsWith(id_temp, [ontology_prefix ':'], 'IgnoreCase', true), id = id_temp; else, id = ''; end; end
            else, id = ''; end
            if isempty(id), warning('ndi:ontology:performIriLookup:IDExtractionFailed', 'Could not extract valid ID (e.g., %s:123) from OLS response for ontology "%s", IRI "%s".', ontology_prefix, ontology_name_ols, term_iri); end
            if isfield(data, 'label') && ~isempty(data.label), name = char(data.label); else, name = ''; end
             if isempty(name), warning('ndi:ontology:performIriLookup:MissingField', 'Field "label" not found/empty for ontology "%s", IRI "%s".', ontology_name_ols, term_iri); end
            if isfield(data, 'description') && ~isempty(data.description) && iscell(data.description), non_empty_defs = data.description(~cellfun('isempty', data.description)); if ~isempty(non_empty_defs), definition = char(non_empty_defs{1}); else, definition = ''; end; else, definition = ''; end
            synonyms = {};
            if isfield(data, 'obo_synonym') && ~isempty(data.obo_synonym) && isstruct(data.obo_synonym), syn_field_name = ''; if isfield(data.obo_synonym(1), 'name'), syn_field_name = 'name'; elseif isfield(data.obo_synonym(1), 'label'), syn_field_name = 'label'; end; if ~isempty(syn_field_name), syn_names = arrayfun(@(x) char(x.(syn_field_name)), data.obo_synonym, 'UniformOutput', false); synonyms = syn_names(~cellfun('isempty', syn_names)); if isempty(synonyms), synonyms = {}; end; end; end
        catch ME
            if contains(ME.message, 'Timeout'), error('ndi:ontology:performIriLookup:APITimeout', 'OLS Term API timeout for IRI "%s", ontology "%s".', term_iri, ontology_name_ols);
            elseif contains(ME.identifier, 'MATLAB:webservices:HTTP') && (contains(ME.message, '404') || contains(ME.message, 'Not Found')), error('ndi:ontology:performIriLookup:IRINotFound', 'IRI "%s" not found via OLS Term API for ontology "%s" (404 Error).', term_iri, ontology_name_ols);
            elseif ismember(ME.identifier, {'ndi:ontology:performIriLookup:EncodingError', 'ndi:ontology:performIriLookup:InvalidResponse'}), rethrow(ME);
            else, error('ndi:ontology:performIriLookup:APIError', 'OLS Term API request failed for IRI "%s", ontology "%s": %s', term_iri, ontology_name_ols, ME.message); end
        end
    end % function performIriLookup

    function [search_query, search_field, lookup_type_msg, original_input] = preprocessLookupInput(term_or_id_or_name, ontology_prefix)
        %PREPROCESSLOOKUPINPUT Processes input for ontology lookup functions.
        %   Handles standard prefix/ID/name logic and OM-specific heuristic.
        %   [...] = ndi.ontology.preprocessLookupInput(...)
        arguments
            term_or_id_or_name (1,:) char {mustBeNonempty}
            ontology_prefix (1,:) char {mustBeNonempty}
        end
        original_input = term_or_id_or_name; processed_input = strtrim(original_input); prefix_with_colon = [ontology_prefix ':']; is_om_ontology = strcmpi(ontology_prefix, 'OM');
        if is_om_ontology % --- Special Handling for OM ---
            if ~isempty(regexp(processed_input, '^\d+$', 'once')), error('ndi:ontology:preprocessLookupInput:NumericIDUnsupported_OM', 'Lookup by purely numeric ID ("%s") is not supported for OM.', original_input); end
            term_component = '';
            if startsWith(processed_input, prefix_with_colon, 'IgnoreCase', true), remainder = strtrim(processed_input(numel(prefix_with_colon)+1:end)); if ~isempty(regexp(remainder, '^\d+$', 'once')), error('ndi:ontology:preprocessLookupInput:NumericIDUnsupported_OM', 'Lookup by prefixed numeric ID ("%s") is not supported for OM.', original_input); elseif isempty(remainder), error('ndi:ontology:preprocessLookupInput:InvalidPrefixFormat_OM', 'Input "%s" has prefix "%s" but is missing term component.', original_input, prefix_with_colon); else, term_component = remainder; end
            else, term_component = processed_input; end
            try likely_label = ndi.ontology.convertComponentToLabel_OMHeuristic(term_component); catch ME_regexp, error('ndi:ontology:preprocessLookupInput:HeuristicError_OM', 'Failed to convert OM term component "%s" to label format: %s', term_component, ME_regexp.message); end
            if isempty(likely_label), error('ndi:ontology:preprocessLookupInput:HeuristicError_OM', 'Derived empty search label from OM term component "%s".', term_component); end
            search_query = likely_label; search_field = 'label'; lookup_type_msg = sprintf('input "%s" (searching label as "%s")', original_input, likely_label);
        else % --- Standard Handling ---
            if startsWith(processed_input, prefix_with_colon, 'IgnoreCase', true), remainder = strtrim(processed_input(numel(prefix_with_colon)+1:end)); if ~isempty(regexp(remainder, '^\d+$', 'once')), numeric_id = remainder; search_query = [ontology_prefix ':' numeric_id]; search_field = 'obo_id'; lookup_type_msg = sprintf('prefixed ID "%s"', original_input); elseif isempty(remainder), error('ndi:ontology:preprocessLookupInput:InvalidPrefixFormat', 'Input "%s" has prefix "%s" but is missing term/ID.', original_input, prefix_with_colon); else, search_query = remainder; search_field = 'label'; lookup_type_msg = sprintf('prefixed name "%s"', original_input); end
            elseif ~isempty(regexp(processed_input, '^\d+$', 'once')), numeric_id = processed_input; search_query = [ontology_prefix ':' numeric_id]; search_field = 'obo_id'; lookup_type_msg = sprintf('numeric ID "%s"', original_input);
            else, search_query = processed_input; search_field = 'label'; lookup_type_msg = sprintf('name "%s"', original_input); end
        end
    end % function preprocessLookupInput

    function [id, name, definition, synonyms] = searchOLSAndPerformIRILookup(search_query, search_field, ontology_name_ols, ontology_prefix, lookup_type_msg)
        %SEARCHOLSANDPERFORMIRILOOKUP Searches OLS and looks up unique result by IRI.
        %   Handles specific logic for non-exact label searches (needed for OM).
        %   [...] = ndi.ontology.searchOLSAndPerformIRILookup(...)
         arguments
            search_query (1,:) char {mustBeNonempty}
            search_field (1,:) char {mustBeMember(search_field, {'obo_id','label'})}
            ontology_name_ols (1,:) char {mustBeNonempty}
            ontology_prefix (1,:) char {mustBeNonempty}
            lookup_type_msg (1,:) char
        end
        term_iri = '';
        ols_search_url = 'https://www.ebi.ac.uk/ols4/api/search'; % Use ols4
        searchOptions = weboptions('ContentType', 'json', 'Timeout', 30, 'HeaderFields', {'Accept', 'application/json'});
        params = {'q', search_query, 'ontology', ontology_name_ols, 'queryFields', search_field};
        if strcmp(search_field, 'obo_id'), params = [params, {'exact', 'true'}]; end % Only exact for ID search
        try
            search_response = webread(ols_search_url, params{:}, searchOptions);
            if isfield(search_response, 'response') && isfield(search_response.response, 'numFound')
                numFound = search_response.response.numFound;
                if numFound == 1, doc = search_response.response.docs(1); if strcmp(search_field,'label'), if ~(isfield(doc,'label') && strcmpi(doc.label, search_query)), label_found = '[Label Missing]'; if isfield(doc,'label'), label_found = doc.label; end; error('ndi:ontology:searchOLSAndPerformIRILookup:MismatchOnSingleResult','Search for name "%s" returned single result with non-matching label ("%s").', search_query, label_found); end; end; if isfield(doc, 'iri') && ~isempty(doc.iri), term_iri = char(doc.iri); else, error('ndi:ontology:searchOLSAndPerformIRILookup:MissingIRIInSearchResult','Found unique term for %s, but could not extract IRI.', lookup_type_msg); end
                elseif numFound == 0, error('ndi:ontology:searchOLSAndPerformIRILookup:NotFound', 'Term matching %s not found in "%s" via OLS search.', lookup_type_msg, ontology_name_ols);
                else % numFound > 1
                     if strcmp(search_field, 'label'), docs_array = search_response.response.docs; match_indices = find(arrayfun(@(x) isfield(x,'label') && strcmpi(x.label, search_query), docs_array)); if numel(match_indices) == 1, doc = docs_array(match_indices); if isfield(doc, 'iri') && ~isempty(doc.iri), term_iri = char(doc.iri); else, error('ndi:ontology:searchOLSAndPerformIRILookup:MissingIRIInSearchResult','Found unique name for %s among multiple results, but could not extract IRI.', lookup_type_msg); end; elseif numel(match_indices) == 0, error('ndi:ontology:searchOLSAndPerformIRILookup:NotFound', 'No exact (case-insensitive) label match for "%s" found among %d results in "%s".', search_query, numFound, ontology_name_ols); else, error('ndi:ontology:searchOLSAndPerformIRILookup:NotUnique', 'Term matching %s resulted in %d exact matches (case-insensitive) in "%s". Requires unique match.', lookup_type_msg, numel(match_indices), ontology_name_ols); end
                     else, error('ndi:ontology:searchOLSAndPerformIRILookup:NotUnique', 'Term matching %s yielded %d results in "%s" (expected 1 for ID search).', lookup_type_msg, numFound, ontology_name_ols); end
                end
            else, error('ndi:ontology:searchOLSAndPerformIRILookup:InvalidSearchResponse', 'Invalid search response structure from OLS for %s in "%s".', lookup_type_msg, ontology_name_ols); end
        catch ME
            if contains(ME.message, 'Timeout'), error('ndi:ontology:searchOLSAndPerformIRILookup:SearchAPITimeout', 'OLS API search timed out for %s in "%s".', lookup_type_msg, ontology_name_ols);
            else, baseME = MException('ndi:ontology:searchOLSAndPerformIRILookup:SearchAPIError', 'OLS API search failed for %s in "%s".', lookup_type_msg, ontology_name_ols); baseME = addCause(baseME, ME); throw(baseME); end
        end
        % --- Perform IRI Lookup ---
        if ~isempty(term_iri)
            try [id, name, definition, synonyms] = ndi.ontology.performIriLookup(term_iri, ontology_name_ols, ontology_prefix);
            catch ME, baseME = MException('ndi:ontology:searchOLSAndPerformIRILookup:PostSearchLookupFailed', 'IRI lookup failed following search for %s (IRI: %s).', lookup_type_msg, term_iri); baseME = addCause(baseME, ME); throw(baseME); end
        else, error('ndi:ontology:searchOLSAndPerformIRILookup:InternalError', 'Could not determine unique IRI after search for %s.', lookup_type_msg); end
    end % function searchOLSAndPerformIRILookup


    function [ontologyName, remainder] = getOntologyNameFromPrefix(ontologyString)
        % GETONTOLOGYNAMEFROMPREFIX - Extracts prefix, maps to ontology name (case-insensitive).
        %   [...] = ndi.ontology.getOntologyNameFromPrefix(...)
         arguments
            ontologyString (1,:) char {mustBeNonempty}
         end
         ontologyName = ''; remainder = ''; prefix = '';
         colonPos = strfind(ontologyString, ':');
         if isempty(colonPos), prefix = strtrim(ontologyString); remainder = ''; else, firstColonPos = colonPos(1); prefix = strtrim(ontologyString(1:firstColonPos-1)); if firstColonPos == length(ontologyString), remainder = ''; else, remainder = strtrim(ontologyString(firstColonPos+1:end)); end; end
         if isempty(prefix), error('GETONTOLOGYNAMEFROMPREFIX:InvalidInputFormat', 'Could not extract prefix from "%s".', ontologyString); end
         ontologyData = ndi.ontology.loadOntologyJSONData_();
         foundMapping = false; ontologyName = '';
         if isfield(ontologyData, 'prefix_ontology_mappings') && isa(ontologyData.prefix_ontology_mappings, 'struct') && ~isempty(ontologyData.prefix_ontology_mappings)
            mappings = ontologyData.prefix_ontology_mappings;
            for i = 1:numel(mappings)
                if isfield(mappings(i), 'prefix') && strcmpi(mappings(i).prefix, prefix) % Case-insensitive
                    if isfield(mappings(i), 'ontology_name') && ~isempty(mappings(i).ontology_name), ontologyName = char(mappings(i).ontology_name); else, warning('GETONTOLOGYNAMEFROMPREFIX:MappingIncomplete', 'Prefix "%s" found but ontology_name is empty.', prefix); end
                    foundMapping = true; break;
                end
            end
         else, error('GETONTOLOGYNAMEFROMPREFIX:InvalidJSONStructure', 'JSON file lacks valid prefix_ontology_mappings.'); end
         if ~foundMapping, error('GETONTOLOGYNAMEFROMPREFIX:PrefixNotFound', 'Prefix "%s" not found in ontology mappings file.', prefix); end
         remainder = char(remainder);
    end % function getOntologyNameFromPrefix

    % --- Static Getters for Cached JSON Data ---
    function mappings = getPrefixOntologyMappings()
        % GETPREFIXONTOLOGYMAPPINGS - Returns the prefix->ontology mappings from JSON cache.
        data = ndi.ontology.loadOntologyJSONData_();
        if isfield(data,'prefix_ontology_mappings') && isstruct(data.prefix_ontology_mappings) && ~isempty(data.prefix_ontology_mappings)
           mappings = data.prefix_ontology_mappings;
        else
            error('ndi:ontology:ontology:MappingNotFound', 'Could not retrieve "prefix_ontology_mappings" from cached ontology data.');
        end
    end % function getPrefixOntologyMappings

    function [id, name, definition, synonyms] = lookupOBOFile(oboFilePath, ontologyPrefix, term_to_lookup_fragment)
        % LOOKUPOBOFILE - Looks up a term in a parsed OBO file.
        %   [ID, NAME, DEFINITION, SYNONYMS] = ndi.ontology.lookupOBOFile(...
        %       OBOFILEPATH, ONTOLOGYPREFIX, TERM_TO_LOOKUP_FRAGMENT)
        %
        %   Parses an OBO file (if not already cached) and searches for a term.
        %   TERM_TO_LOOKUP_FRAGMENT is the part of the term after the prefix
        %   (e.g., '0000001' or 'some term name').
        %
        %   The function caches the parsed OBO data to speed up subsequent lookups
        %   for the same file within a MATLAB session. Call ndi.ontology.clearCache()
        %   or 'clear functions' to clear this cache.
        %
        %   Outputs:
        %       ID         - The full term ID (e.g., 'EMPTY:0000001').
        %       NAME       - The term's primary name.
        %       DEFINITION - The term's definition.
        %       SYNONYMS   - A cell array of synonym strings (currently basic,
        %                    not parsing synonym types).
        %
        %   Throws:
        %       ndi:ontology:lookupOBOFile:FileNotFound
        %       ndi:ontology:lookupOBOFile:ParsingError
        %       ndi:ontology:lookupOBOFile:InvalidInput
        %       ndi:ontology:lookupOBOFile:TermNotFound

        arguments
            oboFilePath (1,:) char {mustBeNonempty}
            ontologyPrefix (1,:) char {mustBeNonempty}
            term_to_lookup_fragment (1,:) char % Can be empty if original lookup was just "PREFIX:"
        end

        id = ''; name = ''; definition = ''; synonyms = {};

        if isempty(term_to_lookup_fragment)
            error('ndi:ontology:lookupOBOFile:InvalidInput', ...
                'Term lookup fragment cannot be empty for OBO file search.');
        end

        persistent oboDataCache
        if isempty(oboDataCache)
            oboDataCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        if ~isfile(oboFilePath)
            error('ndi:ontology:lookupOBOFile:FileNotFound', ...
                'OBO file not found: %s', oboFilePath);
        end

        % Use a canonical path for the cache key to handle relative paths etc.
        [~, file_info] = fileattrib(oboFilePath);
        canonicalPath = file_info.Name;


        if isKey(oboDataCache, canonicalPath)
            parsedTerms = oboDataCache(canonicalPath);
        else
            fprintf('Parsing OBO file: %s...\n', oboFilePath);
            try
                parsedTerms = ndi.ontology.parseOBOFile_(oboFilePath);
                oboDataCache(canonicalPath) = parsedTerms;
                fprintf('OBO file parsed and cached successfully. Found %d terms.\n', numel(parsedTerms));
            catch ME
                % Clear the potentially partial cache entry if parsing failed
                if isKey(oboDataCache, canonicalPath)
                    remove(oboDataCache, canonicalPath);
                end
                baseME = MException('ndi:ontology:lookupOBOFile:ParsingError', ...
                    'Failed to parse OBO file "%s".', oboFilePath);
                baseME = addCause(baseME, ME);
                throw(baseME);
            end
        end

        if isempty(parsedTerms)
            error('ndi:ontology:lookupOBOFile:ParsingError', ...
                'OBO file "%s" parsed to an empty term list.', oboFilePath);
        end

        foundTerm = false;

        % Determine if lookup is by ID or by name
        % OBO IDs are typically PREFIX:NUMERIC_ID
        % We receive the numeric_id part or the name as term_to_lookup_fragment
        is_id_lookup = ~isempty(regexp(term_to_lookup_fragment, '^\d+$', 'once'));
        expected_full_id_if_numeric = [ontologyPrefix ':' term_to_lookup_fragment];

        for i = 1:numel(parsedTerms)
            term = parsedTerms(i);
            if is_id_lookup
                % Case-sensitive ID match
                if strcmp(term.id, expected_full_id_if_numeric)
                    id = term.id;
                    name = term.name;
                    definition = term.definition;
                    synonyms = term.synonyms;
                    foundTerm = true;
                    break;
                end
            else % Name lookup
                % Case-insensitive name match
                if strcmpi(term.name, term_to_lookup_fragment)
                    id = term.id;
                    name = term.name;
                    definition = term.definition;
                    synonyms = term.synonyms;
                    foundTerm = true;
                    break;
                end
                % Also check synonyms for name lookup (case-insensitive)
                if ~isempty(term.synonyms)
                    for s_idx = 1:numel(term.synonyms)
                        if strcmpi(term.synonyms{s_idx}, term_to_lookup_fragment)
                            id = term.id;
                            name = term.name; % Return primary name even if found by synonym
                            definition = term.definition;
                            synonyms = term.synonyms;
                            foundTerm = true;
                            break; % break from synonym loop
                        end
                    end
                    if foundTerm, break; end % break from main term loop
                end
            end
        end

        if ~foundTerm
            if is_id_lookup
                error('ndi:ontology:lookupOBOFile:TermNotFound', ...
                    'Term with ID fragment "%s" (expected full ID "%s") not found in OBO file: %s', ...
                    term_to_lookup_fragment, expected_full_id_if_numeric, oboFilePath);
            else
                error('ndi:ontology:lookupOBOFile:TermNotFound', ...
                    'Term with name "%s" not found in OBO file: %s', ...
                    term_to_lookup_fragment, oboFilePath);
            end
        end
    end % function lookupOBOFile
    
    function ontologies = getOntologies()
        % GETONTOLOGIES - Returns the ontology details list from JSON cache.
         data = ndi.ontology.loadOntologyJSONData_();
         if isfield(data,'Ontologies') && isstruct(data.Ontologies) && ~isempty(data.Ontologies)
             ontologies = data.Ontologies;
         else
             error('ndi:ontology:ontology:OntologyListNotFound', 'Could not retrieve "Ontologies" list from cached ontology data.');
         end
    end % function getOntologies

    function clearCache()
        % CLEARCACHE - Clears cached ontology list JSON data and NDIC data.
        ndi.ontology.loadOntologyJSONData_(true); % Force reload of JSON cache
        ndicFuncName = 'ndi.ontology.lookup_NDIC';
        ndicFuncPath = which(ndicFuncName);
        if ~isempty(ndicFuncPath), clear(ndicFuncName); fprintf('Cleared persistent data for %s.\n', ndicFuncName);
        else, fprintf('Function %s not found on path, skipping clear.\n', ndicFuncName); end
        fprintf('NDI ontology list JSON cache cleared.\n');
        clear ndi.ontology.lookupOBOFile; % This clears persistent vars in lookupOBOFile
        fprintf('Cleared OBO file cache.\n');

    end % function clearCache

end % methods (Static)

methods (Static, Access = private)
    % --- Private Static Helpers ---

    function data = loadOntologyJSONData_(forceReload)
        % LOADONTOLOGYJSONDATA_ - Loads ontology list from JSON, uses persistent cache.
        persistent ontologyDataCache
        if nargin < 1, forceReload = false; end
        if forceReload, ontologyDataCache = []; fprintf('Force reloading NDI ontology list from JSON...\n'); end
        if isempty(ontologyDataCache)
            if ~forceReload, fprintf('Loading NDI ontology list from JSON...\n'); end
            try filePath = fullfile(ndi.common.PathConstants.CommonFolder, ndi.ontology.ONTOLOGY_SUBFOLDER_JSON, ndi.ontology.ONTOLOGY_FILENAME);
            catch ME, error('ndi:ontology:ontology:PathConstantError', 'Could not access ndi.common.PathConstants.CommonFolder: %s', ME.message); end
            if ~isfile(filePath), error('ndi:ontology:ontology:JSONNotFound', 'Ontology list JSON file not found: %s', filePath); end
            try jsonData = fileread(filePath); decodedData = jsondecode(jsonData); if ~isstruct(decodedData) || ~isfield(decodedData, 'prefix_ontology_mappings') || ~isfield(decodedData, 'Ontologies'), error('ndi:ontology:ontology:JSONFormatError', 'Ontology list JSON file "%s" has an invalid format.', filePath); end; ontologyDataCache = decodedData; fprintf('NDI ontology list loaded successfully.\n');
            catch ME, ontologyDataCache = []; error('ndi:ontology:ontology:JSONError', 'Failed to load or decode ontology list JSON file "%s": %s', filePath, ME.message); end
        end
        data = ontologyDataCache;
    end % function loadOntologyJSONData_

    function likely_label = convertComponentToLabel_OMHeuristic(comp)
        % CONVERTCOMPONENTTOLABEL_OMHEURISTIC - OM-specific heuristic conversion.
        try spaced = regexprep(comp,'([a-z])([A-Z])','$1 $2'); likely_label = lower(strtrim(spaced));
        catch err, warning('ndi:ontology:preprocessLookupInput:ConversionHelperWarning', 'Error in OM heuristic for "%s": %s. Using lower(comp).', comp, err.message); likely_label = lower(comp); end
    end % function convertComponentToLabel_OMHeuristic

    function terms = parseOBOFile_(oboFilePath)
        % PARSEOBOFILE_ - Parses an OBO format file to extract term information.
        %   TERMS = ndi.ontology.parseOBOFile_(OBOFILEPATH)
        %
        %   This is a basic OBO parser, focusing on [Term] stanzas and
        %   id, name, def, and synonym tags.
        %
        %   Input:
        %       oboFilePath - Full path to the .obo file.
        %
        %   Output:
        %       terms - A struct array where each element has fields:
        %               .id         (string)
        %               .name       (string)
        %               .definition (string)
        %               .synonyms   (cell array of strings)
        %
        %   Note: This parser is not fully compliant with the OBO 1.2/1.4 spec
        %   but should handle common structures like the example provided.
        %   It does not handle import statements, typedefs, instances, etc.
        %   It assumes definitions and synonyms are single-line for simplicity here,
        %   though OBO can have multi-line quoted strings.
        %   Synonym parsing is basic (extracts quoted string, ignores type).

        terms = struct('id', {}, 'name', {}, 'definition', {}, 'synonyms', {});
        currentTerm = struct('id', '', 'name', '', 'definition', '', 'synonyms', {{}});
        inTermStanza = false;

        try
            fid = fopen(oboFilePath, 'rt');
            if fid == -1
                error('ndi:ontology:parseOBOFile:FileOpenError', 'Cannot open OBO file: %s', oboFilePath);
            end
            rawText = fread(fid, '*char')'; % Read entire file as a character row vector
            fclose(fid);
        catch ME
            error('ndi:ontology:parseOBOFile:FileReadError', 'Error reading OBO file "%s": %s', oboFilePath, ME.message);
        end

        % Split file into lines, handling both \n and \r\n
        lines = strsplit(rawText, {'\n', '\r\n'}, 'CollapseDelimiters', false);
        if iscell(lines) && isscalar(lines) && isempty(lines{1}) % Handle empty file
            lines = {};
        end


        for i = 1:numel(lines)
            line = strtrim(lines{i});

            if isempty(line) || startsWith(line, '!') % Skip empty lines and comments
                continue;
            end

            if strcmp(line, '[Term]')
                if inTermStanza && ~isempty(currentTerm.id) && ~isempty(currentTerm.name)
                    terms(end+1) = currentTerm; % Save previous term
                end
                % Reset for new term
                currentTerm = struct('id', '', 'name', '', 'definition', '', 'synonyms', {{}});
                inTermStanza = true;
                continue;
            end

            if startsWith(line, '[Typedef]') || startsWith(line, '[Instance]')
                if inTermStanza && ~isempty(currentTerm.id) && ~isempty(currentTerm.name)
                    terms(end+1) = currentTerm; % Save previous term
                end
                inTermStanza = false; % We are no longer in a [Term] stanza
                continue; % Skip Typedef and Instance stanzas for this basic parser
            end

            if inTermStanza
                if startsWith(line, 'id:')
                    currentTerm.id = strtrim(extractAfter(line, 'id:'));
                elseif startsWith(line, 'name:')
                    currentTerm.name = strtrim(extractAfter(line, 'name:'));
                elseif startsWith(line, 'def:')
                    % Basic definition extraction: "text" [xref]
                    % Extract text within the first pair of double quotes.
                    defMatches = regexp(line, 'def:\s*"(.*?)"', 'tokens', 'once');
                    if ~isempty(defMatches)
                        currentTerm.definition = defMatches{1};
                    else
                        % Fallback if no quotes, take rest of line (less robust)
                        currentTerm.definition = strtrim(extractAfter(line, 'def:'));
                    end
                elseif startsWith(line, 'synonym:')
                    % Basic synonym extraction: "text" TYPE [xref]
                    % Extract text within the first pair of double quotes.
                    synMatches = regexp(line, 'synonym:\s*"(.*?)"', 'tokens', 'once');
                    if ~isempty(synMatches)
                        currentTerm.synonyms{end+1} = synMatches{1};
                    end
                    % More advanced parsing could extract synonym type, scope, xrefs.
                end
                % Add other tags like 'is_a:', 'namespace:', 'is_obsolete:' if needed later
            end
        end

        % Add the last term if file doesn't end with a blank line or new stanza
        if inTermStanza && ~isempty(currentTerm.id) && ~isempty(currentTerm.name)
            terms(end+1) = currentTerm;
        end

        if isempty(terms) && ~isempty(lines) % Check if lines were processed but no terms found
            warning('ndi:ontology:parseOBOFile:NoTermsFound', ...
                'No [Term] stanzas found or parsed in OBO file: %s. Check file format.', oboFilePath);
        end
    end % function parseOBOFile_


end % methods (Static, Access = private)

end % classdef ontology