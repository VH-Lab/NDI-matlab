function [subjectString, strain, species, biologicalSex] = createSubjectInformation(tableRow)
%CREATESUBJECTINFORMATION Creates subject ID string and openMINDS objects for species/strain/sex.
%
%   [subjectString, strain, species, biologicalSex] = CREATESUBJECTINFORMATION(tableRow)
%
%   Generates a subject identifier string and openMINDS objects based on
%   multiple columns in the input table row. It handles columns that may
%   contain cell arrays or direct numeric/string values. It enforces
%   exclusivity among genotype indicator columns and requires a valid sessionID.
%   Output text values are char. Biological sex output is currently always NaN.
%
%   Depends on the external validation function: ndi.validators.mustHaveRequiredColumns
%
%   Args:
%       tableRow (table): A 1xN MATLAB table (single row). Argument validation
%                         ensures it contains AT LEAST the columns:
%                         'IsWildType', 'IsCRFCre', 'IsOTRCre', 'IsAVPCre',
%                         'RecordingDate', 'SubjectPostfix', 'SpeciesOntologyID',
%                         'sessionID', and 'BiologicalSex'.
%                         Columns may contain cell arrays (value in first cell used)
%                         or direct numeric/string/char values (e.g., NaN, "text", 'text').
%                         Genotype columns: Exactly ONE must resolve to non-empty char.
%                         sessionID column: Must resolve to a non-empty char array or string.
%
%   Returns:
%       subjectString (char | NaN):
%           - A character array string with a prefix determined by the valid
%             genotype column, followed by the formatted date and SubjectPostfix.
%           - Returns numeric NaN if prerequisites fail (e.g., invalid sessionID,
%             genotype, date, or postfix).
%       strain (openminds.core.research.Strain | NaN):
%           - An openMINDS Strain object determined by the valid genotype column
%             and requires valid 'SpeciesOntologyID'.
%           - Returns numeric NaN if prerequisites fail or object creation fails.
%       species (openminds.controlledterms.Species | NaN):
%           - An openMINDS Species object (hardcoded 'Rattus norvegicus') if
%             'SpeciesOntologyID' resolves to a non-empty char array.
%           - Returns numeric NaN otherwise or if object creation fails.
%       biologicalSex (openminds.controlledterms.BiologicalSex | NaN):
%             If 'BiologicalSex' is present and is
%             'male','female','hermaphrodite' or 'notDetectable',
%             BiologicalSex is returned as
%             openminds.controlledterms.BiologicalSex. Otherwise, NaN is
%             returned.

    arguments
        % Validate table properties and required columns directly here
        tableRow (1, :) table {mustBeNonempty, ... % Must be 1 row, non-empty
                 ndi.validators.mustHaveRequiredColumns(tableRow, ... % Call validator
                 {'IsWildType', 'IsCRFCre', 'IsOTRCre', 'IsAVPCre', ... % Hard-coded cols
                  'RecordingDate', 'SubjectPostfix', 'SpeciesOntologyID', 'sessionID','BiologicalSex'})}
    end

    % --- Initialize Outputs ---
    subjectString = NaN;
    strain = NaN;
    species = NaN;
    biologicalSex = NaN; % Initialized to NaN
    sp = NaN; % Local variable for the species object used in strain creation

    % --- Extract Values using Helper Function ---
    % Helper ensures strings are cast to char arrays if extracted as string type.
    sessionIDValue = extractTableCellValue(tableRow, 'sessionID'); % Extract sessionID first
    isWildTypeValue = extractTableCellValue(tableRow, 'IsWildType');
    isCRFCreValue = extractTableCellValue(tableRow, 'IsCRFCre'); 
    isOTRCreValue = extractTableCellValue(tableRow, 'IsOTRCre'); 
    isAVPCreValue = extractTableCellValue(tableRow, 'IsAVPCre'); 
    recordingDateValue = extractTableCellValue(tableRow, 'RecordingDate');
    subjectPostfixValue = extractTableCellValue(tableRow, 'SubjectPostfix');
    speciesOntologyIDValue = extractTableCellValue(tableRow, 'SpeciesOntologyID');
    biologicalSexValue = extractTableCellValue(tableRow, 'BiologicalSex');

    % --- Validate sessionID ---
    % Must be a non-empty character array or string.
    if ~(ischar(sessionIDValue) && ~isempty(sessionIDValue))
        warning('ndi:createSubjectInformation:InvalidSessionID',...
            ['sessionID did not resolve to a non-empty character array (type: %s). ' ...
            'Returning NaN for all outputs.'], class(sessionIDValue));
        return; % Return initial NaN values for all outputs.
    end

    % --- Check Genotype Exclusivity ---
    % Expects exactly one of the genotype indicators to be a non-empty char array.
    genotypeValues = {isWildTypeValue, isCRFCreValue, isOTRCreValue, isAVPCreValue};
    genotypeNames = {'IsWildType', 'IsCRFCre', 'IsOTRCre', 'IsAVPCre'}; 
    isValidGenotype = cellfun(@(x) ischar(x) && ~isempty(x), genotypeValues);

    if sum(isValidGenotype) ~= 1
        % If not exactly one valid genotype indicator is found, issue a warning
        % and return with subjectString (and other outputs) as NaN.
        warning('ndi:createSubjectInformation:GenotypeIssue',...
            ['Expected exactly one valid genotype indicator from (%s). Found %d. ' ...
            'Returning NaN for subjectString.'], ...
            strjoin(genotypeNames, ', '), sum(isValidGenotype));
        return; 
    end

    % Identify the valid genotype and set the prefix for subjectString.
    validGenotypeName = genotypeNames{isValidGenotype}; 

    switch validGenotypeName
        case 'IsWildType'
            prefix = 'sd_rat_WT_';
        case 'IsCRFCre' 
            prefix = 'wi_rat_CRFCre_';
        case 'IsOTRCre' 
            prefix = 'sd_rat_OTRCre_';
        case 'IsAVPCre' 
            prefix = 'sd_rat_AVPCre_';
        otherwise 
             error('ndi:createSubjectInformation:InternalGenotypeError', 'Unexpected valid genotype identified.');
    end

    % --- Validate and Process RecordingDate and SubjectPostfix ---
    % These must be non-empty char arrays to proceed.
    if ~(ischar(recordingDateValue) && ~isempty(recordingDateValue))
        escaped_genotype = strrep(validGenotypeName, '%', '%%'); % Escape for sprintf
        warning('ndi:createSubjectInformation:InvalidDateInput',...
            ['RecordingDate did not resolve to valid text for genotype %s. ' ...
            'Returning NaN outputs.'], escaped_genotype);
        return; % Return initial NaN values.
    end
     if ~(ischar(subjectPostfixValue) && ~isempty(subjectPostfixValue))
         warning('ndi:createSubjectInformation:InvalidPostfixInput',...
             ['SubjectPostfix did not resolve to valid text (expected non-empty char, got type %s). ' ...
             'Returning NaN outputs.'], class(subjectPostfixValue));
        return; % Return initial NaN values.
    end

    % --- Convert Date Format ---
    % Parse the recordingDateValue and reformat it to 'yyMMdd'.
    try
        inputDateFormat = 'MMM dd yy'; % Example: "Apr 01 2021" - Note: yy for 2-digit year, YYYY for 4-digit
        datetimeObj = datetime(recordingDateValue, 'InputFormat', inputDateFormat);
        outputDateFormat = 'yyMMdd'; % Example: "210401"
        formattedDate = char(datetimeObj, outputDateFormat); % Convert datetime to char array in specified format
    catch ME_DateFormat
        escaped_date_val = strrep(recordingDateValue, '%', '%%');
        escaped_msg = strrep(ME_DateFormat.message, '%', '%%');
        warning('ndi:createSubjectInformation:DateFormatError',...
            'Could not parse RecordingDate "%s" with format "%s". Error: %s. Returning NaN outputs.', ...
                escaped_date_val, inputDateFormat, escaped_msg);
        return; % Return initial NaN values.
    end

    % --- Construct the Subject String ---
    % Concatenate prefix, formatted date, and postfix.
    subjectString_temp = string(prefix) + formattedDate + string(subjectPostfixValue);
    subjectString = char(subjectString_temp); % Ensure final output is a char array.

    % --- Populate Species openMINDS Object ---
    % Create species object if SpeciesOntologyID is valid text.
    isSpeciesOntologyIDValid = ischar(speciesOntologyIDValue) && ~isempty(speciesOntologyIDValue);
    if isSpeciesOntologyIDValid
        try
            sp_temp = openminds.controlledterms.Species;
            sp_temp.name = "Rattus norvegicus"; % Hardcoded
            sp_temp.preferredOntologyIdentifier = "NCBITaxon:10116"; % Hardcoded
            species = sp_temp;
            sp = species; % For use in strain creation
        catch ME_SpeciesCreate
             escaped_message = strrep(ME_SpeciesCreate.message, '%', '%%');
             warning('ndi:createSubjectInformation:SpeciesCreationFailed',...
                 'Could not create openMINDS Species object. Error: %s', escaped_message);
             % species and sp remain NaN
        end
    else
         warning('ndi:createSubjectInformation:InvalidSpeciesOntologyID',...
             ['SpeciesOntologyID column (value type: %s) did not resolve to valid text' ...
             ' Cannot determine species or related strain.'], class(speciesOntologyIDValue));
         % species and sp remain NaN
    end

    % --- Populate Strain openMINDS Object ---
    % Depends on a valid species object ('sp').
    if ~isa(sp, 'openminds.controlledterms.Species')
        return; % Strain remains NaN if species is not valid.
    end

    try
        wt_strain_type = "wildtype"; 
        ki_strain_type = "knockin";
        
        st_sd = openminds.core.research.Strain('name', "SD", 'species', sp, ...
            'ontologyIdentifier', "RRID:RGD_70508", 'geneticStrainType', wt_strain_type);
        st_wi = openminds.core.research.Strain('name', "WI", 'species', sp, ...
            'ontologyIdentifier', "RRID:RGD_13508588", 'geneticStrainType', wt_strain_type);
        switch validGenotypeName
            case 'IsWildType'
                 strain = st_sd;
            case {'IsOTRCre', 'IsAVPCre'}
                 st_trans = openminds.core.research.Strain;
                 if strcmp(validGenotypeName, 'IsOTRCre') 
                     st_trans.name = 'OTR-IRES-Cre';
                 elseif strcmp(validGenotypeName, 'IsAVPCre') 
                     st_trans.name = 'AVP-Cre';
                 end
                 st_trans.species = sp;
                 st_trans.backgroundStrain = st_sd;
                 st_trans.geneticStrainType = ki_strain_type;
                 strain = st_trans;
            case 'IsCRFCre'
                 st_trans = openminds.core.research.Strain;
                 st_trans.name = 'CRF-Cre';
                 st_trans.species = sp;
                 st_trans.backgroundStrain = st_wi;
                 st_trans.geneticStrainType = ki_strain_type;
                 strain = st_trans;
        end 
    catch ME_StrainCreate
        escaped_genotype = strrep(validGenotypeName, '%', '%%');
        escaped_message = strrep(ME_StrainCreate.message, '%', '%%');
        warning('ndi:createSubjectInformation:StrainCreationFailed',...
            'Could not create openMINDS Strain object for genotype %s. Error: %s',...
            escaped_genotype, escaped_message);
        strain = NaN;
    end

    % --- Populate Biological Sex (Placeholder) ---
    % Create biologicalSex object if SpeciesOntologyID is valid text.
    isBiologicalSexValid = ismember(biologicalSexValue, {'male', 'female', 'hermaphrodite', 'notDetectable'});
    if isBiologicalSexValid
        ontologyIdentifiers = {'PATO:0000384','PATO:0000383','PATO:0001340',''};
        f = strcmp(biologicalSexValue,{'male', 'female', 'hermaphrodite', 'notDetectable'});
        biologicalSex = openminds.controlledterms.BiologicalSex('name',biologicalSexValue,'preferredOntologyIdentifier',ontologyIdentifiers{f});
    else
        biologicalSex = NaN;
    end


end % End function createSubjectInformation

% --- Nested Helper Function to Extract Table Cell Values ---
function value = extractTableCellValue(tblRow, colName)
    %EXTRACTTABLECELLVALUE Extracts value from a table cell, handling data type variations.
    %
    %   value = EXTRACTTABLECELLVALUE(tblRow, colName)
    %
    %   Retrieves content from the specified column 'colName' in the single-row
    %   table 'tblRow'. It handles cases where the content might be a direct value
    %   (numeric, char, string) or wrapped in a cell (potentially nested).
    %   If the extracted value is a MATLAB string, it's converted to a char array.
    %   If the cell is empty or contains an empty nested cell, NaN is returned.
    %
    %   Args:
    %       tblRow (table): A 1-row table.
    %       colName (char/string): The name of the column to extract from.
    %
    %   Returns:
    %       value (any): The extracted value (char, double, NaN, etc.).
    %                    Strings are returned as char arrays.

    content = tblRow.(colName); % Access column content using dynamic field name.
    value_intermediate = NaN;   % Default if cell is empty or extraction fails.

    if iscell(content) % If the column content is a cell array.
        if ~isempty(content) && numel(content) > 0 % Ensure the cell itself is not empty.
             % Handle potentially nested cells (common if data comes from mixed sources).
             if iscell(content{1}) && ~isempty(content{1}) && numel(content{1}) > 0
                 value_intermediate = content{1}{1}; % Extract from the inner cell.
             else
                 value_intermediate = content{1}; % Extract from the outer cell.
             end
        end
        % If the cell 'content' was empty, value_intermediate remains NaN.
    else % If the column content is not a cell.
        value_intermediate = content; % Use the content directly.
    end

    % --- Standardize Output: Cast MATLAB string to char array ---
    % This ensures downstream functions expecting char arrays work correctly.
    if isstring(value_intermediate)
        value = char(value_intermediate);
    else
        value = value_intermediate;
    end

end % extractTableCellValue