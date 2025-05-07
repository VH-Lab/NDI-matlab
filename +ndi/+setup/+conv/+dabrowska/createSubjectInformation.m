function [subjectString, strain, species, biologicalSex] = createSubjectInformation(tableRow)
%CREATESUBJECTINFORMATION Creates subject ID string and openMINDS objects for species/strain/sex.
%
%   [subjectString, strain, species, biologicalSex] = CREATESUBJECTINFORMATION(tableRow)
%
%   Generates a subject identifier string and openMINDS objects based on
%   multiple columns in the input table row. It handles columns that may
%   contain cell arrays or direct numeric/string values. It enforces
%   exclusivity among genotype indicator columns. Output text values are char.
%   Biological sex output is currently always NaN.
%
%   Depends on the external validation function: ndi.validators.mustHaveRequiredColumns
%
%   Args:
%       tableRow (table): A 1xN MATLAB table (single row). Argument validation
%                         ensures it contains AT LEAST the columns:
%                         'IsWildType', 'isCRFCre', 'isOTRCre', 'isAVPCre',
%                         'RecordingDate', 'SubjectPostfix', 'SpeciesOntologyID'.
%                         Columns may contain cell arrays (value in first cell used)
%                         or direct numeric/string/char values (e.g., NaN, "text", 'text').
%                         Genotype columns: Exactly ONE must resolve to non-empty char.
%
%   Returns:
%       subjectString (char | NaN):
%           - A character array string with a prefix determined by the valid
%             genotype column, followed by the formatted date and SubjectPostfix.
%           - Returns numeric NaN if prerequisites fail.
%       strain (openminds.core.research.Strain | NaN):
%           - An openMINDS Strain object determined by the valid genotype column
%             and requires valid 'SpeciesOntologyID'.
%           - Returns numeric NaN if prerequisites fail or object creation fails.
%       species (openminds.controlledterms.Species | NaN):
%           - An openMINDS Species object (hardcoded 'Rattus norvegicus') if
%             'SpeciesOntologyID' resolves to a non-empty char array.
%           - Returns numeric NaN otherwise or if object creation fails.
%       biologicalSex (NaN):
%           - Placeholder for biological sex information. Currently always
%             returns numeric NaN. Intended future type might be
%             e.g., openminds.controlledterms.BiologicalSex.

    arguments
        % Validate table properties and required columns directly here
        tableRow (1, :) table {mustBeNonempty, ... % Must be 1 row, non-empty
                 ndi.validators.mustHaveRequiredColumns(tableRow, ... % Call validator
                 {'IsWildType', 'isCRFCre', 'isOTRCre', 'isAVPCre', ... % Hard-coded cols
                  'RecordingDate', 'SubjectPostfix', 'SpeciesOntologyID'})} % Column list
    end

    % --- Initialize Outputs ---
    subjectString = NaN;
    strain = NaN;
    species = NaN;
    biologicalSex = NaN; % Added biologicalSex output, initialized to NaN
    sp = NaN; % Local variable for the species object used in strain creation

    % --- Extract Values using Helper Function ---
    % Helper now ensures strings are cast to char arrays
    isWildTypeValue = extractTableCellValue(tableRow, 'IsWildType');
    isCRFCreValue = extractTableCellValue(tableRow, 'isCRFCre');
    isOTRCreValue = extractTableCellValue(tableRow, 'isOTRCre');
    isAVPCreValue = extractTableCellValue(tableRow, 'isAVPCre');
    recordingDateValue = extractTableCellValue(tableRow, 'RecordingDate');
    subjectPostfixValue = extractTableCellValue(tableRow, 'SubjectPostfix');
    speciesOntologyIDValue = extractTableCellValue(tableRow, 'SpeciesOntologyID');

    % --- Check Genotype Exclusivity ---
    % Now operates correctly on extracted char arrays or other types (NaN)
    genotypeValues = {isWildTypeValue, isCRFCreValue, isOTRCreValue, isAVPCreValue};
    genotypeNames = {'IsWildType', 'isCRFCre', 'isOTRCre', 'isAVPCre'};
    isValidGenotype = cellfun(@(x) ischar(x) && ~isempty(x), genotypeValues);

    if sum(isValidGenotype) ~= 1
        error('createSubjectInformation:ExclusiveGenotypeViolation', ...
              'Exactly one genotype column (%s) must resolve to non-empty text. Found %d.', ...
              strjoin(genotypeNames, ', '), sum(isValidGenotype));
    end

    % Identify the valid genotype and set the prefix
    validGenotypeIndex = find(isValidGenotype);
    validGenotypeName = genotypeNames{validGenotypeIndex};

    switch validGenotypeName
        case 'IsWildType'
            prefix = 'sd_rat_wt_';
        case 'isCRFCre'
            prefix = 'sdwi_rat_CRFCre_';
        case 'isOTRCre'
            prefix = 'sdwi_rat_OTRCre_';
        case 'isAVPCre'
            prefix = 'sdwi_rat_AVPCre_';
        otherwise % Should not happen due to the check above
             error('createSubjectInformation:InternalError', 'Unexpected valid genotype identified.');
    end

    % --- Validate and Process RecordingDate and SubjectPostfix ---
    % Checks should now pass if data was originally string, as it's converted to char
    if ~(ischar(recordingDateValue) && ~isempty(recordingDateValue))
        warning('createSubjectInformation:InvalidDateInput', ...
                'RecordingDate did not resolve to valid text for %s. Returning NaN outputs.', validGenotypeName);
        % biologicalSex remains NaN
        return; % Return NaN defaults
    end
     if ~(ischar(subjectPostfixValue) && ~isempty(subjectPostfixValue))
         % This warning should no longer trigger for the 'string' case
         warning('createSubjectInformation:InvalidPostfixInput', ...
                'SubjectPostfix did not resolve to valid text. Expected non-empty char array, got "%s". Returning NaN outputs.', class(subjectPostfixValue));
        % biologicalSex remains NaN
        return; % Return NaN defaults
    end

    % --- Convert Date Format ---
    try
        % Ensure inputDateFormat matches the actual format of recordingDateValue
        inputDateFormat = 'MMM dd yyyy'; % Corrected year format specifier
        datetimeObj = datetime(recordingDateValue, 'InputFormat', inputDateFormat);
        outputDateFormat = 'yyMMdd'; % Using standard MM for month
        formattedDate = char(datetimeObj,outputDateFormat);
    catch ME_DateFormat
        warning('createSubjectInformation:DateFormatError', ...
                'Could not parse RecordingDate "%s" with format "%s". Error: %s. Returning NaN outputs.', ...
                recordingDateValue, inputDateFormat, ME_DateFormat.message); % recordingDateValue is now char
        % biologicalSex remains NaN
        return; % Return NaN defaults
    end

    % --- Construct the Subject String ---
    % Use string() for concatenation flexibility, then final char conversion
    subjectString_temp = string(prefix) + formattedDate + string(subjectPostfixValue);
    subjectString = char(subjectString_temp);

    % --- Populate Species (if SpeciesOntologyID resolved to valid char) ---
    isSpeciesOntologyIDValid = ischar(speciesOntologyIDValue) && ~isempty(speciesOntologyIDValue); % Check char value
    if isSpeciesOntologyIDValid
        try
            sp_temp = openminds.controlledterms.Species;
            sp_temp.name = "Rattus norvegicus"; % Hardcoded name
            sp_temp.preferredOntologyIdentifier = "NCBITaxon:10116"; % Hardcoded ID
            % To use the value from the table instead:
            % sp_temp.preferredOntologyIdentifier = string(speciesOntologyIDValue); % Convert char back to string if needed by openMINDS constructor/setter
            species = sp_temp;
            sp = species;
        catch ME_SpeciesCreate
             warning('createSubjectInformation:SpeciesCreationFailed', ...
                     'Could not create openMINDS Species object. Error: %s', ME_SpeciesCreate.message);
             % species remains NaN, sp remains NaN
        end
    else
         warning('createSubjectInformation:InvalidSpeciesOntologyID', ...
                 'SpeciesOntologyID column did not resolve to valid text. Cannot determine species or strain.');
         % species remains NaN, sp remains NaN
    end

    % --- Populate Strain (depends on valid genotype AND valid species) ---
    if ~isa(sp, 'openminds.controlledterms.Species')
        % biologicalSex remains NaN
        return; % Strain remains NaN
    end

    % Proceed with strain creation only if sp is a valid Species object
    try
        % Define common controlled term links (adjust lookupId/URI as needed)
        wt_strain_type = "wildtype"; % Using string directly as per user's version
        ki_strain_type = "knockin"; % Using string directly as per user's version

        switch validGenotypeName
            case 'IsWildType'
                 st_sd = openminds.core.research.Strain;
                 st_sd.name = "SD";
                 st_sd.species = sp;
                 st_sd.ontologyIdentifier = "RRID:RGD_70508";
                 st_sd.geneticStrainType = wt_strain_type;
                 strain = st_sd;

            case {'isCRFCre', 'isOTRCre', 'isAVPCre'} % Common background for transgenic lines
                 st_sd = openminds.core.research.Strain('name', "SD", 'species', sp, ...
                     'ontologyIdentifier', "RRID:RGD_70508", 'geneticStrainType', wt_strain_type);

                 st_wi = openminds.core.research.Strain('name', "WI", 'species', sp, ...
                     'ontologyIdentifier', "RRID:RGD_13508588", 'geneticStrainType', wt_strain_type);

                 st_trans = openminds.core.research.Strain;
                 st_trans.species = sp;
                 st_trans.backgroundStrain = [st_sd st_wi];
                 st_trans.geneticStrainType = ki_strain_type;

                 if strcmp(validGenotypeName, 'isCRFCre')
                     st_trans.name = 'CRF-Cre';
                 elseif strcmp(validGenotypeName, 'isOTRCre')
                     st_trans.name = 'OTR-IRES-Cre';
                 elseif strcmp(validGenotypeName, 'isAVPCre')
                     st_trans.name = 'AVP-Cre';
                 end
                 strain = st_trans;

        end % End switch validGenotypeName

    catch ME_StrainCreate
        warning('createSubjectInformation:StrainCreationFailed', ...
                'Could not create openMINDS Strain object for %s. Error: %s', validGenotypeName, ME_StrainCreate.message);
        strain = NaN;
        % biologicalSex remains NaN
    end

    % --- Populate Biological Sex (Placeholder) ---
    % Currently no logic, biologicalSex remains NaN as initialized.
    % TODO: Add logic here later if needed, e.g., based on another table column.


end % End function createSubjectInformation


% --- Nested Helper Function ---
function value = extractTableCellValue(tblRow, colName)
    % Extracts the value from a table cell, handling cell arrays vs direct values.
    % Ensures that extracted string data is returned as a char array.
    % Assumes tblRow is a 1-row table and colName exists.
    content = tblRow.(colName); % Use dynamic field access

    if iscell(content)
        if ~isempty(content) && numel(content) > 0 % Ensure cell is not empty
             % Check if the first element itself is a cell (nested cell)
             if iscell(content{1}) && ~isempty(content{1}) && numel(content{1}) > 0
                 value = content{1}{1}; % Extract from nested cell
             else
                 value = content{1}; % Take the first element
             end
        else
            value = NaN; % Return NaN if cell is empty
        end
    else
        value = content; % Assume the content itself is the value (e.g., NaN, double, char, string)
    end

    % --- Cast string to char ---
    % If the extracted value is a string, convert it to char for downstream checks
    if isstring(value)
        value = char(value);
    end

end % extractTableCellValue