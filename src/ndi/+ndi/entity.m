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
    % Make one with ndi.entity.fromDocument or ndi.entity.find:
    %
    %   p = ndi.entity.find(ds, 'person');          % a cell array
    %   p{1}.name()                                  % 'Jess Haley'
    %   p{1}.parents('affiliated_with')              % her organizations
    %
    % A search through an ndi.session sees only that session's documents;
    % dataset-level entities (people, studies, ...) are found through the
    % ndi.dataset.
    %
    % ndi.entity Methods:
    %   kind               - the document class ('person', 'subject', ...)
    %   name               - a display name
    %   document_id        - the document's base.id
    %   document           - the ndi.document
    %   document_properties - its properties (a struct)
    %   global_identifiers - table: scheme, value (ORCID, ROR, RRID, DOI, ...)
    %   relations          - table of the relations it takes part in
    %   parents, children  - the entities across a relation
    %   fromDocument, find - (static) make entities
    %
    % See also ndi.subject, ndi.statement.

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

        function id = document_id(obj)
            % DOCUMENT_ID - the entity document's base.id
            p = obj.document_properties();
            id = char(p.base.id);
        end

        function k = kind(obj)
            % KIND - the entity's document class, e.g. 'person', 'subject'
            p = obj.document_properties();
            k = char(p.document_class.class_name);
        end

        function n = name(obj)
            % NAME - a display name
            %
            % The class's own `name` when it has one; a person's given and
            % family names; else a subject's local_identifier, else base.name.
            p = obj.document_properties();
            k = obj.kind();
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
            % RELATIONS - the relations this entity takes part in
            %
            % T = RELATIONS(OBJ) returns a table, one row per relation document:
            %   relation    the relation's name (e.g. 'member_of', 'part_of')
            %   direction   "out" when this entity is the child (the subject of
            %               the sentence: worm member_of cohort), "in" when it
            %               is the parent
            %   other_id    the document id at the other end
            %   roles       the relation's roles, joined with ', '
            %   relation_id the relation document's id
            % T = RELATIONS(OBJ, RELATIONNAME) keeps one relation.
            % 'Direction' 'out', 'in' or 'both' (default).
            arguments
                obj
                relationName (1,:) char = ''
                options.Direction (1,:) char {mustBeMember(options.Direction, {'out', 'in', 'both'})} = 'both'
            end
            relation = strings(0, 1); direction = strings(0, 1); other_id = strings(0, 1);
            roles = strings(0, 1); relation_id = strings(0, 1);
            id = obj.document_id();
            sides = {'out', 'child_id', 'parent_id'; 'in', 'parent_id', 'child_id'};
            for s = 1:2
                if ~strcmp(options.Direction, 'both') && ~strcmp(options.Direction, sides{s, 1})
                    continue;
                end
                q = ndi.query('', 'isa', 'directed_relation', '') & ...
                    ndi.query('', 'depends_on', sides{s, 2}, id);
                docs = obj.container_.database_search(q);
                for i = 1:numel(docs)
                    p = ndi.v2.props(docs{i});
                    r = ndi.v2.termName(ndi.v2.blockOf(p, 'directed_relation', 'relation', ''));
                    if ~isempty(relationName) && ~strcmp(r, relationName)
                        continue;
                    end
                    other = ndi.v2.edgeIds(p, sides{s, 3});
                    rl = ndi.v2.blockOf(p, 'directed_relation', 'roles', []);
                    rn = {};
                    rl = ndi.v2.entries(rl);
                    for j = 1:numel(rl), rn{end+1} = ndi.v2.termName(rl{j}); end %#ok<AGROW>
                    relation(end+1, 1) = string(r); %#ok<AGROW>
                    direction(end+1, 1) = string(sides{s, 1}); %#ok<AGROW>
                    other_id(end+1, 1) = string(strjoin(other, ', ')); %#ok<AGROW>
                    roles(end+1, 1) = string(strjoin(rn, ', ')); %#ok<AGROW>
                    relation_id(end+1, 1) = string(p.base.id); %#ok<AGROW>
                end
            end
            T = table(relation, direction, other_id, roles, relation_id);
        end

        function e = parents(obj, relationName)
            % PARENTS - the entities this one points to across RELATIONNAME
            %
            % E = PARENTS(OBJ, RELATIONNAME), a cell array: e.g. a worm's
            % parents('member_of') is its cohort. An end that is not found
            % from this container (see the class help) is left out.
            arguments
                obj
                relationName (1,:) char
            end
            e = obj.across(obj.relations(relationName, 'Direction', 'out'));
        end

        function e = children(obj, relationName)
            % CHILDREN - the entities that point to this one across RELATIONNAME
            %
            % E = CHILDREN(OBJ, RELATIONNAME), a cell array: e.g. a cohort's
            % children('member_of') are its worms.
            arguments
                obj
                relationName (1,:) char
            end
            e = obj.across(obj.relations(relationName, 'Direction', 'in'));
        end
    end

    methods (Access = protected)
        function e = across(obj, T)
            e = {};
            for i = 1:height(T)
                d = ndi.v2.getDocument(obj.container_, char(T.other_id(i)));
                if ~isempty(d)
                    e{end+1} = ndi.entity.fromDocument(obj.container_, d); %#ok<AGROW>
                end
            end
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

        function e = find(container, kind, options)
            % FIND - the entities of a kind in a session or dataset
            %
            % E = ndi.entity.find(CONTAINER, KIND) returns a cell array, one
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
                if ~isempty(options.Name) && ~strcmp(x.name(), options.Name)
                    continue;
                end
                e{end+1} = x; %#ok<AGROW>
            end
        end
    end
end
