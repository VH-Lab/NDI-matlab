% file: +ndi/+setup/+NDIMaker/+SubjectInformationCreator/dabrowska.m
classdef dabrowska < ndi.setup.NDIMaker.SubjectInformationCreator
% DABROWSKA - Creates NDI subject information for the Dabrowska Lab.
%
% This class implements the 'create' method to generate subject identifiers
% and openMINDS objects based on the specific metadata structure used in the
% Dabrowska Lab's experimental tables.
%
    methods
        function [subjectIdentifier, strain, species, biologicalSex] = create(obj, tableRow)
            % CREATE - Generates subject data from a Dabrowska Lab table row.
            %
            %   [SUBJECTIDENTIFIER, STRAIN, SPECIES, BIOLOGICALSEX] = CREATE(OBJ, TABLEROW)
            %
            %   This method processes a single row from a table, enforcing Dabrowska Lab
            %   specific rules, such as genotype exclusivity, to generate a unique
            %   subject identifier and corresponding openMINDS objects.
            %
            %   Inputs:
            %       obj (ndi.setup.NDIMaker.SubjectInformationCreator.dabrowska) - The instance of this creator class.
            %       tableRow (table) - A single row from a MATLAB table. It must contain the columns
            %                          defined in the arguments block below.
            %
            %   Outputs:
            %       subjectIdentifier (char) - The unique local identifier string for the subject.
            %                                  Returns NaN on failure.
            %       strain (openminds.core.research.Strain) - The corresponding openMINDS strain object.
            %                                                   Returns NaN if not applicable or on failure.
            %       species (openminds.controlledterms.Species) - The openMINDS species object.
            %                                                       Returns NaN on failure.
            %       biologicalSex (openminds.controlledterms.BiologicalSex) - The openMINDS biological sex object.
            %                                                                   Returns NaN if not specified or on failure.
            %
            %   See also: ndi.setup.NDIMaker.SubjectInformationCreator
            %
                
                % Validate table properties and required columns directly here
                if ~all(ismember({'IsWildType', 'IsCRFCre', 'IsOTRCre', 'IsAVPCre', ...
                    'RecordingDate', 'SubjectPostfix', 'SpeciesOntologyID', 'sessionID','BiologicalSex'},...
                    tableRow.Properties.VariableNames))
                    error('ndi:validators:MissingRequiredColumns',...
                    'The tableRow is missing one or more required columns for the dabrowska subject creator.');
                end

                % --- Initialize Outputs ---
                subjectIdentifier = NaN;
                strain = NaN;
                species = NaN;
                biologicalSex = NaN;
                sp = NaN; % Local variable for the species object used in strain creation

                % --- Extract Values using Helper Function ---
                sessionIDValue = obj.extractTableCellValue(tableRow, 'sessionID');
                isWildTypeValue = obj.extractTableCellValue(tableRow, 'IsWildType');
                isCRFCreValue = obj.extractTableCellValue(tableRow, 'IsCRFCre'); 
                isOTRCreValue = obj.extractTableCellValue(tableRow, 'IsOTRCre'); 
                isAVPCreValue = obj.extractTableCellValue(tableRow, 'IsAVPCre'); 
                recordingDateValue = obj.extractTableCellValue(tableRow, 'RecordingDate');
                subjectPostfixValue = obj.extractTableCellValue(tableRow, 'SubjectPostfix');
                speciesOntologyIDValue = obj.extractTableCellValue(tableRow, 'SpeciesOntologyID');
                biologicalSexValue = obj.extractTableCellValue(tableRow, 'BiologicalSex');

                % --- Validate sessionID ---
                if ~(ischar(sessionIDValue) && ~isempty(sessionIDValue))
                    warning('ndi:createSubjectInformation:InvalidSessionID',...
                        ['sessionID did not resolve to a non-empty character array (type: %s). ' ...
                        'Returning NaN for all outputs.'], class(sessionIDValue));
                    return;
                end

                % --- Check Genotype Exclusivity ---
                genotypeValues = {isWildTypeValue, isCRFCreValue, isOTRCreValue, isAVPCreValue};
                genotypeNames = {'IsWildType', 'IsCRFCre', 'IsOTRCre', 'IsAVPCre'}; 
                isValidGenotype = cellfun(@(x) ischar(x) && ~isempty(x), genotypeValues);

                if sum(isValidGenotype) ~= 1
                    warning('ndi:createSubjectInformation:GenotypeIssue',...
                        ['Expected exactly one valid genotype indicator from (%s). Found %d. ' ...
                        'Returning NaN for subjectString.'], ...
                        strjoin(genotypeNames, ', '), sum(isValidGenotype));
                    return; 
                end
                
                validGenotypeName = genotypeNames{isValidGenotype}; 
                prefix = obj.getPrefix(validGenotypeName);

                % --- Validate and Process RecordingDate and SubjectPostfix ---
                if ~(ischar(recordingDateValue) && ~isempty(recordingDateValue))
                    warning('ndi:createSubjectInformation:InvalidDateInput',...
                        'RecordingDate did not resolve to valid text for genotype %s. Returning NaN outputs.', validGenotypeName);
                    return;
                end
                 if ~(ischar(subjectPostfixValue) && ~isempty(subjectPostfixValue))
                     warning('ndi:createSubjectInformation:InvalidPostfixInput',...
                         'SubjectPostfix did not resolve to valid text. Returning NaN outputs.');
                    return;
                end

                % --- Convert Date Format ---
                try
                    datetimeObj = datetime(recordingDateValue, 'InputFormat', 'MMM dd yyyy');
                    formattedDate = char(datetimeObj, 'yyMMdd');
                catch
                    warning('ndi:createSubjectInformation:DateFormatError',...
                        'Could not parse RecordingDate "%s". Returning NaN outputs.', recordingDateValue);
                    return;
                end

                % --- Construct the Subject String ---
                subjectIdentifier = [prefix, formattedDate, subjectPostfixValue];

                % --- Populate openMINDS Objects ---
                species = obj.lookupSpecies(speciesOntologyIDValue);
                strain = obj.getStrain(validGenotypeName, species);
                biologicalSex = obj.lookupSex(biologicalSexValue);
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

        function prefix = getPrefix(genotypeName)
            % Returns the appropriate subject ID prefix based on genotype.
            switch genotypeName
                case 'IsWildType', prefix = 'sd_rat_WT_';
                case 'IsCRFCre',   prefix = 'wi_rat_CRFCre_';
                case 'IsOTRCre',   prefix = 'sd_rat_OTRCre_';
                case 'IsAVPCre',   prefix = 'sd_rat_AVPCre_';
                otherwise,         prefix = 'unknown_';
            end
        end

        function species_obj = lookupSpecies(speciesOntologyID)
            % Creates an openminds species object.
            species_obj = NaN;
            if ischar(speciesOntologyID) && ~isempty(speciesOntologyID)
                try
                    sp_temp = openminds.controlledterms.Species;
                    sp_temp.name = "Rattus norvegicus"; % Hardcoded for this lab
                    sp_temp.preferredOntologyIdentifier = speciesOntologyID;
                    species_obj = sp_temp;
                catch ME
                     warning('ndi:createSubjectInformation:SpeciesCreationFailed',...
                         'Could not create openMINDS Species object: %s', ME.message);
                end
            end
        end

        function strain_obj = getStrain(genotypeName, species_obj)
            % Creates an openminds strain object based on genotype and species.
            strain_obj = NaN;
            if ~isa(species_obj, 'openminds.controlledterms.Species'), return; end

            try
                st_sd = openminds.core.research.Strain('name', "SD", 'species', species_obj, ...
                    'ontologyIdentifier', "RRID:RGD_70508", 'geneticStrainType', "wildtype");
                st_wi = openminds.core.research.Strain('name', "WI", 'species', species_obj, ...
                    'ontologyIdentifier', "RRID:RGD_13508588", 'geneticStrainType', "wildtype");
                
                st_trans = openminds.core.research.Strain('species', species_obj, 'geneticStrainType', "knockin");

                switch genotypeName
                    case 'IsWildType'
                         strain_obj = st_sd;
                    case {'IsOTRCre', 'IsAVPCre'}
                         if strcmp(genotypeName, 'IsOTRCre'), st_trans.name = 'OTR-IRES-Cre';
                         else, st_trans.name = 'AVP-Cre'; end
                         st_trans.backgroundStrain = st_sd;
                         strain_obj = st_trans;
                    case 'IsCRFCre'
                         st_trans.name = 'CRF-Cre';
                         st_trans.backgroundStrain = st_wi;
                         strain_obj = st_trans;
                end 
            catch ME
                warning('ndi:createSubjectInformation:StrainCreationFailed',...
                    'Could not create openMINDS Strain object for genotype %s: %s', genotypeName, ME.message);
            end
        end

        function sex_obj = lookupSex(sex_string)
            % Creates an openminds biological sex object.
            sex_obj = NaN;
            if ischar(sex_string)
                switch(lower(sex_string))
                    case 'female'
                        sex_obj = openminds.controlledterms.BiologicalSex('name','female','preferredOntologyIdentifier','PATO:0000383');
                    case 'male'
                        sex_obj = openminds.controlledterms.BiologicalSex('name','male','preferredOntologyIdentifier','PATO:0000384');
                end
            end
        end

    end % private static methods

end % classdef
