% Location: +ndi/+ontology/NDIC.m
classdef NDIC < ndi.ontology
% NDIC - NDI Ontology object for the local NDIC controlled vocabulary file.
%   Inherits from ndi.ontology and implements lookupTermOrID for the NDIC text file.

    methods
        function obj = NDIC()
            % NDIC - Constructor for the NDIC ontology object.
            % Implicitly calls the superclass constructor ndi.ontology().
        end % constructor

        function [id, name, definition, synonyms] = lookupTermOrID(obj, term_or_id_or_name)
            % LOOKUPTERMORID - Looks up a term in the NDIC ontology file by ID or name.
            %
            %   [ID, NAME, DEFINITION, SYNONYMS] = lookupTermOrID(OBJ, TERM_OR_ID_OR_NAME)
            %
            %   Overrides the base class method to provide specific lookup
            %   functionality for the NDIC ontology using the local text file.
            %
            %   The input TERM_OR_ID_OR_NAME is the part of the original lookup string
            %   after the 'NDIC:' prefix has been removed (e.g., '8' or 'Postnatal day').
            %
            %   See also: ndi.ontology.lookup (static dispatcher)

            % Get cached data table via private static method
            ndicData = ndi.ontology.NDIC.getNDICData();
            original_input_remainder = term_or_id_or_name; % For error messages

            % Initialize Outputs
            id = ''; name = ''; definition = ''; synonyms = {};

            % Determine if input REMINDER looks like a numeric ID
            [inputNum, isNumericID] = str2num(original_input_remainder);
            % Ensure str2num succeeded and result is a scalar number
            isNumericID = isNumericID && isscalar(inputNum);

            % --- Perform Lookup ---
            rowIndex = [];
            if isNumericID
                % --- Path 1: Lookup by Numeric ID ---
                rowIndex = find(ndicData.Identifier == inputNum, 1, 'first');
                if isempty(rowIndex)
                    error('ndi:ontology:NDIC:IDNotFound', ...
                          'NDIC term with Identifier "%s" not found.', original_input_remainder);
                end
            else
                % --- Path 2: Lookup by Name (Case-Insensitive) ---
                name_to_lookup = original_input_remainder; % Remainder is the name
                match_indices = find(strcmpi(ndicData.Name, name_to_lookup));
                num_matches = numel(match_indices);

                if num_matches == 0
                    error('ndi:ontology:NDIC:NameNotFound', ...
                          'NDIC term with Name "%s" not found (case-insensitive).', name_to_lookup);
                elseif num_matches > 1
                    error('ndi:ontology:NDIC:NameNotUnique', ...
                          'Name "%s" matches multiple (%d) entries in NDIC ontology. Lookup requires a unique name.', name_to_lookup, num_matches);
                else
                    % Exactly one match found
                    rowIndex = match_indices;
                end
            end

            % --- Extract Data if Found ---
            if ~isempty(rowIndex)
                try
                    id = num2str(ndicData.Identifier(rowIndex)); % Return ID as char
                    name = char(ndicData.Name(rowIndex)); % Return canonical Name from table
                    definition = char(ndicData.Description(rowIndex)); % Return Description
                    synonyms = {}; % Always empty for NDIC
                catch ME_extract
                     error('ndi:ontology:NDIC:DataExtractionError', ...
                           'Error extracting data for input "%s" at row %d. Error: %s', original_input_remainder, rowIndex, ME_extract.message);
                end
            else
                 % This part should not be reached if logic above is correct
                 error('ndi:ontology:NDIC:InternalError', ...
                       'Internal error: Could not find index for input "%s".', original_input_remainder);
            end

        end % function lookupTermOrID

    end % methods

    methods (Static, Access = private)
        % --- Helper function to load/cache NDIC data ---
        function ndicDataTable = getNDICData()
            persistent ndicDataCache; % Cache data within this static method

            if isempty(ndicDataCache)
                fprintf('Loading NDIC ontology from file...\n');
                ontologyFilePath = ''; % Initialize
                try
                    % Use constants from base class for path components
                    ontologyFilePath = fullfile(ndi.common.PathConstants.CommonFolder,...
                        ndi.ontology.ONTOLOGY_SUBFOLDER_NDIC,...
                        ndi.ontology.NDIC_FILENAME);
                catch ME_path
                    error('ndi:ontology:NDIC:PathConstantError', ...
                          'Could not access ndi.common.PathConstants.CommonFolder. Ensure NDI paths are set up correctly. Original error: %s', ME_path.message);
                end

                if ~isfile(ontologyFilePath) % Use isfile
                    error('ndi:ontology:NDIC:FileNotFound', ...
                          'NDIC ontology file not found at: %s', ontologyFilePath);
                end
                try
                    opts = delimitedTextImportOptions('Delimiter', '\t', 'VariableNamingRule', 'preserve');
                    opts.VariableNames = {'Identifier', 'Name', 'Description'};
                    opts.VariableTypes = {'double', 'string', 'string'};
                    opts = setvartype(opts, {'Name','Description'}, 'string');
                    opts.DataLines = [2, Inf];

                    loadedData = readtable(ontologyFilePath, opts);

                    if ~all(ismember({'Identifier', 'Name', 'Description'}, loadedData.Properties.VariableNames))
                         error('ndi:ontology:NDIC:FileFormatError', ...
                               'NDIC ontology file "%s" does not contain expected columns.', ontologyFilePath);
                    end
                    if height(loadedData) == 0
                         error('ndi:ontology:NDIC:FileEmpty', ...
                               'NDIC ontology file "%s" contains no data rows.', ontologyFilePath);
                    end
                    ndicDataCache = loadedData; % Store in persistent cache
                    fprintf('NDIC ontology loaded successfully.\n');
                catch ME_read
                    ndicDataCache = []; % Clear cache on error
                    error('ndi:ontology:NDIC:FileReadError', ...
                          'Failed to read or parse NDIC ontology file "%s". Error: %s', ontologyFilePath, ME_read.message);
                end
            end
            ndicDataTable = ndicDataCache; % Return cached or newly loaded data
        end

        % --- Custom Validation Function (copied from old function) ---
        % Although input validation primarily happens in ndi.ontology.lookup now,
        % keeping it here might be useful if this class is ever instantiated directly.
        % Or it could be removed if direct instantiation is disallowed/discouraged.
        function mustBeValidInputType(input)
            if ~(isnumeric(input) && isscalar(input) || ischar(input) || (isstring(input) && isscalar(input)))
                error('ndi:ontology:NDIC:InvalidInputType', ...
                      'Input must be a scalar number, character vector, or string scalar.');
            end
        end

    end % methods (Static, Access = private)

end % classdef NDIC