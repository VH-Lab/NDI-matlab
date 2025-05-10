% Location: +ndi/+ontology/@Uberon/Uberon.m
classdef Uberon < ndi.ontology
% UBERON - An NDI ontology object for the Uberon multi-species anatomy ontology.

    methods
        function obj = Uberon()
            % UBERON - Constructor for the Uberon ontology object.
            % Currently takes no arguments.
        end % constructor

        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name)
            % LOOKUPTERMORID - Looks up a term in the Uberon ontology by ID or name.
            %
            %   [ID, NAME, DEFINITION, SYNONYMS] = lookupTermOrID(OBJ, TERM_OR_ID_OR_NAME)
            %
            %   Overrides the base class method to provide specific lookup functionality
            %   for the Uberon ontology using the EBI OLS API.
            %
            %   The input TERM_OR_ID_OR_NAME is the part of the original lookup string
            %   after the 'UBERON:' prefix has been removed (e.g., '0000948' or 'heart').
            %
            %   This method uses the static helper functions from the base class:
            %   ndi.ontology.ontology.preprocessLookupInput and
            %   ndi.ontology.ontology.searchOLSAndPerformIRILookup.
            %
            %   See also: ndi.ontology.ontology.lookup (static dispatcher)

            % Define ontology specifics for Uberon
            ontology_prefix = 'UBERON';
            ontology_name_ols = 'uberon';

            % --- Step 1: Preprocess Input ---
            % Use the static helper from the base class. It handles the logic
            % for determining if the input is an ID or name and prepares the
            % search parameters for OLS.
            try
                [search_query, search_field, lookup_type_msg, ~] = ...
                    ndi.ontology.preprocessLookupInput(term_or_id_or_name, ontology_prefix);
            catch ME
                baseME = MException('ndi:ontology:Uberon:PreprocessingError', ...
                     'Error preprocessing Uberon lookup input "%s".', term_or_id_or_name);
                baseME = addCause(baseME, ME);
                throw(baseME);
            end

            % --- Step 2: Perform Search and IRI Lookup ---
            % Use the static helper from the base class. It performs the OLS search,
            % verifies unique results (handling non-exact label search filtering),
            % and calls performIriLookup for the final details.
            try
                [id, name, definition, synonyms] = ...
                    ndi.ontology.searchOLSAndPerformIRILookup(...
                        search_query, search_field, ontology_name_ols, ontology_prefix, lookup_type_msg);
            catch ME
                 baseME = MException('ndi:ontology:Uberon:LookupFailed', ...
                     'Uberon lookup failed for %s.', lookup_type_msg);
                 baseME = addCause(baseME, ME);
                 throw(baseME);
            end

        end % function lookupTermOrID

    end % methods

end % classdef Uberon