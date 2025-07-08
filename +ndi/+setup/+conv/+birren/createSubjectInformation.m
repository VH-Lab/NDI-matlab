function [subjectString, strain, species, biologicalSex] = createSubjectInformation(tableRow)
    % CREATESUBJECTINFORMATION - Creates subject ID string and openMINDS objects for Birren lab data.
    %
    %   [subjectString, strain, species, biologicalSex] = ndi.setup.conv.birren.createSubjectInformation(tableRow)
    %
    %   This function processes a single row from a Birren lab information table,
    %   generating a unique subject identifier string and corresponding openMINDS objects
    %   for the species and strain. This function is modeled on the prototype from
    %   ndi.setup.conv.dabrowska.createSubjectInformation.
    %
    %   The function derives a unique 'subjectIdentifier' for each entry by combining the
    %   first 13 characters of the 'filename' column and the 'strain' (e.g., '2024_09_27_01_SHR').
    %
    %   Args:
    %       tableRow (table): A 1xN MATLAB table (single row). Must contain at least
    %                         the columns 'filename' and 'strain'.
    %
    %   Returns:
    %       subjectString (char | NaN):
    %           - A character array string for the subject identifier.
    %           - Returns NaN if the required columns are missing or data is invalid.
    %       strain (openminds.core.research.Strain | NaN):
    %           - An openMINDS Strain object for 'SHR' or 'WKY' strains.
    %           - Returns NaN if the strain is unknown or if object creation fails.
    %       species (openminds.controlledterms.Species | NaN):
    %           - An openMINDS Species object, hardcoded to 'Rattus norvegicus'.
    %           - Returns NaN if object creation fails.
    %       biologicalSex (NaN):
    %           - Returns NaN as biological sex is not specified in the source data.
    %
    
    arguments
        tableRow (1,:) table
    end

    % Initialize outputs to NaN for error handling
    subjectString = NaN;
    strain = NaN;
    species = NaN;
    biologicalSex = NaN;

    % --- Helper function to extract value from table cell ---
    function val = get_val(data)
        if iscell(data)
            val = data{1};
        else
            val = data;
        end
    end

    % --- Validate required columns ---
    requiredCols = {'filename', 'strain'};
    if ~all(ismember(requiredCols, tableRow.Properties.VariableNames))
        missing = strjoin(setdiff(requiredCols, tableRow.Properties.VariableNames), ', ');
        warning(['Input table is missing required columns: ' missing]);
        return;
    end

    % --- Extract data from table row ---
    filename_val = get_val(tableRow.filename);
    strain_val = get_val(tableRow.strain);
    
    if ~ischar(filename_val) || numel(filename_val) < 13 || ~ischar(strain_val)
        warning('Invalid or missing data in filename or strain columns.');
        return;
    end

    % --- 1. Create subjectString ---
    subjectString = [filename_val(1:13) '_' strain_val];

    % --- 2. Create species object ---
    try
        species = openminds.controlledterms.Species('name', 'Rattus norvegicus', ...
            'preferredOntologyIdentifier', 'NCBITaxon:10116');
    catch ME
        warning(['Failed to create openminds Species object: ' ME.message]);
        species = NaN;
        strain = NaN; % Strain depends on species, so it will also fail.
        return;
    end
    
    % --- 3. Create strain object ---
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
            warning(['Unknown strain ''' strain_val '''. Cannot create strain object.']);
            strain = NaN;
            return;
    end

    try
        strain = openminds.core.research.Strain('name', strain_name, ...
            'ontologyIdentifier', {strain_id}, 'species', species);
    catch ME
        warning(['Failed to create openminds Strain object: ' ME.message]);
        strain = NaN;
    end

    % --- 4. Handle Biological Sex ---
    % Data not available in the Birren lab table, so we return NaN as per the prototype.
    biologicalSex = NaN;

end

