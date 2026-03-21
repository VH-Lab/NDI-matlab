% Location: +ndi/+ontology/EDAM.m
classdef EDAM < ndi.ontology
% EDAM - NDI Ontology object for the EDAM ontology.
%   Inherits from ndi.ontology and implements lookupTermOrID for EDAM.
%   EDAM is an ontology of data analysis and management in life sciences.
%
%   EDAM uses sub-ontology prefixes in its OBO IDs (format, data,
%   operation, topic) rather than the top-level 'EDAM' prefix. For
%   example, the FASTA format has obo_id 'format:1929', not 'EDAM:1929'.
%
%   This class uses direct IRI lookups rather than the OLS search API,
%   since EDAM IRIs follow a predictable pattern:
%   http://edamontology.org/{subprefix}_{id}
%
%   See also: http://edamontology.org
%             https://www.ebi.ac.uk/ols4/ontologies/edam

    properties (Constant, Access = private)
        % EDAM sub-ontology prefixes used in OBO IDs
        EDAM_SUBPREFIXES = {'format', 'data', 'operation', 'topic'};
        % Base IRI for EDAM terms
        EDAM_IRI_BASE = 'http://edamontology.org/';
    end

    methods
        function obj = EDAM()
            % EDAM - Constructor for the EDAM ontology object.
            % Implicitly calls the superclass constructor ndi.ontology().
        end % constructor

        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name)
            % LOOKUPTERMORID - Looks up a term in the EDAM ontology.
            %
            %   [ID, NAME, DEFINITION, SYNONYMS] = lookupTermOrID(OBJ, TERM_OR_ID_OR_NAME)
            %
            %   Uses direct IRI lookups against the OLS term API rather than the
            %   search API, since EDAM IRIs are predictable. For numeric IDs, each
            %   sub-ontology prefix is tried. For name lookups, the OLS search API
            %   is used as a fallback.
            %
            %   Example Usage (after being called by ndi.ontology.lookup):
            %   [id, name, ~, def] = ndi.ontology.lookup('format:1929'); % FASTA
            %   [id, name, ~, def] = ndi.ontology.lookup('EDAM:1929');   % FASTA
            %
            %   See also: ndi.ontology.lookup, ndi.ontology.performIriLookup

            ontology_prefix = 'EDAM';
            ontology_name_ols = 'edam';

            isNumericID = ~isempty(regexp(term_or_id_or_name, '^\d+$', 'once'));

            if isNumericID
                % Try direct IRI lookup with each sub-ontology prefix.
                % EDAM IRIs: http://edamontology.org/{subprefix}_{id}
                lastError = [];
                for i = 1:numel(ndi.ontology.EDAM.EDAM_SUBPREFIXES)
                    sub = ndi.ontology.EDAM.EDAM_SUBPREFIXES{i};
                    term_iri = [ndi.ontology.EDAM.EDAM_IRI_BASE sub '_' term_or_id_or_name];
                    try
                        [id, name, definition, synonyms] = ...
                            ndi.ontology.performIriLookup(term_iri, ontology_name_ols, ontology_prefix);
                        % Normalize ID to EDAM:NNNN format
                        id = [ontology_prefix ':' term_or_id_or_name];
                        return;
                    catch ME
                        lastError = ME;
                    end
                end
                baseME = MException('ndi:ontology:EDAM:LookupFailed', ...
                    'EDAM lookup failed for numeric ID "%s".', term_or_id_or_name);
                if ~isempty(lastError)
                    baseME = addCause(baseME, lastError);
                end
                throw(baseME);
            else
                % Name lookup - use OLS search API by label, then fall back
                % to searching across all EDAM sub-ontologies by label.
                search_query = term_or_id_or_name;
                lookup_type_msg = sprintf('name "%s"', term_or_id_or_name);
                try
                    [id, name, definition, synonyms] = ...
                        ndi.ontology.searchOLSAndPerformIRILookup(...
                            search_query, 'label', ontology_name_ols, ontology_prefix, lookup_type_msg);
                    id = ndi.ontology.EDAM.normalizeEDAMId(id, ontology_prefix);
                    return;
                catch ME_search
                    % Search API failed; try broader search without
                    % restricting to label field
                end

                % Fallback: search OLS without field restriction
                try
                    searchOptions = weboptions('ContentType', 'json', 'Timeout', 30, ...
                        'HeaderFields', {'Accept', 'application/json'});
                    search_url = 'https://www.ebi.ac.uk/ols4/api/search';
                    response = webread(search_url, ...
                        'q', search_query, 'ontology', ontology_name_ols, ...
                        'exact', 'true', 'rows', '5', searchOptions);
                    if isfield(response, 'response') && isfield(response.response, 'numFound') ...
                            && response.response.numFound > 0
                        doc = response.response.docs(1);
                        if isfield(doc, 'iri') && ~isempty(doc.iri)
                            [id, name, definition, synonyms] = ...
                                ndi.ontology.performIriLookup(char(doc.iri), ontology_name_ols, ontology_prefix);
                            id = ndi.ontology.EDAM.normalizeEDAMId(id, ontology_prefix);
                            return;
                        end
                    end
                catch ME_broad
                    % Broad search also failed
                end

                baseME = MException('ndi:ontology:EDAM:LookupFailed', ...
                    'EDAM lookup failed for %s.', lookup_type_msg);
                throw(baseME);
            end

        end % function lookupTermOrID

    end % methods

    methods (Static, Access = private)
        function id = normalizeEDAMId(id, ontology_prefix)
            %NORMALIZEEDAMID Convert EDAM sub-ontology IDs to EDAM:NNNN format.
            if ~isempty(id) && ~startsWith(id, [ontology_prefix ':'], 'IgnoreCase', true)
                numMatch = regexp(id, ':(\d+)$', 'tokens', 'once');
                if ~isempty(numMatch)
                    id = [ontology_prefix ':' numMatch{1}];
                end
            end
        end
    end % methods (Static, Access = private)

end % classdef EDAM
