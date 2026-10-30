function [docs, report] = carryFinalDependents(docs, sourceBodies, sourceOutputs)
%CARRYFINALDEPENDENTS Carry every document whose edge names a document that ends as v1.
%
%   [DOCS, REPORT] = ndi.migrate.internal.carryFinalDependents(DOCS, SOURCEBODIES, SOURCEOUTPUTS)
%   is the final sweep of ndi.migrate.local, run after
%   ndi.migrate.internal.carryUnchangedAsV1. DOCS is the cell of did2.document
%   the whole pipeline produced (pass 1, the DID batch passes, NDI's second
%   pass and the final v1 stamp). SOURCEBODIES is the v1 input, in pass 1's
%   order. SOURCEOUTPUTS is pass 1's record of what each source became
%   (did2.convert.v1_to_v2's result.source_outputs: input_index, id,
%   output_ids); it may be empty, and the sweep then attributes a document to
%   a source only by a shared id.
%
%   THE DECISIONS (did-schema schemas/V_eta_go_forward_class_audit.md):
%     Decided by Jess Haley, 2026-10-26 [dependents of a carried document
%     carry]: "a document whose edge points at a document carried as v1 ... is
%     carried too, down the chain, rather than converting with an edge to a v1
%     document (carry-064, any class)". Its NDI build pending: "that every
%     second-pass output whose edge names a document carried as v1 is carried
%     too".
%     Decided by Jess Haley, 2026-10-27 [handed-on documents do not carry
%     dependents]: "a document pass 1 hands on unchanged for NDI's second pass
%     to convert does not make its dependents carry ...; only a document that
%     stays v1 at the end of both passes does". NDI-matlab: "its second pass
%     applies the rule only to its final carries".
%
%   WHICH DOCUMENTS ARE CARRIED AS v1 HERE. Only the FINAL carries: a document
%   of DOCS whose stamp is 'did_v1' when this sweep runs
%   (did2.schema.isV1Stamp(..., 'Explicit', true), the stamp did2.database.
%   sqlitedb stores without V2 validation). A document pass 1 handed on
%   (stimulus_presentation, daqmetadatareader_epochdata_ingested,
%   control_stimulus_ids) and the second pass converted is no longer v1 here,
%   so it makes nothing carry ([handed-on documents do not carry dependents]);
%   one the second pass left as v1 is a final carry, so its dependents do.
%
%   WHAT IS SWEPT. Every document that is NOT v1 at the end, by its
%   depends_on edges (`document_id`, or the `value` key the second-pass
%   builders write). A v1 document's own edges are not swept: a carried
%   document may point at a converted one ([carried documents may point at
%   converted ones], Jess Haley, 2026-10-27). The `session_id` edge is NOT
%   followed: neither decision says whether a session (or dataset) entity
%   that ends as v1 carries every document of its session, and DID-matlab's
%   carryDependents reads only v1 depends_on edges, where a v1 session id is
%   not an edge. Such edges are counted (session_edges_to_v1), not acted on.
%
%   HOW A DOCUMENT IS CARRIED. As DID-matlab's carryDependents does: by its
%   v1 SOURCE. A document is attributed to the source whose base.id it shares
%   (pass 1 and every second-pass fold keep the v1 id on the document a
%   source becomes: the presentation's manipulation, the ingested file's
%   opaque_body, the control record's calculation), else to the source whose
%   pass-1 output_ids name it. The source is carried whole: its v1 body,
%   stamped 'did_v1', replaces the document of its id (or is added when none
%   is left), and is cited under carry-064. Then, repeated until nothing
%   changes, so a chain carries to its end.
%   After the loop, every other remaining pass-1 output of a source carried
%   here is dropped (its content is in the carried source), unless a
%   document that is not one of those outputs still names it: it is then
%   kept and counted (outputs_kept_referenced), since dropping it would leave
%   an edge to nothing.
%   A document that names a final carry but has no source (MINTED by the
%   second pass, e.g. a method, a time reference or a cohort entity) cannot
%   be carried as v1: there is no v1 form. It is left as it is and counted
%   (left_no_source, with a sample), and the sweep warns
%   (NDI:migrate:finalCarryUnattributed). Neither decision says what happens
%   to such a document.
%
%   REPORT (denominators first, unconditionally):
%     documents_inspected      numel(DOCS) on entry
%     v2_documents_inspected   of those, not v1 at the start of the sweep
%     edges_examined           non-empty depends_on edges of those (first round)
%     carried_at_start         documents v1 ('did_v1') at the start of the sweep
%     carried_by_sweep         sources carried here (carry-064)
%     carried_by_class         struct array {class_name, count}, most first
%     outputs_dropped          pass-1 outputs of a carried source dropped
%     outputs_kept_referenced  pass-1 outputs of a carried source kept, because
%                              another document names them
%     left_no_source           documents naming a final carry that no source
%                              could be found for (left as they are)
%     left_no_source_sample    up to 20 of them {id, class_name, edge_name,
%                              edge_document_id}
%     source_unreadable        a source that could not be read (left as it is)
%     session_edges_to_v1      `session_id` edges naming a final carry (not followed)
%     rounds                   passes of the loop
%     carry_rows               struct array {id, row, dependency}: each source
%                              carried here, row carry-064, and the id of the
%                              v1 document its edge names
%
%   See also ndi.migrate.local, ndi.migrate.internal.carryUnchangedAsV1,
%            did2.convert.v1_to_v2, did2.schema.isV1Stamp.

arguments
    docs cell
    sourceBodies
    sourceOutputs struct = struct('input_index', {}, 'id', {}, 'output_ids', {})
end

if ~iscell(sourceBodies)
    sourceBodies = num2cell(sourceBodies);
end
nSources = numel(sourceBodies);

report = struct( ...
    'documents_inspected',     numel(docs), ...
    'v2_documents_inspected',  0, ...
    'edges_examined',          0, ...
    'carried_at_start',        0, ...
    'carried_by_sweep',        0, ...
    'carried_by_class',        struct('class_name', {}, 'count', {}), ...
    'outputs_dropped',         0, ...
    'outputs_kept_referenced', 0, ...
    'left_no_source',          0, ...
    'left_no_source_sample',   struct('id', {}, 'class_name', {}, ...
                                      'edge_name', {}, 'edge_document_id', {}), ...
    'source_unreadable',       0, ...
    'session_edges_to_v1',     0, ...
    'rounds',                  0, ...
    'carry_rows',              struct('id', {}, 'row', {}, 'dependency', {}));
if isempty(docs)
    return;
end

% --- where each source is: by its id, and by each of its pass-1 outputs ------
sourceOf = containers.Map('KeyType', 'char', 'ValueType', 'double');  % v1 id -> source
ownerOf = containers.Map('KeyType', 'char', 'ValueType', 'double');   % output id -> source
outputsOf = cell(1, nSources);
if ~isempty(sourceOutputs) && isfield(sourceOutputs, 'input_index') ...
        && isfield(sourceOutputs, 'id')
    hasOut = isfield(sourceOutputs, 'output_ids');
    for r = 1:numel(sourceOutputs)
        k = sourceOutputs(r).input_index;
        if ~isnumeric(k) || ~isscalar(k) || k < 1 || k > nSources
            continue;   % a transient body (the navigator epoch files), not a source
        end
        sid = char(sourceOutputs(r).id);
        if ~isempty(sid) && ~isKey(sourceOf, sid)
            sourceOf(sid) = k;
        end
        if hasOut
            outs = sourceOutputs(r).output_ids;
            if ischar(outs) || isstring(outs)
                outs = cellstr(outs);
            end
            if ~iscell(outs)
                outs = {};
            end
            outputsOf{k} = cellfun(@char, reshape(outs, 1, []), 'UniformOutput', false);
            for o = 1:numel(outputsOf{k})
                if ~isempty(outputsOf{k}{o}) && ~isKey(ownerOf, outputsOf{k}{o})
                    ownerOf(outputsOf{k}{o}) = k;
                end
            end
        end
    end
else
    % no pass-1 record: attribute by shared id only
    for k = 1:nSources
        src = readSource(sourceBodies{k});
        sid = idOf(src);
        if ~isempty(sid) && ~isKey(sourceOf, sid)
            sourceOf(sid) = k;
        end
    end
end

% --- the final carries --------------------------------------------------------
n = numel(docs);
ids = cell(1, n);
isV1 = false(1, n);
for k = 1:n
    ids{k} = idOf(docs{k});
    isV1(k) = did2.schema.isV1Stamp(docs{k}, 'Explicit', true);
end
carriedSet = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = find(isV1)
    if ~isempty(ids{k})
        carriedSet(ids{k}) = true;
    end
end
report.carried_at_start = nnz(isV1);
report.v2_documents_inspected = n - nnz(isV1);
if carriedSet.Count == 0
    return;
end

edgesOf = cell(1, n);
for k = find(~isV1)
    edgesOf{k} = edgesOfDoc(docs{k});
    report.edges_examined = report.edges_examined + numel(edgesOf{k});
end

sourceCarried = false(1, nSources);
leftSeen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
unreadableSeen = false(1, nSources);
carried = struct('names', {{}}, 'counts', []);
sessionEdgeSeen = false(1, n);

changed = true;
while changed
    changed = false;
    report.rounds = report.rounds + 1;
    for k = 1:numel(docs)
        if isV1(k)
            continue;
        end
        e = edgesOf{k};
        hit = 0;
        for j = 1:numel(e)
            target = e(j).document_id;
            if strcmp(target, ids{k}) || ~isKey(carriedSet, target)
                continue;
            end
            if strcmp(e(j).name, 'session_id')
                if ~sessionEdgeSeen(k)
                    sessionEdgeSeen(k) = true;
                    report.session_edges_to_v1 = report.session_edges_to_v1 + 1;
                end
                continue;   % not followed (see WHAT IS SWEPT)
            end
            hit = j;
            break;
        end
        if hit == 0
            continue;
        end
        s = 0;
        if ~isempty(ids{k}) && isKey(sourceOf, ids{k})
            s = sourceOf(ids{k});
        elseif ~isempty(ids{k}) && isKey(ownerOf, ids{k})
            s = ownerOf(ids{k});
        end
        if s == 0
            if ~isKey(leftSeen, ids{k})
                leftSeen(ids{k}) = true;
                report.left_no_source = report.left_no_source + 1;
                if numel(report.left_no_source_sample) < 20
                    report.left_no_source_sample(end+1) = struct('id', ids{k}, ...
                        'class_name', classOf(docs{k}), 'edge_name', e(hit).name, ...
                        'edge_document_id', e(hit).document_id);
                end
            end
            continue;
        end
        if sourceCarried(s)
            continue;   % a further output of a source already carried: dropped below
        end
        src = readSource(sourceBodies{s});
        sid = idOf(src);
        if isempty(src) || isempty(sid)
            if ~unreadableSeen(s)
                unreadableSeen(s) = true;
                report.source_unreadable = report.source_unreadable + 1;
            end
            continue;
        end
        if isKey(carriedSet, sid)
            % the source itself already ends as v1 (an earlier step carried
            % it): nothing to carry, only its other outputs to drop below
            sourceCarried(s) = true;
            continue;
        end
        src.document_class.schema_version = 'did_v1';
        pos = find(strcmp(ids, sid), 1);
        if isempty(pos)
            docs{end+1} = did2.document(src); %#ok<AGROW>
            ids{end+1} = sid; %#ok<AGROW>
            isV1(end+1) = true; %#ok<AGROW>
            edgesOf{end+1} = struct('name', {}, 'document_id', {}); %#ok<AGROW>
            sessionEdgeSeen(end+1) = false; %#ok<AGROW>
        else
            docs{pos} = did2.document(src);
            isV1(pos) = true;
        end
        carriedSet(sid) = true;
        sourceCarried(s) = true;
        report.carried_by_sweep = report.carried_by_sweep + 1;
        carried = bump(carried, classOf(src));
        % carry-register: carry-064
        report.carry_rows(end+1) = struct('id', sid, 'row', 'carry-064', ...
            'dependency', e(hit).document_id);
        changed = true;
    end
end

% --- the other pass-1 outputs of a source carried here ------------------------
candidate = false(1, numel(docs));
for s = find(sourceCarried)
    for o = 1:numel(outputsOf{s})
        pos = find(strcmp(ids, outputsOf{s}{o}));
        for p = pos
            if ~isV1(p)
                candidate(p) = true;
            end
        end
    end
end
if any(candidate)
    named = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    for k = find(~candidate)
        if isV1(k)
            e = edgesOfDoc(docs{k});   % a v1 document may name a converted one
        else
            e = edgesOf{k};
        end
        for j = 1:numel(e)
            named(e(j).document_id) = true;
        end
    end
    drop = false(1, numel(docs));
    for k = find(candidate)
        if isKey(named, ids{k})
            report.outputs_kept_referenced = report.outputs_kept_referenced + 1;
        else
            drop(k) = true;
        end
    end
    report.outputs_dropped = nnz(drop);
    docs = docs(~drop);
end

report.carried_by_class = asTable(carried);
if report.left_no_source > 0
    warning('NDI:migrate:finalCarryUnattributed', ...
        ['%d document(s) name a document carried as v1 but have no v1 source ' ...
         'to carry (minted by the second pass); left as they are. First: %s ' ...
         '(%s) via %s -> %s.'], report.left_no_source, ...
        report.left_no_source_sample(1).id, report.left_no_source_sample(1).class_name, ...
        report.left_no_source_sample(1).edge_name, ...
        report.left_no_source_sample(1).edge_document_id);
end
end

% ---- helpers ------------------------------------------------------------------

function e = edgesOfDoc(d)
% The non-empty depends_on edges of D as a struct array {name, document_id}.
e = struct('name', {}, 'document_id', {});
if isa(d, 'did2.document')
    d = d.toStruct();
end
if ~isstruct(d) || ~isscalar(d) || ~isfield(d, 'depends_on') || isempty(d.depends_on)
    return;
end
deps = d.depends_on;
for k = 1:numel(deps)
    if iscell(deps)
        x = deps{k};
    else
        x = deps(k);
    end
    if ~isstruct(x) || ~isscalar(x)
        continue;
    end
    v = '';
    if isfield(x, 'document_id')
        v = x.document_id;
    elseif isfield(x, 'value')
        v = x.value;
    elseif isfield(x, 'id')
        v = x.id;
    end
    if isstring(v) && isscalar(v), v = char(v); end
    if ~ischar(v) || isempty(v)
        continue;
    end
    nm = '';
    if isfield(x, 'name')
        nm = x.name;
        if isstring(nm) && isscalar(nm), nm = char(nm); end
        if ~ischar(nm), nm = ''; end
    end
    e(end+1) = struct('name', nm, 'document_id', v); %#ok<AGROW>
end
end

function c = classOf(d)
c = '';
if isa(d, 'did2.document')
    try
        c = char(d.className());
    catch
        c = '';
    end
    return;
end
if isstruct(d) && isscalar(d) && isfield(d, 'document_class') ...
        && isstruct(d.document_class) && isfield(d.document_class, 'class_name')
    c = char(d.document_class.class_name);
end
end

function t = bump(t, name)
name = char(name);
ix = find(strcmp(t.names, name), 1);
if isempty(ix)
    t.names{end+1} = name;
    t.counts(end+1) = 0;
    ix = numel(t.names);
end
t.counts(ix) = t.counts(ix) + 1;
end

function tbl = asTable(t)
[counts, order] = sort(t.counts, 'descend');
names = t.names(order);
tbl = struct('class_name', names, 'count', num2cell(counts));
if isempty(names)
    tbl = struct('class_name', {}, 'count', {});
end
end

function id = idOf(d)
id = '';
if isa(d, 'did2.document')
    d = d.toStruct();
end
if isstruct(d) && isscalar(d) && isfield(d, 'base') && isstruct(d.base) ...
        && isscalar(d.base) && isfield(d.base, 'id')
    v = d.base.id;
    if isstring(v) && isscalar(v), v = char(v); end
    if ischar(v), id = v; end
end
end

function s = readSource(raw)
% The v1 source as a struct with a document_class block, or [] when it is not one.
s = [];
try
    if isstruct(raw) && isscalar(raw)
        s = raw;
    elseif ischar(raw) || (isstring(raw) && isscalar(raw))
        s = jsondecode(char(raw));
    elseif isa(raw, 'did2.document')
        s = raw.toStruct();
    end
catch
    s = [];
end
if ~isstruct(s) || ~isscalar(s) || ~isfield(s, 'document_class') ...
        || ~isstruct(s.document_class) || ~isscalar(s.document_class)
    s = [];
end
end
