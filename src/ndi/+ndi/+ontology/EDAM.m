% Location: +ndi/+ontology/EDAM.m
classdef EDAM < ndi.ontology
% EDAM - NDI Ontology object for the EDAM ontology.
%   Inherits from ndi.ontology and implements lookupTermOrID for EDAM.
%   EDAM is an ontology of data analysis and management in life sciences.
%
%   See also: http://edamontology.org
%             https://www.ebi.ac.uk/ols4/ontologies/edam

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
            %   Example Usage (after being called by ndi.ontology.lookup):
            %   [id, name, ~, def] = ndi.ontology.lookup('format:1929'); % FASTA
            %   [id, name, ~, def] = ndi.ontology.lookup('EDAM:1929');   % FASTA
            %
            %   See also: ndi.ontology.lookup (static dispatcher),
            %             ndi.ontology.preprocessLookupInput (static helper),
            %             ndi.ontology.searchOLSAndPerformIRILookup (static helper)

            % Define ontology specifics for EDAM
            ontology_prefix = 'EDAM';
            ontology_name_ols = 'edam'; % OLS uses 'edam' as the ontology ID

            % --- Step 1: Preprocess Input using Base Class Static Helper ---
            % Standard preprocessing should work. If numeric, it will prepend 'EDAM:'.
            try
                % Call static method using full class name qualification
                [search_query, search_field, lookup_type_msg, ~] = ...
                    ndi.ontology.preprocessLookupInput(term_or_id_or_name, ontology_prefix);
            catch ME
                baseME = MException('ndi:ontology:EDAM:PreprocessingError', ...
                    'Error preprocessing EDAM lookup input "%s".', term_or_id_or_name);
                baseME = addCause(baseME, ME);
                throw(baseME);
            end

            % --- Step 2: Perform Search and IRI Lookup using Base Class Static Helper ---
            try
                % Call static method using full class name qualification
                [id, name, definition, synonyms] = ...
                    ndi.ontology.searchOLSAndPerformIRILookup(...
                        search_query, search_field, ontology_name_ols, ontology_prefix, lookup_type_msg);
            catch ME
                baseME = MException('ndi:ontology:EDAM:LookupFailed', ...
                    'EDAM lookup failed for %s.', lookup_type_msg);
                baseME = addCause(baseME, ME);
                throw(baseME);
            end

        end % function lookupTermOrID

    end % methods

end % classdef EDAM
