function [treatmentTable,docIDs,dependencyIDs] = treatment(session,options)
% TREATMENT Gathers NDI treatment document properties into a table.
%
%   [treatmentTable, docIDs, dependencyIDs] = TREATMENT(SESSION, OPTIONS)
%   retrieves all 'treatment', 'treatment_drug', 'virus_injection', and
%   'measurement'documents from an NDI session and organizes their 
%   properties into a MATLAB table.
%
%   The function aggregates all treatments for a given dependency (e.g., a
%   subject) into a single row. If multiple treatments of the same type exist,
%   their values are combined (numeric values become row vectors, strings
%   become comma-separated lists).
%
%   Input Arguments:
%     session (ndi.session.dir or ndi.dataset.dir) - An NDI session object.
%
%   Optional Name-Value Arguments:
%     depends_on (char or string) - Dependency field to extract (e.g., 'subject_id' (default)).
%     errorIfEmpty (logical) - If true, errors if no documents are found. Default is false.
%     depends_on_docs (cell) - Pre-fetched documents that the target documents depend on.
%                              If provided, a much more efficient, targeted query is performed.
%
%   Output Arguments:
%     treatmentTable (table) - A table with one row per unique dependency,
%                              summarizing all associated treatments.
%     docIDs (cell) - A cell array where each element contains a cell array of
%                     the document IDs for the treatments in the corresponding row.
%     dependencyIDs (cell) - A cell array of the unique dependency IDs
%                            (e.g., subject IDs) for each row.
%
%   See also: ndi.query, ndi.session.dir, ndi.dataset.dir, ndi.fun.table.vstack
%
arguments
    session {mustBeA(session,{'ndi.session.dir','ndi.dataset.dir'})}
    options.depends_on {mustBeText} = 'subject_id';
    options.errorIfEmpty (1,1) logical = false;
    options.depends_on_docs (1,:) cell = {};
    options.hideMixtureTable (1,1) logical = true;
end

% Check depends_on class
options.depends_on = cellstr(options.depends_on);
if ~isscalar(options.depends_on)
    error('depends_on must be a single string.');
else
    options.depends_on = options.depends_on{1};
end

% Get documents
q_treat = ndi.query('','isa','treatment');
q_drug = ndi.query('','isa','treatment_drug');
q_virus = ndi.query('','isa','virus_injection');
q_measurement = ndi.query('','isa','measurement');
query = q_treat | q_drug | q_virus | q_measurement;
treatmentDocs = session.database_search(query);

% Drug Treatment Field Renaming
drugTreatmentFieldsOld = {'location_name','location_ontologyName',...
    'mixture_table','administration_onset_time',...
    'administration_offset_time','administration_duration'};
drugTreatmentFields = {'DrugTreatmentLocationName','DrugTreatmentLocationOntology',...
    'DrugTreatmentMixtureTable','DrugTreatmentOnsetTime',...
    'DrugTreatmentOffsetTime','DrugTreatmentDuration'};

% Handle case where no documents are found
if isempty(treatmentDocs)
    if options.errorIfEmpty
        error('No treatment documents were found.');
    end
    treatmentTable = table(); docIDs = {}; dependencyIDs = {}; return;
end

% --- Step 1: Create a cell array of tables, one for each document ---
treatmentCell = cell(numel(treatmentDocs), 1);
dependencyIDs_all = cell(numel(treatmentDocs), 1);
docIDs_all = cellfun(@(d) d.id, treatmentDocs, 'UniformOutput', false);
for i = 1:numel(treatmentDocs)
    treatmentRow = table();
    doc = treatmentDocs{i};
    docProp = doc.document_properties;

    try
        dependencyIDs_all{i} = doc.dependency_value(options.depends_on);
    catch
        dependencyIDs_all{i} = '';
    end

    if doc.doc_isa('treatment_drug')
        fields = docProp.treatment_drug;
        fn = fieldnames(fields);
        indSkip = false(size(fn));
        for f = 1:numel(fn)
            val = fields.(fn{f});
            if ischar(val)
                val = strtrim(val);
            end
            if (isnumeric(val) & isnan(val)) | (ischar(val) & isempty(val))
                indSkip(f) = true;
                continue
            end
            if contains(fn{f},'_time')
                if contains(val,'T')
                    inputFormat = 'yyyy-MM-dd''T''HH:mm:ss';
                else
                    inputFormat = 'yyyy-MM-dd';
                end
                    val = datetime(val,'InputFormat',inputFormat);
            end
            if strcmp(fn{f},'mixture_table')
                mixtureTable = ndi.database.fun.readtablechar(val,'.txt','Delimiter',',');
                treatmentRow.DrugTreatmentMixtureName = mixtureTable.name;
                treatmentRow.DrugTreatmentMixtureQuantity = cellstr(compose("%g %s", ...
                   mixtureTable.value,mixtureTable.unitName{1}));
                treatmentRow.DrugTreatmentMixtureOntology = mixtureTable.ontologyName;
                if options.hideMixtureTable
                    indSkip(f) = true;
                    continue
                end
            end
            treatmentRow.(fn{f}) = {val};
        end
        treatmentRow = renamevars(treatmentRow, ...
            drugTreatmentFieldsOld(~indSkip),drugTreatmentFields(~indSkip));
    elseif doc.doc_isa('virus_injection')
        fields = docProp.virus_injection;
        fn = fieldnames(fields);
        for f=1:numel(fn)
            val = fields.(fn{f});
            if ischar(val), val = strtrim(val); end
            treatmentRow.(fn{f}) = {val};
        end
    elseif doc.doc_isa('treatment') % Must be last, as others are subclasses
        [~,~,~,~,~,dataType] = ndi.ontology.lookup(docProp.treatment.ontologyName);
        numericValue = docProp.treatment.numeric_value;
        stringValue = strtrim(docProp.treatment.string_value);
        stringOntology = [];
        stringName = [];
        stringDate = [];
        if ~isempty(stringValue) && isStringDatetime(stringValue)
            stringDate = datetime(stringValue);
        elseif contains(stringValue,':')
            [stringOntology,stringName] = ndi.ontology.lookup(stringValue);
        end
        if ~isempty(numericValue) && isempty(stringValue)
            treatmentRow.(dataType) = numericValue;
        elseif ~isempty(stringDate)
            treatmentRow.(dataType) = {stringDate};
        elseif ~isempty(stringOntology)
            treatmentRow.([dataType,'Name']) = {strtrim(stringName)};
            treatmentRow.([dataType,'Ontology']) = {stringOntology};
        elseif ischar(stringValue) && isempty(numericValue)
            treatmentRow.(dataType) = {stringValue};
        elseif ischar(stringValue) && ~isempty(numericValue)
            treatmentRow.([dataType,'Number']) = {numericValue};
            treatmentRow.([dataType,'String']) = {stringValue};
        end
    elseif doc.doc_isa('measurement')
        [~,~,~,~,~,dataType] = ndi.ontology.lookup(docProp.measurement.ontologyName);
        numericValue = docProp.measurement.numeric_value;
        stringValue = strtrim(docProp.measurement.string_value);
        stringOntology = [];
        stringName = [];
        stringDate = [];
        if ~isempty(stringValue) && isStringDatetime(stringValue)
            stringDate = datetime(stringValue);
        elseif contains(stringValue,':')
            [stringOntology,stringName] = ndi.ontology.lookup(stringValue);
        end
        if ~isempty(numericValue) && isempty(stringValue)
            treatmentRow.(dataType) = numericValue;
        elseif ~isempty(stringDate)
            treatmentRow.(dataType) = {stringDate};
        elseif ~isempty(stringOntology)
            treatmentRow.([dataType,'Name']) = {strtrim(stringName)};
            treatmentRow.([dataType,'Ontology']) = {stringOntology};
        elseif ischar(stringValue) && isempty(numericValue)
            treatmentRow.(dataType) = {stringValue};
        elseif ischar(stringValue) && ~isempty(numericValue)
            treatmentRow.([dataType,'Number']) = {numericValue};
            treatmentRow.([dataType,'String']) = {stringValue};
        end
    end
    treatmentCell{i} = treatmentRow;
end

% --- Step 2: Aggregate treatments by unique dependency ID ---
[dependencyIDs, ~, ic] = unique(dependencyIDs_all);
aggregatedCell = cell(numel(dependencyIDs), 1);
docIDs = cell(numel(dependencyIDs), 1);
for i = 1:numel(dependencyIDs)
    idx = find(ic == i);
    docIDs{i} = docIDs_all(idx);

    mergedRow = table();
    for j = 1:numel(idx)
        new_table = treatmentCell{idx(j)};
        if isempty(new_table), continue; end % Skip if no treatment info was extracted
        new_vars = new_table.Properties.VariableNames;

        for k = 1:numel(new_vars)
            var_name = new_vars{k};
            new_val = new_table.(var_name);

            if ismember(var_name, mergedRow.Properties.VariableNames)
                old_val = mergedRow.(var_name);
                % Aggregate values
                if isnumeric(old_val) && iscell(new_val) && isnumeric(new_val{1})
                    mergedRow.(var_name) = [old_val new_val{1}];
                elseif iscell(old_val) && iscell(new_val)
                    % Convert all cell contents to char and trim for consistent joining
                    old_str = cellfun(@(x) strtrim(char(x)), old_val, 'UniformOutput', false);
                    new_str = cellfun(@(x) strtrim(char(x)), new_val, 'UniformOutput', false);

                    % Combine and filter out empty strings before joining
                    combined_cell = [old_str new_str];
                    combined_cell(cellfun('isempty', combined_cell)) = [];

                    if ~isempty(combined_cell)
                        mergedRow.(var_name) = {strjoin(combined_cell, ', ')};
                    else
                        mergedRow.(var_name) = {''}; % Ensure it's an empty string if all were empty
                    end
                else
                    mergedRow.(var_name) = old_val; % Fallback
                end
            else
                % Add new variable to the row
                mergedRow.(var_name) = new_val;
            end
        end
    end
    aggregatedCell{i} = mergedRow;
end

% --- Step 3: Stack the aggregated rows into the final table ---
if isempty(aggregatedCell)
    treatmentTable = table();
    return;
end
treatmentTable = ndi.fun.table.vstack(aggregatedCell);
end

function tf = isStringDatetime(str)
%ISSTRINGDATETIME Checks if a string can be converted to a datetime object.
%   TF = ISSTRINGDATETIME(STR) returns true if STR is a character array or
%   string that can be parsed by the DATETIME function, and false otherwise.

% Ensure the input is a character vector or a string
if ~ischar(str) && ~isstring(str)
    tf = false;
    return;
end

try
    % Attempt to convert the string to a datetime
    datetime(str);
    % If the above line does not error, the string is a valid datetime
    tf = true;
catch
    % If an error occurs, the string is not a valid datetime
    tf = false;
end
end