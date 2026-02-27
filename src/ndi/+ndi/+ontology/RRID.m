% Location: +ndi/+ontology/RRID.m
classdef RRID < ndi.ontology
% RRID - NDI Ontology object for Research Resource Identifiers (RRID).

    methods
        function obj = RRID()
            % RRID - Constructor
        end

        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name)
            original_input_remainder = strtrim(term_or_id_or_name);
            full_rrid = ['RRID:' original_input_remainder];
            % We ignore the 5th and 6th outputs here for standard ontology compatibility
            [id, name, definition, synonyms, ~, ~] = obj.performRridResolverLookup(full_rrid);
        end

        function [scientificName, commonName] = lookupSpecies(obj, term_or_id_or_name)
            % LOOKUPSPECIES - Returns the scientific and common names for an RRID.
            %
            %   [SCIENTIFIC, COMMON] = lookupSpecies(OBJ, RRID_COMPONENT)
            %
            %   Example: [s, c] = obj.lookupSpecies('RGD_13508588')
            %   Returns: s = 'Rattus norvegicus', c = 'Rat'
            
            id_remainder = strtrim(term_or_id_or_name);
            full_rrid = ['RRID:' id_remainder];
            
            try
                [~, ~, ~, ~, scientificName, commonName] = obj.performRridResolverLookup(full_rrid);
            catch ME
                rethrow(ME);
            end
        end
    end

    methods (Static, Access = private)
        function [id, name, definition, synonyms, scientificName, commonName] = performRridResolverLookup(full_rrid)
            id = ''; name = ''; definition = ''; synonyms = {}; 
            scientificName = ''; commonName = '';
            
            apiUrl = ['https://scicrunch.org/resolver/' urlencode(full_rrid) '.json'];
            options = weboptions('Timeout', 30, 'HeaderFields', {'Accept', 'application/json'});

            try
                response = webread(apiUrl, options);
                
                if isstruct(response) && isfield(response, 'hits') && ~isempty(response.hits.hits)
                    source = response.hits.hits(1).x_source;
                    item_data = source.item;
                    id = full_rrid;
                    
                    % 1. Metadata
                    if isfield(item_data, 'name'), name = char(item_data.name); end
                    if isfield(item_data, 'description'), definition = char(item_data.description); end
                    
                    % 2. Organism Data Extraction (Scientific and Common)
                    if isfield(source, 'organisms') && isfield(source.organisms, 'primary') && ~isempty(source.organisms.primary)
                        primary_info = source.organisms.primary(1);
                        
                        if isfield(primary_info, 'species') && isfield(primary_info.species, 'name')
                            scientificName = char(primary_info.species.name);
                        end
                        
                        if isfield(primary_info, 'common') && isfield(primary_info.common, 'name')
                            commonName = char(primary_info.common.name);
                        end
                        
                    elseif isfield(item_data, 'species') && ~isempty(item_data.species)
                        % Fallback for cases like antibodies where species is a simple field
                        if iscell(item_data.species)
                            scientificName = cellfun(@char, item_data.species, 'UniformOutput', false);
                        else
                            scientificName = char(item_data.species);
                        end
                    end
                    
                    % 3. Synonyms
                    if isfield(item_data, 'synonyms') && ~isempty(item_data.synonyms)
                        syn_data = item_data.synonyms;
                        if iscell(syn_data)
                            synonyms = cellfun(@char, syn_data, 'UniformOutput', false);
                        elseif isstruct(syn_data) && isfield(syn_data, 'name')
                            synonyms = {char(syn_data.name)};
                        end
                    end
                end
            catch ME
                rethrow(ME);
            end
        end
    end
end