% Location: +ndi/+ontology/RRID.m
% Final Version: Supports lookup by RRID component only. Removed name search path.

classdef RRID < ndi.ontology
% RRID - NDI Ontology object for Research Resource Identifiers (RRID).
%   Inherits from ndi.ontology and implements lookupTermOrID for RRIDs
%   using the scicrunch.org resolver API's .json endpoint.

    methods
        function obj = RRID()
            % RRID - Constructor for the RRID ontology object.
        end % constructor

        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name)
            % LOOKUPTERMORID - Looks up an RRID via scicrunch.org resolver endpoint using its ID component.
            %
            %   [ID, NAME, DEFINITION, SYNONYMS] = lookupTermOrID(OBJ, TERM_OR_ID_OR_NAME)
            %
            %   Overrides the base class method. Expects TERM_OR_ID_OR_NAME to be the
            %   remainder of the RRID after the 'RRID:' prefix (e.g., 'SCR_006472', 'AB_123456').
            %   It must resemble a valid RRID component structure.
            %
            %   NOTE: Lookup by name (e.g., 'NCBI') is NOT currently supported for RRIDs
            %   due to lack of a confirmed reliable public search API endpoint accessible
            %   via standard web requests from MATLAB. Please provide the specific RRID
            %   component (e.g., SCR_006472).
            %
            %   Queries the SciCrunch resolver endpoint: https://scicrunch.org/resolver/{RRID}.json
            %
            %   Outputs:
            %       ID           - The full RRID used for the lookup (e.g., 'RRID:SCR_006472').
            %       NAME         - The name found for the resource (typically from item.name).
            %       DEFINITION   - The description found (typically from item.description).
            %       SYNONYMS     - Cell array of synonyms, if found within the item.synonyms structure.
            %
            %   See also: ndi.ontology.lookup (static dispatcher)

            original_input_remainder = strtrim(term_or_id_or_name);
            id = ''; name = ''; definition = ''; synonyms = {};

            % --- Check if input looks like a valid RRID identifier component ---
            % Basic regex for common RRID patterns like XXX_YYY or XXX:YYY
            isLikelyID = ~isempty(regexp(original_input_remainder, '^[A-Za-z]+[_:]\S+$', 'once'));

            if ~isLikelyID
                error('ndi:ontology:RRID:NameLookupUnsupported', ...
                      'Input "%s" does not look like a valid RRID component (e.g., SCR_001234 or AB_123456). Lookup by name is not currently supported for RRID. Please provide the specific RRID component after the RRID: prefix.', original_input_remainder);
            end

            % --- Proceed with ID Lookup ---
            full_rrid = ['RRID:' original_input_remainder];
            lookup_type_msg = sprintf('RRID "%s"', full_rrid); % For error context if helper fails

            try
                % Call the private static helper using the full RRID
                [id, name, definition, synonyms] = ndi.ontology.RRID.performRridResolverLookup(full_rrid);
            catch ME
                 % Wrap errors from the helper
                 baseME = MException('ndi:ontology:RRID:IDLookupFailed', ...
                      'Lookup failed for %s.', lookup_type_msg);
                 baseME = addCause(baseME, ME); throw(baseME);
            end

        end % function lookupTermOrID

    end % methods

    methods (Static, Access = private)
        % --- Helper function for the actual RRID Lookup via Resolver ---
        function [id, name, definition, synonyms] = performRridResolverLookup(full_rrid)
            %PERFORMRRIDRESOLVERLOOKUP Fetches details using /resolver/{RRID}.json
            arguments, full_rrid (1,:) char {mustBeNonempty}, end
            id = ''; name = ''; definition = ''; synonyms = {}; % Initialize

            apiUrlBase = 'https://scicrunch.org/resolver/';
            try, encoded_rrid_path_segment = urlencode(full_rrid);
            catch ME_encode, error('ndi:ontology:RRID:EncodingError', 'Failed URL encode for %s: %s', full_rrid, ME_encode.message); end
            apiUrl = [apiUrlBase encoded_rrid_path_segment '.json'];

            ua = 'Mozilla/5.0 (MATLAB NDI Ontology Lookup)';
            options = weboptions('Timeout', 30, 'HeaderFields', {'Accept', 'application/json'; 'User-Agent', ua});

            try
                response = webread(apiUrl, options);

                % Parse the response based on observed structure
                if isstruct(response) && isfield(response, 'hits') && isfield(response.hits, 'hits') && ~isempty(response.hits.hits) && isstruct(response.hits.hits(1)) && isfield(response.hits.hits(1), 'x_source') && isstruct(response.hits.hits(1).x_source) && isfield(response.hits.hits(1).x_source, 'item') && isstruct(response.hits.hits(1).x_source.item)
                    item_data = response.hits.hits(1).x_source.item;
                    id = full_rrid;

                    if isfield(item_data, 'name') && ~isempty(item_data.name) && (ischar(item_data.name) || isstring(item_data.name)), name = strtrim(char(item_data.name)); else, name = ''; end
                    if isfield(item_data, 'description') && ~isempty(item_data.description) && (ischar(item_data.description) || isstring(item_data.description)), definition = strtrim(char(item_data.description)); else, definition = ''; end
                    synonyms = {};
                    if isfield(item_data, 'synonyms') && ~isempty(item_data.synonyms), syn_data = item_data.synonyms; if iscell(syn_data) && all(cellfun(@(c) ischar(c) || isstring(c), syn_data)), synonyms = cellfun(@char, syn_data, 'UniformOutput', false); elseif isstruct(syn_data), if isfield(syn_data, 'literal') && ~isempty(syn_data.literal), literal_data = syn_data.literal; if iscell(literal_data) && all(cellfun(@(c) ischar(c) || isstring(c), literal_data)), synonyms = cellfun(@char, literal_data, 'UniformOutput', false); elseif ischar(literal_data) || isstring(literal_data), synonyms = {char(literal_data)}; end; elseif isfield(syn_data, 'name'), name_data = {syn_data.name}; synonyms = cellfun(@char, name_data, 'UniformOutput', false); end; elseif ischar(syn_data) || isstring(syn_data), synonyms = {char(syn_data)}; end; if ~isempty(synonyms), synonyms = synonyms(~cellfun('isempty', synonyms)); if isempty(synonyms), synonyms = {}; end; end; end % End synonym parsing
                    if isempty(name) && isempty(definition), warning('ndi:ontology:RRID:LookupDataMissing', 'Queried %s successfully but key metadata (item.name, item.description) seems missing.', full_rrid); elseif isempty(name), warning('ndi:ontology:RRID:MissingName', 'Could not extract item.name for %s.', full_rrid); end

                elseif isstruct(response) && isfield(response, 'success') && ~response.success, err_msg = 'API indicated failure (success=false).'; if isfield(response,'errormsg') && ~isempty(response.errormsg), err_msg = response.errormsg; elseif isfield(response,'message') && ~isempty(response.message), err_msg = response.message; end; error('ndi:ontology:RRID:APIReportedFailure', 'SciCrunch API reported failure for RRID "%s": %s', full_rrid, err_msg);
                else, error('ndi:ontology:RRID:InvalidResponse', 'Received unexpected JSON structure from SciCrunch /resolver/*.json API for %s.', full_rrid); end
            catch ME
                isHttpError = contains(ME.identifier, 'MATLAB:webservices:HTTP'); is404Error = isHttpError && (contains(ME.message, '404') || contains(ME.message, 'Not Found'));
                if is404Error, error('ndi:ontology:RRID:IDNotFound', 'RRID "%s" lookup failed via SciCrunch endpoint %s (404 Error).', full_rrid, apiUrlBase);
                elseif contains(ME.message, 'Timeout'), error('ndi:ontology:RRID:APITimeout', 'SciCrunch API request timed out for RRID "%s".', full_rrid);
                elseif isHttpError, error('ndi:ontology:RRID:APIStatusError', 'SciCrunch API returned HTTP error for RRID "%s": %s', full_rrid, ME.message);
                else, baseME = MException('ndi:ontology:RRID:APIError', 'SciCrunch /resolver/*.json API lookup failed for RRID "%s".', full_rrid); baseME = addCause(baseME, ME); throw(baseME); end
            end
        end % function performRridResolverLookup

    end % methods (Static, Access = private)

end % classdef RRID