function [pairs, report] = expectedEpochPairs(structs)
%EXPECTEDEPOCHPAIRS The (session, epoch string) pairs did2.convert.epochMint
%   will have an `epoch` entity for, read off the batch BEFORE it runs.
%
%   [PAIRS, REPORT] = ndi.migrate.internal.expectedEpochPairs(STRUCTS)
%
%   Decided by Jess Haley, 2026-10-27 [epoch-less presentations carry]
%   (did-schema V_eta_go_forward_class_audit.md): after [presentation anchored
%   to its epoch], a presentation whose manipulation could not be anchored to
%   its epoch is carried whole as v1 instead of being written anchored to the
%   session. NDI's stimulus pass runs before epochMint, so it decides from this
%   prediction; ndi.migrate.local checks the prediction against the epoch
%   anchor fold afterwards and reports any miss as a defect.
%
%   The rules are epochMint's own (DID-matlab +did2/+convert/epochMint.m, the
%   find-or-create loop): every epoch string did2.validate.epochStrings reads
%   off a document, keyed on the PAIR (did2.convert.epochIndex.pairKey), is
%   minted unless the string is synthetic (`whole_session_...`), the document
%   has no session id, or its session has no `session` document or more than
%   one (a #88 `entity` of type session counts, as in epochMint's
%   classNameOf). An `epoch` document already in the batch counts as its pair.
%
%   STRUCTS  cell of document property structs (the batch as it will reach
%            epochMint, without the documents the caller is about to consume).
%   PAIRS    containers.Map, pair key -> true.
%   REPORT   denominators first: documents_inspected, documents_unreadable,
%            session_documents, epoch_documents, pairs_expected, and the
%            refused pairs by reason (synthetic, no_session_id,
%            no_session_document, ambiguous_session).

arguments
    structs cell
end

report = struct( ...
    'documents_inspected',          numel(structs), ...
    'documents_unreadable',         0, ...
    'session_documents',            0, ...
    'epoch_documents',              0, ...
    'pairs_expected',               0, ...
    'refused_synthetic',            0, ...
    'refused_no_session_id',        0, ...
    'refused_no_session_document',  0, ...
    'refused_ambiguous_session',    0);
pairs = containers.Map('KeyType', 'char', 'ValueType', 'logical');

n = numel(structs);
sids = cell(1, n);
strs = cell(1, n);
cls = cell(1, n);
sessionCount = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:n
    sids{k} = ''; strs{k} = {}; cls{k} = '';
    b = structs{k};
    if ~isstruct(b) || ~isscalar(b)
        report.documents_unreadable = report.documents_unreadable + 1;
        continue;
    end
    try
        cls{k} = classNameOf(b);
        sids{k} = char(did2.schema.cache.sessionIdOf(b));
        hits = did2.validate.epochStrings(b);
        strs{k} = {hits.value};
    catch
        report.documents_unreadable = report.documents_unreadable + 1;
        continue;
    end
    if strcmp(cls{k}, 'session') && ~isempty(sids{k}) && ~isempty(baseId(b))
        report.session_documents = report.session_documents + 1;
        if isKey(sessionCount, sids{k})
            sessionCount(sids{k}) = sessionCount(sids{k}) + 1;
        else
            sessionCount(sids{k}) = 1;
        end
    end
    if strcmp(cls{k}, 'epoch')
        lid = '';
        for blk = {'entity', 'epoch'}
            if isempty(lid) && isfield(b, blk{1}) && isstruct(b.(blk{1})) ...
                    && isfield(b.(blk{1}), 'local_identifier')
                lid = char(b.(blk{1}).local_identifier);
            end
        end
        if ~isempty(lid)
            report.epoch_documents = report.epoch_documents + 1;
            pairs(did2.convert.epochIndex.pairKey(sids{k}, lid)) = true;
        end
    end
end

refused = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:n
    sid = sids{k};
    for j = 1:numel(strs{k})
        es = char(strs{k}{j});
        if isempty(es); continue; end
        key = did2.convert.epochIndex.pairKey(sid, es);
        if isKey(pairs, key) || isKey(refused, key); continue; end
        if startsWith(es, 'whole_session_')
            refused(key) = true;
            report.refused_synthetic = report.refused_synthetic + 1;
        elseif isempty(sid)
            refused(key) = true;
            report.refused_no_session_id = report.refused_no_session_id + 1;
        elseif ~isKey(sessionCount, sid)
            refused(key) = true;
            report.refused_no_session_document = report.refused_no_session_document + 1;
        elseif sessionCount(sid) > 1
            refused(key) = true;
            report.refused_ambiguous_session = report.refused_ambiguous_session + 1;
        else
            pairs(key) = true;
        end
    end
end
report.pairs_expected = double(pairs.Count);
end

function c = classNameOf(b)
% as epochMint's classNameOf: an `entity` (did-schema #88) answers its type's
% handle ('session', 'epoch'), so a session entity counts as a session document
c = '';
if isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    c = char(b.document_class.class_name);
end
if strcmp(c, 'entity') && isfield(b, 'entity') && isstruct(b.entity) ...
        && isfield(b.entity, 'type')
    t = did2.build.vocabularyHandle('entity_type', b.entity.type);
    if ~isempty(t); c = char(t); end
end
end

function id = baseId(b)
id = '';
if isfield(b, 'base') && isstruct(b.base) && isfield(b.base, 'id')
    id = char(b.base.id);
end
end
