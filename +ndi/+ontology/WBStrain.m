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
            % LOOKUPTERMORID - Looks up a strain in WormBase by its WBStrain ID.
            %
            %   [ID, NAME, DEFINITION, SYNONYMS] = lookupTermOrID(OBJ, TERM_OR_ID_OR_NAME)
            %
            %   This version uses the documented WormBase REST API at rest.wormbase.org
            %   to retrieve each data field from its specific endpoint using the strain's formal ID.
            
            id = ''; name = ''; definition = ''; synonyms = {};
            prefix = 'WBStrain';
            
            % This function requires the 8-digit numeric part of the ID.
            if isempty(regexp(term_or_id_or_name, '^\d{8}$', 'once'))
                 error('ndi:ontology:WBStrain:InvalidInput', 'Input "%s" is not the 8-digit numeric part of a WBStrain ID.', term_or_id_or_name);
            end

            % The API uses the full WBStrain ID in the URL
            full_id = [prefix term_or_id_or_name];
            
            % Use the secure HTTPS protocol and the correct base URL
            api_base_url = 'http://rest.wormbase.org/rest/widget/strain/';
            options = weboptions('Timeout', 30, 'ContentType', 'json');
            
            try
                % --- Make separate API calls for each required field ---
                
                % 1. Get Overview
                overview_url = [api_base_url full_id '/overview'];
                overview_response = webread(overview_url, options);
                overview = overview_response.fields;

                % 1. Get Name
                if isfield(overview, 'name') && isfield(overview.name, 'data') && ...
                        isfield(overview.name.data, 'label') && ~isempty(overview.name.data.label)
                    name = overview.name.data.label;
                else
                    error('ndi:ontology:WBStrain:APIParsingFailed', 'Could not extract name from API "label" field.');
                end

                definition_parts = {};

                % 2. Get Genotype (Required)
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

                % 3. Get Mutagen (Optional)
                if isfield(overview, 'mutagen') && isfield(overview.mutagen, 'data') && ~isempty(overview.mutagen.data)
                    definition_parts{end+1} = ['Mutagen: ' overview.mutagen.data];
                end
                
                % 4. Get Outcrossed (Optional)
                if isfield(overview, 'outcrossed') && isfield(overview.outcrossed, 'data') && ~isempty(overview.outcrossed.data)
                    definition_parts{end+1} = ['Outcrossed: ' overview.outcrossed.data];
                end

                % --- Assemble final definition string ---
                definition = strjoin(definition_parts, '. ');
                definition = replace(definition,'..','.');
                if ~endsWith(definition, '.') && ~isempty(definition)
                    definition = [definition '.'];
                end

                % Get Synonyms (Optional)
                if isfield(overview, 'other_names') && isfield(overview.other_names, 'data') && ~isempty(overview.other_names.data)
                    synonyms = overview.other_names.data;
                end
                
                id = [prefix ':' term_or_id_or_name];

            catch ME
                if contains(ME.message, '404') || contains(ME.message, 'Not Found')
                    error('ndi:ontology:WBStrain:IDNotFound', ...
                          'Data for strain ID "%s" not found via API. Please check the ID and API status.', full_id);
                else
                    baseME = MException('ndi:ontology:WBStrain:APILookupFailed', ...
                                        'An API call failed for WormBase Strain "%s".', full_id);
                    baseME = addCause(baseME, ME);
                    throw(baseME);
                end
            end
        end % function lookupTermOrID
    end % methods
end % classdef WBStrain