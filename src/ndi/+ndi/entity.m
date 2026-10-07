classdef entity
    % ndi.entity - something a V2 dataset names: a subject, a person, an organization, ...
    %
    % An ndi.entity is a read-only view of one V2 `entity` document (a subject,
    % strain, study, person, organization, product, software, funding,
    % publication, ...), with the session or dataset it was read from. Nothing
    % about it changes after it is made: its statements and relations are
    % other documents, found by query each time they are asked for, so a new
    % statement or relation added to the database is seen at once.
    %
    % ndi.subject is an ndi.entity. ndi.session and ndi.dataset are not
    % (design: src/ndi/docs/NDI-matlab/manual/developer/V2_Object_Layer.md).
    %
    % Make one with ndi.entity.fromDocument or ndi.entity.search:
    %
    %   p = ndi.entity.search(ds, 'person');          % a cell array
    %   p{1}.name                                    % 'Jess Haley'
    %   p{1}.parents('affiliated_with')              % her organizations
    %
    % READ THROUGH THE DATASET. A search through an ndi.session sees only
    % that session's documents, and the shared entities (people,
    % organizations, studies, strains, software, instruments) are stored
    % with the dataset. An entity read through the ndi.dataset reaches
    % everything; one read through a session does not reach those.
    %
    % ndi.entity Properties (read from the document when asked; '' without one):
    %   name               - a display name
    %   kind               - the document class ('person', 'subject', ...)
    %   document_id        - the document's base.id
    %
    % ndi.entity Methods:
    %   document           - the ndi.document
    %   document_properties - its properties (a struct)
    %   global_identifiers - table: scheme, value (ORCID, ROR, RRID, DOI, ...)
    %   relations          - table of the relations it (or an array of
    %                        entities) takes part in
    %   parents, children  - the entities across a relation, or a path of
    %                        them, from one entity or an array of them
    %   ancestors, descendants - the nearest entities of a type or kind,
    %                        following any relation: you need not know which
    %   fromDocument, search - (static) make entities
    %
    % See also ndi.subject, ndi.statement.

    properties (Dependent, SetAccess = private)
        % Read from the entity's document each time they are asked for:
        % nothing is stored. Empty for an entity with no document (a v1
        % ndi.subject made with its constructor).
        name          % a display name (see get.name)
        kind          % the document class, e.g. 'person', 'subject'
        document_id   % the document's base.id
    end

    properties (SetAccess = protected, GetAccess = public, Hidden)
        entity_document_ = []   % the ndi.document (or document struct) this entity reads
        container_ = []         % the ndi.session or ndi.dataset it was read from
    end

    methods
        function obj = entity(container, doc)
            % ENTITY - an ndi.entity for DOC, read from CONTAINER
            %
            % OBJ = ndi.entity(CONTAINER, DOC); CONTAINER is an ndi.session or
            % ndi.dataset, DOC an entity document. ndi.entity.fromDocument
            % returns the right subclass (an ndi.subject for a subject).
            if nargin == 0
                return;
            end
            obj.container_ = container;
            obj.entity_document_ = doc;
        end

        function d = document(obj)
            % DOCUMENT - the entity's ndi.document
            d = obj.entity_document_;
        end

        function p = document_properties(obj)
            % DOCUMENT_PROPERTIES - the entity document's properties (a struct)
            p = ndi.v2.props(obj.entity_document_);
        end

        function id = get.document_id(obj)
            % DOCUMENT_ID - the entity document's base.id ('' without a document)
            id = '';
            if isempty(obj.entity_document_), return; end
            p = obj.document_properties();
            id = char(p.base.id);
        end

        function k = get.kind(obj)
            % KIND - the entity's document class, e.g. 'person', 'subject'
            k = '';
            if isempty(obj.entity_document_), return; end
            p = obj.document_properties();
            k = char(p.document_class.class_name);
        end

        function n = get.name(obj)
            % NAME - a display name
            %
            % The class's own `name` when it has one; a person's given and
            % family names; else a subject's local_identifier, else base.name.
            n = '';
            if isempty(obj.entity_document_), return; end
            p = obj.document_properties();
            k = obj.kind;
            n = char(ndi.v2.blockOf(p, k, 'name', ''));
            if isempty(n) && strcmp(k, 'person')
                n = strtrim([char(ndi.v2.blockOf(p, k, 'given_name', '')) ' ' ...
                    char(ndi.v2.blockOf(p, k, 'family_name', ''))]);
            end
            if isempty(n)
                n = char(ndi.v2.blockOf(p, k, 'local_identifier', ''));
            end
            if isempty(n)
                n = char(ndi.v2.blockOf(p, 'base', 'name', ''));
            end
        end

        function T = global_identifiers(obj)
            % GLOBAL_IDENTIFIERS - table with columns scheme and value
            p = obj.document_properties();
            g = ndi.v2.blockOf(p, 'entity', 'global_identifier', []);
            scheme = strings(0, 1); value = strings(0, 1);
            g = ndi.v2.entries(g);
            for i = 1:numel(g)
                sc = ''; v = '';
                if isfield(g{i}, 'scheme'), sc = ndi.v2.termName(g{i}.scheme); end
                if isfield(g{i}, 'value'), v = char(g{i}.value); end
                scheme(end+1, 1) = string(sc); %#ok<AGROW>
                value(end+1, 1) = string(v); %#ok<AGROW>
            end
            T = table(scheme, value);
        end

        function T = relations(obj, relationName, options)
            % RELATIONS - the relations this entity (or these entities) take part in
            %
            % T = RELATIONS(OBJ) returns a table, one row per relation document
            % and entity of OBJ at one end of it:
            %   start_id    the entity of OBJ the row is about
            %   start_name  its name
            %   relation    the relation's name (e.g. 'member_of', 'part_of')
            %   direction   "out" when this entity is the child (the subject of
            %               the sentence: worm member_of cohort), "in" when it
            %               is the parent
            %   other_id    the document id at the other end
            %   roles       the relation's roles, joined with ', '
            %   relation_id the relation document's id
            % T = RELATIONS(OBJ, RELATIONNAME) keeps one relation (or any of
            % a cell array of names). 'Direction' 'out', 'in' or 'both'
            % (default).
            %
            % OBJ may be an array of entities (of one class); from a cell
            % array C call it as a function, RELATIONS([C{:}]) -- one search
            % per direction for every 200 entities, not one per entity. A
            % relation whose two ends are both in OBJ gives two rows, one
            % for each end.
            arguments
                obj
                relationName {mustBeText} = ''
                options.Direction (1,:) char {mustBeMember(options.Direction, {'out', 'in', 'both'})} = 'both'
            end
            start_id = strings(0, 1); start_name = strings(0, 1);
            relation = strings(0, 1); direction = strings(0, 1); other_id = strings(0, 1);
            roles = strings(0, 1); relation_id = strings(0, 1);
            T = table(start_id, start_name, relation, direction, other_id, roles, relation_id);
            if isempty(obj)
                return;
            end
            ids = arrayfun(@(x) x.document_id, obj, 'UniformOutput', false);
            [ids, iu] = unique(ids(:), 'stable');
            names = arrayfun(@(x) string(x.name), obj(iu), 'UniformOutput', false);
            nameOf = containers.Map(ids, names);
            container = obj(1).container_;
            if isempty(relationName), wanted = {}; else, wanted = cellstr(relationName); end
            sides = {'out', 'child_id', 'parent_id'; 'in', 'parent_id', 'child_id'};
            chunk = 200;
            for s = 1:2
                if ~strcmp(options.Direction, 'both') && ~strcmp(options.Direction, sides{s, 1})
                    continue;
                end
                for c = 1:chunk:numel(ids)
                    part = ids(c:min(c + chunk - 1, numel(ids)));
                    q = ndi.entity.anyOf(cellfun(@(i) ndi.query('', 'depends_on', sides{s, 2}, i), ...
                        part, 'UniformOutput', false));
                    docs = container.database_search(ndi.query('', 'isa', 'directed_relation', '') & q);
                    for i = 1:numel(docs)
                        p = ndi.v2.props(docs{i});
                        r = ndi.v2.termName(ndi.v2.blockOf(p, 'directed_relation', 'relation', ''));
                        if ~isempty(wanted) && ~any(strcmp(r, wanted))
                            continue;
                        end
                        mine = ndi.v2.edgeIds(p, sides{s, 2});
                        mine = unique(mine(ismember(mine, part)), 'stable');
                        other = ndi.v2.edgeIds(p, sides{s, 3});
                        rl = ndi.v2.entries(ndi.v2.blockOf(p, 'directed_relation', 'roles', []));
                        rn = {};
                        for j = 1:numel(rl), rn{end+1} = ndi.v2.termName(rl{j}); end %#ok<AGROW>
                        for m = 1:numel(mine)
                            start_id(end+1, 1) = string(mine{m}); %#ok<AGROW>
                            start_name(end+1, 1) = nameOf(mine{m}); %#ok<AGROW>
                            relation(end+1, 1) = string(r); %#ok<AGROW>
                            direction(end+1, 1) = string(sides{s, 1}); %#ok<AGROW>
                            other_id(end+1, 1) = string(strjoin(other, ', ')); %#ok<AGROW>
                            roles(end+1, 1) = string(strjoin(rn, ', ')); %#ok<AGROW>
                            relation_id(end+1, 1) = string(p.base.id); %#ok<AGROW>
                        end
                    end
                end
            end
            T = table(start_id, start_name, relation, direction, other_id, roles, relation_id);
        end

        function e = parents(obj, path, options)
            % PARENTS - the entities this one points to, across one relation or a path of them
            %
            % E = PARENTS(OBJ, RELATIONNAME), a cell array: e.g. a worm's
            % parents('member_of') is its cohort. An end that is not found
            % from this container (see the class help) is left out.
            %
            % RELATIONNAME may be a PATH, a cell array of relation names
            % followed in turn, and OBJ may be an array of entities (of one
            % class). From a cell array C, call it as a function --
            % PARENTS([C{:}], ...) -- since [C{:}].parents(...) is not
            % valid MATLAB:
            %
            %   w.parents({'member_of', 'contained_in'})        % a worm's plates
            %   parents([worms{:}], {'member_of', 'contained_in'})
            %
            % Each step is one search over every entity reached so far, not
            % one per entity. Each entity is returned once.
            % 'Table', true returns a table instead, one row per (start, end)
            % pair: start_id, start_name, end_id, end_name, end (the entity).
            arguments
                obj
                path {mustBeText}
                options.Table (1,1) logical = false
            end
            e = obj.walk(path, 'out', options.Table);
        end

        function e = children(obj, path, options)
            % CHILDREN - the entities that point to this one, across one relation or a path of them
            %
            % E = CHILDREN(OBJ, RELATIONNAME), a cell array: e.g. a cohort's
            % children('member_of') are its worms. As with PARENTS,
            % RELATIONNAME may be a path and OBJ an array:
            %
            %   plate.children({'contained_in', 'member_of'})   % the worms that were on a plate
            %   children([plates{:}], {'contained_in', 'member_of'}, 'Table', true)
            arguments
                obj
                path {mustBeText}
                options.Table (1,1) logical = false
            end
            e = obj.walk(path, 'in', options.Table);
        end

        function e = descendants(obj, options)
            % DESCENDANTS - the entities reached by following relations down, of a type or kind
            %
            % E = DESCENDANTS(OBJ, 'Type', TYPE) follows every relation
            % inward (to the entities that point to OBJ: its members, its
            % parts, what was contained in it), then theirs, and so on, and
            % returns the nearest entities whose subject type is TYPE --
            % without knowing which relations lead there:
            %
            %   descendants([plates{:}], 'Type', 'organism')  % the worms that were on them
            %
            % OBJ may be an array of entities (of one class; from a cell
            % array C, call DESCENDANTS([C{:}], ...) as above). Options:
            %   'Type'      a subject type: 'organism', 'group', 'material',
            %               'culture', ... (ndi.subject's `type`)
            %   'Kind'      a document class the entity is (isa): 'subject',
            %               'person', 'strain', ...
            %   'Relation'  follow only these relations (default: all)
            %   'MaxDepth'  steps to take at most (default 10)
            %   'Table'     true: a table instead, as PARENTS returns, with
            %               a `depth` column (the steps taken)
            % An entity that matches is returned and not followed further.
            % With neither 'Type' nor 'Kind', every entity reached is
            % returned. Each step is one search over everything reached so
            % far; each entity is visited once. With 'Type' or 'Kind', the
            % search picks out the matches, and only they are read: the
            % entities passed through on the way are followed by id alone.
            arguments
                obj
                options.Type (1,:) char = ''
                options.Kind (1,:) char = ''
                options.Relation {mustBeText} = {}
                options.MaxDepth (1,1) double {mustBePositive} = 10
                options.Table (1,1) logical = false
            end
            e = obj.reach('in', options);
        end

        function e = ancestors(obj, options)
            % ANCESTORS - the entities reached by following relations up, of a type or kind
            %
            % E = ANCESTORS(OBJ, 'Type', TYPE): as DESCENDANTS, following
            % every relation outward (to what OBJ is a member of, part of,
            % contained in, ...):
            %
            %   w.ancestors('Type', 'material')      % the plates a worm was on
            %   w.ancestors('Type', 'group')         % its cohort
            arguments
                obj
                options.Type (1,:) char = ''
                options.Kind (1,:) char = ''
                options.Relation {mustBeText} = {}
                options.MaxDepth (1,1) double {mustBePositive} = 10
                options.Table (1,1) logical = false
            end
            e = obj.reach('out', options);
        end
    end

    methods (Access = protected)
        function out = walk(obj, path, direction, asTable)
            % WALK - follow PATH from every entity in OBJ, one search per step
            path = cellstr(path);
            if isempty(obj)
                out = {};
                if asTable, out = ndi.entity.emptyWalkTable(); end
                return;
            end
            container = obj(1).container_;
            ids = arrayfun(@(x) x.document_id, obj, 'UniformOutput', false);
            ids = ids(:);
            % pairs: one row per (start, current) still being followed
            pairs = unique(table(ids, ids, 'VariableNames', {'start', 'at'}), 'stable');
            if strcmp(direction, 'out')
                from = 'child_id'; to = 'parent_id';
            else
                from = 'parent_id'; to = 'child_id';
            end
            for s = 1:numel(path)
                E = ndi.entity.edges(container, unique(pairs.at, 'stable'), path{s}, from, to);
                pairs = innerjoin(pairs, E, 'LeftKeys', 'at', 'RightKeys', 'from');
                pairs = unique(table(pairs.start, pairs.to, 'VariableNames', {'start', 'at'}), 'stable');
                if height(pairs) == 0
                    break;
                end
            end
            endIds = unique(pairs.at, 'stable');
            ents = ndi.entity.fetch(container, endIds);
            found = ~cellfun(@isempty, ents);
            if ~asTable
                out = ents(found)';
                return;
            end
            byId = containers.Map(endIds(found), ents(found));
            [u, iu] = unique(ids, 'stable');
            nameOf = containers.Map(u, arrayfun(@(x) string(x.name), obj(iu), 'UniformOutput', false));
            keep = isKey(byId, pairs.at);
            pairs = pairs(keep, :);
            out = ndi.entity.emptyWalkTable();
            n = height(pairs);
            if n == 0, return; end
            ends = values(byId, pairs.at);
            out = table(string(pairs.start), string(cellfun(@(i) char(nameOf(i)), pairs.start, 'UniformOutput', false)), ...
                string(pairs.at), string(cellfun(@(x) x.name, ends(:), 'UniformOutput', false)), ends(:), ...
                'VariableNames', {'start_id', 'start_name', 'end_id', 'end_name', 'end'});
        end

        function out = reach(obj, direction, options)
            % REACH - breadth-first over relations from every entity in OBJ
            filtered = ~isempty(options.Type) || ~isempty(options.Kind);
            filterQuery = [];
            if ~isempty(options.Type)
                filterQuery = ndi.query('subject.type.name', 'exact_string', options.Type, '');
            end
            if ~isempty(options.Kind)
                k = ndi.query('', 'isa', options.Kind, '');
                if isempty(filterQuery), filterQuery = k; else, filterQuery = filterQuery & k; end
            end
            rel = cellstr(options.Relation);
            empty = ndi.entity.emptyWalkTable();
            empty.depth = zeros(0, 1);
            if isempty(obj)
                out = {};
                if options.Table, out = empty; end
                return;
            end
            container = obj(1).container_;
            ids = arrayfun(@(x) x.document_id, obj, 'UniformOutput', false);
            ids = ids(:);
            [u, iu] = unique(ids, 'stable');
            nameOf = containers.Map(u, arrayfun(@(x) string(x.name), obj(iu), 'UniformOutput', false));
            if strcmp(direction, 'out')
                from = 'child_id'; to = 'parent_id';
            else
                from = 'parent_id'; to = 'child_id';
            end
            seen = unique(ids);                     % never followed twice, never returned as a start
            frontier = unique(table(ids, ids, 'VariableNames', {'start', 'at'}), 'stable');
            byId = containers.Map();
            hits = table(cell(0, 1), cell(0, 1), zeros(0, 1), 'VariableNames', {'start', 'at', 'depth'});
            for depth = 1:options.MaxDepth
                E = ndi.entity.edges(container, unique(frontier.at, 'stable'), rel, from, to);
                if height(E) == 0, break; end
                next = innerjoin(frontier, E, 'LeftKeys', 'at', 'RightKeys', 'from');
                next = unique(table(next.start, next.to, 'VariableNames', {'start', 'at'}), 'stable');
                next = next(~ismember(next.at, seen), :);
                if height(next) == 0, break; end
                newIds = unique(next.at, 'stable');
                seen = [seen; newIds]; %#ok<AGROW>
                % with a filter, the search itself says which ids match, and
                % only those are read; the others are followed by id alone
                % (on the Haley plates: 7,422 patches never read)
                ents = ndi.entity.fetch(container, newIds, filterQuery);
                match = ~cellfun(@isempty, ents);
                for k = find(match)'
                    byId(newIds{k}) = ents{k};
                end
                isHit = ismember(next.at, newIds(match));
                h = next(isHit, :);
                h.depth = repmat(depth, height(h), 1);
                hits = [hits; h]; %#ok<AGROW>
                if filtered
                    frontier = next(~isHit, :);     % a match is not followed further
                else
                    frontier = next(isHit, :);      % every id found in this container
                end
                if height(frontier) == 0, break; end
            end
            hitIds = unique(hits.at, 'stable');
            if ~options.Table
                out = cellfun(@(i) byId(i), hitIds, 'UniformOutput', false)';
                return;
            end
            out = empty;
            if height(hits) == 0, return; end
            ends = values(byId, hits.at);
            out = table(string(hits.start), string(cellfun(@(i) char(nameOf(i)), hits.start, 'UniformOutput', false)), ...
                string(hits.at), string(cellfun(@(x) x.name, ends(:), 'UniformOutput', false)), ends(:), hits.depth, ...
                'VariableNames', {'start_id', 'start_name', 'end_id', 'end_name', 'end', 'depth'});
        end
    end

    methods (Static, Access = protected)
        function E = edges(container, ids, relationName, from, to)
            % EDGES - table from, to: the relations whose FROM end is one of IDS
            % RELATIONNAME: a name, a cellstr of names, or empty for every relation
            fromIds = cell(0, 1); toIds = cell(0, 1);
            chunk = 200;
            for c = 1:chunk:numel(ids)
                part = ids(c:min(c + chunk - 1, numel(ids)));
                q = ndi.entity.anyOf(cellfun(@(i) ndi.query('', 'depends_on', from, i), part, ...
                    'UniformOutput', false));
                docs = container.database_search(ndi.query('', 'isa', 'directed_relation', '') & q);
                for i = 1:numel(docs)
                    p = ndi.v2.props(docs{i});
                    r = ndi.v2.termName(ndi.v2.blockOf(p, 'directed_relation', 'relation', ''));
                    if ~isempty(relationName) && ~any(strcmp(r, cellstr(relationName)))
                        continue;
                    end
                    a = ndi.v2.edgeIds(p, from);
                    b = ndi.v2.edgeIds(p, to);
                    a = a(ismember(a, part));
                    for x = 1:numel(a)
                        for y = 1:numel(b)
                            fromIds{end+1, 1} = a{x}; %#ok<AGROW>
                            toIds{end+1, 1} = b{y}; %#ok<AGROW>
                        end
                    end
                end
            end
            E = table(fromIds, toIds, 'VariableNames', {'from', 'to'});
        end

        function ents = fetch(container, ids, extra)
            % FETCH - the entity for each id ({} where not found), a few searches in all
            % EXTRA, an ndi.query or [], is ANDed in: ids not matching it are {} too
            if nargin < 3, extra = []; end
            ents = cell(numel(ids), 1);
            if isempty(ids), return; end
            where = containers.Map(ids, num2cell(1:numel(ids)));
            chunk = 200;
            for c = 1:chunk:numel(ids)
                part = ids(c:min(c + chunk - 1, numel(ids)));
                q = ndi.entity.anyOf(cellfun(@(i) ndi.query('base.id', 'exact_string', i, ''), part, ...
                    'UniformOutput', false));
                if ~isempty(extra), q = extra & q; end
                docs = container.database_search(q);
                for i = 1:numel(docs)
                    p = ndi.v2.props(docs{i});
                    k = where(char(p.base.id));
                    ents{k} = ndi.entity.fromDocument(container, docs{i});
                end
            end
        end

        function q = anyOf(qs)
            % ANYOF - the OR of the queries in cell array QS, as a balanced
            % tree (nested log2(N) deep rather than N)
            while numel(qs) > 1
                n = floor(numel(qs) / 2);
                pairs = cell(1, ceil(numel(qs) / 2));
                for i = 1:n
                    pairs{i} = qs{2*i - 1} | qs{2*i};
                end
                if mod(numel(qs), 2), pairs{end} = qs{end}; end
                qs = pairs;
            end
            q = qs{1};
        end

        function T = emptyWalkTable()
            T = table(strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), cell(0, 1), ...
                'VariableNames', {'start_id', 'start_name', 'end_id', 'end_name', 'end'});
        end
    end

    methods (Static)
        function obj = fromDocument(container, doc)
            % FROMDOCUMENT - the right object for an entity document
            %
            % OBJ = ndi.entity.fromDocument(CONTAINER, DOC): an ndi.subject for
            % a subject document, else an ndi.entity. DOC may be an
            % ndi.document or a document id.
            if ischar(doc) || isstring(doc)
                d = ndi.v2.getDocument(container, char(doc));
                if isempty(d)
                    error('ndi:entity:notFound', 'No document %s in this %s.', char(doc), class(container));
                end
                doc = d;
            end
            chain = ndi.v2.classChain(ndi.v2.props(doc));
            if any(strcmp(chain, 'subject'))
                obj = ndi.subject.fromDocument(container, doc);
            else
                obj = ndi.entity(container, doc);
            end
        end

        function reached = walkIds(container, ids, relationNames, direction, maxDepth)
            % WALKIDS - the ids reached from IDS across relations, without reading entities
            %
            % REACHED = ndi.entity.walkIds(CONTAINER, IDS, RELATIONNAMES, DIRECTION)
            % follows RELATIONNAMES (a name, a cellstr, or {} for all) from
            % every id in IDS, 'in' (to what points at them: members, parts)
            % or 'out' (to what they point at), step after step until nothing
            % new is reached or MAXDEPTH (default Inf) steps. REACHED (a row
            % cellstr) leaves out IDS themselves. One search per step for
            % every 200 ids; nothing is read but the relations.
            arguments
                container
                ids
                relationNames = {}
                direction (1,:) char {mustBeMember(direction, {'in', 'out'})} = 'in'
                maxDepth (1,1) double = Inf
            end
            if strcmp(direction, 'out')
                from = 'child_id'; to = 'parent_id';
            else
                from = 'parent_id'; to = 'child_id';
            end
            frontier = unique(cellstr(ids), 'stable');
            frontier = frontier(:);
            seen = frontier;
            reached = {};
            depth = 0;
            while ~isempty(frontier) && depth < maxDepth
                depth = depth + 1;
                E = ndi.entity.edges(container, frontier, relationNames, from, to);
                next = unique(E.to, 'stable');
                next = next(~ismember(next, seen));
                seen = [seen; next]; %#ok<AGROW>
                reached = [reached, next(:)']; %#ok<AGROW>
                frontier = next;
            end
        end

        function e = fetchMany(container, ids)
            % FETCHMANY - the entities with these document ids, a few searches in all
            %
            % E = ndi.entity.fetchMany(CONTAINER, IDS): a cell array (row), one
            % entity per id found, in the order of IDS; ids not found are
            % left out.
            ids = unique(cellstr(ids), 'stable');
            e = ndi.entity.fetch(container, ids(:));
            e = reshape(e(~cellfun(@isempty, e)), 1, []);
        end

        function e = search(container, kind, options)
            % SEARCH - the entities of a kind in a session or dataset
            %
            % E = ndi.entity.search(CONTAINER, KIND) returns a cell array, one
            % object per document of class KIND (default 'entity': every
            % entity). Options: 'Name' keeps those whose name() is exactly it.
            arguments
                container
                kind (1,:) char = 'entity'
                options.Name (1,:) char = ''
            end
            docs = container.database_search(ndi.query('', 'isa', kind, ''));
            e = {};
            for i = 1:numel(docs)
                x = ndi.entity.fromDocument(container, docs{i});
                if ~isempty(options.Name) && ~strcmp(x.name, options.Name)
                    continue;
                end
                e{end+1} = x; %#ok<AGROW>
            end
        end
    end
end
