function [treatmentTable,docIDs,dependencyIDs] = treatment(session,options)
% TREATMENT Gathers NDI treatment document properties into a table.
%
%   [treatmentTable, docIDs, dependencyIDs] = TREATMENT(SESSION, OPTIONS)
%   retrieves all 'treatment', 'treatment_drug', and 'virus_injection'
%   documents from an NDI session and organizes their properties into a
%   MATLAB table.
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
end
% Check depends_on class
options.depends_on = cellstr(options.depends_on);
if ~isscalar(options.depends_on), error('depends_on must be a single string.'); else options.depends_on = options.depends_on{1}; end
% --- Get documents: either via a targeted query or a broad one ---
q_treat = ndi.query('','isa','treatment');
q_drug = ndi.query('','isa','treatment_drug');
q_virus = ndi.query('','isa','virus_injection');
q_type = q_treat | q_drug | q_virus;
if ~isempty(options.depends_on_docs)
    % Build a composite query using a loop of ORs with the 'depends_on' operator
    if ~isempty(options.depends_on_docs)
        % First, extract the document IDs, which is what the query operator needs
        depends_on_ids = cellfun(@(d) d.id, options.depends_on_docs, 'UniformOutput', false);

        % Start with the first document ID
        q_dependency = ndi.query('','depends_on', options.depends_on, depends_on_ids{1});
        % Loop through the rest of the IDs and append them with an OR
        for i = 2:numel(depends_on_ids)
            q_dependency = q_dependency | ndi.query('','depends_on', options.depends_on, depends_on_ids{i});
        end
        query = q_type & q_dependency;
    else
        % If depends_on_docs is provided but empty, the result must be empty
        query = []; 
    end
else
    query = q_type;
end
if isempty(query) % Handle case where no query could be formed
    treatmentDocs = {};
else
    treatmentDocs = session.database_search(query);
end
% Handle case where no documents are found
if isempty(treatmentDocs)
    if options.errorIfEmpty, error('No treatment documents were found.'); end
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
    
    try, dependencyIDs_all{i} = doc.dependency_value(options.depends_on); catch, dependencyIDs_all{i} = ''; end
    
    if doc.doc_isa('treatment_drug')
        fields = docProp.treatment_drug;
        fn = fieldnames(fields);
        for f=1:numel(fn)
            val = fields.(fn{f});
            if ischar(val), val = strtrim(val); end
            treatmentRow.(fn{f}) = {val};
        end
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
        if contains(stringValue,':')
            [stringOntology,stringName] = ndi.ontology.lookup(stringValue);
        else
            stringOntology = [];
            stringName = [];
        end
        if ~isempty(numericValue) && isempty(stringValue), treatmentRow.(dataType) = numericValue; end
        if ~isempty(stringOntology)
            treatmentRow.([dataType,'Name']) = {strtrim(stringName)};
            treatmentRow.([dataType,'Ontology']) = {stringOntology};
        elseif ischar(stringValue) && isempty(numericValue) % Use ischar to include empty strings
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

