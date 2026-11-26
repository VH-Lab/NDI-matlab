function c = epochInstrumentCensus(bodies, label)
%EPOCHINSTRUMENTCENSUS Interactions that name an instrument, on an epoch or
%   not, in a migrated database, and the device entities they would make
%   elements. Report-only: prints, denominators first, and returns C.
%
%   C = ndi.unittest.migrate.epochInstrumentCensus(BODIES, LABEL). BODIES is
%   every document of the migrated database (a cell of structs, after
%   ndi.migrate.local's second pass), or the path of that database (the
%   `destination` ndi.migrate.local returns), read whole. LABEL names the
%   corpus in the output.
%
%   Decided by Jess Haley, 2026-11-26 [instrument of an epoch interaction is
%   a link] (did-schema docs/plans/did_v2_go_forward_class_audit.md): before
%   it is built, the corpora are counted for interactions that name an
%   `instrument_id` and are not on an epoch; a count other than 0 goes back
%   to the team.
%
%   ON AN EPOCH: one of the interaction's `time_reference_id` documents is a
%   `relative_time_reference` whose `referent_id` is an entity of type epoch
%   (EMPTY:0000383 "recording epoch", by node) of the interaction's own
%   session.
%
%   LINKED BEFORE: a device entity an observation names as `instrument_id`,
%   or the child of a `connected to` (RO:0002170) relation (the link test
%   of ndi.vintage.linkedElements). LINKED AFTER: that, or an interaction on
%   an epoch names it as `instrument_id`. A device an "ndi element class"
%   assertion is about is counted on its own line (the assertion decides
%   while written).

label = char(label);
if ischar(bodies) || (isstring(bodies) && isscalar(bodies))
    bodies = readAll(char(bodies));
end
n = numel(bodies);
byId = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:n
    p = bodies{k};
    if isstruct(p) && isfield(p, 'base') && isfield(p.base, 'id')
        id = char(p.base.id);
        if ~isKey(byId, id); byId(id) = k; end
    end
end
c = struct('documents_inspected', n, 'interactions', 0, 'with_instrument', 0, ...
    'on_epoch', 0, 'not_on_epoch', 0, 'devices', 0, 'devices_linked_before', 0, ...
    'devices_linked_after', 0, 'devices_gained', {{}}, 'devices_asserted', 0, ...
    'devices_unlinked_after', 0);
classCount = containers.Map('KeyType', 'char', 'ValueType', 'any');   % class -> [with, on, off]
whyCount = containers.Map('KeyType', 'char', 'ValueType', 'double');
examples = {};
oldLink = containers.Map('KeyType', 'char', 'ValueType', 'logical');
epochLink = containers.Map('KeyType', 'char', 'ValueType', 'any');
asserted = containers.Map('KeyType', 'char', 'ValueType', 'logical');
devices = {};
names = containers.Map('KeyType', 'char', 'ValueType', 'char');
classVar = ndi.vintage.elementClassVariable();
for k = 1:n
    p = bodies{k};
    if ~isstruct(p) || ~isfield(p, 'document_class'); continue; end
    cn = char(p.document_class.class_name);
    if strcmp(cn, 'entity')
        if strcmp(entityType(p), 'device')
            id = char(p.base.id);
            devices{end+1} = id; %#ok<AGROW>
            names(id) = textOf(p.entity, 'local_identifier');
        end
        continue;
    end
    if strcmp(cn, 'assertion')
        if isfield(p, 'statement') && isfield(p.statement, 'variable')
            v = p.statement.variable;
            if (isfield(v, 'node') && strcmpi(char(v.node), classVar.node)) || ...
                    (isfield(v, 'name') && strcmpi(char(v.name), ndi.vintage.elementLabel('class')))
                for e = ndi.v2.edgeIds(p, 'entity_id'); asserted(e{1}) = true; end
            end
        end
        continue;
    end
    if strcmp(cn, 'directed_relation')
        if isfield(p, 'directed_relation') && isfield(p.directed_relation, 'relation') ...
                && strcmp(char(ndi.v2.vocabHandle('relation', p.directed_relation.relation)), 'connected_to')
            for e = [ndi.v2.edgeIds(p, 'child_id'), ndi.v2.edgeIds(p, 'child')]; oldLink(e{1}) = true; end
        end
        continue;
    end
    if ~isInteraction(p); continue; end
    c.interactions = c.interactions + 1;
    inst = ndi.v2.edgeIds(p, 'instrument_id');
    if isempty(inst); continue; end
    c.with_instrument = c.with_instrument + 1;
    if ~isKey(classCount, cn); classCount(cn) = [0 0 0]; end
    if any(strcmp(cn, ndi.v2.vetaAliases('observation')))
        for i = 1:numel(inst); oldLink(inst{i}) = true; end
    end
    [on, why] = onAnEpoch(p, bodies, byId);
    cc = classCount(cn);
    cc(1) = cc(1) + 1;
    if on
        c.on_epoch = c.on_epoch + 1;
        cc(2) = cc(2) + 1;
        for i = 1:numel(inst)
            if isKey(epochLink, inst{i})
                epochLink(inst{i}) = unique([epochLink(inst{i}), {cn}], 'stable');
            else
                epochLink(inst{i}) = {cn};
            end
        end
    else
        c.not_on_epoch = c.not_on_epoch + 1;
        cc(3) = cc(3) + 1;
        if ~isKey(whyCount, why); whyCount(why) = 0; end
        whyCount(why) = whyCount(why) + 1;
        if numel(examples) < 10
            examples{end+1} = sprintf('%s %s instrument %s (%s)', cn, char(p.base.id), ...
                strjoin(inst, ','), why); %#ok<AGROW>
        end
    end
    classCount(cn) = cc;
end
c.devices = numel(devices);
for k = 1:numel(devices)
    id = devices{k};
    before = isKey(oldLink, id);
    after = before || isKey(epochLink, id);
    c.devices_linked_before = c.devices_linked_before + before;
    c.devices_linked_after = c.devices_linked_after + after;
    c.devices_asserted = c.devices_asserted + isKey(asserted, id);
    if after && ~before
        c.devices_gained{end+1} = sprintf('%s "%s" by %s', id, names(id), strjoin(epochLink(id), ','));
    end
    if ~after && ~isKey(asserted, id)
        c.devices_unlinked_after = c.devices_unlinked_after + 1;
    end
end

fprintf(['[%s] EPOCH INSTRUMENT CENSUS: %d document(s) inspected; %d interaction(s); ' ...
    '%d name an instrument_id: on an epoch %d, NOT on an epoch %d\n'], label, ...
    c.documents_inspected, c.interactions, c.with_instrument, c.on_epoch, c.not_on_epoch);
ks = classCount.keys;
for k = 1:numel(ks)
    cc = classCount(ks{k});
    fprintf('[%s]   instrument %s: %d (on an epoch %d, not %d)\n', label, ks{k}, cc(1), cc(2), cc(3));
end
ks = whyCount.keys;
for k = 1:numel(ks)
    fprintf('[%s]   not on an epoch, %s: %d\n', label, ks{k}, whyCount(ks{k}));
end
for k = 1:numel(examples)
    fprintf('[%s]   example not on an epoch: %s\n', label, examples{k});
end
fprintf(['[%s] EPOCH INSTRUMENT DEVICES: %d device entit(ies); linked before %d, after %d ' ...
    '(gained %d); element class asserted %d; unlinked after %d\n'], label, c.devices, ...
    c.devices_linked_before, c.devices_linked_after, numel(c.devices_gained), ...
    c.devices_asserted, c.devices_unlinked_after);
for k = 1:numel(c.devices_gained)
    fprintf('[%s]   device gained: %s\n', label, c.devices_gained{k});
end
end

function [on, why] = onAnEpoch(p, bodies, byId)
on = false;
refs = ndi.v2.edgeIds(p, 'time_reference_id');
if isempty(refs)
    why = 'no time_reference_id';
    return;
end
sid = ndi.v2.sessionIdOf(p);
whys = {};
for k = 1:numel(refs)
    if ~isKey(byId, refs{k})
        whys{end+1} = 'time reference not in the database'; %#ok<AGROW>
        continue;
    end
    t = bodies{byId(refs{k})};
    tc = char(t.document_class.class_name);
    if ~strcmp(tc, 'relative_time_reference')
        whys{end+1} = tc; %#ok<AGROW>
        continue;
    end
    for r = ndi.v2.edgeIds(t, 'referent_id')
        if ~isKey(byId, r{1})
            whys{end+1} = 'relative to a document not in the database'; %#ok<AGROW>
            continue;
        end
        e = bodies{byId(r{1})};
        ec = char(e.document_class.class_name);
        if strcmp(ec, 'entity')
            et = entityType(e);
            if strcmp(et, 'epoch')
                if strcmp(ndi.v2.sessionIdOf(e), sid)
                    on = true;
                    why = '';
                    return;
                end
                whys{end+1} = 'relative to an epoch of another session'; %#ok<AGROW>
            else
                whys{end+1} = ['relative to an entity of type ' et]; %#ok<AGROW>
            end
        else
            whys{end+1} = ['relative to a ' ec]; %#ok<AGROW>
        end
    end
end
why = strjoin(unique(whys, 'stable'), ' + ');
if isempty(why)
    why = 'relative_time_reference with no referent';
end
end

function tf = isInteraction(p)
names = {char(p.document_class.class_name)};
if isfield(p.document_class, 'superclasses') && ~isempty(p.document_class.superclasses)
    sc = p.document_class.superclasses;
    if isstruct(sc); sc = num2cell(sc); end
    for k = 1:numel(sc)
        if isstruct(sc{k}) && isfield(sc{k}, 'class_name')
            names{end+1} = char(sc{k}.class_name); %#ok<AGROW>
        end
    end
end
tf = any(ismember(names, [ndi.v2.vetaAliases('interaction'), ndi.v2.vetaAliases('observation'), ...
    ndi.v2.vetaAliases('manipulation'), ndi.v2.vetaAliases('calculation')]));
end

function t = entityType(p)
t = '';
if isfield(p, 'entity') && isstruct(p.entity) && isfield(p.entity, 'type') && ~isempty(p.entity.type)
    try
        t = char(ndi.v2.vocabHandle('entity_type', p.entity.type));
    catch
        t = '?';
    end
end
end

function s = textOf(block, name)
s = '';
if isstruct(block) && isfield(block, name) && ~isempty(block.(name))
    s = char(block.(name));
end
end

function bodies = readAll(dstPath)
db = did2.database.sqlitedb(dstPath);
cleanup = onCleanup(@() db.close()); %#ok<NASGU>
ids = db.allIds();
bodies = cell(1, numel(ids));
for k = 1:numel(ids)
    bodies{k} = db.get(ids{k}).toStruct();
end
end
