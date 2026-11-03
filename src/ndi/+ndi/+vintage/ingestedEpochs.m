function E = ingestedEpochs(ndi_session_obj, docs, probemapClass)
%INGESTEDEPOCHS Each ingested epoch's id, files and probe map, read from either vintage.
%
%   E = ndi.vintage.ingestedEpochs(SESSION, DOCS, PROBEMAPCLASS). DOCS are
%   the documents ndi.vintage.ingestedQuery found (a cell of ndi.document);
%   PROBEMAPCLASS the navigator's epochprobemap class (already validated by
%   the caller). E is a struct array, one per document, with fields
%
%     epoch_id   the epoch's id string ('t00001')
%     files      the files ingested for it (cellstr)
%     probemap   the epoch's probe map, an object of PROBEMAPCLASS, or []
%                when none can be read
%     vintage    'v1' or 'V_eta'
%
%   v1 `epochfiles_ingested` holds all three in its block. A migrated
%   `ingestion_manifest` (did-schema #88; Jess Haley 2026-10-22 [ingested
%   epochs found]) holds only `files`:
%
%     epoch_id   is the `local_identifier` of the `epoch` entity its
%                `epoch_id` edge names (DID-matlab epochMint)
%     probemap   was DECOMPOSED by DID-matlab's resolveEpochProbemap into one
%                observation (or, for a stimulator, manipulation) per row,
%                timed by a relative_time_reference onto that epoch entity.
%                Each row is put back together from its statement:
%                  name, reference, type  the instrument_id element entity
%                                         (ndi.vintage.elementFields)
%                  subjectstring          the entity_id entity's
%                                         local_identifier
%                  devicestring           the statement's acquisition_system_id
%                                         system's name, ':', then the
%                                         conditions of the probe's wiring
%                                         relation (a directed_relation
%                                         `connected to`, RO:0002170, child
%                                         the probe, parent the system, timed
%                                         by the statement's anchor; did-schema
%                                         [probe wiring is a relation]), each
%                                         a channel type's v1 prefix -- found
%                                         BY NODE through
%                                         ndi.vintage.channelPrefix ([channel
%                                         types]) -- and its numbers. A
%                                         session migrated before that names
%                                         system and channels through an
%                                         acquisition_channels_id document;
%                                         both are read.
%                Rows are kept once each, in statement order. A manifest whose
%                statements give no row reads as probemap [].
%
%                ONLY THE MANIFEST'S OWN SYSTEM. One epoch is one recording,
%                shared by every acquisition system that wrote files for it
%                (Decided by Jess Haley, 2026-10-26 [device clocks on one
%                epoch]: B's vhspike2 and vhvis_spike2 share "t00001"), so
%                the epoch's statements are those of all its systems. A v1
%                navigator's epoch held only its own system's rows, so a row
%                is kept only when its system's `epoch_file_pattern_id` is the
%                manifest's (a row whose system states none is kept). Without
%                this, B's vhvis_spike2 epochs read vhspike2's tet1 row too
%                (VH-Lab/NDI-matlab#785 corpus equivalence: 1,242 epochs).
%
%   Lookups (element fields, systems, subjects) are cached across DOCS, so a
%   navigator reading a session's ingested epochs reads each element once.
%
%   See also ndi.vintage.ingestedQuery, ndi.file.navigator/selectfilegroups.

arguments
    ndi_session_obj
    docs cell
    probemapClass (1,:) char
end

E = struct('epoch_id', {}, 'files', {}, 'probemap', {}, 'vintage', {});
cache = struct('doc', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'element', containers.Map('KeyType', 'char', 'ValueType', 'any'));
for k = 1:numel(docs)
    p = docs{k}.document_properties;
    if isfield(p, 'epochfiles_ingested')
        blk = p.epochfiles_ingested;
        pm = [];
        if isfield(blk, 'epochprobemap') && ~isempty(blk.epochprobemap)
            pm = feval(probemapClass, blk.epochprobemap);
        end
        E(end+1) = struct('epoch_id', char(blk.epoch_id), 'files', {asCellstr(blk.files)}, ...
            'probemap', {pm}, 'vintage', 'v1'); %#ok<AGROW>
        continue;
    end
    if ~isfield(p, 'ingestion_manifest')
        continue;
    end
    files = {};
    if isfield(p.ingestion_manifest, 'files')
        files = asCellstr(p.ingestion_manifest.files);
    end
    epochDocId = docs{k}.dependency_value('epoch_id', 'ErrorIfNotFound', 0);
    [epochDoc, cache] = docById(ndi_session_obj, epochDocId, cache);
    epochId = '';
    if ~isempty(epochDoc)
        epochId = localIdentifier(epochDoc.document_properties);
    end
    patternId = docs{k}.dependency_value('epoch_file_pattern_id', 'ErrorIfNotFound', 0);
    if isempty(patternId)
        patternId = docs{k}.dependency_value('filenavigator_id', 'ErrorIfNotFound', 0);
    end
    [pm, cache] = probemapOf(ndi_session_obj, epochDocId, probemapClass, cache, patternId);
    E(end+1) = struct('epoch_id', epochId, 'files', {files}, 'probemap', {pm}, ...
        'vintage', 'V_eta'); %#ok<AGROW>
end
end

% ===================== the probe map, put back together ===================

function [pm, cache] = probemapOf(S, epochDocId, probemapClass, cache, patternId)
pm = [];
if isempty(epochDocId)
    return;
end
anchors = S.database_search(ndi.query('', 'isa', 'relative_time_reference', '') & ...
    ndi.query('', 'depends_on', 'referent_id', epochDocId));
if isempty(anchors)
    return;
end
q = ndi.v2.anyOf(cellfun(@(a) ndi.query('', 'depends_on', 'time_reference_id', a.id()), ...
    anchors, 'UniformOutput', false));
statements = S.database_search(ndi.v2.isaQuery('statement') & q);
seen = {};
for i = 1:numel(statements)
    st = statements{i};
    acId = st.dependency_value('acquisition_channels_id', 'ErrorIfNotFound', 0);
    sysId = st.dependency_value('acquisition_system_id', 'ErrorIfNotFound', 0);
    elId = st.dependency_value('instrument_id', 'ErrorIfNotFound', 0);
    if (isempty(acId) && isempty(sysId)) || isempty(elId)
        continue;   % not a probe-map row: no rig or no probe
    end
    [own, cache] = isOwnSystem(S, sysId, acId, patternId, cache);
    if ~own
        continue;   % another acquisition system's row of this recording
    end
    [el, cache] = elementOf(S, elId, cache);
    if isempty(el)
        continue;
    end
    subjectString = '';
    sId = st.dependency_value('entity_id', 'ErrorIfNotFound', 0);
    if isempty(sId), sId = st.dependency_value('subject_id', 'ErrorIfNotFound', 0); end
    [sDoc, cache] = docById(S, sId, cache);
    if ~isempty(sDoc)
        subjectString = localIdentifier(sDoc.document_properties);
    end
    if ~isempty(acId)
        [devicestring, cache] = deviceString(S, acId, cache);
    else
        [devicestring, cache] = ndi.vintage.wiredDeviceString(S, st, sysId, elId, cache);
    end
    key = strjoin({el.name, num2str(el.reference), el.type, devicestring, subjectString}, char(0));
    if any(strcmp(seen, key))
        continue;
    end
    seen{end+1} = key; %#ok<AGROW>
    row = feval(probemapClass, el.name, el.reference, el.type, devicestring, subjectString);
    if isempty(pm)
        pm = row;
    else
        pm(end+1) = row; %#ok<AGROW>
    end
end
end

function [tf, cache] = isOwnSystem(S, sysId, acId, patternId, cache)
% Is the row's acquisition system the one whose epoch file pattern is
% PATTERNID? True when either is not stated.
tf = true;
if isempty(patternId)
    return;
end
if isempty(sysId) && ~isempty(acId)
    [ac, cache] = docById(S, acId, cache);
    if ~isempty(ac)
        sysId = ac.dependency_value('acquisition_system_id', 'ErrorIfNotFound', 0);
    end
end
[sys, cache] = docById(S, sysId, cache);
if isempty(sys)
    return;
end
p = sys.dependency_value('epoch_file_pattern_id', 'ErrorIfNotFound', 0);
if isempty(p)
    p = sys.dependency_value('filenavigator_id', 'ErrorIfNotFound', 0);
end
tf = isempty(p) || strcmp(p, patternId);
end

function [s, cache] = deviceString(S, acId, cache)
% 'vhspike2:ai11-14;di1' from an acquisition_channels document (a session
% migrated before [probe wiring is a relation])
s = '';
[ac, cache] = docById(S, acId, cache);
if isempty(ac)
    return;
end
sysName = '';
sysId = ac.dependency_value('acquisition_system_id', 'ErrorIfNotFound', 0);
[sys, cache] = docById(S, sysId, cache);
if ~isempty(sys)
    sysName = char(ndi.vintage.objectName(sys));
end
groups = {};
p = ac.document_properties;
if isfield(p, 'acquisition_channels') && isfield(p.acquisition_channels, 'channels')
    ch = p.acquisition_channels.channels;
    if isstruct(ch), ch = num2cell(ch); end
    for g = 1:numel(ch)
        c = ch{g};
        if ~isstruct(c) || ~isfield(c, 'type'), continue; end
        nums = [];
        if isfield(c, 'numbers'), nums = double(c.numbers(:)'); end
        groups{end+1} = [char(ndi.vintage.channelPrefix(c.type)) ranges(nums)]; %#ok<AGROW>
    end
end
s = sysName;
if ~isempty(groups)
    s = [sysName ':' strjoin(groups, ';')];
end
end

function t = ranges(n)
% [11 12 13 14 20] -> '11-14,20' (ndi.daq.daqsystemstring's own spelling)
t = '';
if isempty(n), return; end
n = n(:)';
parts = {};
i = 1;
while i <= numel(n)
    j = i;
    while j < numel(n) && n(j+1) == n(j) + 1
        j = j + 1;
    end
    if j > i
        parts{end+1} = sprintf('%d-%d', n(i), n(j)); %#ok<AGROW>
    else
        parts{end+1} = sprintf('%d', n(i)); %#ok<AGROW>
    end
    i = j + 1;
end
t = strjoin(parts, ',');
end

function [el, cache] = elementOf(S, id, cache)
% name, reference and type of the element entity ID (cached)
el = [];
if isKey(cache.element, id)
    el = cache.element(id);
    return;
end
[d, cache] = docById(S, id, cache);
if ~isempty(d)
    f = ndi.vintage.elementFields(d, S);
    if ~isempty(f.name)
        el = struct('name', char(f.name), 'reference', f.reference, 'type', char(f.type));
        if isempty(el.reference), el.reference = 0; end
    end
end
cache.element(id) = el;
end

function [d, cache] = docById(S, id, cache)
d = [];
if isempty(id)
    return;
end
if isKey(cache.doc, id)
    d = cache.doc(id);
    return;
end
r = S.database_search(ndi.query('base.id', 'exact_string', id, ''));
if ~isempty(r)
    d = r{1};
end
cache.doc(id) = d;
end

function lid = localIdentifier(p)
lid = '';
for blk = {'entity', 'subject'}
    if isfield(p, blk{1}) && isstruct(p.(blk{1})) && isfield(p.(blk{1}), 'local_identifier')
        lid = char(p.(blk{1}).local_identifier);
        return;
    end
end
end

function c = asCellstr(x)
if isempty(x)
    c = {};
elseif iscell(x)
    c = x;
else
    c = cellstr(x);
end
end
