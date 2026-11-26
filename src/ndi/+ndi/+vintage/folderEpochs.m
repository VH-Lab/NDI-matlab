function D = folderEpochs(S, navigatorId, groups, probemapClass)
%FOLDEREPOCHS A migrated session folder's epochs, their ids and probe maps, read from the database.
%
%   D = ndi.vintage.folderEpochs(SESSION, NAVIGATORID, GROUPS, PROBEMAPCLASS)
%   takes the file groups a file navigator found in the session folder
%   (GROUPS, a cell of cellstr, one per epoch, none ingested) and returns a
%   struct array, one per group, with fields
%
%     found      true when the database holds the epoch: a `recording epoch`
%                entity that the epoch's files belong to
%     epoch_id   that entity's `local_identifier` ('' when not found)
%     probemap   the epoch's probe map put back together from the database,
%                an object of PROBEMAPCLASS or [] ([] when not found)
%     epoch_doc_id  the entity's document id ('' when not found)
%
%   Jess Haley, 2026-11-19, did-schema
%   docs/plans/did_v2_standing_wiring_plan.md:
%     [wiring read from the database only] after migration NDI reads a
%         session's wiring only from its `connected to` relations, not from
%         the `*.epochprobemap.ndi` files; an edit to a file after migration
%         is not seen;
%     [no new hidden epoch-id files] after migration an epoch's id is read
%         from its `recording epoch` entity's `local_identifier`, and NDI
%         writes no new `.epochid.ndi` file;
%     [session folder wiring migrated] migration writes the `connected to`
%         relations of a non-ingested epoch from the session folder's
%         `.epochprobemap.ndi` files (ndi.migrate.internal.navigatorEpochFiles
%         and DID-matlab did2.convert.resolveEpochProbemap).
%
%   HOW AN EPOCH'S FILES LEAD TO ITS ENTITY. Migration records each file of
%   a non-ingested epoch as an `opaque_body` BY LOCATION (location_type
%   'file', `data_body.filename` the file's name, the location the path v1
%   read it from), owned by that epoch's recording observations, which are
%   timed by a relative_time_reference onto the epoch entity (DID-matlab
%   resolveEpochProbemap, "THE EPOCH'S FILES ARE THE OBSERVATIONS' DATA
%   BODIES"; Jess Haley, 2026-10-21, V_eta_recording_observation_plan.md).
%   So: the bodies named like the group's files whose location is that file
%   (the same path, or the same path below the session folder, so a session
%   folder that was moved still matches) -> their owners -> the owners'
%   time references -> the `recording epoch` entity they point at. A group
%   whose files lead to no epoch entity, or to more than one, is not found;
%   its reader keeps the v1 reading for it (see ndi.file.navigator).
%
%   THE PROBE MAP is the one ndi.vintage.ingestedEpochs puts together for a
%   migrated ingested epoch, from the statements and the `connected to`
%   relations timed onto the epoch, keeping the rows of the acquisition
%   system whose epoch file pattern is NAVIGATORID.
%
%   On a session that is not on a v2 database, nothing is found.
%
%   See also ndi.vintage.ingestedEpochs, ndi.file.navigator/databaseEpochs.

arguments
    S
    navigatorId (1,:) char
    groups cell
    probemapClass (1,:) char
end

n = numel(groups);
D = struct('found', num2cell(false(1, n)), 'epoch_id', {''}, 'probemap', {[]}, ...
    'epoch_doc_id', {''});
if n == 0 || ~ndi.daq.reader.isv2database(S)
    return;
end
root = normPath(char(S.getpath()));

% every file of every group: its name, its path and its path below the folder
names = {};
paths = {};
rels = {};
owner = [];
for g = 1:n
    files = cellstr(groups{g});
    for f = 1:numel(files)
        p = normPath(files{f});
        if isempty(p) || contains(p, '://'); continue; end
        [~, stem, ext] = fileparts(p);
        names{end+1} = [stem ext]; %#ok<AGROW>
        paths{end+1} = p; %#ok<AGROW>
        rel = '';
        if ~isempty(root) && startsWith(p, [root '/'])
            rel = p(numel(root) + 2:end);
        end
        rels{end+1} = rel; %#ok<AGROW>
        owner(end+1) = g; %#ok<AGROW>
    end
end
if isempty(names)
    return;
end

% the bodies by location named like those files, 200 names to a search
un = unique(names);
bodies = {};
for c = 1:200:numel(un)
    part = un(c:min(c + 199, numel(un)));
    bodies = [bodies, reshape(S.database_search(ndi.query('', 'isa', 'opaque_body', '') & ...
        ndi.v2.anyOf(cellfun(@(x) ndi.query('data_body.filename', 'exact_string', x, ''), ...
        part, 'UniformOutput', false))), 1, [])]; %#ok<AGROW>
end
if isempty(bodies)
    return;
end

% each body's group (by its location), and its owners
ownersOf = cell(1, n);
for b = 1:numel(bodies)
    p = ndi.v2.props(bodies{b});
    loc = locationOf(p);
    if isempty(loc); continue; end
    for k = 1:numel(paths)
        if strcmp(loc, paths{k}) || (~isempty(rels{k}) && endsWith(loc, ['/' rels{k}]))
            ownersOf{owner(k)} = [ownersOf{owner(k)}, ndi.v2.edgeIds(p, 'owner_id')];
        end
    end
end

% owners -> their time references -> the recording epoch entities
allOwners = unique([{}, ownersOf{:}]);
if isempty(allOwners)
    return;
end
ownerDocs = ndi.vintage.docsById(S, allOwners);
anchorsOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
allAnchors = {};
for k = 1:numel(allOwners)
    d = ownerDocs(allOwners{k});
    a = {};
    if ~isempty(d)
        a = ndi.v2.edgeIds(ndi.v2.props(d), 'time_reference_id');
    end
    anchorsOf(allOwners{k}) = a;
    allAnchors = [allAnchors, a]; %#ok<AGROW>
end
allAnchors = unique(allAnchors);
if isempty(allAnchors)
    return;
end
anchorDocs = ndi.vintage.docsById(S, allAnchors);
referentOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
allReferents = {};
for k = 1:numel(allAnchors)
    d = anchorDocs(allAnchors{k});
    r = {};
    if ~isempty(d)
        r = ndi.vintage.edgeTargets(d, 'referent_id');
    end
    referentOf(allAnchors{k}) = r;
    allReferents = [allReferents, r]; %#ok<AGROW>
end
allReferents = unique(allReferents);
if isempty(allReferents)
    return;
end
referentDocs = ndi.vintage.docsById(S, allReferents);

epochDocs = {};
at = zeros(1, 0);
for g = 1:n
    found = {};
    for o = unique(ownersOf{g})
        for a = anchorsOf(o{1})
            for r = referentOf(a{1})
                d = referentDocs(r{1});
                if ~isempty(d) && isEpochEntity(ndi.v2.props(d)) && ~any(strcmp(found, r{1}))
                    found{end+1} = r{1}; %#ok<AGROW>
                end
            end
        end
    end
    if numel(found) ~= 1
        continue;
    end
    d = referentDocs(found{1});
    D(g).found = true;
    D(g).epoch_doc_id = found{1};
    D(g).epoch_id = char(ndi.v2.props(d).entity.local_identifier);
    epochDocs{end+1} = d; %#ok<AGROW>
    at(end+1) = g; %#ok<AGROW>
end
if isempty(epochDocs)
    return;
end
E = ndi.vintage.ingestedEpochs(S, epochDocs, probemapClass, 'PatternId', navigatorId, ...
    'UseIndex', false);
for k = 1:numel(at)
    D(at(k)).probemap = E(k).probemap;
end
end

function loc = locationOf(p)
% the one location of a body recorded by location (location_type 'file'),
% '' for any other body
loc = '';
if ~isfield(p, 'files') || ~isstruct(p.files) || ~isfield(p.files, 'file_info') ...
        || isempty(p.files.file_info)
    return;
end
fi = p.files.file_info;
if iscell(fi); fi = [fi{:}]; end
if ~isstruct(fi) || ~isfield(fi, 'locations'); return; end
l = fi(1).locations;
if iscell(l); l = [l{:}]; end
if ~isstruct(l) || isempty(l) || ~isfield(l, 'location'); return; end
for k = 1:numel(l)
    if isfield(l(k), 'location_type') && ~strcmp(char(l(k).location_type), 'file')
        continue;
    end
    loc = normPath(char(l(k).location));
    return;
end
end

function tf = isEpochEntity(p)
% an `entity` of type epoch (EMPTY:0000383, "recording epoch"; written
% 'epoch' by older migrations), as ndi.vintage.epochSeries reads it
tf = false;
if ~isfield(p, 'entity') || ~isstruct(p.entity) || ~isfield(p.entity, 'type') ...
        || ~isstruct(p.entity.type) || ~isfield(p.entity, 'local_identifier')
    return;
end
t = p.entity.type;
name = ''; node = '';
if isfield(t, 'name'); name = char(t.name); end
if isfield(t, 'node'); node = char(t.node); end
tf = strcmp(node, 'EMPTY:0000383') || strcmpi(name, 'epoch') || strcmpi(name, 'recording epoch');
end

function p = normPath(p)
% forward slashes, no trailing slash
p = strrep(char(p), '\', '/');
while numel(p) > 1 && endsWith(p, '/')
    p = p(1:end-1);
end
end
