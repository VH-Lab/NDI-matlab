% Location: +ndi/+ontology/EDAM.m
classdef EDAM < ndi.ontology
% EDAM - NDI Ontology object for the EDAM ontology.
%   Inherits from ndi.ontology and implements lookupTermOrID for EDAM.
%   EDAM is an ontology of data analysis and management in life sciences.
%
%   This class supports multiple lookup formats:
%     1. Numeric IDs: '1929'
%     2. CURIEs: 'format:1929' or 'data:0000'
%     3. Full Namespace IDs: 'EDAM:format_1929'
%     4. Term Names: 'FASTA' or 'Sequence alignment' (case-insensitive)
%
%   EDAM uses sub-ontology prefixes in its OBO IDs (format, data,
%   operation, topic) rather than the top-level 'EDAM' prefix. For
%   example, the FASTA format has IRI http://edamontology.org/format_1929.
%
%   This class downloads and parses the EDAM OWL file directly from
%   GitHub, bypassing the OLS search API for reliability.
%
%   See also: http://edamontology.org
%             https://github.com/edamontology/edamontology

    properties (Constant, Access = private)
        ONTOLOGY_PREFIX = 'EDAM';
        % Raw OWL file from the EDAM GitHub releases
        OWL_URL = 'https://raw.githubusercontent.com/edamontology/edamontology/main/EDAM_dev.owl';
        % EDAM IRI base used in OWL rdf:about attributes
        IRI_BASE = 'http://edamontology.org/';
    end

    methods
        function obj = EDAM()
            % Constructor for the EDAM ontology object.
        end

        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name)
            % LOOKUPTERMORID - Looks up a term in the EDAM ontology.
            %
            %   Downloads and caches the EDAM OWL file from GitHub, then
            %   searches by numeric ID, prefixed ID, or label name.
            %
            %   Example:
            %   [id, name] = ndi.ontology.lookup('format:1929');      % Numeric match
            %   [id, name] = ndi.ontology.lookup('EDAM:format_1929'); % Namespace match
            %   [id, name] = ndi.ontology.lookup('FASTA');           % Name match

            persistent edamCache;
            if isempty(edamCache)
                edamCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end

            % Parse and cache the EDAM terms if not already present
            cacheKey = 'edam_terms';
            if ~isKey(edamCache, cacheKey)
                terms = ndi.ontology.EDAM.downloadAndParseEDAM();
                edamCache(cacheKey) = terms;
            end
            terms = edamCache(cacheKey);

            if isempty(terms)
                error('ndi:ontology:EDAM:NoTerms', ...
                    'EDAM ontology file contained no parseable terms.');
            end

            % --- Determine if input is a numeric ID or a name ---
            % Regex captures digits at the end, ignoring "EDAM:", "format:", "format_", etc.
            id_match = regexp(term_or_id_or_name, '(?:EDAM:)?(?:[a-z]+[:_])?(\d+)$', 'tokens', 'once');
            
            if ~isempty(id_match)
                search_value = id_match{1}; 
                isIDSearch = true;
            else
                search_value = term_or_id_or_name;
                isIDSearch = false;
            end

            found = false;
            id = ''; name = ''; definition = ''; synonyms = {};

            for i = 1:numel(terms)
                t = terms(i);
                if isIDSearch
                    % Match by the numeric portion (e.g., '1929')
                    if strcmp(t.numeric_id, search_value)
                        found = true;
                    end
                else
                    % Match by label name or synonyms (case-insensitive)
                    if strcmpi(t.name, search_value) || any(strcmpi(t.synonyms, search_value))
                        found = true;
                    end
                end

                if found
                    id = [obj.ONTOLOGY_PREFIX ':' t.numeric_id];
                    name = t.name;
                    definition = t.definition;
                    synonyms = t.synonyms;
                    break;
                end
            end

            if ~found
                error('ndi:ontology:EDAM:LookupFailed', ...
                    'EDAM lookup failed for input "%s".', term_or_id_or_name);
            end
        end
    end

    methods (Static, Access = private)
        function terms = downloadAndParseEDAM()
            %DOWNLOADANDPARSEEDAM Download EDAM OWL and extract terms.
            terms = struct('numeric_id', {}, 'sub_prefix', {}, ...
                           'name', {}, 'definition', {}, 'synonyms', {});
            options = weboptions('Timeout', 60, 'ContentType', 'text');
            try
                owl_content = webread(ndi.ontology.EDAM.OWL_URL, options);
            catch ME
                error('ndi:ontology:EDAM:DownloadFailed', ...
                    'Failed to download EDAM OWL file: %s', ME.message);
            end

            % Extract owl:Class blocks with EDAM IRIs
            iri_base_escaped = regexptranslate('escape', ndi.ontology.EDAM.IRI_BASE);
            class_pattern = ['(?s)<owl:Class\s+rdf:about="' iri_base_escaped '([^"]+)">(.*?)</owl:Class>'];
            class_blocks = regexp(owl_content, class_pattern, 'tokens');

            for i = 1:numel(class_blocks)
                local_id = class_blocks{i}{1};   % e.g., 'format_1929'
                content  = class_blocks{i}{2};

                % Parse local_id into sub_prefix and numeric_id
                id_parts = regexp(local_id, '^(\w+)_(\d+)$', 'tokens', 'once');
                if isempty(id_parts)
                    continue; 
                end
                sub_prefix = id_parts{1};
                numeric_id = id_parts{2};

                % Extract label
                label_match = regexp(content, '(?s)<rdfs:label[^>]*>([^<]+)</rdfs:label>', 'tokens', 'once');
                thisName = '';
                if ~isempty(label_match)
                    thisName = strtrim(ndi.ontology.EDAM.unescapeXML(label_match{1}));
                end

                % Skip deprecated terms
                if contains(content, '>true<') && contains(content, 'deprecated')
                    continue;
                end

                % Extract definition
                thisDef = '';
                def_match = regexp(content, '(?s)<oboInOwl:hasDefinition[^>]*>.*?<rdfs:label[^>]*>([^<]+)</rdfs:label>.*?</oboInOwl:hasDefinition>', 'tokens', 'once');
                if isempty(def_match)
                    def_match = regexp(content, '(?s)<obo:IAO_0000115[^>]*>([^<]+)</obo:IAO_0000115>', 'tokens', 'once');
                end
                if ~isempty(def_match)
                    thisDef = strtrim(ndi.ontology.EDAM.unescapeXML(def_match{1}));
                end

                % Extract synonyms
                syn_matches = regexp(content, '(?s)<oboInOwl:has(?:Exact|Narrow|Related|Broad)Synonym[^>]*>([^<]+)</oboInOwl:has(?:Exact|Narrow|Related|Broad)Synonym>', 'tokens');
                thisSynonyms = {};
                if ~isempty(syn_matches)
                    thisSynonyms = cellfun(@(x) strtrim(ndi.ontology.EDAM.unescapeXML(x{1})), ...
                        syn_matches, 'UniformOutput', false);
                end

                % Add to terms array
                idx = numel(terms) + 1;
                terms(idx).numeric_id = numeric_id;
                terms(idx).sub_prefix = sub_prefix;
                terms(idx).name = thisName;
                terms(idx).definition = thisDef;
                terms(idx).synonyms = thisSynonyms;
            end
        end

        function str = unescapeXML(str)
            %UNESCAPEXML Handle common XML entities
            str = strrep(str, '&apos;', '''');
            str = strrep(str, '&quot;', '"');
            str = strrep(str, '&amp;', '&');
            str = strrep(str, '&lt;', '<');
            str = strrep(str, '&gt;', '>');
            str = strtrim(str);
        end
    end
end