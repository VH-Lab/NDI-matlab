% Location: +ndi/+ontology/EFO.m
classdef EFO < ndi.ontology
% EFO - NDI Ontology object for the Experimental Factor Ontology (EFO).
%   Inherits from ndi.ontology and implements lookupTermOrID for EFO.
%   EFO provides a systematic description of experimental variables in 
%   chemical biology, molecular biology, and clinical data.
%
%   See also: https://www.ebi.ac.uk/efo/
%             https://www.ebi.ac.uk/ols4/ontologies/efo
    methods
        function obj = EFO()
            % EFO - Constructor for the EFO ontology object.
            % Implicitly calls the superclass constructor ndi.ontology().
        end % constructor

        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name)
            % LOOKUPTERMORID - Looks up a term in the EFO ontology.
            %
            %   [ID, NAME, DEFINITION, SYNONYMS] = lookupTermOrID(OBJ, TERM_OR_ID_OR_NAME)
            %
            %   Overrides the base class method to provide specific lookup functionality
            %   for EFO using the EBI OLS API via static helper methods.
            %
            %   The input TERM_OR_ID_OR_NAME is the part after the 'EFO:' prefix.
            %   (e.g., '0002677' for saline, or 'saline' for a name search).
            %
            %   Example Usage (via dispatcher):
            %   [id, name, ~, def] = ndi.ontology.lookup('EFO:0002677'); % Saline
            %   [id, name, ~, def] = ndi.ontology.lookup('EFO:drug'); % Drug search
            
            % Define ontology specifics for EFO
            ontology_prefix = 'EFO';
            ontology_name_ols = 'efo'; % OLS uses 'efo' as the ontology ID
            
            % --- Step 1: Preprocess Input using Base Class Static Helper ---
            try
                [search_query, search_field, lookup_type_msg, ~] = ...
                    ndi.ontology.preprocessLookupInput(term_or_id_or_name, ontology_prefix);
            catch ME
                baseME = MException('ndi:ontology:EFO:PreprocessingError', ...
                    'Error preprocessing EFO lookup input "%s".', term_or_id_or_name);
                baseME = addCause(baseME, ME);
                throw(baseME);
            end

            % --- Step 2: Perform Search and IRI Lookup ---
            try
                % search_query will be 'EFO:0002677' for numeric IDs or 'saline' for labels
                [id, name, definition, synonyms] = ...
                    ndi.ontology.searchOLSAndPerformIRILookup(...
                        search_query, search_field, ontology_name_ols, ontology_prefix, lookup_type_msg);
            catch ME
                baseME = MException('ndi:ontology:EFO:LookupFailed', ...
                    'EFO lookup failed for %s.', lookup_type_msg);
                baseME = addCause(baseME, ME);
                throw(baseME);
            end
        end % function lookupTermOrID
    end % methods
end % classdef EFO