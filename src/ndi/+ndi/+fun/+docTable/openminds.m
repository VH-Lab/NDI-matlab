function [openmindsTable,docIDs,dependencyIDs] = openminds(session,type,options)
% OPENMINDS Gathers OpenMINDS document properties into a table.
%
%   [openmindsTable, docIDs, dependencyIDs] = OPENMINDS(SESSION, TYPE, OPTIONS)
%   retrieves OpenMINDS documents of a specified 'TYPE' from an NDI session
%   and organizes their key properties into a MATLAB table.
%
%   Input Arguments:
%     session (ndi.session.dir or ndi.dataset.dir) - An NDI session object.
%     type (char or string) - The OpenMINDS type to search for (e.g., 'Strain').
%
%   Optional Name-Value Arguments:
%     depends_on (char or string) - Dependency field to extract (e.g., 'subject_id').
%     errorIfEmpty (logical) - If true, errors if no documents are found. Default is false.
%     depends_on_docs (cell) - Pre-fetched documents that the target documents depend on.
%                              If provided, filtering is performed in memory, which is much more
%                              efficient than a new database query.
%     allOpenMindsDocs (cell) - A pre-fetched cell array of all openminds documents in
%                               the session. If provided, the function uses this list
%                               instead of performing its own expensive query.
%
%   Output Arguments:
%     openmindsTable (table) - A table of OpenMINDS document properties.
%     docIDs (cell) - Document IDs of the corresponding rows.
%     dependencyIDs (cell) - IDs of the documents the OpenMINDS docs depend on.
%
%   See also: ndi.query, ndi.session.dir, ndi.dataset.dir, ndi.fun.table.vstack
%
arguments
    session {mustBeA(session,{'ndi.session.dir','ndi.dataset.dir'})}
    type {mustBeText}
    options.depends_on {mustBeText} = {''};
    options.errorIfEmpty (1,1) logical = false;
    options.depends_on_docs (1,:) cell = {};
    options.allOpenMindsDocs (1,:) cell = {};
end
% Check type class
type = cellstr(type); 
if ~isscalar(type)
    error('Type must be a single string.');
else
    type = type{1};
end
% Check depends_on class
options.depends_on = cellstr(options.depends_on);
if ~isscalar(options.depends_on)
    error('depends_on must be a single string.');
else
    options.depends_on = options.depends_on{1};
end

% --- Get documents ---
if ~isempty(options.depends_on_docs) && ~isempty(options.allOpenMindsDocs) && ~isempty(options.depends_on)
    % OPTIMIZED PATH: Filter from pre-fetched documents, no new DB query
    
    % 1. Find all docs of the correct type from the master list
    all_type_docs = {};
    type_url = ['https://openminds.om-i.org/types/', type];
    for i=1:numel(options.allOpenMindsDocs)
        if strcmp(options.allOpenMindsDocs{i}.document_properties.openminds.openminds_type, type_url)
            all_type_docs{end+1} = options.allOpenMindsDocs{i};
        end
    end
    
    % 2. Now filter these docs by dependency
    depends_on_ids = cellfun(@(d) d.id, options.depends_on_docs, 'UniformOutput', false);
    typeDocs = {};
    for i=1:numel(all_type_docs)
        try
            dep_id = all_type_docs{i}.dependency_value(options.depends_on);
            if ismember(dep_id, depends_on_ids)
                typeDocs{end+1} = all_type_docs{i};
            end
        catch
            % dependency not found or error, just continue
        end
    end
else
    % ORIGINAL PATH: Perform a broad database query
    query = ndi.query('openminds.openminds_type','exact_string', ['https://openminds.om-i.org/types/',type]);
    typeDocs = session.database_search(query);
end

% Handle case where no documents are found
if isempty(typeDocs)
    if options.errorIfEmpty, error('No documents of type "%s" were found.', type); end
    openmindsTable = table(); docIDs = {}; dependencyIDs = {}; return;
end
docIDs = cellfun(@(d) d.id,typeDocs,'UniformOutput',false)';

% Get all openminds documents (needed for resolving dependencies)
if ~isempty(options.allOpenMindsDocs)
    allDocs = options.allOpenMindsDocs; % Use pre-fetched list
else
    query = ndi.query('','isa', 'openminds'); % Perform expensive query if needed
    allDocs = session.database_search(query);
end
allDocs_id = cellfun(@(d) d.id,allDocs,'UniformOutput',false);

% Initialize table
openmindsCell = cell(size(typeDocs))';
dependencyIDs = cell(size(typeDocs))';
totalDependencies = nan(size(typeDocs))';
for i = 1:numel(typeDocs)
    openMINDsRow = table();
    docProp = typeDocs{i}.document_properties;
    totalDependencies(i) = numel(docProp.depends_on);
    try
        dependencyIDs{i} = typeDocs{i}.dependency_value(options.depends_on);
    catch
        dependencyIDs{i} = '';
    end
    fieldNames = fields(docProp.openminds.fields);
    ontologyField = fieldNames{contains(fieldNames,'ontology','IgnoreCase',true)};
    openMINDsRow.([type,'Name']) = {docProp.openminds.fields.name};
    openMINDsRow.([type,'Ontology']) = {docProp.openminds.fields.(ontologyField)};
    openminds_fields = fields(docProp.openminds.fields);
    dependentDocs = cell(size(openminds_fields));
    dependentTypes = cell(size(openminds_fields));
    removeCells = false(size(openminds_fields));
    for j = 1:numel(openminds_fields)
        fieldName = openminds_fields{j};
        openminds_field = docProp.openminds.fields.(fieldName);
        if iscell(openminds_field) && all(contains(openminds_field,'ndi'))
            dependentDocs{j} = regexp(openminds_field, '[^/]*$', 'match', 'once');
            dependentTypes{j} = [upper(fieldName(1)),fieldName(2:end)];
        else
            removeCells(j) = true;
        end
    end
    dependentDocs(removeCells) = []; dependentTypes(removeCells) = [];
    for j = 1:numel(dependentDocs)
        depDocIDs = dependentDocs{j};
        if ~iscell(depDocIDs)
            depDocIDs = {depDocIDs};
        end

        depNames = {};
        depOntologies = {};

        for k = 1:numel(depDocIDs)
            dependentDoc_idx = strcmp(allDocs_id,depDocIDs{k});
            if ~any(dependentDoc_idx)
                continue;
            end
            dependentDoc = allDocs{dependentDoc_idx};
            docProp_dep = dependentDoc.document_properties;
            fieldNames_dep = fields(docProp_dep.openminds.fields);
            ontologyField_dep = fieldNames_dep{contains(fieldNames_dep,'ontology','IgnoreCase',true)};

            depNames{end+1} = docProp_dep.openminds.fields.name;
            if ~isempty(docProp_dep.openminds.fields.(ontologyField_dep))
                 depOntologies{end+1} = docProp_dep.openminds.fields.(ontologyField_dep);
            end
        end

        if ~isempty(depNames)
            openMINDsRow.([dependentTypes{j},'Name']) = {strjoin(depNames, ', ')};
        end
        if ~isempty(depOntologies)
            openMINDsRow.([dependentTypes{j},'Ontology']) = {strjoin(depOntologies, ', ')};
        end
    end
    openmindsCell{i} = openMINDsRow;
end

% Check for encompassing openminds document
[~,~,indDepend] = unique(dependencyIDs);
removeRows = false(size(dependencyIDs));
for i = 1:max(indDepend)
    ind = find(indDepend == i);
    if isempty(ind)
        continue;
    end
    [~,indMax] = max(totalDependencies(ind));
    removeRows(setdiff(ind,ind(indMax))) = true;
end
openmindsCell(removeRows) = [];
docIDs(removeRows) = [];
dependencyIDs(removeRows) = [];

% Handle case where all rows were filtered out
if isempty(openmindsCell)
    if options.errorIfEmpty, error('No valid documents remained after filtering.'); end
    openmindsTable = table(); docIDs = {}; dependencyIDs = {}; return;
end

% Stack table
openmindsTable = ndi.fun.table.vstack(openmindsCell);
end

