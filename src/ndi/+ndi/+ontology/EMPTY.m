classdef EMPTY < ndi.ontology
% EMPTY - NDI Ontology object for a remote experimental ontology (EMPTY).
%   Inherits from ndi.ontology and implements lookupTermOrID for EMPTY
%   by reading from a GitHub-hosted .owl file.

    properties (Constant)
        ONTOLOGY_PREFIX = 'EMPTY';
        % The RAW URL ensures we get the RDF/XML content directly
        OWL_URL_MAIN = 'https://raw.githubusercontent.com/Waltham-Data-Science/empty-ontology/main/empty-base.owl';
        OWL_URL_DEV = 'https://raw.githubusercontent.com/Waltham-Data-Science/empty-ontology/development/src/ontology/empty-edit.owl';
    end

    methods
        function obj = EMPTY()
            % EMPTY - Constructor (no local path resolution needed)
        end 

        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name_fragment)
            % lookupTermOrID - Search for a term in the remote OWL files
            %   This method first checks the MAIN branch, and if the term is not found,
            %   it falls back to checking the DEVELOPMENT branch.

            % 1. Try to fetch from the MAIN branch
            try
                [id, name, definition, synonyms] = obj.performRemoteLookup(obj.OWL_URL_MAIN, term_or_id_or_name_fragment);
                return; % If successful, exit the function here
            catch ME
                % If the error isn't "TermNotFound", it might be a network issue.
                % We proceed to try DEV regardless.
                fprintf('Term "%s" not found in MAIN branch. Checking DEVELOPMENT branch...\n', term_or_id_or_name_fragment);
            end

            % 2. Try to fetch from the DEVELOPMENT branch
            try
                [id, name, definition, synonyms] = obj.performRemoteLookup(obj.OWL_URL_DEV, term_or_id_or_name_fragment);
            catch ME
                % If it fails here too, throw a final exception combining the attempts
                baseME = MException('ndi:ontology:EMPTY:LookupFailed', ...
                    'EMPTY remote lookup failed for input "%s" in both Main and Dev branches.', term_or_id_or_name_fragment);
                baseME = addCause(baseME, ME);
                throw(baseME);
            end
        end 
    end

    methods (Access = private)
        function [id, name, definition, synonyms] = performRemoteLookup(obj, url, term_or_id_or_name_fragment)
            % Internal helper to handle fetching, parsing, and searching the XML
            
            id = ''; name = ''; definition = ''; synonyms = {};
            
            % 1. Fetch the OWL content from GitHub
            options = weboptions('Timeout', 30, 'ContentType', 'text');
            owl_xml_string = webread(url, options);
            
            % 2. Parse XML into a Document Object using a temp file
            temp_file = [tempname '.owl'];
            fid = fopen(temp_file, 'w', 'n', 'UTF-8');
            fprintf(fid, '%s', owl_xml_string);
            fclose(fid);
            
            xDoc = xmlread(temp_file);
            delete(temp_file); % Clean up temp file
            
            % 3. Search for the term in owl:Class elements
            classes = xDoc.getElementsByTagName('owl:Class');
            found = false;
            
            for k = 0:classes.getLength-1
                thisClass = classes.item(k);
                
                % Get the URI (e.g., http://purl.obolibrary.org/obo/EMPTY_0000085)
                uri = char(thisClass.getAttribute('rdf:about'));
                
                % Extract the fragment after the last / or _
                tokens = regexp(uri, 'EMPTY_(\d+)$', 'tokens');
                if ~isempty(tokens)
                    shortId = tokens{1}{1}; % Result: '0000085'
                else
                    shortId = uri;
                end
                
                % Get Label (Name) via rdfs:label
                labels = thisClass.getElementsByTagName('rdfs:label');
                thisName = '';
                if labels.getLength > 0
                    thisName = char(labels.item(0).getTextContent());
                end
                
                % Match Logic: Match against the numeric ID or the Name
                is_id_match = strcmpi(shortId, term_or_id_or_name_fragment);
                is_name_match = strcmpi(thisName, term_or_id_or_name_fragment);
                
                if is_id_match || is_name_match
                    id = [obj.ONTOLOGY_PREFIX ':' shortId];
                    name = thisName;
                    
                    % Get Definition via standard OBO definition tag (IAO_0000115)
                    % Fallback to rdfs:comment if IAO is missing
                    defs = thisClass.getElementsByTagName('obo:IAO_0000115');
                    if defs.getLength == 0
                        defs = thisClass.getElementsByTagName('rdfs:comment');
                    end
                    
                    if defs.getLength > 0
                        definition = char(defs.item(0).getTextContent());
                    end
                    
                    % Get Synonyms (Standard OBO synonym tags)
                    synTags = {'oboInOwl:hasExactSynonym', 'oboInOwl:hasRelatedSynonym'};
                    for t = 1:length(synTags)
                        synNodes = thisClass.getElementsByTagName(synTags{t});
                        for s = 0:synNodes.getLength-1
                            synonyms{end+1} = char(synNodes.item(s).getTextContent());
                        end
                    end
                    
                    found = true;
                    break;
                end
            end
            
            % If the loop completes without finding the term, throw error to trigger fallback
            if ~found
                error('ndi:ontology:EMPTY:TermNotFound', 'Term not found.');
            end
        end
    end 
end