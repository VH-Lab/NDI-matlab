% Location: +ndi/+ontology/NCBITaxon.m
classdef NCBITaxon < ndi.ontology
% NCBITAXON - NDI Ontology object for the NCBI Taxonomy database.
%   Inherits from ndi.ontology and implements lookupTermOrID for NCBITaxon.

    methods
        function obj = NCBITaxon()
            % NCBITAXON - Constructor for the NCBITaxon ontology object.
            % Implicitly calls the superclass constructor ndi.ontology().
        end % constructor

        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name)
            % LOOKUPTERMORID - Looks up a term in NCBI Taxonomy by ID or exact scientific name.
            %
            %   [ID, NAME, DEFINITION, SYNONYMS] = lookupTermOrID(OBJ, TERM_OR_ID_OR_NAME)
            %
            %   Overrides the base class method to provide specific lookup
            %   functionality for the NCBI Taxonomy using NCBI E-utilities.
            %
            %   The input TERM_OR_ID_OR_NAME is the part of the original lookup string
            %   after the prefix (e.g., 'NCBITaxon:', 'taxonomy:') has been removed.
            %   It should be either a numeric TaxID string (e.g., '9606') or an
            %   exact scientific name (e.g., 'Homo sapiens').
            %
            %   See also: ndi.ontology.lookup (static dispatcher)

            % Check if the input is purely numeric (a TaxID)
            isNumericID = ~isempty(regexp(term_or_id_or_name, '^\d+$', 'once'));

            if isNumericID
                % --- Path 1: Input looks like a TaxID ---
                taxid_to_lookup = term_or_id_or_name;
                try
                    % Call private static helper method within this class
                    [id, name, definition, synonyms] = ndi.ontology.NCBITaxon.performNcbiTaxonIdLookup(taxid_to_lookup);
                catch ME
                    % Add context if the error is specific to ID lookup failure
                    if strcmp(ME.identifier, 'ndi:ontology:lookup_NCBITaxon:IDNotFound')
                         error('ndi:ontology:NCBITaxon:TaxIDNotFound', ...
                               'NCBI Taxon with TaxID "%s" not found via E-utilities efetch.', taxid_to_lookup);
                    else % Other unexpected errors from helper
                         baseME = MException('ndi:ontology:NCBITaxon:TaxIDLookupFailed', ...
                               'Failed to look up NCBI TaxID "%s".', taxid_to_lookup);
                         baseME = addCause(baseME, ME);
                         throw(baseME);
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
                search_term = [scientific_name '[Scientific Name]']; % Exact scientific name match
                encoded_term = urlencode(search_term);
                search_url = [eutils_base, esearch_script, '?db=', db, '&term=', encoded_term, '&retmode=xml'];
                searchOptions = weboptions('Timeout', 30);

                try
                    % Perform E-utilities search
                    xml_response = webread(search_url, searchOptions);
                    id_matches = regexp(xml_response, '<IdList>.*?<Id>(\d+)</Id>.*?</IdList>', 'tokens');

                    % Check search results
                    if ~isempty(id_matches)
                         numFound = numel(id_matches);
                         if numFound == 1
                             taxid_from_search = id_matches{1}{1};
                         else
                             error('ndi:ontology:NCBITaxon:NameNotUnique', ...
                                  'Scientific name "%s" matched multiple (%d) TaxIDs. Requires unique exact match.', scientific_name, numFound);
                         end
                    else % No <Id> found - check common reasons
                         if contains(xml_response, '<ErrorList>') || contains(xml_response, '<PhraseNotFound>') || contains(xml_response, '<Count>0</Count>')
                             error('ndi:ontology:NCBITaxon:NameNotFound', ...
                                   'Scientific name "%s" not found via E-utilities esearch.', scientific_name);
                         else
                             error('ndi:ontology:NCBITaxon:InvalidSearchResponse', ...
                                   'Unexpected/empty esearch response for name "%s".', scientific_name);
                         end
                    end
                catch ME
                     baseME = MException('ndi:ontology:NCBITaxon:SearchAPIError', 'E-utilities esearch failed for name "%s".', scientific_name);
                     baseME = addCause(baseME, ME); throw(baseME);
                end

                % --- If unique match found, perform ID lookup ---
                if ~isempty(taxid_from_search)
                    try
                        % Call private static helper method within this class
                        [id, name, definition, synonyms] = ndi.ontology.NCBITaxon.performNcbiTaxonIdLookup(taxid_from_search);
                    catch ME
                         baseME = MException('ndi:ontology:NCBITaxon:PostSearchLookupFailed', ...
                               'Found name "%s" (TaxID: %s), but failed subsequent efetch lookup.', ...
                               scientific_name, taxid_from_search);
                         baseME = addCause(baseME, ME);
                         throw(baseME);
                    end
                else
                    % Should be unreachable if search logic is correct
                     error('ndi:ontology:NCBITaxon:InternalError', ...
                           'Internal error after searching for name "%s". Could not proceed.', scientific_name);
                end
            end % End if/else (Numeric vs Name)

        end % function lookupTermOrID

    end % methods

    methods (Static, Access = private)
        % --- Helper function for the actual NCBI Taxonomy ID Lookup via efetch ---
        function [id, name, definition, synonyms] = performNcbiTaxonIdLookup(taxid)
            %PERFORMNCBITAXONIDLOOKUP Fetches and parses record for a given TaxID using efetch.
            %   This is a private static method called by lookupTermOrID.

            % Initialize outputs
            id = ''; name = ''; definition = ''; synonyms = {};

            % Construct API URL
            eutils_base = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/';
            efetch_script = 'efetch.fcgi';
            db = 'taxonomy';
            fetch_url = [eutils_base, efetch_script, '?db=', db, '&id=', taxid, '&retmode=xml'];
            fetchOptions = weboptions('Timeout', 30);

            try
                % Send the API request
                xml_response = webread(fetch_url, fetchOptions);
                % Check for basic error indicators
                if contains(xml_response, '<Error>') || isempty(xml_response) || ~contains(xml_response, '<Taxon>')
                     error('ndi:ontology:lookup_NCBITaxon:IDNotFound', 'No valid Taxon record found or error returned by efetch for TaxID "%s".', taxid);
                end

                % Extract Information using Regular Expressions
                id_match = regexp(xml_response, '<TaxId>(\d+)</TaxId>', 'tokens', 'once');
                if ~isempty(id_match), id = id_match{1}; else, id = taxid; end
                if ~strcmp(id, taxid) % Verify returned ID matches query
                    warning('ndi:ontology:NCBITaxon:IDMismatch', 'Returned TaxID "%s" does not match queried TaxID "%s". Using queried ID.', id, taxid);
                    id = taxid;
                end

                id = ['NCBITaxon:' id];

                name_match = regexp(xml_response, '<ScientificName>(.*?)</ScientificName>', 'tokens', 'once');
                if ~isempty(name_match), name = name_match{1}; else, name = ''; end

                definition = ''; % No standard definition field

                syn_list = {};
                common_name_matches = regexp(xml_response, '<CommonName>(.*?)</CommonName>', 'tokens');
                if ~isempty(common_name_matches), syn_list = [syn_list; cellfun(@(x) x{1}, common_name_matches, 'UniformOutput', false)]; end

                other_name_matches = regexp(xml_response, '<OtherNames>.*?<Name>.*?<DispName>(.*?)</DispName>.*?</Name>.*?</OtherNames>', 'tokens');
                 if ~isempty(other_name_matches)
                     all_other_names = {};
                     for k=1:length(other_name_matches)
                         disp_names_in_block = regexp(other_name_matches{k}{1}, '<DispName>(.*?)</DispName>', 'tokens');
                         if ~isempty(disp_names_in_block), all_other_names = [all_other_names; cellfun(@(x) x{1}, disp_names_in_block(:), 'UniformOutput', false)]; end
                     end
                     syn_list = [syn_list; all_other_names];
                 end

                if ~isempty(syn_list), synonyms = unique(syn_list, 'stable'); synonyms = synonyms(~cellfun('isempty', synonyms)); if isempty(synonyms), synonyms = {}; end; else, synonyms = {}; end

            catch ME
                % Rethrow specific ID not found error, wrap others
                if strcmp(ME.identifier, 'ndi:ontology:lookup_NCBITaxon:IDNotFound')
                    rethrow(ME);
                else
                    baseME = MException('ndi:ontology:NCBITaxon:FetchAPIError', 'E-utilities efetch failed for TaxID "%s".', taxid);
                    baseME = addCause(baseME, ME);
                    throw(baseME);
                end
            end
        end % function performNcbiTaxonIdLookup

    end % methods (Static, Access = private)

end % classdef NCBITaxon