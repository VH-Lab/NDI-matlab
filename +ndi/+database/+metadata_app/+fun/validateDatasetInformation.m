function dsInfoOut = validateDatasetInformation(dsInfoIn, appHandle)
%VALIDATEDATASETINFORMATION Validates and corrects the datasetInformation structure.
%   Ensures fields like DataType, ExperimentalApproach, TechniquesEmployed
%   are cell arrays of strings, converting from comma-separated strings if necessary.

    if nargin < 2
        appHandle = []; 
    end

    isInitializingNew = false;
    if nargin < 1 || ~isstruct(dsInfoIn) || (isstruct(dsInfoIn) && isempty(fieldnames(dsInfoIn)) && numel(dsInfoIn) <=1 )
        dsInfoIn = struct(); 
        isInitializingNew = true;
        fprintf('DEBUG (validateDatasetInformation): Input dsInfoIn is empty/invalid, initializing new default structure.\n');
    end

    dsInfoOut = dsInfoIn; 

    emptyAuthorStruct = struct('givenName', '', 'familyName', '', ...
                             'contactInformation', struct('email', ''), ...
                             'digitalIdentifier', struct('identifier', ''), ...
                             'affiliation', repmat(struct('memberOf',struct('fullName','')),0,1), ...
                             'authorRole', {{}});
    
    defaultSpeciesStruct = struct('name','','preferredOntologyIdentifier','','synonym',{{}});
    emptySubjectBase = struct('SubjectName', '', 'BiologicalSexList', {{}}, ...
                              'SpeciesList', defaultSpeciesStruct, 'StrainList', {{}});
    emptyProbeBase = struct('Name', '', 'ClassType', ''); 

    dsInfoOut = ensureFieldLocal(dsInfoOut, 'DatasetFullName', '', @(x) ischar(x) || isstring(x));
    dsInfoOut = ensureStringFieldLocal(dsInfoOut, 'DatasetShortName', '');
    dsInfoOut = ensureStringFieldLocal(dsInfoOut, 'Description', '');
    dsInfoOut = ensureStringFieldLocal(dsInfoOut, 'Comments', '');
    dsInfoOut = ensureFieldLocal(dsInfoOut, 'ReleaseDate', NaT, @(x) (isdatetime(x) && (isscalar(x) || isempty(x))) || isnat(x) || isempty(x) );
    if isempty(dsInfoOut.ReleaseDate) && ~isnat(dsInfoOut.ReleaseDate)
        dsInfoOut.ReleaseDate = NaT;
    end
    
    defaultLicense = '';
    % ... (license default logic remains same) ...
    if ~isempty(appHandle) && isvalid(appHandle) && isprop(appHandle, 'LicenseDropDown') && ...
       isprop(appHandle.LicenseDropDown, 'ItemsData') && ~isempty(appHandle.LicenseDropDown.ItemsData)
        if numel(appHandle.LicenseDropDown.ItemsData) > 1 && ~isempty(appHandle.LicenseDropDown.ItemsData{2}) 
            defaultLicense = appHandle.LicenseDropDown.ItemsData{2}; 
        elseif numel(appHandle.LicenseDropDown.ItemsData) == 1 && ~isempty(appHandle.LicenseDropDown.ItemsData{1}) && appHandle.LicenseDropDown.ItemsData{1} ~= ""
             defaultLicense = appHandle.LicenseDropDown.ItemsData{1}; 
        end
    end
    dsInfoOut = ensureStringFieldLocal(dsInfoOut, 'License', defaultLicense);
    
    dsInfoOut = ensureStringFieldLocal(dsInfoOut, 'FullDocumentation', '');
    dsInfoOut = ensureStringFieldLocal(dsInfoOut, 'VersionIdentifier', '1.0.0');
    dsInfoOut = ensureStringFieldLocal(dsInfoOut, 'VersionInnovation', 'This is the first version of the dataset');

    expectedFundingFields = {'funder','awardTitle','awardNumber'};
    dsInfoOut.Funding = validateTableStructArrayLocal(dsInfoOut, 'Funding', expectedFundingFields);
    expectedPublicationFields = {'title','doi','pmid','pmcid'};
    dsInfoOut.RelatedPublication = validateTableStructArrayLocal(dsInfoOut, 'RelatedPublication', expectedPublicationFields);

    % --- Fields that should be cell arrays of strings (e.g., from trees, multi-selects) ---
    cellStrFields = {'DataType', 'ExperimentalApproach', 'TechniquesEmployed'};
    for k_csf = 1:numel(cellStrFields)
        fName = cellStrFields{k_csf};
        fprintf('DEBUG (validateDatasetInformation): Validating field "%s" to be cell array of strings.\n', fName);
        if ~isfield(dsInfoOut, fName)
            fprintf('DEBUG: Field "%s" not present, initializing as empty cell.\n', fName);
            dsInfoOut.(fName) = {};
        else
            currentVal = dsInfoOut.(fName);
            if ischar(currentVal) % Might be a comma-separated string from previous save
                if isempty(currentVal)
                    dsInfoOut.(fName) = {};
                     fprintf('DEBUG: Field "%s" was empty char, set to empty cell.\n', fName);
                else
                    % Split by comma, then trim whitespace.
                    % This assumes that individual items do not themselves contain ", "
                    splitVals = strsplit(currentVal, ', ');
                    dsInfoOut.(fName) = cellfun(@strtrim, splitVals, 'UniformOutput', false);
                    fprintf('DEBUG: Field "%s" (char) split into cell: %s\n', fName, strjoin(dsInfoOut.(fName), '|'));
                end
            elseif isstring(currentVal) % String array or scalar string
                if all(ismissing(currentVal)) || isempty(currentVal)
                    dsInfoOut.(fName) = {};
                else
                    dsInfoOut.(fName) = cellstr(currentVal); % Convert to cell array of char vectors
                    % If it was a scalar string that might have been comma-separated:
                    if numel(dsInfoOut.(fName)) == 1 && contains(dsInfoOut.(fName){1}, ', ')
                        splitVals = strsplit(dsInfoOut.(fName){1}, ', ');
                        dsInfoOut.(fName) = cellfun(@strtrim, splitVals, 'UniformOutput', false);
                    end
                end
                 fprintf('DEBUG: Field "%s" (string) converted to cell: %s\n', fName, strjoin(dsInfoOut.(fName), '|'));
            elseif ~iscell(currentVal) % If it's some other type, default to empty cell
                fprintf(2, 'Warning: Field "%s" was unexpected type %s. Resetting to empty cell.\n', fName, class(currentVal));
                dsInfoOut.(fName) = {};
            else % It's already a cell, ensure it's cell of char
                dsInfoOut.(fName) = cellfun(@char, currentVal, 'UniformOutput', false);
                 fprintf('DEBUG: Field "%s" (cell) ensured elements are char.\n', fName);
            end
        end
    end
    
    % Author field
    if ~isfield(dsInfoOut, 'Author') || ~(isstruct(dsInfoOut.Author) || isempty(dsInfoOut.Author))
        dsInfoOut.Author = repmat(emptyAuthorStruct, 0, 1);
    % ... (rest of Author validation logic remains same) ...
    elseif ~isempty(dsInfoOut.Author) && ~isvector(dsInfoOut.Author)
        fprintf(2, 'Warning: Author field was a matrix struct; resetting to empty.\n');
        dsInfoOut.Author = repmat(emptyAuthorStruct, 0, 1);
    else 
        for k = 1:numel(dsInfoOut.Author)
            dsInfoOut.Author(k) = ensureStringFieldLocal(dsInfoOut.Author(k), 'givenName', '');
            dsInfoOut.Author(k) = ensureStringFieldLocal(dsInfoOut.Author(k), 'familyName', '');
            
            dsInfoOut.Author(k) = ensureFieldLocal(dsInfoOut.Author(k), 'contactInformation', struct('email', ''), @isstruct);
            dsInfoOut.Author(k).contactInformation = ensureStringFieldLocal(dsInfoOut.Author(k).contactInformation, 'email', '');
            
            dsInfoOut.Author(k) = ensureFieldLocal(dsInfoOut.Author(k), 'digitalIdentifier', struct('identifier', ''), @isstruct);
            dsInfoOut.Author(k).digitalIdentifier = ensureStringFieldLocal(dsInfoOut.Author(k).digitalIdentifier, 'identifier', '');
            
            dsInfoOut.Author(k) = ensureFieldLocal(dsInfoOut.Author(k), 'authorRole', {}, @(x) iscellstr(x) || isstring(x) || isempty(x));
             if isstring(dsInfoOut.Author(k).authorRole), dsInfoOut.Author(k).authorRole = cellstr(dsInfoOut.Author(k).authorRole); end
            
            dsInfoOut.Author(k).affiliation = validateTableStructArrayLocal(dsInfoOut.Author(k), 'affiliation', {'memberOf'});
            if ~isempty(dsInfoOut.Author(k).affiliation)
                for affIdx = 1:numel(dsInfoOut.Author(k).affiliation)
                    dsInfoOut.Author(k).affiliation(affIdx) = ensureFieldLocal(dsInfoOut.Author(k).affiliation(affIdx),'memberOf',struct('fullName',''), @isstruct);
                    dsInfoOut.Author(k).affiliation(affIdx).memberOf = ensureStringFieldLocal(dsInfoOut.Author(k).affiliation(affIdx).memberOf, 'fullName','');
                end
            end
        end
    end
    if isInitializingNew && isempty(dsInfoOut.Author)
        if ~isempty(appHandle) && isvalid(appHandle) && isprop(appHandle, 'AuthorData') && ismethod(appHandle.AuthorData, 'toStructs')
            dsInfoOut.Author = appHandle.AuthorData.toStructs(); 
             if isempty(dsInfoOut.Author) 
                dsInfoOut.Author = repmat(emptyAuthorStruct, 1, 1);
             end
        else
             dsInfoOut.Author = repmat(emptyAuthorStruct, 1, 1); 
        end
    end

    % Subjects field
    dsInfoOut.Subjects = validateTableStructArrayLocal(dsInfoOut, 'Subjects', fieldnames(emptySubjectBase));
    % ... (rest of Subjects validation logic remains same) ...
    if isstruct(dsInfoOut.Subjects) 
        for k_sub = 1:numel(dsInfoOut.Subjects)
            dsInfoOut.Subjects(k_sub) = ensureStringFieldLocal(dsInfoOut.Subjects(k_sub), 'SubjectName', ['UnnamedSubject' num2str(k_sub)]);
            dsInfoOut.Subjects(k_sub) = ensureFieldLocal(dsInfoOut.Subjects(k_sub), 'BiologicalSexList', {}, @(x) iscellstr(x) || isstring(x) || isempty(x));
             if isstring(dsInfoOut.Subjects(k_sub).BiologicalSexList), dsInfoOut.Subjects(k_sub).BiologicalSexList = cellstr(dsInfoOut.Subjects(k_sub).BiologicalSexList); end

            dsInfoOut.Subjects(k_sub) = ensureFieldLocal(dsInfoOut.Subjects(k_sub), 'SpeciesList', defaultSpeciesStruct, @isstruct);
            dsInfoOut.Subjects(k_sub).SpeciesList = ensureStringFieldLocal(dsInfoOut.Subjects(k_sub).SpeciesList, 'name', '');
            dsInfoOut.Subjects(k_sub).SpeciesList = ensureStringFieldLocal(dsInfoOut.Subjects(k_sub).SpeciesList, 'preferredOntologyIdentifier', '');
            dsInfoOut.Subjects(k_sub).SpeciesList = ensureFieldLocal(dsInfoOut.Subjects(k_sub).SpeciesList, 'synonym', {}, @(x) iscellstr(x) || isstring(x) || isempty(x));
             if isstring(dsInfoOut.Subjects(k_sub).SpeciesList.synonym), dsInfoOut.Subjects(k_sub).SpeciesList.synonym = cellstr(dsInfoOut.Subjects(k_sub).SpeciesList.synonym); end

            dsInfoOut.Subjects(k_sub) = ensureFieldLocal(dsInfoOut.Subjects(k_sub), 'StrainList', {}, @(x) iscellstr(x) || isstring(x) || isempty(x));
             if isstring(dsInfoOut.Subjects(k_sub).StrainList), dsInfoOut.Subjects(k_sub).StrainList = cellstr(dsInfoOut.Subjects(k_sub).StrainList); end
        end
    end
    if isInitializingNew && isempty(dsInfoOut.Subjects)
        if ~isempty(appHandle) && isvalid(appHandle) && isprop(appHandle, 'SubjectData') && ismethod(appHandle.SubjectData, 'formatTable')
            dsInfoOut.Subjects = appHandle.SubjectData.formatTable(); 
            if isempty(dsInfoOut.Subjects) 
                dsInfoOut.Subjects = repmat(emptySubjectBase,0,1);
            end
        else
            dsInfoOut.Subjects = repmat(emptySubjectBase,0,1); 
        end
    end

    % Probe field
    if ~isfield(dsInfoOut, 'Probe') || ~iscell(dsInfoOut.Probe)
        dsInfoOut.Probe = {}; 
    % ... (rest of Probe validation logic remains same) ...
    else
        if ~isvector(dsInfoOut.Probe) && ~isempty(dsInfoOut.Probe)
            fprintf(2, 'Warning: Probe field was a matrix cell array. Linearizing.\n');
            dsInfoOut.Probe = dsInfoOut.Probe(:); 
        end
        if ~iscolumn(dsInfoOut.Probe) && ~isempty(dsInfoOut.Probe)
            dsInfoOut.Probe = dsInfoOut.Probe(:);
        end
        
        for k_probe = 1:numel(dsInfoOut.Probe)
            if ~isstruct(dsInfoOut.Probe{k_probe})
                fprintf(2, 'Warning: Probe item %d was not a struct. Replacing with default.\n', k_probe);
                dsInfoOut.Probe{k_probe} = emptyProbeBase;
            else
                dsInfoOut.Probe{k_probe} = ensureStringFieldLocal(dsInfoOut.Probe{k_probe}, 'Name', ['UnnamedProbe' num2str(k_probe)]);
                dsInfoOut.Probe{k_probe} = ensureStringFieldLocal(dsInfoOut.Probe{k_probe}, 'ClassType', 'Unknown');
            end
        end
    end
    if isInitializingNew && isempty(dsInfoOut.Probe)
        if ~isempty(appHandle) && isvalid(appHandle) && isprop(appHandle, 'ProbeData') && ismethod(appHandle.ProbeData, 'formatTable')
            probeTableData = appHandle.ProbeData.formatTable(); 
            if iscell(probeTableData) 
                 dsInfoOut.Probe = probeTableData;
            elseif isstruct(probeTableData) 
                 dsInfoOut.Probe = num2cell(probeTableData); 
            else
                 dsInfoOut.Probe = {};
            end
            if isempty(dsInfoOut.Probe)
                 dsInfoOut.Probe = {}; 
            end
        else
            dsInfoOut.Probe = {}; 
        end
    end
    
    fprintf('DEBUG (validateDatasetInformation): Validation complete. isInitializingNew was %d.\n', isInitializingNew);

end % validateDatasetInformation


% --- Local Helper Functions ---
function S_out = ensureFieldLocal(S_in, fieldName, defaultValue, typeCheckFcn)
    if nargin < 4 || isempty(typeCheckFcn)
        typeCheckFcn = @(x) true; 
    end
    
    if ~isfield(S_in, fieldName) || ~typeCheckFcn(S_in.(fieldName))
        S_in.(fieldName) = defaultValue;
    end
    S_out = S_in;
end

function S_out = ensureStringFieldLocal(S_in, fieldName, defaultValue)
    if ~isfield(S_in, fieldName) || (~ischar(S_in.(fieldName)) && ~isstring(S_in.(fieldName)))
        S_in.(fieldName) = defaultValue;
    elseif isstring(S_in.(fieldName)) && isscalar(S_in.(fieldName)) 
        S_in.(fieldName) = char(S_in.(fieldName)); 
    elseif isstring(S_in.(fieldName)) && ~isscalar(S_in.(fieldName))
        S_in.(fieldName) = cellstr(S_in.(fieldName)); 
    end
    if ischar(S_in.(fieldName)) && isempty(S_in.(fieldName)) && ~isempty(defaultValue) && ~strcmp(defaultValue,'')
        S_in.(fieldName) = defaultValue;
    end
    S_out = S_in;
end

function isCP = isCellOrEmptyCharLocal(val)
   isCP = (iscellstr(val) || isstring(val) || (iscell(val) && all(cellfun(@ischar,val)))) || (ischar(val) && isempty(val)); %#ok<ISCLSTR>
end

function outStructArray = validateTableStructArrayLocal(dsInfoStruct, fieldName, expectedFields)
    fieldDefaultsCell = cell(1, 2*numel(expectedFields));
    for k_ef = 1:numel(expectedFields)
        fieldDefaultsCell{2*k_ef-1} = expectedFields{k_ef};
        fieldDefaultsCell{2*k_ef}   = ''; 
    end
    defaultEmptyStructArrayWithFields = repmat(struct(fieldDefaultsCell{:}), 0, 1);

    if ~isfield(dsInfoStruct, fieldName) || ...
       (~isstruct(dsInfoStruct.(fieldName)) && ~isempty(dsInfoStruct.(fieldName))) 
        outStructArray = defaultEmptyStructArrayWithFields;
        return;
    end
    
    structArrayIn = dsInfoStruct.(fieldName);

    if isempty(structArrayIn) 
        outStructArray = defaultEmptyStructArrayWithFields; 
        return;
    end
    
    if ~(isscalar(structArrayIn) || isvector(structArrayIn))
        fprintf(2, 'Warning: Field "%s" was a non-vector (matrix) struct. Resetting to empty table structure.\n', fieldName);
        outStructArray = defaultEmptyStructArrayWithFields;
        return;
    end

    numElements = numel(structArrayIn);
    outStructArray = repmat(struct(fieldDefaultsCell{:}), numElements, 1); 

    for i = 1:numElements
        currentInputStruct = structArrayIn(i);
        for k_ef = 1:numel(expectedFields)
            fieldNameToCheck = expectedFields{k_ef};
            if isfield(currentInputStruct, fieldNameToCheck)
                val = currentInputStruct.(fieldNameToCheck);
                if ischar(val) || isstring(val) || isnumeric(val) || islogical(val) || iscell(val) || isdatetime(val) || isstruct(val)
                    outStructArray(i).(fieldNameToCheck) = val;
                else
                    fprintf(2, 'Warning: Field "%s.%s" had unexpected type. Defaulting to empty char.\n', fieldName, fieldNameToCheck);
                    outStructArray(i).(fieldNameToCheck) = ''; 
                end
            else
            end
        end
    end
    if ~iscolumn(outStructArray) && ~isempty(outStructArray)
        outStructArray = outStructArray(:);
    end
end
