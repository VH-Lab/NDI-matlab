function census = finalV1BodyCensus(sourceBodies, destBodies, options)
%FINALV1BODYCENSUS Which destination documents are still v1 BODIES, not just v1 NAMES.
%   CENSUS = finalV1BodyCensus(SOURCEBODIES, DESTBODIES) is the Bar-2 survivor
%   census, decided per DOCUMENT rather than per class NAME.
%
%   WHY NOT finalV1SurvivorCensus. That helper flags every destination document
%   whose class_name is also a v1 source class_name. On the pinned schema
%   (did-schema `v_eta-pre73`) that is wrong in both directions it can be wrong:
%   the calculator leaves REUSE the v1 spellings as real V2 classes
%   (`tuningcurve_calc`, `contrasttuning_calc`, `oridirtuning_calc`, ... chain
%   to `tuning_curve_calculation` / `subject_calculation`), so ~69k CONVERTED
%   calculator documents on Soph read as survivors, and so do `subject` and
%   `session`, which persist correctly as `entity` classes. A name says nothing
%   about whether the body was re-shaped.
%
%   ---------------------------------------------------------------------
%   THE SIGNAL: the destination document's OWN superclass chain
%   ---------------------------------------------------------------------
%   did2.convert.v1_to_v2 runs ensureClassBlocks on every emitted body, which
%   REBUILDS document_class.superclasses from the schema in use -- the full
%   ancestor list of the class on the pinned schema. So each destination
%   document carries, in itself, what its class IS on this schema:
%
%     * every ancestor is a v1 class name  -> the pinned schema defines the
%       class as a RESTATEMENT of v1 (a tombstone). A document of that class
%       validates only against the v1 shape: it is an unconverted v1 body.
%     * some ancestor is NOT a v1 class name (`entity`, `subject_calculation`,
%       `tuning_curve_calculation`, `data_type`, ...) -> the class is a real V2
%       class that happens to keep a v1 spelling. Counted, not flagged.
%
%   This is the most direct signal available to a test that sees only the two
%   databases: it does not need the schema index (CI copies only stable/ and
%   draft/ class files, not index.json with its `disposition` markers), and it
%   does not depend on what a migrator chose to name its output. It is read off
%   the document, so a reshaped class cannot hide behind its name and a
%   tombstone cannot pass for a V2 class.
%
%   THE SAME-ID COMPARISON is reported beside it, per row: how many of the
%   destination documents have a SOURCE document of the same base.id AND the
%   same class (modulo camelCase -> snake_case, which universalRenames applies).
%   For an unconverted v1 body that should be all of them -- the migrator
%   handed its input back. A tombstone-class document with NO same-id source is
%   something emitted ONTO a v1 tombstone, and the row says so rather than
%   hiding it in the total.
%
%   "v1 class name" = the union of (1) every class_name and every superclass
%   `definition` basename in the SOURCE corpus and (2) every class_name and
%   superclass basename in NDI's own did_v1 templates
%   (ndi.common.PathConstants.DocumentFolder), each also in its snake_case
%   spelling. Pass 'V1Vocabulary' to replace (2) -- the unit test does, so it is
%   hermetic.
%
%   THE DIRECTION OF ERROR, stated so it is known: a destination document with
%   NO superclass chain (ensureClassBlocks was a no-op) has no non-v1 ancestor
%   and reads as an UNCONVERTED v1 body -- the pessimistic direction, on
%   purpose. A tombstone whose v1 ancestor was renamed in V_eta would read as a
%   V2 class (the optimistic direction); the (b) table prints the V_eta-only
%   ancestor that put each class there, so that case is visible in the output.
%
%   INPUTS
%     SOURCEBODIES  cell array of raw v1 JSON text (what readCorpusBodies returns).
%     DESTBODIES    cell array of destination doc STRUCTS (destinationBodies).
%     'Deferrals'   struct array with fields class_name, label: classes whose
%                   unconverted v1 bodies are a KNOWN deferral. They are still
%                   v1 bodies and are listed as such, in their own table (c).
%     'V1Vocabulary' cell array of extra v1 class names (default: NDI templates).
%
%   OUTPUT  CENSUS, a struct:
%     .denominator  source_read, source_classified, dest_read,
%                   dest_v1_spelled, v1_vocabulary_size
%     .unconverted  (a) rows: class_name, count, same_id_source, chain
%     .v2_classes   (b) rows: class_name, count, same_id_source, veta_ancestor
%     .deferred     (c) rows: class_name, count, same_id_source, label
%   Each table is sorted by count, descending.
%
%   REPORT-ONLY. This measures; the caller prints and decides. DENOMINATOR
%   FIRST (Operating Rule 5): a census that read zero documents reports an
%   empty survivor set for the wrong reason.

arguments
    sourceBodies (1,:) cell
    destBodies   (1,:) cell
    options.Deferrals struct = struct('class_name', {}, 'label', {})
    options.V1Vocabulary cell = templateVocabulary()
end

% --- the source side: names, ids ------------------------------------------
vocab = containers.Map('KeyType', 'char', 'ValueType', 'logical');
sourceNames = containers.Map('KeyType', 'char', 'ValueType', 'logical');
srcClassById = containers.Map('KeyType', 'char', 'ValueType', 'any');
classified = 0;
for k = 1:numel(sourceBodies)
    [name, id, supers] = sourceFacts(sourceBodies{k});
    if isempty(name); continue; end
    classified = classified + 1;
    addName(sourceNames, name);
    addName(vocab, name);
    for s = 1:numel(supers); addName(vocab, supers{s}); end
    if ~isempty(id); srcClassById(id) = name; end
end
for k = 1:numel(options.V1Vocabulary)
    addName(vocab, char(options.V1Vocabulary{k}));
end

deferLabel = containers.Map('KeyType', 'char', 'ValueType', 'char');
for k = 1:numel(options.Deferrals)
    deferLabel(char(options.Deferrals(k).class_name)) = char(options.Deferrals(k).label);
end

% --- the destination side --------------------------------------------------
rowsA = containers.Map('KeyType', 'char', 'ValueType', 'any');
rowsB = containers.Map('KeyType', 'char', 'ValueType', 'any');
rowsC = containers.Map('KeyType', 'char', 'ValueType', 'any');
v1Spelled = 0;
for k = 1:numel(destBodies)
    d = destBodies{k};
    name = classNameOfStruct(d);
    if isempty(name) || ~isKey(sourceNames, name)
        continue;   % a minted V_eta class name: not a v1 spelling at all
    end
    v1Spelled = v1Spelled + 1;

    sameId = false;
    id = idOfStruct(d);
    if ~isempty(id) && isKey(srcClassById, id)
        srcName = srcClassById(id);
        sameId = strcmp(srcName, name) || strcmp(snakeCase(srcName), name);
    end

    chain = superclassNames(d);
    vetaAncestor = '';
    for c = 1:numel(chain)
        if ~isKey(vocab, chain{c})
            vetaAncestor = chain{c};
            break;
        end
    end

    if ~isempty(vetaAncestor)
        rowsB = bump(rowsB, name, sameId, 'veta_ancestor', vetaAncestor);
    elseif isKey(deferLabel, name)
        rowsC = bump(rowsC, name, sameId, 'label', deferLabel(name));
    else
        rowsA = bump(rowsA, name, sameId, 'chain', strjoin(chain, ' > '));
    end
end

census = struct();
census.denominator = struct( ...
    'source_read',        numel(sourceBodies), ...
    'source_classified',  classified, ...
    'dest_read',          numel(destBodies), ...
    'dest_v1_spelled',    v1Spelled, ...
    'v1_vocabulary_size', vocab.Count);
census.unconverted = toRows(rowsA, 'chain');
census.v2_classes  = toRows(rowsB, 'veta_ancestor');
census.deferred    = toRows(rowsC, 'label');
end

% ===================== helpers =============================================

function addName(map, name)
if isempty(name); return; end
map(name) = true;
sn = snakeCase(name);
if ~strcmp(sn, name); map(sn) = true; end
end

function m = bump(m, name, sameId, extraField, extraValue)
if isKey(m, name)
    r = m(name);
else
    r = struct('class_name', name, 'count', 0, 'same_id_source', 0, ...
        extraField, extraValue);
end
r.count = r.count + 1;
r.same_id_source = r.same_id_source + double(sameId);
m(name) = r;
end

function rows = toRows(m, extraField)
rows = struct('class_name', {}, 'count', {}, 'same_id_source', {}, extraField, {});
keys = m.keys();
for k = 1:numel(keys)
    rows(end+1) = m(keys{k}); %#ok<AGROW>
end
if ~isempty(rows)
    [~, order] = sort([rows.count], 'descend');
    rows = rows(order);
end
end

function [name, id, supers] = sourceFacts(jsonText)
%SOURCEFACTS class_name, base.id and superclass names from raw v1 JSON.
%   Targeted regexes, not a full jsondecode: a hartley_calc body carries a
%   200x200x36x2 volume and Soph has ~101k bodies. The format is machine-
%   written, so the keys are verbatim. A body the regexes cannot read falls
%   back to jsondecode rather than being silently skipped.
t = char(jsonText);
name = ''; id = ''; supers = {};
tok = regexp(t, '"document_class"\s*:\s*\{[^{}]*?"class_name"\s*:\s*"([^"]+)"', ...
    'tokens', 'once');
if isempty(tok)
    tok = regexp(t, '"class_name"\s*:\s*"([^"]+)"', 'tokens', 'once');
end
if ~isempty(tok); name = tok{1}; end
tok = regexp(t, '"base"\s*:\s*\{[^{}]*?"id"\s*:\s*"([^"]+)"', 'tokens', 'once');
if ~isempty(tok); id = tok{1}; end
defs = regexp(t, '"definition"\s*:\s*"[^"]*?([^"/\\]+)\.json"', 'tokens');
supers = cellfun(@(c) c{1}, defs, 'UniformOutput', false);
if isempty(name) || isempty(id)
    try
        j = jsondecode(t);
        if isempty(name) && isfield(j, 'document_class') ...
                && isfield(j.document_class, 'class_name')
            name = char(j.document_class.class_name);
        end
        if isempty(id) && isfield(j, 'base') && isfield(j.base, 'id')
            id = char(j.base.id);
        end
    catch
    end
end
end

function name = classNameOfStruct(body)
name = '';
if isstruct(body) && isfield(body, 'document_class') ...
        && isstruct(body.document_class) ...
        && isfield(body.document_class, 'class_name')
    name = char(body.document_class.class_name);
end
end

function id = idOfStruct(body)
id = '';
if isstruct(body) && isfield(body, 'base') && isstruct(body.base) ...
        && isfield(body.base, 'id')
    id = char(body.base.id);
end
end

function names = superclassNames(body)
%SUPERCLASSNAMES The destination chain as ensureClassBlocks rebuilt it.
%   Decoded JSON gives a struct array when the entries are uniform and a cell
%   of structs when they are not; both are read.
names = {};
if ~isstruct(body) || ~isfield(body, 'document_class') ...
        || ~isfield(body.document_class, 'superclasses')
    return;
end
sc = body.document_class.superclasses;
if isstruct(sc)
    sc = num2cell(sc);
end
if ~iscell(sc); return; end
for k = 1:numel(sc)
    e = sc{k};
    if isstruct(e) && isfield(e, 'class_name') && ~isempty(e.class_name)
        names{end+1} = char(e.class_name); %#ok<AGROW>
    elseif isstruct(e) && isfield(e, 'definition')
        [~, n] = fileparts(char(e.definition));
        names{end+1} = n; %#ok<AGROW>
    end
end
end

function s = snakeCase(name)
%SNAKECASE camelCase -> snake_case, the spelling universalRenames gives a v1
%   camelCase class name (ontologyTableRow -> ontology_table_row,
%   imageStack_parameters -> image_stack_parameters).
s = regexprep(char(name), '([a-z0-9])([A-Z])', '$1_$2');
s = regexprep(s, '([A-Z]+)([A-Z][a-z])', '$1_$2');
s = lower(s);
end

function vocab = templateVocabulary()
%TEMPLATEVOCABULARY class names + superclass basenames in NDI's did_v1 templates.
vocab = {};
try
    root = ndi.common.PathConstants.DocumentFolder;
catch
    return;
end
files = dir(fullfile(root, '**', '*.json'));
for k = 1:numel(files)
    try
        j = jsondecode(fileread(fullfile(files(k).folder, files(k).name)));
    catch
        continue;
    end
    if ~isfield(j, 'document_class'); continue; end
    dc = j.document_class;
    if isfield(dc, 'class_name'); vocab{end+1} = char(dc.class_name); end %#ok<AGROW>
    if isfield(dc, 'superclasses')
        sc = dc.superclasses;
        if isstruct(sc); sc = num2cell(sc); end
        for s = 1:numel(sc)
            if isstruct(sc{s}) && isfield(sc{s}, 'definition')
                [~, n] = fileparts(char(sc{s}.definition));
                vocab{end+1} = n; %#ok<AGROW>
            end
        end
    end
end
end
