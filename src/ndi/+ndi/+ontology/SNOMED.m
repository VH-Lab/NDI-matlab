% Location: +ndi/+ontology/SNOMED.m
classdef SNOMED < ndi.ontology
% SNOMED - NDI Ontology object for SNOMED CT (Systematized Nomenclature of Medicine).
%   Inherits from ndi.ontology and implements lookupTermOrID for SNOMED.
%   SNOMED CT is a systematic, computer-processable collection of medical 
%   terms providing codes, terms, synonyms, and definitions.
%
%   See also: https://www.snomed.org/
%             https://www.ebi.ac.uk/ols4/ontologies/snomedct
    methods
        function obj = SNOMED()
            % SNOMED - Constructor for the SNOMED ontology object.
            % Implicitly calls the superclass constructor ndi.ontology().
        end % constructor

        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name)
            % LOOKUPTERMORID - Looks up a term in the SNOMED CT ontology.
            %
            %   [ID, NAME, DEFINITION, SYNONYMS] = lookupTermOrID(OBJ, TERM_OR_ID_OR_NAME)
            %
            %   Overrides the base class method to provide specific lookup functionality
            %   for SNOMED CT using the EBI OLS API via static helper methods.
            %
            %   The input TERM_OR_ID_OR_NAME is the part after the 'SNOMED:' prefix.
            %   (e.g., '396163008' for an ID, or 'Alprazolam' for a name search).
            %
            %   Example Usage (via dispatcher):
            %   [id, name, ~, def] = ndi.ontology.lookup('SNOMED:396163008'); 
            %   [id, name, ~, def] = ndi.ontology.lookup('SNOMED:Intraperitoneal');
            
            % Define ontology specifics for SNOMED
            ontology_prefix = 'SNOMED';
            ontology_name_ols = 'snomed'; % OLS uses 'snomed' as the ontology ID
            
            % --- Step 1: Preprocess Input using Base Class Static Helper ---
            try
                [search_query, search_field, lookup_type_msg, ~] = ...
                    ndi.ontology.preprocessLookupInput(term_or_id_or_name, ontology_prefix);
            catch ME
                baseME = MException('ndi:ontology:SNOMED:PreprocessingError', ...
                    'Error preprocessing SNOMED lookup input "%s".', term_or_id_or_name);
                baseME = addCause(baseME, ME);
                throw(baseME);
            end

            % --- Step 2: Perform Search and IRI Lookup ---
            try
                % Call static method using full class name qualification.
                % Note: SNOMED IDs in OLS are often prefixed with 'SNOMED:'
                [id, name, definition, synonyms] = ...
                    ndi.ontology.searchOLSAndPerformIRILookup(...
                        search_query, search_field, ontology_name_ols, ontology_prefix, lookup_type_msg);
            catch ME
                baseME = MException('ndi:ontology:SNOMED:LookupFailed', ...
                    'SNOMED lookup failed for %s.', lookup_type_msg);
                baseME = addCause(baseME, ME);
                throw(baseME);
            end
        end % function lookupTermOrID
    end % methods
end % classdef SNOMED