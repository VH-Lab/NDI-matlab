% Location: +ndi/+ontology/NCIm.m
classdef NCIm < ndi.ontology
% NCIM - NDI Ontology object for the NCI Metathesaurus (NCIm).
%   Inherits from ndi.ontology and implements lookupTermOrID for NCIm.

    methods
        function obj = NCIm()
            % NCIM - Constructor for the NCIm ontology object.
            % Implicitly calls the superclass constructor ndi.ontology().
        end % constructor

        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name)
            % LOOKUPTERMORID - Looks up a term in NCI Metathesaurus by CUI or exact name.
            %
            %   [ID, NAME, DEFINITION, SYNONYMS] = lookupTermOrID(OBJ, TERM_OR_ID_OR_NAME)
            %
            %   Overrides the base class method to provide specific lookup
            %   functionality for the NCIm terminology using the NCI EVS API.
            %
            %   The input TERM_OR_ID_OR_NAME is the part of the original lookup string
            %   after the 'NCIm:' prefix has been removed (e.g., 'C0018787' or 'Heart').
            %
            %   See also: ndi.ontology.lookup (static dispatcher)

            % Define the regex pattern for a typical CUI
            cui_pattern = '^C\d{7}$';

            % Check if the input matches the CUI pattern
            isCUI = ~isempty(regexp(term_or_id_or_name, cui_pattern, 'once'));

            if isCUI
                % --- Path 1: Input looks like a CUI ---
                cui_to_lookup = term_or_id_or_name;
                try
                    % Call private static helper specific to this class
                    [id, name, definition, synonyms] = ndi.ontology.NCIm.performNcimIdLookup(cui_to_lookup);
                catch ME
                    % Add context if the error is specific to ID lookup failure
                    if strcmp(ME.identifier, 'ndi:ontology:lookup_NCIm:IDNotFound') % Specific error from helper
                         error('ndi:ontology:NCIm:CUINotFound', ...
                               'NCIm concept with CUI "%s" not found via EVS API.', cui_to_lookup);
                    else % Other unexpected errors from helper re-wrap
                         baseME = MException('ndi:ontology:NCIm:CUILookupFailed', ...
                               'Failed to look up NCIm CUI "%s".', cui_to_lookup);
                         baseME = addCause(baseME, ME);
                         throw(baseME);
                    end
                end
            else
                % --- Path 2: Input is potentially a Term Name ---
                term_name = term_or_id_or_name;
                cui_from_search = '';

                % Construct Search URL
                evs_search_url = 'https://api-evsrest.nci.nih.gov/api/v1/concept/search';
                terminology = 'ncim';
                searchOptions = weboptions('ContentType', 'json', 'Timeout', 30, 'HeaderFields', {'Accept', 'application/json'});

                try
                    % Perform exact search ('type=match')
                    search_response = webread(evs_search_url, ...
                        'term', term_name, ...
                        'terminology', terminology, ...
                        'type', 'match', ...
                        'include', 'minimal', ...
                        searchOptions);

                    % Check search results
                    if isstruct(search_response) && isfield(search_response, 'total')
                        numFound = search_response.total;
                        if numFound == 1
                            if isfield(search_response, 'concepts') && isstruct(search_response.concepts) && numel(search_response.concepts) == 1
                                concept = search_response.concepts(1);
                                if isfield(concept, 'code') && ~isempty(concept.code)
                                    if ~isempty(regexp(concept.code, cui_pattern, 'once'))
                                        cui_from_search = char(concept.code);
                                    else
                                        error('ndi:ontology:NCIm:UnexpectedIDFormat','Found "%s", Code "%s" invalid format.', term_name, concept.code);
                                    end
                                else
                                    error('ndi:ontology:NCIm:MissingIDInSearchResult','Found "%s", missing Code.', term_name);
                                end
                            else
                                 error('ndi:ontology:NCIm:ConceptDataMismatch','API reported 1 result for "%s", but concept data invalid.', term_name);
                            end
                        elseif numFound == 0
                            error('ndi:ontology:NCIm:NameNotFound', '"%s" not found as exact match.', term_name);
                        else % numFound > 1
                            error('ndi:ontology:NCIm:NameNotUnique','"%s" had %d exact matches.', term_name, numFound);
                        end
                    else
                        error('ndi:ontology:NCIm:InvalidSearchResponse','Invalid search response for "%s".', term_name);
                    end
                catch ME
                    if contains(ME.message, '400'), error('ndi:ontology:NCIm:SearchAPIError','Search failed "%s" (Bad Request): %s', term_name, ME.message);
                    else, error('ndi:ontology:NCIm:SearchAPIError','Search failed "%s": %s', term_name, ME.message); end
                end

                % --- If unique match found, perform ID lookup ---
                if isempty(cui_from_search)
                     error('ndi:ontology:NCIm:InternalError','Could not determine CUI for "%s".', term_name);
                end

                try
                    % Call private static helper specific to this class
                    [id, name, definition, synonyms] = ndi.ontology.NCIm.performNcimIdLookup(cui_from_search);
                catch ME
                     baseME = MException('ndi:ontology:NCIm:PostSearchLookupFailed',...
                           'Found "%s" (CUI: %s), but failed subsequent lookup.', term_name, cui_from_search);
                     baseME = addCause(baseME, ME);
                     throw(baseME);
                end
            end % End if/else (isCUI vs Name)

        end % function lookupTermOrID

    end % methods

    methods (Static, Access = private)
        % --- Helper function for the actual NCIm CUI Lookup ---
        function [id, name, definition, synonyms] = performNcimIdLookup(cui)
            %PERFORMNCIMIDLOOKUP Fetches NCIm details by CUI using EVS API.
            %   This is a private static method.

            arguments, cui (1,:) char {mustBeNonempty}, end % Add arguments block
            id = ''; name = ''; definition = ''; synonyms = {};

            base_url = 'https://api-evsrest.nci.nih.gov/api/v1/concept/ncim/';
            encoded_cui = urlencode(cui);
            url = [base_url encoded_cui '?include=full'];
            options = weboptions('ContentType', 'json', 'Timeout', 30, 'HeaderFields', {'Accept', 'application/json'});

            try
                data = webread(url, options);
                if ~isstruct(data) || isempty(fieldnames(data))
                    error('ndi:ontology:lookup_NCIm:InvalidResponse', 'Received invalid response from EVS Concept API for CUI "%s".', cui);
                end
                if isfield(data, 'code') && ~isempty(data.code), id = char(data.code); else, id = cui; end
                if ~strcmp(id, cui), warning('ndi:ontology:lookup_NCIm:IDMismatch', 'Code "%s"!= CUI "%s".', id, cui); id = cui; end
                if isfield(data, 'name') && ~isempty(data.name), name = char(data.name); else, name = ''; end
                if isfield(data, 'definitions') && isstruct(data.definitions) && ~isempty(data.definitions), if isfield(data.definitions(1), 'definition') && ~isempty(data.definitions(1).definition), definition = char(data.definitions(1).definition); else, definition = ''; end; else, definition = ''; end
                if isfield(data, 'synonyms') && isstruct(data.synonyms) && ~isempty(data.synonyms), if isfield(data.synonyms(1), 'name'), syn_names = arrayfun(@(x) char(x.name), data.synonyms, 'UniformOutput', false); synonyms = syn_names(~cellfun('isempty', syn_names)); if isempty(synonyms), synonyms = {}; end; else, synonyms = {}; end; else, synonyms = {}; end
            catch ME
                if contains(ME.message, 'Timeout'), error('ndi:ontology:lookup_NCIm:APITimeout', 'EVS timeout for CUI "%s".', cui);
                elseif contains(ME.message, '404') || contains(ME.message, 'Not Found'), error('ndi:ontology:lookup_NCIm:IDNotFound', 'EVS 404 Not Found for CUI "%s".', cui); % Specific error ID for ID not found
                else, error('ndi:ontology:lookup_NCIm:APIError', 'EVS API failed for CUI "%s": %s', cui, ME.message); end
            end
        end % function performNcimIdLookup

    end % methods (Static, Access = private)

end % classdef NCIm