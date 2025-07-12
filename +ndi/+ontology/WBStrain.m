% Location: +ndi/+ontology/WBStrain.m
classdef WBStrain < ndi.ontology
% WBSTRAIN - NDI Ontology object for the WormBase Strain database.
%   Inherits from ndi.ontology and implements lookupTermOrID for WBStrain.
    methods
        function obj = WBStrain()
            % WBSTRAIN - Constructor for the WBStrain ontology object.
            % Implicitly calls the superclass constructor ndi.ontology().
        end % constructor
        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name)
            % LOOKUPTERMORID - Looks up a strain in WormBase by its ID or public name.
            %
            %   [ID, NAME, DEFINITION, SYNONYMS] = lookupTermOrID(OBJ, TERM_OR_ID_OR_NAME)
            %
            %   This version can resolve a strain name (e.g., 'N2') to its ID
            %   by scraping the WormBase search results page.
            
            id = ''; name = ''; definition = ''; synonyms = {};
            prefix = 'WBStrain';
            
            % --- Step 1: Resolve the input (name or ID) to a full WBStrain ID ---
            is_id_lookup = ~isempty(regexp(term_or_id_or_name, '^\d{8}$', 'once'));
            full_id = ''; % This will be populated by either branch

            if is_id_lookup
                % The input is a numeric ID. The case is simple.
                full_id = [prefix term_or_id_or_name];
            else
                % The input is a name. Scrape the search results page to find the ID.
                search_name = urlencode(term_or_id_or_name);
                search_url = ['https://wormbase.org/search/strain/' search_name '?inline=1'];
                options = weboptions('Timeout', 15);
                
                try
                    html = webread(search_url, options);
                    
                    % This pattern finds a link to a strain page where the link text
                    % exactly matches the strain name we're looking for.
                    id_match = regexp(html, '(WBStrain\d{8})', 'tokens', 'once');

                    if ~isempty(id_match)
                        full_id = id_match{1};
                    else
                        error('ndi:ontology:WBStrain:NameNotFound', 'Could not find a unique strain link for name "%s" on the search results page.', term_or_id_or_name);
                    end
                catch ME
                    if contains(ME.message, '404')
                         error('ndi:ontology:WBStrain:NameNotFound', 'Search page for strain name "%s" not found.', term_or_id_or_name);
                    else
                        baseME = MException('ndi:ontology:WBStrain:NameLookupFailed', ...
                                            'Failed to scrape search page for strain name "%s".', term_or_id_or_name);
                        baseME = addCause(baseME, ME);
                        throw(baseME);
                    end
                end
            end

            if isempty(full_id)
                error('Could not determine a valid WBStrain ID for lookup from input "%s".', term_or_id_or_name);
            end

            % --- Step 2: Use the resolved full_id to fetch details from the API ---
            api_base_url = 'http://rest.wormbase.org/rest/widget/strain/';
            options = weboptions('Timeout', 30, 'ContentType', 'json');
            
            try
                overview_url = [api_base_url full_id '/overview'];
                overview_response = webread(overview_url, options);
                overview = overview_response.fields;

                if isfield(overview, 'name') && isfield(overview.name, 'data') && ...
                        isfield(overview.name.data, 'label') && ~isempty(overview.name.data.label)
                    name = overview.name.data.label;
                else
                    error('ndi:ontology:WBStrain:APIParsingFailed', 'Could not extract name from API "label" field.');
                end
                
                definition_parts = {};
                
                if isfield(overview, 'genotype') && isfield(overview.genotype, 'data')
                    if isfield(overview.genotype.data, 'str') && ~isempty(overview.genotype.data.str)
                        definition_parts{end+1} = ['Genotype: ' overview.genotype.data.str];
                    end
                    if isfield(overview.genotype.data, 'data') && ~isempty(overview.genotype.data.data)
                        genotypeField = fields(overview.genotype.data.data);
                        for i = 1:numel(genotypeField)
                            genotypeData = overview.genotype.data.data.(genotypeField{i});
                            definition_parts{end+1} = [genotypeData.class,': ',...
                                genotypeData.label,' (',genotypeData.id,')'];
                        end
                    end
                else
                    error('ndi:ontology:WBStrain:APIParsingFailed', 'Could not extract genotype from API.');
                end
                
                if isfield(overview, 'mutagen') && isfield(overview.mutagen, 'data') && ~isempty(overview.mutagen.data)
                    definition_parts{end+1} = ['Mutagen: ' overview.mutagen.data];
                end
                
                if isfield(overview, 'outcrossed') && isfield(overview.outcrossed, 'data') && ~isempty(overview.outcrossed.data)
                    definition_parts{end+1} = ['Outcrossed: ' overview.outcrossed.data];
                end
                
                definition = strjoin(definition_parts, '. ');
                definition = replace(definition,'..','.');
                if ~endsWith(definition, '.') && ~isempty(definition)
                    definition = [definition '.'];
                end
                
                if isfield(overview, 'other_names') && isfield(overview.other_names, 'data') && ~isempty(overview.other_names.data)
                    synonyms = overview.other_names.data;
                end
                
                id = [full_id(1:numel(prefix)) ':' full_id(numel(prefix)+1:end)]; 
            catch ME
                if contains(ME.message, '404') || contains(ME.message, 'Not Found')
                    error('ndi:ontology:WBStrain:IDNotFound', ...
                          'Data for resolved strain ID "%s" not found via API. Please check the ID and API status.', full_id);
                else
                    baseME = MException('ndi:ontology:WBStrain:APILookupFailed', ...
                                        'An API call failed for WormBase Strain "%s".', full_id);
                    baseME = addCause(baseME, ME);
                    throw(baseME);
                end
            end
        end 
    end 
end