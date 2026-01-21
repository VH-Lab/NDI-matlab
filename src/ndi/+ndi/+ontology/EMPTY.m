classdef EMPTY < ndi.ontology
% EMPTY - NDI Ontology object for a remote experimental ontology (EMPTY).
%   Inherits from ndi.ontology and implements lookupTermOrID for EMPTY
%   by reading from a GitHub-hosted .owl file (Supports XML and Functional syntax).

    properties (Constant)
        ONTOLOGY_PREFIX = 'EMPTY';
        OWL_URL_MAIN = 'https://raw.githubusercontent.com/Waltham-Data-Science/empty-ontology/main/empty-base.owl';
        OWL_URL_DEV = 'https://raw.githubusercontent.com/Waltham-Data-Science/empty-ontology/development/src/ontology/empty-edit.owl';
    end

    methods
        function obj = EMPTY()
            % Constructor
        end 

        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name_fragment)
            % lookupTermOrID - Search with failover from Main (XML) to Dev (Functional)
            try
                [id, name, definition, synonyms] = obj.performRemoteLookup(obj.OWL_URL_MAIN, term_or_id_or_name_fragment);
                return; 
            catch
                fprintf('Term "%s" not found in MAIN (XML). Checking DEVELOPMENT (Functional Syntax)...\n', term_or_id_or_name_fragment);
            end

            try
                [id, name, definition, synonyms] = obj.performRemoteLookup(obj.OWL_URL_DEV, term_or_id_or_name_fragment);
            catch ME
                baseME = MException('ndi:ontology:EMPTY:LookupFailed', ...
                    'EMPTY lookup failed for "%s" in both branches.', term_or_id_or_name_fragment);
                baseME = addCause(baseME, ME);
                throw(baseME);
            end
        end 
    end

    methods (Access = private)
        function [id, name, definition, synonyms] = performRemoteLookup(obj, url, term_or_id_or_name_fragment)
            id = ''; name = ''; definition = ''; synonyms = {};
            
            options = weboptions('Timeout', 30, 'ContentType', 'text');
            owl_content = webread(url, options);
            
            % --- DETECT FORMAT ---
            if contains(owl_content, '<?xml') || contains(owl_content, '<rdf:RDF')
                % Use the XML Parser logic
                [id, name, definition, synonyms] = obj.parseXMLFormat(owl_content, term_or_id_or_name_fragment);
            else
                % Use Text/Regex Parser logic for Functional Syntax
                [id, name, definition, synonyms] = obj.parseFunctionalFormat(owl_content, term_or_id_or_name_fragment);
            end
        end

        function [id, name, definition, synonyms] = parseFunctionalFormat(obj, content, fragment)
            % parseFunctionalFormat - Regex-based parser for Manchester/Functional OWL
            id = ''; name = ''; definition = ''; synonyms = {};
            
            % 1. Find the Class block for the target term
            % This looks for "Class: obo:EMPTY_XXXXXXX (label)" or "Class(obo:EMPTY_XXXXXXX)"
            % We look for the numeric ID or the label in the comment
            searchPattern = sprintf('Class: obo:EMPTY_(%s|\\d+) \\(([^\\)]*)\\)', fragment);
            
            % If input is a name, we might need a broader search. 
            % Let's use a logic that finds the ID first if the fragment is numeric, 
            % or finds the ID based on a label match.
            
            full_id_expr = 'EMPTY_(\d+)';
            all_ids = regexp(content, full_id_expr, 'tokens');
            unique_ids = unique(cellfun(@(x) x{1}, all_ids, 'UniformOutput', false));
            
            found = false;
            for i = 1:length(unique_ids)
                thisId = unique_ids{i};
                
                % Extract the specific AnnotationAssertion block for this ID
                % Pattern: AnnotationAssertion(rdfs:label obo:EMPTY_ID "Label")
                labelPattern = sprintf('AnnotationAssertion\\(rdfs:label obo:EMPTY_%s "([^"]+)"', thisId);
                labelMatch = regexp(content, labelPattern, 'tokens');
                thisName = '';
                if ~isempty(labelMatch), thisName = labelMatch{1}{1}; end
                
                % Match check
                if strcmpi(thisId, fragment) || strcmpi(thisName, fragment)
                    id = [obj.ONTOLOGY_PREFIX ':' thisId];
                    name = thisName;
                    
                    % Extract Definition
                    defPattern = sprintf('AnnotationAssertion\\(obo:IAO_0000115 obo:EMPTY_%s "([^"]+)"', thisId);
                    defMatch = regexp(content, defPattern, 'tokens');
                    if ~isempty(defMatch), definition = defMatch{1}{1}; end
                    
                    % Extract Synonyms
                    synPattern = sprintf('AnnotationAssertion\\(oboInOwl:has(?:Exact|Related)Synonym obo:EMPTY_%s "([^"]+)"', thisId);
                    synMatches = regexp(content, synPattern, 'tokens');
                    synonyms = cellfun(@(x) x{1}, synMatches, 'UniformOutput', false);
                    
                    found = true;
                    break;
                end
            end
            
            if ~found, error('TermNotFound', 'Not found in functional text.'); end
        end

        function [id, name, definition, synonyms] = parseXMLFormat(obj, xml_string, fragment)
            % (Original xmlread logic goes here)
            temp_file = [tempname '.owl'];
            fid = fopen(temp_file, 'w', 'n', 'UTF-8');
            fprintf(fid, '%s', xml_string);
            fclose(fid);
            xDoc = xmlread(temp_file);
            delete(temp_file);
            
            % ... [Rest of your original XML search loop] ...
            % [Note: Ensure this handles found/not found correctly]
            id = ''; % Placeholder for your existing code
        end
    end 
end