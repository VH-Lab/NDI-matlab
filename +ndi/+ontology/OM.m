% Location: +ndi/+ontology/OM.m
classdef OM < ndi.ontology
% OM - NDI Ontology object for the Ontology of Units of Measure (OM).
%   Inherits from ndi.ontology and implements lookupTermOrID for OM.

    methods
        function obj = OM()
            % OM - Constructor for the OM ontology object.
            % Implicitly calls the superclass constructor ndi.ontology().
        end % constructor

        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name)
            % LOOKUPTERMORID - Looks up a unit in the OM ontology by name/term.
            %
            %   [ID, NAME, DEFINITION, SYNONYMS] = lookupTermOrID(OBJ, TERM_OR_ID_OR_NAME)
            %
            %   Overrides the base class method to provide specific lookup functionality
            %   for the OM ontology using the EBI OLS API via static helper methods
            %   from the ndi.ontology base class. It relies on the OM-specific logic
            %   within ndi.ontology.preprocessLookupInput.
            %
            %   The input TERM_OR_ID_OR_NAME is the part of the original lookup string
            %   after the 'OM:' prefix has been removed (e.g., 'metre', 'Metre', 'MolarVolumeUnit').
            %   Purely numeric inputs are rejected during preprocessing.
            %
            %   See also: ndi.ontology.lookup (static dispatcher),
            %             ndi.ontology.preprocessLookupInput (static helper),
            %             ndi.ontology.searchOLSAndPerformIRILookup (static helper)

            % Define ontology specifics for OM
            ontology_prefix = 'OM';
            ontology_name_ols = 'om';

            % --- Step 1: Preprocess Input using Base Class Static Helper ---
            % preprocessLookupInput contains OM-specific logic:
            % - Rejects numeric/prefixed-numeric IDs.
            % - Converts input term component to a likely label format.
            % - Sets search_field to 'label'.
            % - Sets search_query to the likely label format.
            try
                % Call static method using full class name qualification
                [search_query, search_field, lookup_type_msg, ~] = ...
                    ndi.ontology.preprocessLookupInput(term_or_id_or_name, ontology_prefix);
            catch ME
                baseME = MException('ndi:ontology:OM:PreprocessingError', ...
                     'Error preprocessing OM lookup input "%s".', term_or_id_or_name);
                baseME = addCause(baseME, ME);
                throw(baseME);
            end

            % --- Step 2: Perform Search and IRI Lookup using Base Class Static Helper ---
            % searchOLSAndPerformIRILookup handles non-exact label search + filtering
            % when search_field is 'label'.
            try
                % Call static method using full class name qualification
                [id, name, definition, synonyms] = ...
                    ndi.ontology.searchOLSAndPerformIRILookup(...
                        search_query, search_field, ontology_name_ols, ontology_prefix, lookup_type_msg);
            catch ME
                 baseME = MException('ndi:ontology:OM:LookupFailed', ...
                     'OM lookup failed for %s.', lookup_type_msg);
                 baseME = addCause(baseME, ME);
                 throw(baseME);
            end

        end % function lookupTermOrID

    end % methods

end % classdef OM