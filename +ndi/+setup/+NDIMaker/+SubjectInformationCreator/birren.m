% file: +ndi/+setup/+NDIMaker/+SubjectInformationCreator/birren.m
classdef birren < ndi.setup.NDIMaker.SubjectInformationCreator
% BIRREN - Creates NDI subject information for the Birren Lab.
%
% This class implements the 'create' method to generate subject identifiers
% and openMINDS objects based on the specific metadata structure used in the
% Birren Lab's experimental tables.
%
    methods
        function [subjectIdentifier, strain, species, biologicalSex] = create(obj, tableRow)
            % CREATE - Generates subject data from a Birren Lab table row.
            %
            %   [SUBJECTIDENTIFIER, STRAIN, SPECIES, BIOLOGICALSEX] = CREATE(OBJ, TABLEROW)
            %
            %   This method processes a single row from a table, enforcing Birren Lab
            %   specific rules to generate a unique subject identifier and corresponding
            %   openMINDS objects for species and strain.
            %
            %   Inputs:
            %       obj (ndi.setup.NDIMaker.SubjectInformationCreator.birren) - The instance of this creator class.
            %       tableRow (table) - A single row from a MATLAB table. It must contain 'filename',
            %                          'strain', and 'subject' columns.
            %
            %   Outputs:
            %       subjectIdentifier (char) - The unique local identifier string for the subject.
            %                                  Returns NaN on failure.
            %       strain (openminds.core.research.Strain) - The corresponding openMINDS strain object.
            %                                                   Returns NaN if not applicable or on failure.
            %       species (openminds.controlledterms.Species) - The openMINDS species object.
            %                                                       Returns NaN on failure.
            %       biologicalSex (NaN) - Not specified in this data; always returns NaN.
            %
            %   See also: ndi.setup.NDIMaker.SubjectInformationCreator
            %

            % --- Initialize Outputs ---
            [subjectIdentifier, strain, species, biologicalSex] = deal(NaN);

            % --- Validate required columns ---
            requiredCols = {'filename', 'strain', 'subject'};
            if ~all(ismember(requiredCols, tableRow.Properties.VariableNames))
                missing = strjoin(setdiff(requiredCols, tableRow.Properties.VariableNames), ', ');
                warning('ndi:setup:NDIMaker:birren:MissingColumns', ...
                    'Input table is missing required columns: %s. Cannot create subject.', missing);
                return;
            end

            % --- Extract data from table row ---
            filename_val = obj.extractTableCellValue(tableRow, 'filename');
            strain_val = obj.extractTableCellValue(tableRow, 'strain');
            subject_val = obj.extractTableCellValue(tableRow, 'subject');
            
            if ~ischar(filename_val) || numel(filename_val) < 13 || ~ischar(strain_val) || ~ischar(subject_val)
                warning('ndi:setup:NDIMaker:birren:InvalidData', ...
                    'Invalid or missing data in filename, strain, or subject columns.');
                return;
            end

            % --- Construct Subject Identifier ---
            subjectIdentifier = [filename_val(1:13) '_' strain_val '_' subject_val];

            % --- Create openMINDS objects ---
            species = obj.getSpecies();
            strain = obj.getStrain(strain_val, species);
            biologicalSex = NaN; % Not available in this dataset
        end
    end % methods

    methods (Access = private, Static)
        
        function value = extractTableCellValue(tblRow, colName)
            % Safely extracts a value from a table cell, handling nested cells.
            content = tblRow.(colName);
            if iscell(content) && ~isempty(content)
                value = content{1};
            else
                value = content;
            end
            if isstring(value), value = char(value); end
        end

        function species_obj = getSpecies()
            % Creates the openMINDS species object for Rattus norvegicus.
            species_obj = NaN;
            try
                species_obj = openminds.controlledterms.Species('name', 'Rattus norvegicus', ...
                    'preferredOntologyIdentifier', 'NCBITaxon:10116');
            catch ME
                warning('ndi:setup:NDIMaker:birren:SpeciesCreationFail', ...
                    'Failed to create openminds Species object: %s', ME.message);
            end
        end

        function strain_obj = getStrain(strain_val, species_obj)
            % Creates an openminds strain object based on the strain value.
            strain_obj = NaN;
            if ~isa(species_obj, 'openminds.controlledterms.Species'), return; end

            strain_name = '';
            strain_id = '';
            switch upper(strain_val)
                case 'SHR'
                    strain_name = 'SHR';
                    strain_id = 'RRID:RGD_1357994';
                case 'WKY'
                    strain_name = 'WKY';
                    strain_id = 'RRID:RGD_1358112';
                otherwise
                    warning('ndi:setup:NDIMaker:birren:UnknownStrain',...
                        'Unknown strain ''%s''. Cannot create strain object.', strain_val);
                    return;
            end

            try
                strain_obj = openminds.core.research.Strain('name', strain_name, ...
                    'ontologyIdentifier', {strain_id}, 'species', species_obj);
            catch ME
                warning('ndi:setup:NDIMaker:birren:StrainCreationFail',...
                    'Failed to create openminds Strain object: %s', ME.message);
                strain_obj = NaN;
            end
        end

    end % private static methods

end % classdef
