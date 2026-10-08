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
    % Every entity is read as an ndi.entity: a worm, a plate, a probe, a
    % person, a strain. ndi.subject is v1's class and is not used here;
    % ndi.session and ndi.dataset are not entities (design:
    % src/ndi/docs/NDI-matlab/manual/developer/V2_Object_Layer.md).
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
    %   type, local_identifier, description
    %
    % ndi.entity Methods:
    %   document           - the ndi.document
    %   document_properties - its properties (a struct)
    %   global_identifiers - table: scheme, value (ORCID, ROR, RRID, DOI, ...)
    %   summary            - a table, one row per entity (ndi.summary for a cell)
    %   relations          - table of the relations it (or an array of
    %                        entities) takes part in
    %   parents, children  - the entities across a relation, or a path of
    %                        them, from one entity or an array of them
    %   ancestors, descendants - the nearest entities of a type or kind,
    %                        following any relation: you need not know which
    %   statements         - the statements about it (or an array of
    %                        entities), inherited by default; assertions,
    %                        observations, manipulations, calculations,
    %                        interactions: statements of one kind
    %   members, memberOf, parts, partOf
    %   fromDocument, search - (static) make entities; search finds them by
    %                        what is true of them
    %
    % See also ndi.statement, ndi.v2.subjectTypes.

    properties (Dependent, SetAccess = private)
        % Read from the entity's document each time they are asked for:
        % nothing is stored. Empty for an entity with no document.
        name          % a display name (see get.name)
        kind          % the document class, e.g. 'person', 'subject'
        document_id   % the document's base.id
        type          % the entity's type: a subject's coarse kind ('organism',
                      % 'group', ...); with one entity class (2026-10-08) every
                      % entity's ('person', 'strain', ...); '' when none
        local_identifier  % its handle within the dataset ('' when none)
        description   % free text ('' when none)
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
            % ndi.dataset, DOC an entity document (ndi.entity.fromDocument
            % also takes a document id).
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
            % KIND - the entity's document class, e.g. 'person', 'subject';
            % for an `entity` (one entity class, 2026-10-08) its `type`, so a
            % person is 'person' under either schema. A subject's type is a
            % physical kind ('organism', 'material', ...), so its kind is
            % 'subject', the block its fields are in under the earlier schema.
            k = '';
            if isempty(obj.entity_document_), return; end
            p = obj.document_properties();
            k = ndi.v2.kindOf(p);
            if any(strcmp(k, ndi.v2.entityTypesFor('subject')))
                k = 'subject';
            end
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

        function t = get.type(obj)
            % TYPE - the entity's type: a subject's coarse kind, or (one entity
            %   class) any entity's ('' for an entity with no document)
            t = '';
            if isempty(obj.entity_document_), return; end
            t = ndi.v2.termName(ndi.v2.blockOf(obj.document_properties(), obj.kind, 'type', ''));
        end

        function v = get.local_identifier(obj)
            % LOCAL_IDENTIFIER - its handle within the dataset, from the document
            v = '';
            if isempty(obj.entity_document_), return; end
            v = char(ndi.v2.blockOf(obj.document_properties(), obj.kind, 'local_identifier', ''));
        end

        function v = get.description(obj)
            % DESCRIPTION - free text, from the document
            v = '';
            if isempty(obj.entity_document_), return; end
            v = char(ndi.v2.blockOf(obj.document_properties(), obj.kind, 'description', ''));
        end

        function s = statements(obj, varargin)
            % STATEMENTS - the statements about this subject (or these subjects)
            %
            % S = STATEMENTS(SUBJ, ...) returns a cell array of ndi.statement
            % objects (each the right child: ndi.observation,
            % ndi.manipulation, ndi.calculation, ndi.assertion). SUBJ may be an
            % array of subjects; from a cell array C call statements([C{:}]).
            % The subjects are searched together, a few searches in all; a
            % statement that holds of several of them comes back once for each,
            % and each knows which subject it was asked for (about()) and how
            % it holds of it (via()).
            %
            % What holds of a subject ('inherited', default true -- the same
            % rules as ndi.entity.search):
            %   own        statements about it
            %   member_of  statements about a group it belongs to (groups of
            %              groups too) that are marked distributive
            %   part_of, sample_of, aliquot_of, passage_of
            %              assertions about a whole it is part or a sample of
            % 'inherited', false: its own statements only.
            %
            % 'context', true (default false) adds what the subject was IN
            % (V_eta tenet T17): the observations, manipulations and
            % calculations of each container it was contained_in (its own
            % stays, a distributive stay of a group it is in, and the
            % containers of those), whose time overlaps the stay. They are
            % not about the subject: via() says 'contained_in' (after any
            % member_of), and summary's stated_on names the container. A stay
            % or statement whose times cannot be compared is left out.
            %
            % Filters, the words ndi.entity.search uses:
            %   s = w.statements('manipulation')
            %   s = w.statements('manipulation', {'method', 'refrigeration'})
            %   s = w.statements('assertion', {'variable', 'strain'})
            % A kind ('statement', 'assertion', 'interaction', 'observation',
            % 'manipulation', 'calculation') with an optional cell of filters
            % on that statement ('variable', 'method', 'value',
            % 'formulation', and when: 'at', 'during', 'before', 'after',
            % 'duration' -- see ndi.v2.timeFilter); several kinds are any of
            % them. 'tolerant', true widens each time by its tolerance (and
            % each stay, for 'context'). 'during' also takes statements,
            % {'observation', {'variable', 'ambient temperature', 'value',
            % '>22'}}: kept when it overlaps one matching that which holds of
            % the same subject by the same rules. The older 'Class',
            % 'Variable', 'Method' pairs still work.
            [kinds, inherited, context] = ndi.entity.statementArgs(varargin);
            s = {};
            subjects = obj(arrayfun(@(x) ~isempty(x.container_), obj));
            if isempty(subjects), return; end
            container = subjects(1).container_;
            ids = arrayfun(@(x) x.document_id, subjects, 'UniformOutput', false);
            L = ndi.entity.statementLinks(container, ids, kinds, inherited, context);
            s = cell(1, numel(L.doc));
            for i = 1:numel(L.doc)
                s{i} = ndi.statement.fromDocument(container, L.doc{i}).withContext(L.about{i}, L.via{i});
            end
        end % statements()

        function s = assertions(obj, varargin)
            % ASSERTIONS - what is asserted about the subject (or subjects): species, strain, ...
            %
            % S = ASSERTIONS(SUBJ, ...) is STATEMENTS(SUBJ, 'assertion', ...): a
            % cell array of ndi.assertion objects, inherited by default. A cell
            % of filters may come first:
            %   a = w.assertions({'variable', 'strain'})
            %   a = w.assertions('inherited', false)
            % ndi.summary(a) makes the table.
            args = ndi.entity.kindArgs('assertion', varargin);
            s = obj.statements(args{:});
        end % assertions()

        function s = observations(obj, varargin)
            % OBSERVATIONS - what was observed of the subject (or subjects)
            %
            % S = OBSERVATIONS(SUBJ, ...) is STATEMENTS(SUBJ, 'observation', ...),
            % a cell array of ndi.observation objects; filters as ASSERTIONS:
            %   o = w.observations({'variable', 'temperature'})
            args = ndi.entity.kindArgs('observation', varargin);
            s = obj.statements(args{:});
        end % observations()

        function s = manipulations(obj, varargin)
            % MANIPULATIONS - what was done to the subject (or subjects)
            %
            % S = MANIPULATIONS(SUBJ, ...) is STATEMENTS(SUBJ, 'manipulation', ...),
            % a cell array of ndi.manipulation objects; filters as ASSERTIONS:
            %   m = w.manipulations({'method', 'refrigeration'})
            args = ndi.entity.kindArgs('manipulation', varargin);
            s = obj.statements(args{:});
        end % manipulations()

        function s = calculations(obj, varargin)
            % CALCULATIONS - what was calculated of the subject (or subjects)
            %
            % S = CALCULATIONS(SUBJ, ...) is STATEMENTS(SUBJ, 'calculation', ...),
            % a cell array of ndi.calculation objects; filters as ASSERTIONS:
            %   c = calculations([w{:}], {'variable', 'midpoint speed'})
            args = ndi.entity.kindArgs('calculation', varargin);
            s = obj.statements(args{:});
        end % calculations()

        function s = interactions(obj, varargin)
            % INTERACTIONS - observations, manipulations and calculations of the subject
            %
            % S = INTERACTIONS(SUBJ, ...) is STATEMENTS(SUBJ, 'interaction', ...):
            % every statement with a time and a method; filters as ASSERTIONS.
            args = ndi.entity.kindArgs('interaction', varargin);
            s = obj.statements(args{:});
        end % interactions()

        function m = members(obj)
            % MEMBERS - a group's members (the subjects that are member_of it), a cell array
            m = obj.children('member_of');
        end

        function g = memberOf(obj)
            % MEMBEROF - the groups this subject is member_of, a cell array
            g = obj.parents('member_of');
        end

        function p = parts(obj)
            % PARTS - the subjects that are part_of this one (a plate's patches), a cell array
            p = obj.children('part_of');
        end

        function w = partOf(obj)
            % PARTOF - what this subject is part_of (a patch's plate), a cell array
            w = obj.parents('part_of');
        end

        function T = global_identifiers(obj)
            % GLOBAL_IDENTIFIERS - table with columns scheme and value
            p = obj.document_properties();
            g = ndi.v2.blockOf(p, 'entity', 'global_identifier', []);
            scheme = strings(0, 1); value = strings(0, 1);
            if ischar(g) || isstring(g)
                g = cellstr(g);
            end
            if ~iscell(g) || ~all(cellfun(@ischar, g))
                g = ndi.v2.entries(g);
            end
            for i = 1:numel(g)
                sc = ''; v = '';
                if ischar(g{i})
                    % a CURIE or an IRI since 2026-10-08: the prefix is the scheme
                    tok = regexp(g{i}, '^([A-Za-z][A-Za-z0-9_.]*):(?!//)(.*)$', 'tokens', 'once');
                    if isempty(tok)
                        sc = 'IRI'; v = g{i};
                    else
                        sc = tok{1}; v = tok{2};
                    end
                end
                if isstruct(g{i}) && isfield(g{i}, 'scheme'), sc = ndi.v2.termName(g{i}.scheme); end
                if isstruct(g{i}) && isfield(g{i}, 'value'), v = char(g{i}.value); end
                scheme(end+1, 1) = string(sc); %#ok<AGROW>
                value(end+1, 1) = string(v); %#ok<AGROW>
            end
            T = table(scheme, value);
        end

        function T = summary(obj, options)
            % SUMMARY - one table row per entity
            %
            % T = SUMMARY(E) for an entity or an array of one class; for a cell
            % array (what search returns) use ndi.summary. Columns: name,
            % kind, id; for subjects also type, local_identifier, and one
            % column per asserted variable (species, strain, ...), inherited
            % as statements inherits (several values joined with
            % '; '). 'nodes', true adds beside each a <variable>_node column,
            % the values' ontology nodes.
            arguments
                obj
                options.nodes (1,1) logical = false
            end
            T = ndi.entity.summaryOf(num2cell(obj), 'nodes', options.nodes);
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
            %               'culture', ... (the entity's `type`)
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
                filterQuery = ndi.v2.blockQuery('subject.type.name', 'exact_string', options.Type, '');
            end
            if ~isempty(options.Kind)
                k = ndi.v2.isaQuery(options.Kind);
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
            % EDGES - table from, to, distributive: the relations whose FROM
            % end is one of IDS, and whether each is marked distributive
            % RELATIONNAME: a name, a cellstr of names, or empty for every relation
            fromIds = cell(0, 1); toIds = cell(0, 1); dist = false(0, 1);
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
                    d = ndi.v2.blockOf(p, 'directed_relation', 'distributive', false);
                    d = ~isempty(d) && (islogical(d) || isnumeric(d)) && logical(d(1));
                    for x = 1:numel(a)
                        for y = 1:numel(b)
                            fromIds{end+1, 1} = a{x}; %#ok<AGROW>
                            toIds{end+1, 1} = b{y}; %#ok<AGROW>
                            dist(end+1, 1) = d; %#ok<AGROW>
                        end
                    end
                end
            end
            E = table(fromIds, toIds, dist, 'VariableNames', {'from', 'to', 'distributive'});
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
            % ANYOF - the OR of the queries in cell array QS (ndi.v2.anyOf)
            q = ndi.v2.anyOf(qs);
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
            % OBJ = ndi.entity.fromDocument(CONTAINER, DOC): an ndi.entity for
            % any entity document (a subject's too). DOC may be an
            % ndi.document or a document id.
            if ischar(doc) || isstring(doc)
                d = ndi.v2.getDocument(container, char(doc));
                if isempty(d)
                    error('ndi:entity:notFound', 'No document %s in this %s.', char(doc), class(container));
                end
                doc = d;
            end
            obj = ndi.entity(container, doc);
        end

        function T = summaryOf(entities, options)
            % SUMMARYOF - the summary table of a cell array of entities (see SUMMARY)
            arguments
                entities
                options.nodes (1,1) logical = false
            end
            n = numel(entities);
            name = strings(n, 1); kind = strings(n, 1); id = strings(n, 1);
            type = strings(n, 1); local_identifier = strings(n, 1);
            isSubj = false(n, 1);   % entities read from a document (any kind)
            for i = 1:n
                e = entities{i};
                name(i) = string(e.name); kind(i) = string(e.kind); id(i) = string(e.document_id);
                if ~isempty(e.document_id) && ~isempty(e.container_)
                    isSubj(i) = true;
                    type(i) = string(e.type); local_identifier(i) = string(e.local_identifier);
                end
            end
            T = table(name, kind, id);
            if ~any(isSubj), return; end
            T.type = type; T.local_identifier = local_identifier;
            container = entities{find(isSubj, 1)}.container_;
            L = ndi.entity.statementLinks(container, cellstr(id(isSubj)), ...
                struct('kind', 'assertion', 'filt', struct()), true);
            cols = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for k = 1:numel(L.doc)
                p = ndi.v2.props(L.doc{k});
                v = ndi.v2.termName(ndi.v2.blockOf(p, 'statement', 'variable', ''));
                [vk, vv, txt] = ndi.v2.statementValue(p);
                if isempty(v), continue; end
                nd = '';
                if strcmp(vk, 'term') && isstruct(vv) && isfield(vv, 'node'), nd = char(vv(1).node); end
                if ~isKey(cols, v), cols(v) = containers.Map('KeyType', 'char', 'ValueType', 'any'); end
                m = cols(v);
                if isKey(m, L.about{k}), m(L.about{k}) = [m(L.about{k}), {{txt, nd}}];
                else, m(L.about{k}) = {{txt, nd}}; end
            end
            % its types (instance_of: a strain, a product), each under its
            % type, named as the type entity is named (T17)
            S = ndi.entity.inheritanceStates(container, cellstr(id(isSubj)), true);
            S = S([S.i]);
            if ~isempty(S)
                tdocs = typeDocuments(container, unique({S.at}, 'stable'));
                for k = 1:numel(S)
                    if ~isKey(tdocs, S(k).at), continue; end
                    p = tdocs(S(k).at);
                    [v, blk] = ndi.v2.kindOf(p);
                    txt = char(ndi.v2.blockOf(p, blk, 'name', ''));
                    if isempty(txt), txt = char(ndi.v2.blockOf(p, blk, 'local_identifier', '')); end
                    if isempty(v) || isempty(txt), continue; end
                    nd = cellstr(ndi.v2.blockOf(p, blk, 'global_identifier', {}));
                    if isempty(nd), nd = ''; else, nd = nd{1}; end
                    if ~isKey(cols, v), cols(v) = containers.Map('KeyType', 'char', 'ValueType', 'any'); end
                    m = cols(v);
                    if isKey(m, S(k).start), m(S(k).start) = [m(S(k).start), {{txt, nd}}];
                    else, m(S(k).start) = {{txt, nd}}; end
                end
            end
            vars = sort(keys(cols));
            for k = 1:numel(vars)
                m = cols(vars{k});
                c = strings(n, 1); cn = strings(n, 1);
                for i = 1:n
                    if ~isKey(m, char(id(i))), continue; end
                    pairs = m(char(id(i)));
                    txts = cellfun(@(x) x{1}, pairs, 'UniformOutput', false);
                    nds = cellfun(@(x) x{2}, pairs, 'UniformOutput', false);
                    [txts, keep] = unique(txts, 'stable');
                    c(i) = string(strjoin(txts, '; '));
                    cn(i) = string(strjoin(nds(keep), '; '));
                end
                name_ = matlab.lang.makeValidName(vars{k});
                T.(name_) = c;
                if options.nodes, T.([name_ '_node']) = cn; end
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

        function s = search(container, varargin)
            % SEARCH - the entities in a session or dataset, by what is true of them
            %
            % S = ndi.entity.search(CONTAINER, PROPERTY, VALUE, ...) returns a
            % cell array of entities (ndi.entity objects): those for
            % which every pair holds. With no pairs, every entity.
            %
            % S = ndi.entity.search(CONTAINER, KIND, PROPERTY, VALUE, ...) with
            % an odd number of arguments after CONTAINER: only entities of KIND,
            % a document class or (one entity class, 2026-10-08) an entity
            % type -- 'person', 'strain', 'study', 'organism', ... ('subject'
            % is not a kind: the subjects are 'type', ndi.v2.subjectTypes()).
            % A statement may be about any
            % entity, so every property below works for any kind:
            %   ndi.entity.search(ds, 'person', 'name', 'Jess*')
            %   ndi.entity.search(ds, 'strain', 'derived_from', {'name', 'N2'})
            %
            %   ndi.entity.search(ds, 'type', 'organism', ...
            %       'species', 'Caenorhabditis elegans', 'strain', {'N2', 'CB*'})
            %   ndi.entity.search(ds, 'manipulation', {'method', 'heating'})
            %   ndi.entity.search(ds, 'type', 'organism', ...
            %       'contained_in', {'manipulation', {'variable', 'NGM agar'}})
            %
            % A PROPERTY is one of:
            %   'type', 'name', 'local_identifier', 'id'
            %       the subject's own fields ('id': its document id)
            %   'statement', 'assertion', 'interaction', 'observation',
            %   'manipulation', 'calculation'
            %       a statement of that kind (or a child kind) about the
            %       subject; VALUE is a cell of filters on ONE statement:
            %       'variable', 'method' (not an assertion's), 'value',
            %       'formulation' (a dose's), and when it held: 'at', 'during',
            %       'before', 'after', 'duration' (ndi.v2.timeFilter). 'during'
            %       also takes statements, {'observation', {...}}: a statement
            %       of the subject's that overlaps one of those of the same
            %       subject (by 'inherited' and 'context'). The key twice is
            %       two statements.
            %   'relation', 'directed_relation', 'undirected_relation'
            %       a relation the subject is in; VALUE is a cell:
            %         'name'    the relation ('contained_in', 'paired_with', ...)
            %         'parent'  the subject is the child; the parent is ...
            %         'child'   the subject is the parent; a child is ...
            %         'with'    the other end, either way, is ...
            %         'at', 'during', 'before', 'after', 'duration'
            %                   when the relation held (ndi.v2.timeFilter)
            %       where ... is a subject (an ndi.entity, several in a cell,
            %       or a document id) or a cell describing subjects -- anything
            %       ndi.entity.search takes, nested as deep as needed.
            %   a relation's name ('member_of', 'contained_in', 'part_of',
            %   'paired_with', ...): short for 'directed_relation',
            %       {'name', NAME, 'parent', VALUE} ('with' for an undirected one)
            %   'inherited'  true (default) or false, below
            %   'explain'    true: print what the search means before it runs
            %   'strict'     true (default): an unknown property is an error and
            %                values matching nothing a warning, each naming what
            %                there is (with a "did you mean"); false: an empty
            %                answer, quietly (for scripts over many datasets)
            %   'tolerant'   false (default): times are compared as stated;
            %                true: a time matches when its tolerance allows
            %   'context'    false (default); true: also the subjects a
            %                matching observation, manipulation or calculation
            %                was CONTEXT for -- what its subject contained at
            %                the time (V_eta tenet T17), below
            %
            %   Times typed without a zone are read in the zone the lab
            %   recorded each time in; 'during' takes two times, a date or a
            %   month; 'duration' takes '>=3h', '<30min', ...
            %   anything else: an asserted variable -- 'strain', 'N2' is
            %       'assertion', {'variable', 'strain', 'value', 'N2'}
            % Property names ignore case.
            %
            % A pattern matches a term's name ignoring case or its node
            % exactly ('NCBITaxon:6239'); a cell array is any of them; '*' is
            % a wildcard, '\*' a literal star. A value is compared by its kind:
            % numbers and dates take '>', '>=', '<', '<=' ('>=0.02',
            % '>2023-11-16'); see ndi.v2.searchStatements. All pairs must hold.
            %
            % 'inherited' (default true):
            %   - a statement or relation about a group holds of its members
            %     when it is marked distributive, all the way down member_of
            %     (a strain stated on a cohort; a cohort contained_in a plate);
            %   - an assertion about a whole holds of its parts and samples,
            %     down part_of, sample_of, aliquot_of and passage_of (an
            %     animal's strain is its slice's).
            %   contained_in is not followed for statements (a plate's are not
            %   its worms'). false: only what is stated of the subject itself.
            % 'context' (default false): a container's observations,
            %   manipulations and calculations reach what it contained, down
            %   contained_in (and nested containers), but only when the
            %   statement's time overlaps the stay's; a distributive stay of a
            %   group reaches its members. A plate's 22 C reading finds the
            %   worms on the plate during it. A stay or statement whose times
            %   cannot be compared is left out. Assertions never pass.
            %   The group or whole a statement was about matches too; 'type'
            %   narrows to what you want.
            %
            % An unknown asserted variable, relation name, or a kind /
            % variable / method no statement has, is an error; values none of
            % which match is a warning naming the values there are.
            kind = 'entity';
            if mod(numel(varargin), 2)
                kind = char(varargin{1});
                varargin = varargin(2:end);
                if strcmpi(kind, 'subject')
                    error('ndi:entity:search:subjectKind', ...
                        ['''subject'' is not a kind: give the type, e.g. ''type'', ' ...
                         '{''organism'', ''group''} (ndi.v2.subjectTypes are the subjects).']);
                end
            end
            s = ndi.entity.searchKind(container, kind, varargin);
        end % search()

        function s = searchKind(container, kind, args)
            % SEARCHKIND - SEARCH for entities of KIND, with ARGS its pairs
            spec = ndi.entity.parseSearch(args);
            spec.kind = kind;
            if spec.explain
                fprintf('%s\n', ndi.entity.explainSearch(spec, '', containerWord(container)));
            end
            ids = ndi.entity.searchIds(container, spec);
            if iscell(ids)
                s = ndi.entity.fetchMany(container, ids);
            else
                q = ndi.v2.isaQuery(kind);   % a merged entity by its type (2026-10-08)
                lid = spec.own(strcmp(spec.own(:, 1), 'local_identifier'), 2);
                if isscalar(lid) && ischar(lid{1}) && ~ndi.v2.hasWildcard(lid{1})
                    if ~strcmp(kind, 'entity')   % (every entity: compared below)
                        q = q & ndi.v2.blockQuery([kind '.local_identifier'], 'exact_string_anycase', ...
                            strrep(lid{1}, '\*', '*'), '');
                    end
                end
                docs = container.database_search(q);
                s = cellfun(@(d) ndi.entity.fromDocument(container, d), docs, 'UniformOutput', false);
            end
            s = reshape(s, 1, []);
            keep = cellfun(@(x) strcmp(kind, 'entity') || strcmp(x.kind, kind), s);
            own = spec.own;
            for k = 1:size(own, 1)
                for i = find(keep)
                    x = s{i};
                    switch own{k, 1}
                        case 'type', keep(i) = ndi.v2.matchTerm(x.type, own{k, 2});
                        case 'name', keep(i) = ndi.v2.matchTerm(x.name, own{k, 2});
                        case 'kind', keep(i) = ndi.v2.matchTerm(x.kind, own{k, 2});
                        case 'local_identifier', keep(i) = ndi.v2.matchTerm(x.local_identifier, own{k, 2});
                        case 'id', keep(i) = any(strcmp(x.document_id, cellstr(own{k, 2})));
                    end
                end
            end
            s = reshape(s(keep), 1, []);
        end % searchKind()
    end

    methods (Static, Hidden)
        function t = explainNested(c, indent)
            % EXPLAINNESTED - a description (a cell of search's pairs) in words
            t = ndi.entity.explainSearch(ndi.entity.parseSearch(c), indent, '');
        end

    end

    methods (Static, Access = protected)
        function spec = parseSearch(args)
            % PARSESEARCH - search's PROPERTY, VALUE pairs as a search spec:
            % own fields, statement filters, relation filters, and switches
            if mod(numel(args), 2)
                error('ndi:entity:search:pairs', 'ndi.entity.search takes PROPERTY, VALUE pairs.');
            end
            statementKinds = {'statement', 'assertion', 'interaction', 'observation', 'manipulation', 'calculation'};
            relationKinds = {'relation', 'directed_relation', 'undirected_relation'};
            [directed, undirected] = ndi.v2.relationNames();
            spec = struct('own', {cell(0, 2)}, ...
                'filters', {struct('kind', {}, 'filt', {})}, ...
                'relations', {struct('kind', {}, 'name', {}, 'side', {}, 'target', {}, 'time', {})}, ...
                'inherited', true, 'explain', false, 'strict', true, 'tolerant', false, ...
                'context', false);
            for k = 1:2:numel(args)
                p = args{k};
                if ~(ischar(p) || (isstring(p) && isscalar(p)))
                    error('ndi:entity:search:pairs', 'A property name must be text (argument %d).', k + 1);
                end
                p = char(p);
                v = args{k + 1};
                if isstring(v), v = cellstr(v); if isscalar(v), v = v{1}; end, end
                key = lower(strrep(p, '_', ''));
                lp = lower(p);
                if any(strcmp(key, {'inherited', 'explain', 'strict', 'tolerant', 'context'}))
                    spec.(key) = logical(v);
                elseif any(strcmp(key, {'type', 'name', 'id'}))
                    spec.own(end+1, :) = {key, v};
                elseif strcmp(key, 'localidentifier')
                    spec.own(end+1, :) = {'local_identifier', v};
                elseif any(strcmp(lp, statementKinds))
                    spec.filters(end+1) = struct('kind', lp, 'filt', ndi.entity.statementFilter(lp, v));
                elseif any(strcmp(lp, relationKinds))
                    spec.relations(end+1) = ndi.entity.relationFilter(lp, v);
                elseif any(strcmpi(p, directed))
                    spec.relations(end+1) = struct('kind', 'directed_relation', 'name', {{p}}, ...
                        'side', 'parent', 'target', {v}, 'time', struct());
                elseif any(strcmpi(p, undirected))
                    spec.relations(end+1) = struct('kind', 'undirected_relation', 'name', {{p}}, ...
                        'side', 'with', 'target', {v}, 'time', struct());
                else
                    if ~iscell(v), v = {v}; end      % a cell is already "any of"
                    spec.filters(end+1) = struct('kind', 'assertion', ...
                        'filt', struct('variable', p, 'value', {v}));
                end
            end
        end

        function filt = statementFilter(kind, c)
            % STATEMENTFILTER - {'variable', V, 'method', M, ...} as a struct
            if ~iscell(c) || mod(numel(c), 2)
                error('ndi:entity:search:statementFilter', ...
                    '''%s'' takes a cell of filters, e.g. {''variable'', ''NGM agar'', ''value'', ''>=0.02''}.', kind);
            end
            filt = struct();
            for k = 1:2:numel(c)
                n = lower(char(c{k}));
                if ~any(strcmp(n, {'variable', 'method', 'value', 'formulation', ...
                        'at', 'during', 'before', 'after', 'duration'}))
                    error('ndi:entity:search:statementFilter', ...
                        ['Unknown filter ''%s'' for ''%s'': variable, method, value, formulation, ' ...
                         'at, during, before, after, duration.'], c{k}, kind);
                end
                v = c{k + 1};
                if isstring(v), v = cellstr(v); if isscalar(v), v = v{1}; end, end
                if strcmp(n, 'during') && ndi.entity.isStatementDescription(v)
                    % 'during', {'observation', {...}}: when a statement
                    % matching that holds of the same subject (statementLinks)
                    filt.during_statements = ndi.entity.statementKinds(v);
                    continue;
                end
                filt.(n) = v;
            end
            if strcmp(kind, 'assertion') && isfield(filt, 'during_statements')
                error('ndi:entity:search:assertionTime', 'An assertion has no time, so it is never ''during'' anything.');
            end
            if strcmp(kind, 'assertion') && isfield(filt, 'method')
                error('ndi:entity:search:assertionMethod', 'An assertion has no method.');
            end
        end

        function tf = isStatementDescription(v)
            % ISSTATEMENTDESCRIPTION - is V {'observation', {...}, ...}, a
            % description of statements, rather than times?
            kinds = {'statement', 'interaction', 'observation', 'manipulation', 'calculation'};
            tf = iscell(v) && ~isempty(v) && (ischar(v{1}) || (isstring(v{1}) && isscalar(v{1}))) ...
                && any(strcmpi(char(v{1}), [kinds, {'assertion'}]));
        end

        function kinds = statementKinds(v)
            % STATEMENTKINDS - {'observation', {...}, 'manipulation', {...}}
            % (a kind alone is any of that kind) as the kinds struct
            % statementLinks takes; several are any of them
            kinds = struct('kind', {}, 'filt', {});
            k = 1;
            while k <= numel(v)
                kind = lower(char(v{k}));
                if ~ndi.entity.isStatementDescription({kind})
                    error('ndi:entity:search:statementFilter', ...
                        '''during'' takes times or statements, e.g. {''observation'', {''variable'', ''ambient temperature'', ''value'', ''>22''}}.');
                end
                f = struct();
                if k < numel(v) && iscell(v{k + 1})
                    f = ndi.entity.statementFilter(kind, v{k + 1});
                    k = k + 1;
                end
                if strcmp(kind, 'assertion')
                    error('ndi:entity:search:assertionTime', 'An assertion has no time, so nothing is ''during'' it.');
                end
                kinds(end+1) = struct('kind', kind, 'filt', f); %#ok<AGROW>
                k = k + 1;
            end
        end

        function r = relationFilter(kind, c)
            % RELATIONFILTER - {'name', N, 'parent'|'child'|'with', X} as a struct
            if ~iscell(c) || mod(numel(c), 2)
                error('ndi:entity:search:relationFilter', ...
                    '''%s'' takes a cell, e.g. {''name'', ''contained_in'', ''parent'', {''type'', ''material''}}.', kind);
            end
            r = struct('kind', kind, 'name', {{}}, 'side', '', 'target', {[]}, 'time', struct());
            for k = 1:2:numel(c)
                n = lower(char(c{k}));
                v = c{k + 1};
                switch n
                    case 'name'
                        if ~iscell(v), v = {v}; end
                        r.name = cellfun(@char, v, 'UniformOutput', false);
                    case {'parent', 'child', 'with'}
                        if ~isempty(r.side)
                            error('ndi:entity:search:relationFilter', ...
                                'Give one of ''parent'', ''child'' and ''with'' in a relation (got ''%s'' and ''%s'').', r.side, n);
                        end
                        if strcmp(kind, 'undirected_relation') && ~strcmp(n, 'with')
                            error('ndi:entity:search:relationFilter', ...
                                'An undirected relation has no %s: use ''with''.', n);
                        end
                        r.side = n;
                        r.target = v;
                    case {'at', 'during', 'before', 'after', 'duration'}
                        r.time.(n) = v;
                    case 'depth'
                        error('ndi:entity:search:notYet', ...
                            'Relation filter ''%s'' is not built yet.', n);
                    otherwise
                        error('ndi:entity:search:relationFilter', ...
                            ['Unknown filter ''%s'' for ''%s'': name, parent, child, with, ' ...
                             'at, during, before, after, duration.'], c{k}, kind);
                end
            end
            if ~isempty(r.name)
                [directed, undirected] = ndi.v2.relationNames();
                known = [directed, undirected];
                for k = 1:numel(r.name)
                    if ~isempty(known) && ~any(cellfun(@(x) ndi.v2.matchTerm(x, r.name{k}), known))
                        error('ndi:entity:search:unknownRelation', 'No relation is called ''%s''. Relations: %s.', ...
                            r.name{k}, strjoin(known, ', '));
                    end
                end
            end
        end

        function ids = searchIds(container, spec)
            % SEARCHIDS - the subject ids every statement and relation filter
            % of SPEC holds of ([] when SPEC has none)
            ids = [];
            for k = 1:numel(spec.filters)
                these = ndi.entity.subjectsOf(container, spec.filters(k), spec);
                ids = narrow(ids, these);
                if isempty(ids), ids = {}; return; end
            end
            for k = 1:numel(spec.relations)
                these = ndi.entity.relatedIds(container, spec.relations(k), spec);
                ids = narrow(ids, these);
                if isempty(ids), ids = {}; return; end
            end
            if isempty(ids) && ~iscell(ids)
                id = spec.own(strcmp(spec.own(:, 1), 'id'), 2);
                if isscalar(id), ids = unique(cellstr(id{1}), 'stable'); end
            end
        end

        function ids = subjectsOf(container, f, spec)
            % SUBJECTSOF - ids of the subjects statement filter F holds of: the
            % statements' subjects; and, SPEC.inherited, the members (down
            % member_of) of a group whose statement is distributive, and the
            % parts and samples of a subject an assertion is about. With
            % SPEC.strict, an unknown variable or method is an error and
            % values that match nothing a warning (each naming what there is).
            if isfield(f.filt, 'during_statements')
                % the subjects with such a statement, then those for which it
                % overlaps one matching the description (statementLinks)
                g = f; g.filt = rmfield(g.filt, 'during_statements');
                ids = ndi.entity.subjectsOf(container, g, spec);
                if isempty(ids), return; end
                k = f; k.filt.tolerant = spec.tolerant;
                L = ndi.entity.statementLinks(container, ids, k, spec.inherited, ...
                    isfield(spec, 'context') && spec.context);
                ids = ids(ismember(ids, L.about));
                return;
            end
            inherited = spec.inherited;
            filt = f.filt;
            filt.tolerant = spec.tolerant;
            [docs, info] = ndi.v2.searchStatements(container, f.kind, filt);
            if info.structural == 0 && strcmp(f.kind, 'assertion')
                % with one entity class, a strain is not asserted: the
                % subject is an instance_of the strain entity
                via = ndi.entity.instanceIds(container, filt, spec);
                if iscell(via), ids = via; return; end
            end
            if info.structural == 0
                ndi.entity.noSuchStatement(container, f, spec.strict, kindOfSpec(spec));   % errors unless each part exists
                ids = {};
                return;
            elseif isempty(docs) && spec.strict && info.timed && info.beforeTime > 0
                warning('ndi:entity:search:noSuchTime', '%s', ...
                    noTimeMessage(f.kind, f.filt, info.time, containerWord(container)));
            elseif isempty(docs) && spec.strict
                warning('ndi:entity:search:noSuchValue', '%s', ...
                    noValueMessage(f, info.values, containerWord(container), kindOfSpec(spec)));
            end
            ids = {}; groups = {}; asserted = {};
            for i = 1:numel(docs)
                p = ndi.v2.props(docs{i});
                sid = ndi.v2.edgeIds(p, 'entity_id');
                ids = [ids, sid]; %#ok<AGROW>
                if ~inherited, continue; end
                if isDistributive(ndi.v2.blockOf(p, 'statement', 'distributive', false))
                    groups = [groups, sid]; %#ok<AGROW>
                end
                if any(strcmp(ndi.v2.classChain(p), 'assertion'))
                    asserted = [asserted, sid]; %#ok<AGROW>
                end
            end
            ids = unique(ids, 'stable');
            if isfield(spec, 'context') && spec.context
                ids = unique([ids, ndi.entity.contextIds(container, docs, spec.tolerant)], 'stable');
            end
            if ~inherited, return; end
            if ~isempty(groups)
                ids = unique([ids, ndi.entity.walkIds(container, unique(groups, 'stable'), ...
                    'member_of', 'in')], 'stable');
            end
            if ~isempty(asserted)
                % an assertion holds of the parts and samples of what it is
                % about, and of those of the members it holds of
                g = unique(groups(ismember(groups, asserted)), 'stable');
                whole = asserted;
                if ~isempty(g)
                    whole = [whole, ndi.entity.walkIds(container, g, 'member_of', 'in')];
                end
                whole = unique(whole, 'stable');
                parts = ndi.entity.walkIds(container, whole, ...
                    {'part_of', 'sample_of', 'aliquot_of', 'passage_of'}, 'in');
                ids = unique([ids, parts], 'stable');
            end
        end

        function ids = relatedIds(container, r, spec)
            % RELATEDIDS - ids of the subjects in a relation matching R: the
            % relation kind and name, and the other end (a subject, ids, or a
            % description, searched first). INHERITED: a distributive relation
            % whose child is a group holds of the group's members too.
            inherited = spec.inherited;
            T = ndi.entity.targetIds(container, r.target, spec);     % [] = any
            if iscell(T) && isempty(T), ids = {}; return; end
            ids = {};
            if ~strcmp(r.kind, 'undirected_relation')
                sides = {r.side};
                if isempty(r.side) || strcmp(r.side, 'with'), sides = {'parent', 'child'}; end
                for k = 1:numel(sides)
                    if strcmp(sides{k}, 'parent')    % this subject is the child
                        mine = 'child_id'; theirs = 'parent_id';
                    else
                        mine = 'parent_id'; theirs = 'child_id';
                    end
                    docs = ndi.entity.relationDocs(container, 'directed_relation', r.name, theirs, T);
                    docs = ndi.entity.timed(container, docs, r, spec);
                    groups = {};
                    for i = 1:numel(docs)
                        p = ndi.v2.props(docs{i});
                        m = ndi.v2.edgeIds(p, mine);
                        ids = [ids, m]; %#ok<AGROW>
                        if inherited && strcmp(mine, 'child_id') && ...
                                isDistributive(ndi.v2.blockOf(p, 'directed_relation', 'distributive', false))
                            groups = [groups, m]; %#ok<AGROW>
                        end
                    end
                    if ~isempty(groups)
                        ids = [ids, ndi.entity.walkIds(container, unique(groups, 'stable'), 'member_of', 'in')]; %#ok<AGROW>
                    end
                end
            end
            if any(strcmp(r.kind, {'relation', 'undirected_relation'})) && ...
                    (isempty(r.side) || strcmp(r.side, 'with'))
                docs = ndi.entity.relationDocs(container, 'undirected_relation', r.name, 'entity_id', T);
                docs = ndi.entity.timed(container, docs, r, spec);
                for i = 1:numel(docs)
                    pair = ndi.v2.edgeIds(ndi.v2.props(docs{i}), 'entity_id');
                    for j = 1:numel(pair)
                        others = pair([1:j-1, j+1:end]);
                        if ~iscell(T) || any(ismember(others, T))
                            ids{end+1} = pair{j}; %#ok<AGROW>
                        end
                    end
                end
            end
            ids = unique(ids, 'stable');
        end

        function docs = timed(container, docs, r, spec)
            % TIMED - the relation documents DOCS whose time meets R's time
            % filters (all of them when R has none)
            if isempty(fieldnames(r.time)) || isempty(docs), return; end
            [keep, tinfo] = ndi.v2.timeFilter(container, docs, r.time, spec.tolerant);
            if ~any(keep) && spec.strict
                warning('ndi:entity:search:noSuchTime', '%s', ...
                    noTimeMessage(r.kind, r.time, tinfo, containerWord(container)));
            end
            docs = docs(keep);
        end

        function docs = relationDocs(container, className, names, edge, T)
            % RELATIONDOCS - relation documents of CLASSNAME named one of NAMES
            % ({} any) whose EDGE is one of the ids T ([] any)
            base = ndi.query('', 'isa', className, '');
            if ~isempty(names)
                t = ndi.v2.termQuery([className '.relation'], names);
                if ~isempty(t), base = base & t; end
            end
            if ~iscell(T)
                docs = container.database_search(base);
            else
                docs = {};
                for c = 1:200:numel(T)
                    part = T(c:min(c + 199, numel(T)));
                    q = ndi.entity.anyOf(cellfun(@(i) ndi.query('', 'depends_on', edge, i), part, ...
                        'UniformOutput', false));
                    docs = [docs, reshape(container.database_search(base & q), 1, [])]; %#ok<AGROW>
                end
            end
            if isempty(names), return; end
            keep = cellfun(@(d) ndi.v2.matchTerm(ndi.v2.blockOf(ndi.v2.props(d), className, 'relation', []), ...
                names), docs);
            docs = docs(keep);
        end

        function ids = instanceIds(container, filt, spec)
            % INSTANCEIDS - the subjects that are an instance_of an entity of
            % the type FILT's variable names ('strain', 'product'), the
            % entity matching FILT's value by name or global identifier. With
            % one entity class (did-schema V_eta_entity_composition_plan.md
            % sec. 5) that is how a subject has a strain. [] when the variable
            % names no such type or the container holds no entity of it --
            % the caller then reports the property as unknown. A session
            % opened from its dataset also looks in the dataset's documents,
            % where the strain entities are (entitiesOfType).
            ids = [];
            v = cellstr(filt.variable);
            if ~isscalar(v), return; end
            type = lower(v{1});
            types = ndi.v2.entityTypesFor(type);
            if ~isscalar(types) || ~strcmp(types{1}, type), return; end
            targets = entitiesOfType(container, type);
            if isempty(targets), return; end
            if isfield(filt, 'value') && ~isempty(filt.value)
                keep = cellfun(@(d) entityMatches(ndi.v2.props(d), type, filt.value), targets);
                targets = targets(keep);
            end
            if isempty(targets)
                if spec.strict
                    warning('ndi:entity:search:noSuchValue', 'No %s in this %s is called %s.', ...
                        type, containerWord(container), strjoin(cellstr(filt.value), ' or '));
                end
                ids = {};
                return;
            end
            tid = cellfun(@(d) d.document_properties.base.id, targets, 'UniformOutput', false);
            r = struct('kind', 'directed_relation', 'name', {{'instance_of'}}, 'side', 'parent', ...
                'target', struct('ids', {reshape(tid, 1, [])}), 'time', struct());
            ids = ndi.entity.relatedIds(container, r, spec);
        end

        function T = targetIds(container, target, spec)
            % TARGETIDS - the ids a relation's other end may be: [] for any;
            % an ndi.entity (or several, or a cell of them); a document id; or
            % a cell describing subjects, searched with ndi.entity.search
            if isempty(target) && ~iscell(target)
                T = [];
            elseif isstruct(target) && isfield(target, 'ids')
                T = target.ids;      % document ids, already resolved
            elseif isa(target, 'ndi.entity')
                T = arrayfun(@(x) x.document_id, target, 'UniformOutput', false);
            elseif ischar(target) || (isstring(target) && isscalar(target))
                T = {char(target)};
            elseif iscell(target) && ~isempty(target) && all(cellfun(@(x) isa(x, 'ndi.entity'), target))
                T = cellfun(@(x) x.document_id, target, 'UniformOutput', false);
            elseif iscell(target)
                % a description: the outer search's strict and inherited
                % hold inside it unless it says otherwise
                given = cellfun(@(x) lower(char(x)), target(1:2:end), 'UniformOutput', false);
                if ~any(strcmp(given, 'strict')), target = [target, {'strict', spec.strict}]; end
                if ~any(strcmp(given, 'inherited')), target = [target, {'inherited', spec.inherited}]; end
                s = ndi.entity.search(container, target{:});
                T = cellfun(@(x) x.document_id, s, 'UniformOutput', false);
            else
                error('ndi:entity:search:relationTarget', ...
                    'The other end of a relation is a subject, a document id, or a cell describing subjects.');
            end
            if iscell(T), T = reshape(T, 1, []); end
        end

        function t = explainSearch(spec, indent, where)
            % EXPLAINSEARCH - SPEC in words, one line per condition; WHERE is
            % 'dataset' or 'session' for the first line ('' when nested)
            lines = {};
            for k = 1:size(spec.own, 1)
                v = valueText(spec.own{k, 2});
                switch spec.own{k, 1}
                    case 'type', lines{end+1} = sprintf('are of type %s', v); %#ok<AGROW>
                    case 'name', lines{end+1} = sprintf('are named %s', v); %#ok<AGROW>
                    case 'local_identifier', lines{end+1} = sprintf('have local identifier %s', v); %#ok<AGROW>
                    case 'id', lines{end+1} = sprintf('have id %s', v); %#ok<AGROW>
                end
            end
            for k = 1:numel(spec.filters)
                lines{end+1} = statementText(spec.filters(k), spec.inherited); %#ok<AGROW>
                if isfield(spec, 'context') && spec.context && ~strcmp(spec.filters(k).kind, 'assertion')
                    lines{end} = [lines{end} ...
                        ', or were contained in something that did while they were in it'];
                end
            end
            for k = 1:numel(spec.relations)
                lines{end+1} = relationText(spec.relations(k), indent, spec.inherited); %#ok<AGROW>
            end
            if isempty(where)
                head = 'subjects that';
            else
                head = sprintf('Searching this %s for subjects that', where);
                if ~spec.inherited
                    head = [head ' (counting only what is stated about each subject itself)'];
                end
            end
            if isempty(lines)
                if isempty(where), t = [indent 'any subject'];
                else, t = sprintf('Searching this %s for every subject', where); end
                return;
            end
            t = [indent head];
            for k = 1:numel(lines)
                t = [t newline indent '  ' char(8226) ' ' lines{k}]; %#ok<AGROW>
            end
        end

        function noSuchStatement(container, f, strict, noun)
            % NOSUCHSTATEMENT - no statement matched F's kind, variable and
            % method together. When one of them matches nothing on its own,
            % that is an error (for an asserted variable, naming the
            % properties there are, with the nearest as a suggestion); when
            % each exists but never on one statement, the answer is simply
            % none. STRICT false: never an error.
            if ~strict, return; end
            where = containerWord(container);
            for part = {'variable', 'method'}
                if ~isfield(f.filt, part{1}), continue; end
                [~, info] = ndi.v2.searchStatements(container, f.kind, struct(part{1}, {f.filt.(part{1})}));
                if info.structural > 0, continue; end
                pats = cellstr(f.filt.(part{1}));
                if strcmp(f.kind, 'assertion') && strcmp(part{1}, 'variable')
                    docs = container.database_search(ndi.v2.isaQuery('assertion'));
                    names = cellfun(@(d) ndi.v2.termName(ndi.v2.blockOf(ndi.v2.props(d), ...
                        'statement', 'variable', '')), docs, 'UniformOutput', false);
                    % and the entity types a subject can be an instance_of
                    % (one entity class: a strain is a relation)
                    for t = {'strain', 'product'}
                        if ~isempty(entitiesOfType(container, t{1}))
                            names{end+1} = t{1}; %#ok<AGROW>
                        end
                    end
                    props = unique([names, {'id', 'local_identifier', 'name', 'type'}]);
                    [~, o] = sort(lower(props));
                    props = props(o);
                    msg = sprintf('No %s in this %s has a property %s.', noun, where, quoted(pats));
                    msg = [msg didYouMean(pats, props)];
                    error('ndi:entity:search:unknownVariable', '%s\nProperties in this %s: %s', ...
                        msg, where, strjoin(props, ', '));
                end
                error('ndi:entity:search:noSuchStatement', 'No %s in this %s has %s %s.', ...
                    f.kind, where, part{1}, quoted(pats));
            end
        end
    end

    methods (Static, Hidden)
        function args = kindArgs(kind, args)
            % KINDARGS - (internal) ASSERTIONS/OBSERVATIONS/...: STATEMENTS'
            % arguments for one kind, with an optional cell of filters first
            if ~isempty(args) && iscell(args{1})
                args = [{kind, args{1}}, args(2:end)];
            else
                args = [{kind}, args];
            end
        end

        function [kinds, inherited, context] = statementArgs(args)
            % STATEMENTARGS - (internal) STATEMENTS' arguments: kinds with
            % filters, the older 'Class'/'Variable'/'Method' pairs, 'inherited'
            short = {'statement', 'assertion', 'interaction', 'observation', 'manipulation', 'calculation'};
            kinds = struct('kind', {}, 'filt', {});
            inherited = true;
            context = false;
            tolerant = false;
            legacy = struct();
            k = 1;
            while k <= numel(args)
                a = args{k};
                if ~(ischar(a) || (isstring(a) && isscalar(a)))
                    error('ndi:entity:statements:args', 'Expected a kind or an option name at argument %d.', k + 1);
                end
                a = char(a);
                la = lower(a);
                if any(strcmp(la, short))
                    f = struct();
                    if k < numel(args) && iscell(args{k + 1})
                        f = ndi.entity.statementFilter(la, args{k + 1});
                        k = k + 1;
                    end
                    kinds(end+1) = struct('kind', la, 'filt', f); %#ok<AGROW>
                elseif strcmp(la, 'inherited') && k < numel(args)
                    inherited = logical(args{k + 1}); k = k + 1;
                elseif strcmp(la, 'context') && k < numel(args)
                    context = logical(args{k + 1}); k = k + 1;
                elseif strcmp(la, 'tolerant') && k < numel(args)
                    tolerant = logical(args{k + 1}); k = k + 1;
                elseif any(strcmp(la, {'class', 'variable', 'method'})) && k < numel(args)
                    legacy.(la) = char(args{k + 1}); k = k + 1;
                else
                    error('ndi:entity:statements:args', ...
                        'Unknown argument ''%s'': a kind (%s), ''inherited'', ''context'', ''tolerant'', or ''Class''/''Variable''/''Method''.', ...
                        a, strjoin(short, ', '));
                end
                k = k + 1;
            end
            if ~isempty(fieldnames(legacy))
                f = struct();
                if isfield(legacy, 'variable'), f.variable = legacy.variable; end
                if isfield(legacy, 'method'), f.method = legacy.method; end
                kind = 'statement';
                if isfield(legacy, 'class'), kind = lower(legacy.class); end
                kinds(end+1) = struct('kind', kind, 'filt', f);
            end
            if isempty(kinds)
                kinds = struct('kind', 'statement', 'filt', struct());
            end
            for k = 1:numel(kinds)
                kinds(k).filt.tolerant = tolerant;
            end
        end

        function all_ = inheritanceStates(container, ids, inherited)
            % INHERITANCESTATES - (internal) what the subjects IDS inherit from
            %
            % A struct array, one element per (start, at) pair: START is one
            % of IDS, AT an entity it inherits from (itself included), PATH
            % the relations walked ('' for itself), and the flags M (a
            % member_of was walked), L (a part_of, sample_of, aliquot_of or
            % passage_of was) and I (the last step was instance_of: AT is a
            % type of START). Groups and wholes are walked up to 16 steps;
            % a type is reached from a subject, a whole, or a group whose
            % instance_of is distributive, and is not walked past. Without
            % INHERITED, only the subjects themselves.
            ids = unique(cellstr(ids), 'stable');
            ids = reshape(ids, 1, []);
            lineage = {'part_of', 'sample_of', 'aliquot_of', 'passage_of'};
            % states: start, at, hasMember, hasLineage, isInstance, path
            S = struct('start', ids, 'at', ids, 'm', false, 'l', false, 'i', false, 'path', {''});
            all_ = S;
            frontier = S;
            depth = 0;
            while inherited && ~isempty(frontier) && depth < 16
                depth = depth + 1;
                frontier = frontier(~[frontier.i]);     % a type is not walked past
                if isempty(frontier), break; end
                at = unique({frontier.at}, 'stable');
                next = struct('start', {}, 'at', {}, 'm', {}, 'l', {}, 'i', {}, 'path', {});
                for r = [{'member_of'}, lineage, {'instance_of'}]
                    step = r{1};
                    E = ndi.entity.edges(container, at(:), step, 'child_id', 'parent_id');
                    if height(E) == 0, continue; end
                    isType = strcmp(step, 'instance_of');
                    for f = 1:numel(frontier)
                        hit = find(strcmp(E.from, frontier(f).at));
                        for h = reshape(hit, 1, [])
                            % a group's type is its members' only when the
                            % group's instance_of is distributive
                            if isType && frontier(f).m && ~E.distributive(h), continue; end
                            p = step;
                            if ~isempty(frontier(f).path), p = [frontier(f).path ' > ' step]; end
                            next(end+1) = struct('start', frontier(f).start, 'at', E.to{h}, ...
                                'm', frontier(f).m || strcmp(step, 'member_of'), ...
                                'l', frontier(f).l || any(strcmp(step, lineage)), ...
                                'i', isType, 'path', p); %#ok<AGROW>
                        end
                    end
                end
                % a (start, at) reached before is not followed again
                keep = true(1, numel(next));
                for j = 1:numel(next)
                    keep(j) = ~any(strcmp({all_.start}, next(j).start) & strcmp({all_.at}, next(j).at));
                    if keep(j), all_(end+1) = next(j); end %#ok<AGROW>
                end
                frontier = next(keep);
            end
        end

        function L = statementLinks(container, ids, kinds, inherited, context)
            % STATEMENTLINKS - (internal) which statements hold of the subjects IDS
            %
            % L has fields about, doc, via (cell arrays, one entry per
            % subject-statement pair). The subjects' groups (member_of, up)
            % and wholes (part_of, sample_of, aliquot_of, passage_of, up) are
            % walked together, one search per step; then one statement search
            % per kind for every 200 subjects reached. A statement on a group
            % holds when it is distributive; one on a whole when it is an
            % assertion; on both, both. A subject's types (instance_of: its
            % strain, its product) are walked too, from the subject or from
            % a group whose instance_of is distributive, and an assertion
            % about the type holds of each instance (T17); the walk stops at
            % a type, which a session opened from its dataset finds among
            % the dataset's documents. CONTEXT: then the containers of
            % every subject reached (contextLinks).
            if nargin < 5, context = false; end
            described = arrayfun(@(k) isfield(k.filt, 'during_statements'), kinds);
            if any(described)
                L = struct('about', {{}}, 'doc', {{}}, 'via', {{}});
                if any(~described)
                    L = ndi.entity.statementLinks(container, ids, kinds(~described), inherited, context);
                end
                for k = find(described)
                    kk = kinds(k);
                    inner = kk.filt.during_statements;
                    kk.filt = rmfield(kk.filt, 'during_statements');
                    Lk = ndi.entity.statementLinks(container, ids, kk, inherited, context);
                    tolerant = isfield(kk.filt, 'tolerant') && kk.filt.tolerant;
                    for i = 1:numel(inner), inner(i).filt.tolerant = tolerant; end
                    Lk = ndi.entity.duringLinks(container, Lk, inner, inherited, context, tolerant);
                    have = strcat(L.about, '|', cellfun(@docIdOf, L.doc, 'UniformOutput', false));
                    for i = 1:numel(Lk.doc)
                        key = [Lk.about{i} '|' docIdOf(Lk.doc{i})];
                        if any(strcmp(have, key)), continue; end
                        have{end+1} = key; %#ok<AGROW>
                        L.about{end+1} = Lk.about{i}; L.doc{end+1} = Lk.doc{i}; L.via{end+1} = Lk.via{i};
                    end
                end
                return;
            end
            all_ = ndi.entity.inheritanceStates(container, ids, inherited);
            reached = unique({all_.at}, 'stable');
            L = struct('about', {{}}, 'doc', {{}}, 'via', {{}});
            seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            for k = 1:numel(kinds)
                f = kinds(k).filt;
                f.subject = reached;
                f.withDataset = any([all_.i]);
                docs = ndi.v2.searchStatements(container, kinds(k).kind, f);
                for i = 1:numel(docs)
                    p = ndi.v2.props(docs{i});
                    sid = ndi.v2.edgeIds(p, 'entity_id');
                    if isempty(sid), continue; end
                    isAssertion = any(strcmp(ndi.v2.classChain(p), 'assertion'));
                    d = ndi.v2.blockOf(p, 'statement', 'distributive', false);
                    distributive = ~isempty(d) && (islogical(d) || isnumeric(d)) && logical(d(1));
                    for j = find(strcmp({all_.at}, sid{1}))
                        st = all_(j);
                        if st.i
                            % a type's assertions hold of its instances;
                            % its interactions do not (T17)
                            if ~isAssertion, continue; end
                        elseif (st.m && ~distributive) || (st.l && ~isAssertion)
                            continue;
                        end
                        key = [st.start '|' char(p.base.id)];
                        if isKey(seen, key), continue; end
                        seen(key) = true;
                        via = st.path;
                        if isempty(via), via = 'own'; end
                        L.about{end+1} = st.start;
                        L.doc{end+1} = docs{i};
                        L.via{end+1} = via;
                    end
                end
            end
            if context
                % a type (a strain) is in no container
                L = ndi.entity.contextLinks(container, all_(~[all_.i]), kinds, L, seen);
            end
        end

        function L = contextLinks(container, states, kinds, L, seen)
            % CONTEXTLINKS - (internal) add to L the interactions of the
            % containers the subjects of STATES were in, while they were in
            % them (V_eta tenet T17). STATES: start (the subject asked for),
            % at (a subject it reaches), m (reached through member_of),
            % path. A stay reached through member_of must be distributive.
            % Nested containers narrow the window to when both held.
            cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            tolerant = false;
            for k = 1:numel(kinds)
                if isfield(kinds(k).filt, 'tolerant') && kinds(k).filt.tolerant, tolerant = true; end
            end
            frontier = struct('start', {states.start}, 'at', {states.at}, 'm', {states.m}, ...
                'path', {states.path}, 'win', {[]});
            C = struct('start', {}, 'at', {}, 'm', {}, 'path', {}, 'win', {});
            undecided = 0;
            for depth = 1:4
                if isempty(frontier), break; end
                S = ndi.v2.stays(container, unique({frontier.at}, 'stable'), 'child', cache);
                next = struct('start', {}, 'at', {}, 'm', {}, 'path', {}, 'win', {});
                for i = 1:numel(S)
                    for f = find(strcmp({frontier.at}, S(i).child))
                        fr = frontier(f);
                        if fr.m && ~S(i).distributive, continue; end
                        if ~S(i).decided, undecided = undecided + 1; continue; end
                        w = S(i);
                        if ~isempty(fr.win)
                            w.start = max(w.start, fr.win.start); w.end = min(w.end, fr.win.end);
                            if w.start > w.end, continue; end
                        end
                        p = 'contained_in';
                        if ~isempty(fr.path), p = [fr.path ' > contained_in']; end
                        next(end+1) = struct('start', fr.start, 'at', S(i).parent, 'm', false, ...
                            'path', p, 'win', w); %#ok<AGROW>
                    end
                end
                C = [C, next]; %#ok<AGROW>
                frontier = next;
            end
            if undecided > 0
                warning('ndi:entity:context:undecided', ['%d stay(s) in a container had no ' ...
                    'start or no end and were left out of the context.'], undecided);
            end
            if isempty(C), return; end
            parents = unique({C.at}, 'stable');
            for k = 1:numel(kinds)
                kind = kinds(k).kind;
                if strcmp(kind, 'assertion'), continue; end          % assertions never pass
                if strcmp(kind, 'statement'), kind = 'interaction'; end
                f = kinds(k).filt;
                f.subject = parents;
                docs = ndi.v2.searchStatements(container, kind, f);
                refs = cell(1, numel(docs));
                for i = 1:numel(docs)
                    refs{i} = ndi.v2.edgeIds(ndi.v2.props(docs{i}), 'time_reference_id');
                end
                all_ = unique([refs{:}]);
                times = containers.Map('KeyType', 'char', 'ValueType', 'any');
                if ~isempty(all_), times = ndi.v2.timesOf(container, all_, cache); end
                for i = 1:numel(docs)
                    p = ndi.v2.props(docs{i});
                    sid = ndi.v2.edgeIds(p, 'entity_id');
                    if isempty(sid), continue; end
                    t = cellfun(@(r) ifKeyAny(times, r), refs{i}, 'UniformOutput', false);
                    for j = find(strcmp({C.at}, sid{1}))
                        key = [C(j).start '|' char(p.base.id)];
                        if isKey(seen, key), continue; end
                        if ~ndi.v2.overlaps(t, C(j).win, tolerant), continue; end
                        seen(key) = true;
                        L.about{end+1} = C(j).start;
                        L.doc{end+1} = docs{i};
                        L.via{end+1} = C(j).path;
                    end
                end
            end
        end

        function L = duringLinks(container, L, inner, inherited, context, tolerant)
            % DURINGLINKS - (internal) keep the links of L whose statement's
            % time overlaps that of a statement matching INNER (a kinds
            % struct) that holds of the same subject -- by the same rules,
            % INHERITED and CONTEXT. A statement or reading whose time
            % cannot be compared does not match.
            if isempty(L.doc), return; end
            abouts = unique(L.about, 'stable');
            Li = ndi.entity.statementLinks(container, abouts, inner, inherited, context);
            cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            refsOf = @(d) ndi.v2.edgeIds(ndi.v2.props(d), 'time_reference_id');
            ro = cellfun(refsOf, L.doc, 'UniformOutput', false);
            ri = cellfun(refsOf, Li.doc, 'UniformOutput', false);
            all_ = unique([ro{:}, ri{:}]);
            times = containers.Map('KeyType', 'char', 'ValueType', 'any');
            if ~isempty(all_), times = ndi.v2.timesOf(container, all_, cache); end
            % each subject's windows: the times of the statements matching INNER
            wins = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for i = 1:numel(Li.doc)
                for r = 1:numel(ri{i})
                    w = windowOf(ifKeyAny(times, ri{i}{r}));
                    if isempty(w), continue; end
                    if isKey(wins, Li.about{i}), wins(Li.about{i}) = [wins(Li.about{i}), w];
                    else, wins(Li.about{i}) = w; end
                end
            end
            keep = false(1, numel(L.doc));
            for i = 1:numel(L.doc)
                if ~isKey(wins, L.about{i}), continue; end
                t = cellfun(@(r) ifKeyAny(times, r), ro{i}, 'UniformOutput', false);
                W = wins(L.about{i});
                for j = 1:numel(W)
                    if ndi.v2.overlaps(t, W(j), tolerant), keep(i) = true; break; end
                end
            end
            L.about = L.about(keep); L.doc = L.doc(keep); L.via = L.via(keep);
        end

        function ids = contextIds(container, docs, tolerant)
            % CONTEXTIDS - (internal) the subjects the interactions DOCS were
            % context for: what each one's subject contained while the
            % statement held (V_eta tenet T17), down nested containers, and
            % the members of a group in a distributive stay. Assertions
            % never pass.
            ids = {};
            keep = cellfun(@(d) ~any(strcmp(ndi.v2.classChain(ndi.v2.props(d)), 'assertion')), docs);
            docs = docs(keep);
            if isempty(docs), return; end
            cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            refs = cell(1, numel(docs)); subj = cell(1, numel(docs));
            for i = 1:numel(docs)
                p = ndi.v2.props(docs{i});
                refs{i} = ndi.v2.edgeIds(p, 'time_reference_id');
                s = ndi.v2.edgeIds(p, 'entity_id');
                if isempty(s), s = {''}; end
                subj{i} = s{1};
            end
            all_ = unique([refs{:}]);
            times = containers.Map('KeyType', 'char', 'ValueType', 'any');
            if ~isempty(all_), times = ndi.v2.timesOf(container, all_, cache); end
            T = cell(1, numel(docs));
            for i = 1:numel(docs)
                T{i} = cellfun(@(r) ifKeyAny(times, r), refs{i}, 'UniformOutput', false);
            end
            frontier = struct('at', subj, 'doc', num2cell(1:numel(docs)), 'win', {[]});
            frontier = frontier(~cellfun(@isempty, subj));
            groups = {};
            for depth = 1:4
                if isempty(frontier), break; end
                S = ndi.v2.stays(container, unique({frontier.at}, 'stable'), 'parent', cache);
                next = struct('at', {}, 'doc', {}, 'win', {});
                for i = 1:numel(S)
                    if ~S(i).decided, continue; end
                    for f = find(strcmp({frontier.at}, S(i).parent))
                        fr = frontier(f);
                        w = S(i);
                        if ~isempty(fr.win)
                            w.start = max(w.start, fr.win.start); w.end = min(w.end, fr.win.end);
                            if w.start > w.end, continue; end
                        end
                        if ~ndi.v2.overlaps(T{fr.doc}, w, tolerant), continue; end
                        ids{end+1} = S(i).child; %#ok<AGROW>
                        if S(i).distributive, groups{end+1} = S(i).child; end %#ok<AGROW>
                        next(end+1) = struct('at', S(i).child, 'doc', fr.doc, 'win', w); %#ok<AGROW>
                    end
                end
                frontier = next;
            end
            if ~isempty(groups)
                ids = [ids, ndi.entity.walkIds(container, unique(groups, 'stable'), 'member_of', 'in')];
            end
            ids = unique(ids, 'stable');
        end
    end

end

function id = docIdOf(d)
% a document's base.id
p = ndi.v2.props(d);
id = char(p.base.id);
end

function w = windowOf(t)
% a resolved time (ndi.v2.timeOf) as a window for ndi.v2.overlaps, or []
% when it cannot be placed (no time, or only a bound on its anchor)
w = [];
if isempty(t) || isnat(t.start) || strcmp(t.resolved_by, 'relation'), return; end
e = t.end;
if isnat(e), e = t.start; end
tol = t.tolerance; etol = t.end_tolerance;
if isempty(tol) || all(isnan(tol)), tol = [0 0]; end
if isempty(etol) || all(isnan(etol)), etol = tol; end
if isscalar(tol), tol = [tol tol]; end
if isscalar(etol), etol = [etol etol]; end
tol(isnan(tol)) = 0; etol(isnan(etol)) = 0;
w = struct('start', t.start, 'end', e, 'tol', tol, 'end_tol', etol);
end

function v = ifKeyAny(m, k)
% the value at key K of map M, or [] when absent
if isKey(m, k), v = m(k); else, v = []; end
end

function t = describe(filt)
% 'variable = strain, value = N2' for messages
f = fieldnames(filt);
parts = cell(1, numel(f));
for k = 1:numel(f)
    v = filt.(f{k});
    if iscell(v)
        v = strjoin(cellfun(@toText, v, 'UniformOutput', false), ' or ');
    else
        v = toText(v);
    end
    parts{k} = sprintf('%s = %s', f{k}, v);
end
t = strjoin(parts, ', ');
if isempty(t), t = 'anything'; end
end

function t = toText(v)
if ischar(v), t = ['''' v '''']; elseif isnumeric(v) || islogical(v), t = mat2str(v); else, t = class(v); end
end


function ids = narrow(ids, these)
% the intersection so far ([] = not narrowed yet)
if isempty(ids) && ~iscell(ids)
    ids = these;
else
    ids = ids(ismember(ids, these));
end
end

function tf = isDistributive(d)
tf = ~isempty(d) && (islogical(d) || isnumeric(d)) && logical(d(1));
end

function t = relationText(r, indent, inherited)
% one condition line for a relation filter, with its target nested below
name = 'related to';
if ~isempty(r.name), name = strjoin(r.name, ' or '); end
through = '';
if inherited && (strcmp(r.side, 'parent') || isempty(r.side) || strcmp(r.side, 'with'))
    through = ' (directly, or through a group they are members of)';
end
target = r.target;
named = '';
if isempty(target) && ~iscell(target)
    named = 'anything';
elseif isa(target, 'ndi.entity')
    named = strjoin(arrayfun(@(x) ['"' char(x.name) '"'], target, 'UniformOutput', false), ' or ');
elseif ischar(target) || isstring(target)
    named = ['the document ' char(target)];
elseif iscell(target) && all(cellfun(@(x) isa(x, 'ndi.entity'), target))
    named = strjoin(cellfun(@(x) ['"' char(x.name) '"'], target, 'UniformOutput', false), ' or ');
end
switch r.side
    case 'child'
        lead = sprintf('are the %s parent of', name);
    case 'parent'
        lead = sprintf('are %s', name);
    otherwise
        if isempty(r.name), lead = 'are related to'; else, lead = sprintf('are in a %s relation with', name); end
end
when = timeText(r.time);
if ~isempty(named)
    t = sprintf('%s %s%s%s', lead, named, when, through);
else
    inner = ndi.entity.explainNested(target, [indent '    ']);
    inner = regexprep(inner, '^\s*subjects that', '');      % the nested head reads "a subject that"
    t = sprintf('%s a subject%s%s that%s', lead, when, through, inner);
end
end

function t = statementText(f, inherited)
% one condition line for a statement filter: "have strain N2", "had a
% manipulation with variable NGM agar and value >= 0.02"
kind = f.kind;
verb = 'had';
if any(strcmp(kind, {'assertion', 'statement'})), verb = 'have'; end
fl = f.filt;
names = intersect({'variable', 'method', 'value', 'formulation'}, fieldnames(fl), 'stable');
when = timeText(fl);
if isfield(fl, 'during_statements')
    inner = arrayfun(@(k) statementText(k, false), fl.during_statements, 'UniformOutput', false);
    when = [when ', at a time when they also ' strjoin(inner, ' or ')];
end
if strcmp(kind, 'assertion') && isequal(sort(names), sort({'value', 'variable'})) && ischar(fl.variable)
    t = sprintf('have %s %s%s', fl.variable, valueText(fl.value), when);
else
    parts = cellfun(@(n) sprintf('%s %s', n, valueText(fl.(n))), names, 'UniformOutput', false);
    t = sprintf('%s %s %s', verb, article(kind), kind);
    if ~isempty(parts)
        if numel(parts) > 1
            parts = [strjoin(parts(1:end-1), ', ') ' and ' parts{end}];
        else
            parts = parts{1};
        end
        t = sprintf('%s with %s', t, parts);
    end
    t = [t when];
end
if inherited
    if strcmp(kind, 'assertion')
        t = [t ' (stated on them, on a group they are members of, or on what they are part of)'];
    else
        t = [t ' (on them, or on a group they are members of)'];
    end
end
end

function t = timeText(f)
% ', at 2023-11-16T14:00, lasting >=3h' for the time filters in F ('' when none)
t = '';
if ~isstruct(f), return; end
words = struct('at', 'at', 'during', 'during', 'before', 'before', 'after', 'after', 'duration', 'lasting');
for n = {'at', 'during', 'before', 'after', 'duration'}
    if ~isfield(f, n{1}) || isempty(f.(n{1})), continue; end
    v = f.(n{1});
    if isa(v, 'datetime'), v = arrayfun(@char, v, 'UniformOutput', false); end
    if strcmp(n{1}, 'during') && iscell(v) && numel(v) == 2
        txt = sprintf('%s to %s', valueText(v{1}), valueText(v{2}));
    else
        txt = valueText(v);
    end
    t = sprintf('%s, %s %s', t, words.(n{1}), txt);
end
end

function m = noTimeMessage(kind, filt, tinfo, where)
% the warning when statements or relations matched but none at that time
m = sprintf('No %s in this %s matches %s at the time asked.', kind, where, describe(filt));
why = {};
if tinfo.unresolved > 0, why{end+1} = sprintf('%d time(s) could not be resolved here', tinfo.unresolved); end
if tinfo.nozone > 0, why{end+1} = sprintf(['%d time(s) have no recorded time zone to read the times ' ...
        'you typed in (give a zone, e.g. ''2023-11-16T14:00-08:00'')'], tinfo.nozone); end
if tinfo.bound > 0, why{end+1} = sprintf(['%d time(s) are known only as before or after another ' ...
        'event, which cannot decide this'], tinfo.bound); end
if tinfo.docs > 0, why{end+1} = sprintf('%d have no time at all', tinfo.docs); end
if ~isempty(why), m = sprintf('%s\nNot compared: %s.', m, strjoin(why, '; ')); end
end

function t = valueText(v)
% a pattern or a list of them, as typed: N2 or CB*
if iscell(v)
    t = strjoin(cellfun(@valueText, v, 'UniformOutput', false), ' or ');
elseif ischar(v) || isstring(v)
    t = char(v);
elseif isnumeric(v) || islogical(v)
    t = mat2str(v);
else
    t = class(v);
end
end

function q = quoted(pats)
q = strjoin(cellfun(@(x) ['''' char(x) ''''], cellstr(pats), 'UniformOutput', false), ' or ');
end

function m = didYouMean(pats, candidates)
% ' Did you mean ''strain''?' for the first pattern with a near candidate
m = '';
for k = 1:numel(pats)
    if ~ischar(pats{k}) || ndi.v2.hasWildcard(pats{k}), continue; end
    c = ndi.v2.closest(pats{k}, candidates);
    if ~isempty(c)
        m = sprintf(' Did you mean ''%s''?', c);
        return;
    end
end
end

function w = containerWord(container)
if isa(container, 'ndi.dataset'), w = 'dataset'; else, w = 'session'; end
end

function m = noValueMessage(f, values, where, noun)
% the warning when a variable is there and none of the values is
vals = f.filt.value;
if ~iscell(vals), vals = {vals}; end
shown = values(1:min(end, 30));
more = '';
if numel(values) > 30, more = sprintf(' (and %d more)', numel(values) - 30); end
pats = vals(cellfun(@ischar, vals));
if strcmp(f.kind, 'assertion') && isfield(f.filt, 'variable') && ischar(f.filt.variable)
    var = f.filt.variable;
    m = sprintf('No %s in this %s has %s %s.', noun, where, var, quoted(pats));
    label = [upper(var(1)) var(2:end)];
else
    m = sprintf('No %s in this %s matches %s.', f.kind, where, describe(f.filt));
    label = 'Values';
end
m = [m didYouMean(pats, values)];
m = sprintf('%s\n%s in this %s: %s%s', m, label, where, strjoin(shown, ', '), more);
end

function a = article(word)
if any(lower(word(1)) == 'aeiou'), a = 'an'; else, a = 'a'; end
end

function tf = entityMatches(p, type, patterns)
% does entity P of TYPE match any of PATTERNS by name or global identifier
tf = ndi.v2.matchTerm(char(ndi.v2.blockOf(p, type, 'name', '')), patterns);
ids = cellstr(ndi.v2.blockOf(p, type, 'global_identifier', {}));
for k = 1:numel(ids)
    if tf, return; end
    tf = ndi.v2.matchTerm(struct('name', '', 'node', ids{k}), patterns);
end
end

function m = typeDocuments(container, ids)
% the properties of the documents IDS (a strain, a product), by id: the
% container's own, and for a session opened from a dataset the dataset's
m = containers.Map('KeyType', 'char', 'ValueType', 'any');
qs = cellfun(@(i) ndi.query('base.id', 'exact_string', i, ''), ids, 'UniformOutput', false);
q = ndi.v2.anyOf(qs);
docs = container.database_search(q);
if numel(docs) < numel(ids) && isa(container, 'ndi.session')
    docs = container.database_search_with_dataset(q);
end
for i = 1:numel(docs)
    p = ndi.v2.props(docs{i});
    m(char(p.base.id)) = p;
end
end

function docs = entitiesOfType(container, type)
% the entities of TYPE (merged `entity` documents only) CONTAINER can reach:
% its own, and for a session opened from a dataset the dataset's too, since
% a strain or product entity is written once, at dataset level
q = ndi.v2.isaQuery(type) & ndi.query('', 'isa', 'entity', '');
docs = container.database_search(q);
if isempty(docs) && isa(container, 'ndi.session')
    docs = container.database_search_with_dataset(q);
end
end

function n = kindOfSpec(spec)
% the noun a search's messages use: its kind ('subject', 'person', ...)
n = 'entity';
if isfield(spec, 'kind') && ~isempty(spec.kind), n = char(spec.kind); end
end
