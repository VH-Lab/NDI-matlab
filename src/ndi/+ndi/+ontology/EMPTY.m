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
            mainError = [];
            try
                [id, name, definition, synonyms] = obj.performRemoteLookup(obj.OWL_URL_MAIN, term_or_id_or_name_fragment);
                return; 
            catch ME
                mainError = ME;
            end

            % If we are here, MAIN lookup failed (TermNotFound or connection issue).
            % Try the DEVELOPMENT branch, but only if it exists.

            try
                [id, name, definition, synonyms] = obj.performRemoteLookup(obj.OWL_URL_DEV, term_or_id_or_name_fragment);
                return;
            catch ME
                % If DEV branch doesn't exist (404), skip it and return original error or a clean failure.
                % GitHub raw URLs return "404: Not Found" for missing branches.
                is404 = contains(ME.message, '404') || contains(ME.message, 'Not Found');

                if is404
                    if ~isempty(mainError), throw(mainError);
                    else, error('ndi:ontology:EMPTY:LookupFailed', 'EMPTY lookup failed for "%s".', term_or_id_or_name_fragment);
                    end
                end

                % If it was some other error (e.g., TermNotFound in DEV), combine them
                baseME = MException('ndi:ontology:EMPTY:LookupFailed', ...
                    'EMPTY lookup failed for "%s" in both MAIN and DEVELOPMENT branches.', term_or_id_or_name_fragment);
                if ~isempty(mainError), baseME = addCause(baseME, mainError); end
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
            % parseXMLFormat - Robust Regex-based parser for OWL/XML
            id = ''; name = ''; definition = ''; synonyms = {};

            % Extract Class blocks using a regex that handles newlines and attributes
            class_blocks = regexp(xml_string, '(?s)<owl:Class\s+rdf:about=["'']([^"'']*)["'']>(.*?)</owl:Class>', 'tokens');
            
            found = false;
            for i = 1:length(class_blocks)
                about_url = class_blocks{i}{1};
                content = class_blocks{i}{2};

                % Extract numeric ID from URL (e.g., .../EMPTY_0000001)
                id_tokens = regexp(about_url, 'EMPTY_(\d+)', 'tokens');
                if isempty(id_tokens), continue; end
                thisId = id_tokens{1}{1};

                % Extract Label: <rdfs:label ...>Label Text</rdfs:label>
                % Handle potential xml:lang or other attributes
                label_match = regexp(content, '(?s)<rdfs:label[^>]*>(.*?)</rdfs:label>', 'tokens');
                thisName = '';
                if ~isempty(label_match), thisName = obj.unescapeXML(label_match{1}{1}); end

                % Check for match: numeric ID match or exact label match
                if strcmpi(thisId, fragment) || strcmpi(thisName, fragment)
                    id = [obj.ONTOLOGY_PREFIX ':' thisId];
                    name = thisName;

                    % Extract Definition: <obo:IAO_0000115>...</obo:IAO_0000115>
                    def_match = regexp(content, '(?s)<obo:IAO_0000115[^>]*>(.*?)</obo:IAO_0000115>', 'tokens');
                    if ~isempty(def_match), definition = obj.unescapeXML(def_match{1}{1}); end

                    % Extract Synonyms: <oboInOwl:hasExactSynonym ...>...</oboInOwl:hasExactSynonym>
                    syn_matches = regexp(content, '(?s)<oboInOwl:has(?:Exact|Related)Synonym[^>]*>(.*?)</oboInOwl:has(?:Exact|Related)Synonym>', 'tokens');
                    synonyms = cellfun(@(x) obj.unescapeXML(x{1}), syn_matches, 'UniformOutput', false);

                    found = true;
                    break;
                end
            end

            if ~found, error('TermNotFound', 'Term "%s" not found in XML format.', fragment); end
        end

        function str = unescapeXML(obj, str)
            % unescapeXML - Helper to handle common XML entities in labels/definitions
            str = strrep(str, '&apos;', '''');
            str = strrep(str, '&quot;', '"');
            str = strrep(str, '&amp;', '&');
            str = strrep(str, '&lt;', '<');
            str = strrep(str, '&gt;', '>');
            % Remove any remaining tags if they somehow leaked in
            str = regexprep(str, '<[^>]*>', '');
            str = strtrim(str);
        end
    end 
end