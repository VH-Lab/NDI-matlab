% file: +ndi/+setup/+conv/+birren/SubjectInformationCreator.m
classdef SubjectInformationCreator < ndi.setup.NDIMaker.SubjectInformationCreator
% BIRREN.SUBJECTINFORMATIONCREATOR - Creates NDI subject information for the Birren Lab.
%
% This class implements the 'create' method to generate subject identifiers
% and species/strain objects based on the specific metadata structure used in the
% Birren Lab's experimental tables.
%
    methods
        function [subjectIdentifier, strain, species, biologicalSex] = create(obj, tableRow)
            % CREATE - Generates subject data from a Birren Lab table row.
            %
            %   [SUBJECTIDENTIFIER, STRAIN, SPECIES, BIOLOGICALSEX] = CREATE(OBJ, TABLEROW)
            %
            %   This method processes a single row from a table to generate a unique
            %   subject identifier and associated species/strain information. A subject
            %   is defined by the date and the cell number.
            %
            %   Inputs:
            %       obj (ndi.setup.conv.birren.SubjectInformationCreator) - The instance of this creator class.
            %       tableRow (table) - A single row from a MATLAB table. It must contain the columns
            %                          'ExperimentDateString', 'cellNumber', and 'strain'.
            %
            %   Outputs:
            %       subjectIdentifier (char) - The unique local identifier for the subject
            %                                  (e.g., '2024_08_20_1@sjbirrenlab.brandeis.edu'). Returns NaN on failure.
            %       strain (openminds.core.research.Strain) - The strain object. Returns NaN on failure.
            %       species (openminds.controlledterms.Species) - The species object. Returns NaN on failure.
            %       biologicalSex (NaN) - Not used for this creator; returns NaN.
            %
            %   See also: ndi.setup.NDIMaker.SubjectInformationCreator
            %
                
                % --- Initialize Outputs ---
                subjectIdentifier = NaN;
                strain = NaN;
                species = NaN;
                biologicalSex = NaN;

                % --- Extract Values from Table Row ---
                try
                    % The values might be in cell arrays, so we use the utility to extract them
                    dateStr = ndi.util.unwrapTableCellContent(tableRow.ExperimentDateString);
                    cellNum = ndi.util.unwrapTableCellContent(tableRow.cellNumber);
                    % cellRecordNumber is not needed for the subject identifier
                    strain_val = ndi.util.unwrapTableCellContent(tableRow.strain);
                catch ME
                    warning('Could not extract required columns from the table row. Error: %s', ME.message);
                    return;
                end
                
                % --- Validate and Process Data ---
                if ischar(dateStr) && ~isempty(dateStr) && isnumeric(cellNum)
                    % dateStr is already in YYYY_MM_DD format
                    YYYY_MM_DD = dateStr; 
                    C = num2str(cellNum);

                    % --- Construct the Subject String in the new format ---
                    subjectIdentifier = [YYYY_MM_DD '_' C '@sjbirrenlab.brandeis.edu'];
                else
                    warning('Invalid data types in table row. Could not generate subject identifier.');
                    return; % Exit if we can't even make the identifier
                end

                % --- Create species object ---
                try
                    species = openminds.controlledterms.Species('name', 'Rattus norvegicus', ...
                        'preferredOntologyIdentifier', 'NCBITaxon:10116');
                catch ME
                    warning(['Failed to create openminds Species object: ' ME.message]);
                    species = NaN;
                    strain = NaN; % Strain depends on species, so it will also fail.
                    return;
                end
                
                % --- Create strain object ---
                strain_name = '';
                strain_id = '';
                if ischar(strain_val)
                    switch upper(strain_val)
                        case 'SHR'
                            strain_name = 'SHR';
                            strain_id = 'RRID:RGD_1357994';
                        case 'WKY'
                            strain_name = 'WKY';
                            strain_id = 'RRID:RGD_1358112';
                    end
                end

                if ~isempty(strain_name) && ~isempty(strain_id)
                    try
                        strain = openminds.core.research.Strain(...
                            'name', strain_name, ...
                            'species', species, ...
                            'ontologyIdentifier', strain_id);
                    catch ME
                        warning(['Failed to create openminds Strain object: ' ME.message]);
                        strain = NaN;
                    end
                else
                    warning('Strain value "%s" is not a recognized type (SHR or WKY).', strain_val);
                    strain = NaN;
                end
        end
    end % methods
end % classdef
