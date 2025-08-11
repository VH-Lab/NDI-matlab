% Location: +ndi/+ontology/NCIT.m
classdef NCIT < ndi.ontology
% NCIT - NDI Ontology object for the National Cancer Institute Thesaurus (NCIT).
%   Inherits from ndi.ontology and implements lookupTermOrID for NCIT.
%   NCIT is a comprehensive thesaurus covering cancer-related terminology.
%
%   See also: http://obofoundry.org/ontology/ncit.html
%             https://www.ebi.ac.uk/ols4/ontologies/ncit
    methods
        function obj = NCIT()
            % NCIT - Constructor for the NCIT ontology object.
            % Implicitly calls the superclass constructor ndi.ontology().
        end % constructor
        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name)
            % LOOKUPTERMORID - Looks up a term in the NCIT ontology.
            %
            %   [ID, NAME, DEFINITION, SYNONYMS] = lookupTermOrID(OBJ, TERM_OR_ID_OR_NAME)
            %
            %   Overrides the base class method to provide specific lookup functionality
            %   for the NCIT ontology using the EBI OLS API via static helper methods
            %   from the ndi.ontology base class.
            %
            %   The input TERM_OR_ID_OR_NAME is the part of the original lookup string
            %   after the 'NCIT:' prefix has been removed (e.g., 'C9523' for an ID,
            %   or 'Neoplasm' for a name/label search).
            %
            %   Example Usage (after being called by ndi.ontology.lookup):
            %   [id, name, ~, def] = ndi.ontology.lookup('NCIT:C9523'); % Stage I Esophageal Cancer
            %   [id, name, ~, def] = ndi.ontology.lookup('NCIT:Neoplasm'); % Neoplasm
            %
            %   See also: ndi.ontology.lookup (static dispatcher),
            %             ndi.ontology.preprocessLookupInput (static helper),
            %             ndi.ontology.searchOLSAndPerformIRILookup (static helper)
            
            % Define ontology specifics for NCIT
            ontology_prefix = 'NCIT';
            ontology_name_ols = 'ncit'; % OLS uses 'ncit' as the ontology ID

            % --- Step 1: Preprocess Input using Base Class Static Helper ---
            % The standard preprocessing logic in preprocessLookupInput should handle
            % NCIT's common "PREFIX:ID" or "PREFIX:Label" formats correctly.
            % It will determine if search_field should be 'obo_id' or 'label'.
            try
                % Call static method using full class name qualification
                [search_query, search_field, lookup_type_msg, ~] = ...
                    ndi.ontology.preprocessLookupInput(term_or_id_or_name, ontology_prefix);
            catch ME
                baseME = MException('ndi:ontology:NCIT:PreprocessingError', ...
                    'Error preprocessing NCIT lookup input "%s".', term_or_id_or_name);
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
                        ['NCIT:',search_query], 'obo_id', ontology_name_ols, ontology_prefix, lookup_type_msg);
            catch ME
                baseME = MException('ndi:ontology:NCIT:LookupFailed', ...
                    'NCIT lookup failed for %s.', lookup_type_msg);
                baseME = addCause(baseME, ME);
                throw(baseME);
            end
        end % function lookupTermOrID
    end % methods
end % classdef NCIT