function [held, undecided] = containersDuring(container, docs, tolerant)
%CONTAINERSDURING The containers each statement's subject was in while the statement held.
%
%   [HELD, UNDECIDED] = ndi.v2.containersDuring(CONTAINER, DOCS, TOLERANT)
%   takes statement documents DOCS (ndi.document, did2.document or structs)
%   and returns, for each, the ids of the containers its subject was
%   `contained_in` at the statement's time (HELD, a cell of row cellstrs), and
%   whether some stay could not be compared with that time (UNDECIDED, a
%   logical row).
%
%   The subject is the statement's entity_id. A container is reached
%     - by the subject's own stay, or by a DISTRIBUTIVE stay of a group it is
%       member_of (a worm through its cohort's stay on a plate; did-schema
%       tenet T17, Haley decision #55). The relations that lead from a member
%       to its group are those whose `passes` is `distributive` in the V2
%       schema's registry (ndi.v2.relationPasses, as ndi.entity takes them);
%     - then by the container's own stays, nested (a plate in an incubator),
%       each within the window of the stay that reached it; up to 4 levels.
%   A stay counts only when its time overlaps the statement's
%   (ndi.v2.overlaps, ends included; TOLERANT widens both by their
%   tolerances). Undecidable means not in (T17): a stay with no time or no
%   end, or a statement with no time it can be compared on (an assertion),
%   reaches no container, and UNDECIDED says so. The subject is not its own
%   container.
%
%   Used by ndi.statement.search's 'ContainerAssertion' and
%   'NotContainerAssertion' (V_eta tenet T17, "An assertion about a
%   container stays on the container": a plate's exclusion does not pass to
%   the worms on it; an analysis asks the containers).
%
%   See also ndi.v2.stays, ndi.v2.overlaps, ndi.v2.relationPasses,
%   ndi.statement.search.

arguments
    container
    docs cell
    tolerant (1,1) logical = false
end

n = numel(docs);
held = repmat({{}}, 1, n);
undecided = false(1, n);
if n == 0, return; end
cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
refs = cell(1, n); subj = cell(1, n);
for i = 1:n
    p = ndi.v2.props(docs{i});
    refs{i} = ndi.v2.edgeIds(p, 'time_reference_id');
    s = ndi.v2.edgeIds(p, 'entity_id');
    if isempty(s), s = {''}; end
    subj{i} = s{1};
end
allRefs = unique([refs{:}]);
times = containers.Map('KeyType', 'char', 'ValueType', 'any');
if ~isempty(allRefs), times = ndi.v2.timesOf(container, allRefs, cache); end
T = cell(1, n);
for i = 1:n
    T{i} = {};
    for k = 1:numel(refs{i})
        if isKey(times, refs{i}{k}), T{i}{end+1} = times(refs{i}{k}); end
    end
end

% who holds each statement's stays: the subject, and the groups it is in
% (whose stays count only when distributive)
frontier = struct('at', {}, 'doc', {}, 'group', {}, 'win', {});
for i = 1:n
    if ~isempty(subj{i})
        frontier(end+1) = struct('at', subj{i}, 'doc', i, 'group', false, 'win', []); %#ok<AGROW>
    end
end
level = frontier;
seenGroup = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for depth = 1:4
    if isempty(level), break; end
    E = memberOf(container, unique({level.at}, 'stable'));
    next = struct('at', {}, 'doc', {}, 'group', {}, 'win', {});
    for h = 1:numel(E.from)
        for f = find(strcmp({level.at}, E.from{h}))
            key = sprintf('%d|%s', level(f).doc, E.to{h});
            if isKey(seenGroup, key), continue; end
            seenGroup(key) = true;
            next(end+1) = struct('at', E.to{h}, 'doc', level(f).doc, 'group', true, ...
                'win', []); %#ok<AGROW>
        end
    end
    frontier = [frontier, next]; %#ok<AGROW>
    level = next;
end

% the stays, nested, each within the window of the one that reached it
for depth = 1:4
    if isempty(frontier), break; end
    S = ndi.v2.stays(container, unique({frontier.at}, 'stable'), 'child', cache);
    next = struct('at', {}, 'doc', {}, 'group', {}, 'win', {});
    for j = 1:numel(S)
        for f = find(strcmp({frontier.at}, S(j).child))
            fr = frontier(f);
            if fr.group && ~S(j).distributive, continue; end
            if ~S(j).decided
                undecided(fr.doc) = true;
                continue;
            end
            w = S(j);
            if ~isempty(fr.win)
                w.start = max(w.start, fr.win.start); w.end = min(w.end, fr.win.end);
                if w.start > w.end, continue; end
            end
            [tf, dec] = ndi.v2.overlaps(T{fr.doc}, w, tolerant);
            if ~dec
                undecided(fr.doc) = true;
                continue;
            end
            if ~tf, continue; end
            if ~ismember(S(j).parent, held{fr.doc})
                held{fr.doc}{end+1} = S(j).parent;
                next(end+1) = struct('at', S(j).parent, 'doc', fr.doc, 'group', false, ...
                    'win', w); %#ok<AGROW>
            end
        end
    end
    frontier = next;
end
end

% -----------------------------------------------------------------------------
function E = memberOf(container, ids)
% the relations that pass distributive (member_of; ndi.v2.relationPasses) whose
% child is one of IDS: E.from (the member), E.to (the group), one row per pair
arguments
    container
    ids cell
end
from = {}; to = {};
groupNames = ndi.v2.relationPasses().distributive;
if isempty(groupNames)
    E = struct('from', {from}, 'to', {to});
    return;
end
for c = 1:200:numel(ids)
    part = ids(c:min(c + 199, numel(ids)));
    q = ndi.v2.anyOf(cellfun(@(i) ndi.query('', 'depends_on', 'child_id', i), part, ...
        'UniformOutput', false));
    rels = container.database_search(ndi.query('', 'isa', 'directed_relation', '') & q);
    for k = 1:numel(rels)
        p = ndi.v2.props(rels{k});
        if ~ismember(ndi.v2.vocabHandle('relation', ndi.v2.blockOf(p, 'directed_relation', 'relation', '')), ...
                groupNames)   % by node (L1); relationPasses gives handles
            continue;
        end
        a = ndi.v2.edgeIds(p, 'child_id');
        b = ndi.v2.edgeIds(p, 'parent_id');
        a = a(ismember(a, part));
        for x = 1:numel(a)
            for y = 1:numel(b)
                from{end+1} = a{x}; %#ok<AGROW>
                to{end+1} = b{y}; %#ok<AGROW>
            end
        end
    end
end
E = struct('from', {from}, 'to', {to});
end
