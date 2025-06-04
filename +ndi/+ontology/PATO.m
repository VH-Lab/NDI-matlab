% Location: +ndi/+ontology/PATO.m
classdef PATO < ndi.ontology
% PATO - NDI Ontology object for the Phenotype And Trait Ontology (PATO).
%   Inherits from ndi.ontology and implements lookupTermOrID for PATO.
%   PATO is an ontology of phenotypic qualities.
%
%   See also: http://obofoundry.org/ontology/pato.html
%             https://www.ebi.ac.uk/ols/ontologies/pato

    methods
        function obj = PATO()
            % PATO - Constructor for the PATO ontology object.
            % Implicitly calls the superclass constructor ndi.ontology().
        end % constructor

        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name)
            % LOOKUPTERMORID - Looks up a term in the PATO ontology.
            %
            %   [ID, NAME, DEFINITION, SYNONYMS] = lookupTermOrID(OBJ, TERM_OR_ID_OR_NAME)
            %
            %   Overrides the base class method to provide specific lookup functionality
            %   for the PATO ontology using the EBI OLS API via static helper methods
            %   from the ndi.ontology base class.
            %
            %   The input TERM_OR_ID_OR_NAME is the part of the original lookup string
            %   after the 'PATO:' prefix has been removed (e.g., '0000001' for an ID,
            %   or 'color' for a name/label search).
            %
            %   Example Usage (after being called by ndi.ontology.lookup):
            %   [id, name, ~, def] = ndi.ontology.lookup('PATO:0000012'); % quality
            %   [id, name, ~, def] = ndi.ontology.lookup('PATO:color');   % color
            %
            %   See also: ndi.ontology.lookup (static dispatcher),
            %             ndi.ontology.preprocessLookupInput (static helper),
            %             ndi.ontology.searchOLSAndPerformIRILookup (static helper)

            % Define ontology specifics for PATO
            ontology_prefix = 'PATO';
            ontology_name_ols = 'pato'; % OLS uses 'pato' as the ontology ID

            % --- Step 1: Preprocess Input using Base Class Static Helper ---
            % The standard preprocessing logic in preprocessLookupInput should handle
            % PATO's common "PREFIX:ID" (numeric) or "PREFIX:Label" formats correctly.
            % It will determine if search_field should be 'obo_id' or 'label'.
            try
                % Call static method using full class name qualification
                [search_query, search_field, lookup_type_msg, ~] = ...
                    ndi.ontology.preprocessLookupInput(term_or_id_or_name, ontology_prefix);
            catch ME
                baseME = MException('ndi:ontology:PATO:PreprocessingError', ...
                    'Error preprocessing PATO lookup input "%s".', term_or_id_or_name);
                baseME = addCause(baseME, ME);
                throw(baseME);
            end

            % --- Step 2: Perform Search and IRI Lookup using Base Class Static Helper ---
            % searchOLSAndPerformIRILookup will use 'exact=true' for 'obo_id' searches
            % and its existing logic for 'label' searches (broad search then filter for exact match).
            try
                % Call static method using full class name qualification
                [id, name, definition, synonyms] = ...
                    ndi.ontology.searchOLSAndPerformIRILookup(...
                        search_query, search_field, ontology_name_ols, ontology_prefix, lookup_type_msg);
            catch ME
                baseME = MException('ndi:ontology:PATO:LookupFailed', ...
                    'PATO lookup failed for %s.', lookup_type_msg);
                baseME = addCause(baseME, ME);
                throw(baseME);
            end

        end % function lookupTermOrID

    end % methods

end % classdef PATO
