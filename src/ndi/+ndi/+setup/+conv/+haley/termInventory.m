function T = termInventory(path, options)
%TERMINVENTORY Every term a written V2 dataset uses, plain text or ontology.
%
%   T = ndi.setup.conv.haley.termInventory(PATH) reads every document in the
%   V2 dataset at PATH (the folder holding .ndi; its own database and each
%   linked session's, ndi.setup.V2.datasetDatabaseFiles) and lists each term it
%   carries: every {node, name} pair (or {name} alone: did2.build stores a
%   term with no node without one), wherever it sits (a statement's
%   variable or method, a unit, a key's or condition's variable, an axis, a
%   scale, a subject type, an asserted value, ...). A term with an empty
%   node is PLAIN TEXT; one with a node is an ONTOLOGY term.
%
%   One row per distinct (name, node, field):
%     kind          "plain text" or "ontology"
%     name, node    the term
%     field         where it sits, block.field with [] for array elements
%     classes       the document classes it appears in
%     documents     how many documents carry it there
%     occurrences   how many times (a document can carry it more than once)
%     example_id    one document that carries it
%
%   Options:
%     'OutFile'    also write T to this .csv, with empty review columns
%                  (proposed_node, proposed_name, notes) to fill in
%     'BatchSize'  documents read per query (default 5000)
%
%   Prints its denominators first: documents read, term occurrences found,
%   distinct terms (plain text / ontology). Writes nothing else.
%
%   See also ndi.setup.conv.haley.verifyDataset, ndi.setup.conv.haley.import_V2.

arguments
    path (1,:) char {mustBeFolder}
    options.OutFile (1,:) char = ''
    options.BatchSize (1,1) double {mustBePositive, mustBeInteger} = 5000
end

% the dataset's own database, then each linked session's (decision #71)
files = ndi.setup.V2.datasetDatabaseFiles(path);
nDocs = 0;

index = containers.Map();       % key -> row number
rows = struct('name', {}, 'node', {}, 'field', {}, 'classes', {}, 'docs', {}, ...
    'occurrences', {}, 'example_id', {});
nOcc = 0;
read = 0;
t0 = tic;
for f = 1:numel(files)
    db = did2.database.sqlitedb(files{f});
    dbid = db.testHookDbId();
    nHere = mksqlite(dbid, 'SELECT COUNT(*) AS n FROM documents');
    nHere = double(nHere.n);
    nDocs = nDocs + nHere;
    for offset = 0:options.BatchSize:nHere - 1
        B = mksqlite(dbid, sprintf(['SELECT id, classname, body FROM documents ' ...
            'ORDER BY id LIMIT %d OFFSET %d'], options.BatchSize, offset));
        for k = 1:numel(B)
            found = walk(jsondecode(B(k).body), '', {});
            read = read + 1;
            seen = containers.Map();
            for j = 1:size(found, 1)
                key = [found{j, 1} char(31) found{j, 2} char(31) found{j, 3}];
                nOcc = nOcc + 1;
                if ~isKey(index, key)
                    rows(end+1) = struct('name', found{j, 1}, 'node', found{j, 2}, ...
                        'field', found{j, 3}, 'classes', {{B(k).classname}}, 'docs', 0, ...
                        'occurrences', 0, 'example_id', B(k).id); %#ok<AGROW>
                    index(key) = numel(rows);
                end
                r = index(key);
                rows(r).occurrences = rows(r).occurrences + 1;
                if ~isKey(seen, key)
                    seen(key) = true;
                    rows(r).docs = rows(r).docs + 1;
                    if ~any(strcmp(rows(r).classes, B(k).classname))
                        rows(r).classes{end+1} = B(k).classname;
                    end
                end
            end
        end
        fprintf('  terms: %d documents read (database %d of %d), %s\n', read, f, numel(files), ...
            char(duration(0, 0, round(toc(t0)), 'Format', 'hh:mm:ss')));
    end
    db.close();
end

kind = repmat("plain text", numel(rows), 1);
kind(~cellfun(@isempty, {rows.node})) = "ontology";
T = table(kind, string({rows.name})', string({rows.node})', string({rows.field})', ...
    string(cellfun(@(c) strjoin(sort(c), ', '), {rows.classes}, 'UniformOutput', false))', ...
    [rows.docs]', [rows.occurrences]', string({rows.example_id})', ...
    'VariableNames', {'kind', 'name', 'node', 'field', 'classes', 'documents', ...
    'occurrences', 'example_id'});
T = sortrows(T, {'kind', 'field', 'name'});

nPlain = numel(unique(T.name(T.kind == "plain text")));
nOnt = height(unique(T(T.kind == "ontology", {'name', 'node'})));
fprintf(['DENOMINATOR: %d document(s) read of %d; %d term occurrence(s); %d distinct ' ...
    '(name, node, field) row(s): %d distinct plain-text name(s), %d distinct ontology term(s)\n'], ...
    read, nDocs, nOcc, height(T), nPlain, nOnt);

if ~isempty(options.OutFile)
    out = T;
    out.proposed_node = strings(height(T), 1);
    out.proposed_name = strings(height(T), 1);
    out.notes = strings(height(T), 1);
    writetable(out, options.OutFile);
    fprintf('written: %s\n', options.OutFile);
end
end

% -----------------------------------------------------------------------------
function found = walk(x, path, found)
% every {node, name} struct under X, as rows {name, node, path}
if isstruct(x)
    f = fieldnames(x);
    % a term: node and/or name and nothing else. did2.build leaves an empty
    % node out, so a plain-text term is stored as {name} alone.
    if ~isempty(f) && all(ismember(f, {'node', 'name'}))
        for i = 1:numel(x)
            nm = ''; nd = '';
            if isfield(x, 'name'), nm = char(string(x(i).name)); end
            if isfield(x, 'node'), nd = char(string(x(i).node)); end
            if isempty(nm) && isempty(nd), continue; end      % a blank (unset) term
            found(end+1, :) = {nm, nd, path}; %#ok<AGROW>
        end
        return;
    end
    sub = path;
    if numel(x) > 1, sub = [path '[]']; end
    for i = 1:numel(x)
        for j = 1:numel(f)
            found = walk(x(i).(f{j}), join(sub, f{j}), found);
        end
    end
elseif iscell(x)
    for i = 1:numel(x)
        found = walk(x{i}, [path '[]'], found);
    end
end
end

function p = join(a, b)
if isempty(a), p = b; else, p = [a '.' b]; end
end
