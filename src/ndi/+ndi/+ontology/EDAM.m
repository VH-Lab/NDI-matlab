% Location: +ndi/+ontology/EDAM.m
classdef EDAM < ndi.ontology
% EDAM - NDI Ontology object for the EDAM ontology.
%   Inherits from ndi.ontology and implements lookupTermOrID for EDAM.
%   EDAM is an ontology of data analysis and management in life sciences.
%
%   EDAM uses sub-ontology prefixes in its OBO IDs (format, data,
%   operation, topic) rather than the top-level 'EDAM' prefix. For
%   example, the FASTA format has obo_id 'format:1929', not 'EDAM:1929'.
%   This class handles that mapping.
%
%   See also: http://edamontology.org
%             https://www.ebi.ac.uk/ols4/ontologies/edam

    properties (Constant, Access = private)
        % EDAM sub-ontology prefixes used in OBO IDs
        EDAM_SUBPREFIXES = {'format', 'data', 'operation', 'topic'};
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
            %   Overrides the base class method to provide specific lookup functionality
            %   for the EDAM ontology using the EBI OLS API via static helper methods
            %   from the ndi.ontology base class.
            %
            %   The input TERM_OR_ID_OR_NAME is the part of the original lookup string
            %   after the prefix has been removed (e.g., '1929' for 'format:1929' or 'FASTA'
            %   for 'format:FASTA').
            %
            %   EDAM uses sub-ontology prefixes (format, data, operation, topic) in its
            %   OBO IDs rather than the top-level 'EDAM' prefix. For numeric IDs, this
            %   method tries each sub-ontology prefix to find the correct term.
            %
            %   Example Usage (after being called by ndi.ontology.lookup):
            %   [id, name, ~, def] = ndi.ontology.lookup('format:1929'); % FASTA
            %   [id, name, ~, def] = ndi.ontology.lookup('EDAM:1929');   % FASTA
            %
            %   See also: ndi.ontology.lookup (static dispatcher),
            %             ndi.ontology.searchOLSAndPerformIRILookup (static helper)

            ontology_prefix = 'EDAM';
            ontology_name_ols = 'edam';

            isNumericID = ~isempty(regexp(term_or_id_or_name, '^\d+$', 'once'));

            if isNumericID
                % EDAM obo_ids use sub-ontology prefixes (e.g., format:1929)
                % not the top-level EDAM prefix. Try each sub-prefix.
                lastError = [];
                for i = 1:numel(ndi.ontology.EDAM.EDAM_SUBPREFIXES)
                    search_query = [ndi.ontology.EDAM.EDAM_SUBPREFIXES{i} ':' term_or_id_or_name];
                    lookup_type_msg = sprintf('numeric ID "%s" (trying obo_id "%s")', ...
                        term_or_id_or_name, search_query);
                    try
                        [id, name, definition, synonyms] = ...
                            ndi.ontology.searchOLSAndPerformIRILookup(...
                                search_query, 'obo_id', ontology_name_ols, ontology_prefix, lookup_type_msg);
                        % Normalize the returned ID to EDAM:NNNN format
                        id = [ontology_prefix ':' term_or_id_or_name];
                        return;
                    catch ME
                        lastError = ME;
                    end
                end
                % None of the sub-prefixes matched
                baseME = MException('ndi:ontology:EDAM:LookupFailed', ...
                    'EDAM lookup failed for numeric ID "%s".', term_or_id_or_name);
                if ~isempty(lastError)
                    baseME = addCause(baseME, lastError);
                end
                throw(baseME);
            else
                % Name lookup - search by label
                search_query = term_or_id_or_name;
                lookup_type_msg = sprintf('name "%s"', term_or_id_or_name);
                try
                    [id, name, definition, synonyms] = ...
                        ndi.ontology.searchOLSAndPerformIRILookup(...
                            search_query, 'label', ontology_name_ols, ontology_prefix, lookup_type_msg);
                    % Normalize the ID: convert sub-ontology format (e.g.,
                    % "format:1929") to EDAM format ("EDAM:1929")
                    id = ndi.ontology.EDAM.normalizeEDAMId(id, ontology_prefix);
                catch ME
                    baseME = MException('ndi:ontology:EDAM:LookupFailed', ...
                        'EDAM lookup failed for %s.', lookup_type_msg);
                    baseME = addCause(baseME, ME);
                    throw(baseME);
                end
            end

        end % function lookupTermOrID

    end % methods

    methods (Static, Access = private)
        function id = normalizeEDAMId(id, ontology_prefix)
            %NORMALIZEEDAMID Convert EDAM sub-ontology IDs to EDAM:NNNN format.
            %   EDAM obo_ids use sub-ontology prefixes (e.g., "format:1929").
            %   This normalizes them to the standard "EDAM:NNNN" format.
            if ~isempty(id) && ~startsWith(id, [ontology_prefix ':'], 'IgnoreCase', true)
                numMatch = regexp(id, ':(\d+)$', 'tokens', 'once');
                if ~isempty(numMatch)
                    id = [ontology_prefix ':' numMatch{1}];
                end
            end
        end
    end % methods (Static, Access = private)

end % classdef EDAM
