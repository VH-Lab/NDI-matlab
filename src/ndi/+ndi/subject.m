classdef subject < ndi.ido & ndi.documentservice & ndi.entity
    % ndi.subject - an object describing the subject of a measurement or stimulation
    %
    % ndi.subject is an object that stores information about the subject of an ndi.element.
    %   Each ndi.element object must have a subject; the subject associated with the element
    %   is a key defining feature of an ndi.element object.
    %
    % ndi.subject Properties:
    %  local_identifier - A string that is a unique global identifier but that also has meaning within an individual
    %                     lab. Must include an '@' character that identifies the lab. For example: anteater23@nosuchlab.org
    %  description - A string of description that is free for the user to choose.
    %
    % ndi.subject Methods:
    %  subject - Create a new ndi.subject object
    %  newdocument - Create an ndi.document based on an ndi.subject
    %  searchquery - Search for an ndi.document representation of an ndi.subject
    %  isvalidlocalidentifierstring - Is a string a valid local_identifier string? (Static)
    %  does_subjectstring_match_session_document - Does an ndi.subject object already have a representation in an ndi.database? (Static)
    %  search - Find subjects by what is true of them (Static)
    %  statements - The statements about the subject(s), inherited by default
    %  assertions, observations, manipulations, calculations, interactions -
    %               statements of that kind (ndi.summary makes a table)
    %

    properties (GetAccess=public, SetAccess=protected)
        local_identifier    % A string that is a local identifier in the lab, e.g. anteater23@nosuchlab.org
        description             % A string description
    end % properties

    properties (Dependent, SetAccess = private)
        type    % V2: the subject's coarse kind ('organism', 'group', ...); '' without a V2 document
    end

    methods

        function ndi_subject_obj = subject(varargin)
            % ndi.subject - create a new ndi.subject object
            %
            % NDI_SUBJECT_OBJ = ndi.subject(LOCAL_IDENTIFIER, DESCRIPTION)
            %   or
            % NDI_SUBJECT_OBJ = ndi.subject(NDI_SESSION_OBJ, NDI_SUBJECT_DOCUMENT)
            %
            % Creates an ndi.subject object, either from a local identifier name or
            % an ndi.session object and an ndi.document that describes the ndi.subject object.
            %
            %
            local_identifier_ = '';
            description_ = '';

            if numel(varargin)==2
                E = varargin{1};
                if ~isa(E,'ndi.session')
                    local_identifier_ = varargin{1};
                    [b,msg] = ndi.subject.isvalidlocalidentifierstring(local_identifier_);
                    if ~b
                        error(msg);
                    end
                    description_ = varargin{2};
                    if ~ischar(description_)
                        error(['description must be a string.']);
                    end
                else
                    if ~isa(E,'ndi.session')
                        error(['First input argument must be an ndi.session input']);
                    end
                    if ~isa(varargin{2},'ndi.document')
                        subject_search = E.database_search(ndi.query('base.id',...
                            'exact_string',varargin{2},''));
                        if numel(subject_search)~=1
                            error(['When 2 input arguments are given, 2nd input must be an ndi.document or document ID.']);
                        end
                        subject_doc = subject_search{1};
                    else
                        subject_doc = varargin{2};
                    end
                    local_identifier_ = subject_doc.document_properties.subject.local_identifer;
                    description_ = subject_doc.document_properties.subject.description;
                end
            end
            ndi_subject_obj.local_identifier = local_identifier_;
            ndi_subject_obj.description = description_;
        end % ndi.subject()

        %%% ndi.documentservice methods

        function ndi_document_obj = newdocument(ndi_subject_obj)
            % NEWDOCUMENT - return a new database document of type ndi.document based on a subject
            %
            % NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_SUBJECT_OBJ)
            %
            % Creates a new ndi.document of type 'subject'.
            %
            ndi_document_obj = ndi.document('subject',...
                'subject.local_identifier', ndi_subject_obj.local_identifier,...
                'subject.description', ndi_subject_obj.description,...
                'base.id', ndi_subject_obj.id(),...
                'base.name', ndi_subject_obj.local_identifier,...
                'base.session_id', ndi.session.empty_id());

        end % newdocument()

        function sq = searchquery(ndi_subject_obj)
            % SEARCHQUERY - return a search query for an ndi.document based on this element
            %
            % SQ = SEARCHQUERY(NDI_SUBJECT_OBJ)
            %
            %
            sq = {'subject.local_identifier',ndi_subject.local_identifer'};
        end % searchquery()

        %%% V2 (V_eta) methods: an ndi.subject read from a V2 document with
        %%% ndi.subject.fromDocument / ndi.subject.search. They return empty on
        %%% a subject that was not (no container to search).

        function t = get.type(ndi_subject_obj)
            % TYPE - the subject's coarse kind: 'organism', 'group', 'culture', 'material', ...
            %   ('' for a subject with no V2 document)
            t = '';
            if isempty(ndi_subject_obj.entity_document_), return; end
            t = ndi.v2.termName(ndi.v2.blockOf(ndi_subject_obj.document_properties(), 'subject', 'type', ''));
        end % get.type()

        function s = statements(ndi_subject_obj, varargin)
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
            % rules as ndi.subject.search):
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
            % Filters, the words ndi.subject.search uses:
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
            [kinds, inherited, context] = ndi.subject.statementArgs(varargin);
            s = {};
            subjects = ndi_subject_obj(arrayfun(@(x) ~isempty(x.container_), ndi_subject_obj));
            if isempty(subjects), return; end
            container = subjects(1).container_;
            ids = arrayfun(@(x) x.document_id, subjects, 'UniformOutput', false);
            L = ndi.subject.statementLinks(container, ids, kinds, inherited, context);
            s = cell(1, numel(L.doc));
            for i = 1:numel(L.doc)
                s{i} = ndi.statement.fromDocument(container, L.doc{i}).withContext(L.about{i}, L.via{i});
            end
        end % statements()

        function s = assertions(ndi_subject_obj, varargin)
            % ASSERTIONS - what is asserted about the subject (or subjects): species, strain, ...
            %
            % S = ASSERTIONS(SUBJ, ...) is STATEMENTS(SUBJ, 'assertion', ...): a
            % cell array of ndi.assertion objects, inherited by default. A cell
            % of filters may come first:
            %   a = w.assertions({'variable', 'strain'})
            %   a = w.assertions('inherited', false)
            % ndi.summary(a) makes the table.
            args = ndi.subject.kindArgs('assertion', varargin);
            s = ndi_subject_obj.statements(args{:});
        end % assertions()

        function s = observations(ndi_subject_obj, varargin)
            % OBSERVATIONS - what was observed of the subject (or subjects)
            %
            % S = OBSERVATIONS(SUBJ, ...) is STATEMENTS(SUBJ, 'observation', ...),
            % a cell array of ndi.observation objects; filters as ASSERTIONS:
            %   o = w.observations({'variable', 'temperature'})
            args = ndi.subject.kindArgs('observation', varargin);
            s = ndi_subject_obj.statements(args{:});
        end % observations()

        function s = manipulations(ndi_subject_obj, varargin)
            % MANIPULATIONS - what was done to the subject (or subjects)
            %
            % S = MANIPULATIONS(SUBJ, ...) is STATEMENTS(SUBJ, 'manipulation', ...),
            % a cell array of ndi.manipulation objects; filters as ASSERTIONS:
            %   m = w.manipulations({'method', 'refrigeration'})
            args = ndi.subject.kindArgs('manipulation', varargin);
            s = ndi_subject_obj.statements(args{:});
        end % manipulations()

        function s = calculations(ndi_subject_obj, varargin)
            % CALCULATIONS - what was calculated of the subject (or subjects)
            %
            % S = CALCULATIONS(SUBJ, ...) is STATEMENTS(SUBJ, 'calculation', ...),
            % a cell array of ndi.calculation objects; filters as ASSERTIONS:
            %   c = calculations([w{:}], {'variable', 'midpoint speed'})
            args = ndi.subject.kindArgs('calculation', varargin);
            s = ndi_subject_obj.statements(args{:});
        end % calculations()

        function s = interactions(ndi_subject_obj, varargin)
            % INTERACTIONS - observations, manipulations and calculations of the subject
            %
            % S = INTERACTIONS(SUBJ, ...) is STATEMENTS(SUBJ, 'interaction', ...):
            % every statement with a time and a method; filters as ASSERTIONS.
            args = ndi.subject.kindArgs('interaction', varargin);
            s = ndi_subject_obj.statements(args{:});
        end % interactions()

        function m = members(ndi_subject_obj)
            % MEMBERS - a group's members (the subjects that are member_of it), a cell array
            m = ndi_subject_obj.children('member_of');
        end

        function g = memberOf(ndi_subject_obj)
            % MEMBEROF - the groups this subject is member_of, a cell array
            g = ndi_subject_obj.parents('member_of');
        end

        function p = parts(ndi_subject_obj)
            % PARTS - the subjects that are part_of this one (a plate's patches), a cell array
            p = ndi_subject_obj.children('part_of');
        end

        function w = partOf(ndi_subject_obj)
            % PARTOF - what this subject is part_of (a patch's plate), a cell array
            w = ndi_subject_obj.parents('part_of');
        end

    end % methods

    methods (Static) % static methods

        function [value, rest] = takeOption(args, name, default)
            % TAKEOPTION - remove the name-value pair NAME from ARGS
            value = default;
            rest = args;
            for k = numel(args)-1:-1:1
                if (ischar(args{k}) || isstring(args{k})) && strcmpi(args{k}, name)
                    value = args{k+1};
                    rest(k:k+1) = [];
                end
            end
        end

        function obj = fromDocument(container, doc)
            % FROMDOCUMENT - an ndi.subject read from a subject document (V2 or v1)
            %
            % OBJ = ndi.subject.fromDocument(CONTAINER, DOC); CONTAINER is the
            % ndi.session or ndi.dataset DOC was read from; DOC an ndi.document
            % or a document id. The subject keeps DOC's id. The '@' that
            % ndi.subject(LOCAL_IDENTIFIER, DESCRIPTION) requires is a v1 rule
            % for MAKING a subject and is not applied here (V2_Object_Layer.md, D6).
            if ischar(doc) || isstring(doc)
                d = ndi.v2.getDocument(container, char(doc));
                if isempty(d)
                    error('ndi:subject:notFound', 'No document %s in this %s.', char(doc), class(container));
                end
                doc = d;
            end
            p = ndi.v2.props(doc);
            obj = ndi.subject();
            obj.identifier = char(p.base.id);
            obj.local_identifier = char(ndi.v2.blockOf(p, 'subject', 'local_identifier', ''));
            obj.description = char(ndi.v2.blockOf(p, 'subject', 'description', ''));
            obj.container_ = container;
            obj.entity_document_ = doc;
        end % fromDocument()

        function s = search(container, varargin)
            % SEARCH - the subjects in a session or dataset, by what is true of them
            %
            % S = ndi.subject.search(CONTAINER, PROPERTY, VALUE, ...) returns a
            % cell array of ndi.subject: those for which every pair holds.
            % With no pairs, every subject (instruments included,
            % V2_Object_Layer.md, Q2).
            %
            %   ndi.subject.search(ds, 'type', 'organism', ...
            %       'species', 'Caenorhabditis elegans', 'strain', {'N2', 'CB*'})
            %   ndi.subject.search(ds, 'manipulation', {'method', 'heating'})
            %   ndi.subject.search(ds, 'type', 'organism', ...
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
            %       ndi.subject.search takes, nested as deep as needed.
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
            spec = ndi.subject.parseSearch(varargin);
            if spec.explain
                fprintf('%s\n', ndi.subject.explainSearch(spec, '', containerWord(container)));
            end
            ids = ndi.subject.searchIds(container, spec);
            if iscell(ids)
                s = ndi.entity.fetchMany(container, ids);
            else
                q = ndi.v2.isaQuery('subject');   % an entity of a physical type since 2026-10-08
                lid = spec.own(strcmp(spec.own(:, 1), 'local_identifier'), 2);
                if isscalar(lid) && ischar(lid{1}) && ~ndi.v2.hasWildcard(lid{1})
                    q = q & ndi.v2.blockQuery('subject.local_identifier', 'exact_string_anycase', ...
                        strrep(lid{1}, '\*', '*'), '');
                end
                docs = container.database_search(q);
                s = cellfun(@(d) ndi.subject.fromDocument(container, d), docs, 'UniformOutput', false);
            end
            s = reshape(s, 1, []);
            keep = cellfun(@(x) isa(x, 'ndi.subject'), s);
            own = spec.own;
            for k = 1:size(own, 1)
                for i = find(keep)
                    x = s{i};
                    switch own{k, 1}
                        case 'type', keep(i) = ndi.v2.matchTerm(x.type, own{k, 2});
                        case 'name', keep(i) = ndi.v2.matchTerm(x.name, own{k, 2});
                        case 'local_identifier', keep(i) = ndi.v2.matchTerm(x.local_identifier, own{k, 2});
                        case 'id', keep(i) = any(strcmp(x.document_id, cellstr(own{k, 2})));
                    end
                end
            end
            s = reshape(s(keep), 1, []);
        end % search()

    end

    methods (Static, Hidden)
        function t = explainNested(c, indent)
            % EXPLAINNESTED - a description (a cell of search's pairs) in words
            t = ndi.subject.explainSearch(ndi.subject.parseSearch(c), indent, '');
        end

    end

    methods (Static)
        function [b,msg] = isvalidlocalidentifierstring(local_identifier)
            % ISVALIDLOCALIDENTIFIERSTRING - is this a valid local identifier string?
            %
            % [B,MSG] = ISVALIDLOCALIDENTIFIERSTRING(LOCAL_IDENTIFIER)
            %
            % Returns 1 if the input LOCAL_IDENTIFIER is a character string and
            % if it has an '@' in it. If B is 0, then an error message string is returned
            % in MSG.
            b = 1; msg = '';
            if ~ischar(local_identifier)
                msg = 'local_identifier must be a character string';
                b = 0;
            end
            if ~any(local_identifier=='@')
                msg = 'local_identifier must have an @ character.';
                b = 0;
            end
            if any(local_identifier==' ')
                msg = 'local_identifier must not have any spaces.';
                b = 0;
            end
        end % isvalidlocalidentifierstring()

        function [b,subject_id] = does_subjectstring_match_session_document(ndi_session_obj,subjectstring,makeit)
            % DOES_SUBJECTSTRING_MATCH_SESSION_DOCUMENT - does a subject string match a document?
            %
            % [B, SUBJECT_ID] = DOES_SUBJECTSTRING_MATCH_SESSION_DOCUMENT(NDI_SESSION_OBJ, ...
            %    SUBJECTSTRING, MAKEIT)
            %
            % Given a SUBJECTSTRING, which is either the local identifier for a subject in the
            % ndi.session object, or a document ID in the database, determine if the SUBJECTSTRING
            % corresponds to an ndi.document already in the database. If so, then the ID of that document
            % is returned in SUBJECT_ID and B is 1. If it is not there, and if MAKEIT is 1, then
            % a new entry is made and the document id is returned in SUBJECT_ID. If MAKEIT is 0, and it is
            % not there, then B is 0 and SUBJECT_ID is empty.
            %
            need_to_make_it = 0;
            b = 0;
            subject_id = '';

            islocal = ndi.subject.isvalidlocalidentifierstring(subjectstring);
            if islocal
                subject_doc = ndi_session_obj.database_search(...
                    ndi.query('subject.local_identifier','exact_string',subjectstring,''));
            else
                subject_doc = ndi_session_obj.database_search(...
                    ndi.query('base.id','exact_string',subjectstring,''));
            end
            if numel(subject_doc)==1
                subject_id = subject_doc{1}.document_properties.base.id;
                b = 1;
                return;
            elseif numel(subject_doc)==0
                if islocal&makeit
                    newsubject = ndi.subject(subjectstring,'');
                    subject_doc = newsubject.newdocument();
                    ndi_session_obj.database_add(subject_doc);
                    subject_id = subject_doc.document_properties.base.id;
                    b = 1;
                else
                    return;
                end
            elseif numel(subject_doc)>1
                error(['More than one subject doc matches..should only be 1!']);
            end
        end % does_subjectstring_match_session_document()
    end % static methods

    methods (Static, Access = protected)
        function spec = parseSearch(args)
            % PARSESEARCH - search's PROPERTY, VALUE pairs as a search spec:
            % own fields, statement filters, relation filters, and switches
            if mod(numel(args), 2)
                error('ndi:subject:search:pairs', 'ndi.subject.search takes PROPERTY, VALUE pairs.');
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
                    error('ndi:subject:search:pairs', 'A property name must be text (argument %d).', k + 1);
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
                    spec.filters(end+1) = struct('kind', lp, 'filt', ndi.subject.statementFilter(lp, v));
                elseif any(strcmp(lp, relationKinds))
                    spec.relations(end+1) = ndi.subject.relationFilter(lp, v);
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
                error('ndi:subject:search:statementFilter', ...
                    '''%s'' takes a cell of filters, e.g. {''variable'', ''NGM agar'', ''value'', ''>=0.02''}.', kind);
            end
            filt = struct();
            for k = 1:2:numel(c)
                n = lower(char(c{k}));
                if ~any(strcmp(n, {'variable', 'method', 'value', 'formulation', ...
                        'at', 'during', 'before', 'after', 'duration'}))
                    error('ndi:subject:search:statementFilter', ...
                        ['Unknown filter ''%s'' for ''%s'': variable, method, value, formulation, ' ...
                         'at, during, before, after, duration.'], c{k}, kind);
                end
                v = c{k + 1};
                if isstring(v), v = cellstr(v); if isscalar(v), v = v{1}; end, end
                if strcmp(n, 'during') && ndi.subject.isStatementDescription(v)
                    % 'during', {'observation', {...}}: when a statement
                    % matching that holds of the same subject (statementLinks)
                    filt.during_statements = ndi.subject.statementKinds(v);
                    continue;
                end
                filt.(n) = v;
            end
            if strcmp(kind, 'assertion') && isfield(filt, 'during_statements')
                error('ndi:subject:search:assertionTime', 'An assertion has no time, so it is never ''during'' anything.');
            end
            if strcmp(kind, 'assertion') && isfield(filt, 'method')
                error('ndi:subject:search:assertionMethod', 'An assertion has no method.');
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
                if ~ndi.subject.isStatementDescription({kind})
                    error('ndi:subject:search:statementFilter', ...
                        '''during'' takes times or statements, e.g. {''observation'', {''variable'', ''ambient temperature'', ''value'', ''>22''}}.');
                end
                f = struct();
                if k < numel(v) && iscell(v{k + 1})
                    f = ndi.subject.statementFilter(kind, v{k + 1});
                    k = k + 1;
                end
                if strcmp(kind, 'assertion')
                    error('ndi:subject:search:assertionTime', 'An assertion has no time, so nothing is ''during'' it.');
                end
                kinds(end+1) = struct('kind', kind, 'filt', f); %#ok<AGROW>
                k = k + 1;
            end
        end

        function r = relationFilter(kind, c)
            % RELATIONFILTER - {'name', N, 'parent'|'child'|'with', X} as a struct
            if ~iscell(c) || mod(numel(c), 2)
                error('ndi:subject:search:relationFilter', ...
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
                            error('ndi:subject:search:relationFilter', ...
                                'Give one of ''parent'', ''child'' and ''with'' in a relation (got ''%s'' and ''%s'').', r.side, n);
                        end
                        if strcmp(kind, 'undirected_relation') && ~strcmp(n, 'with')
                            error('ndi:subject:search:relationFilter', ...
                                'An undirected relation has no %s: use ''with''.', n);
                        end
                        r.side = n;
                        r.target = v;
                    case {'at', 'during', 'before', 'after', 'duration'}
                        r.time.(n) = v;
                    case 'depth'
                        error('ndi:subject:search:notYet', ...
                            'Relation filter ''%s'' is not built yet.', n);
                    otherwise
                        error('ndi:subject:search:relationFilter', ...
                            ['Unknown filter ''%s'' for ''%s'': name, parent, child, with, ' ...
                             'at, during, before, after, duration.'], c{k}, kind);
                end
            end
            if ~isempty(r.name)
                [directed, undirected] = ndi.v2.relationNames();
                known = [directed, undirected];
                for k = 1:numel(r.name)
                    if ~isempty(known) && ~any(cellfun(@(x) ndi.v2.matchTerm(x, r.name{k}), known))
                        error('ndi:subject:search:unknownRelation', 'No relation is called ''%s''. Relations: %s.', ...
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
                these = ndi.subject.subjectsOf(container, spec.filters(k), spec);
                ids = narrow(ids, these);
                if isempty(ids), ids = {}; return; end
            end
            for k = 1:numel(spec.relations)
                these = ndi.subject.relatedIds(container, spec.relations(k), spec);
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
                ids = ndi.subject.subjectsOf(container, g, spec);
                if isempty(ids), return; end
                k = f; k.filt.tolerant = spec.tolerant;
                L = ndi.subject.statementLinks(container, ids, k, spec.inherited, ...
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
                via = ndi.subject.instanceIds(container, filt, spec);
                if iscell(via), ids = via; return; end
            end
            if info.structural == 0
                ndi.subject.noSuchStatement(container, f, spec.strict);   % errors unless each part exists
                ids = {};
                return;
            elseif isempty(docs) && spec.strict && info.timed && info.beforeTime > 0
                warning('ndi:subject:search:noSuchTime', '%s', ...
                    noTimeMessage(f.kind, f.filt, info.time, containerWord(container)));
            elseif isempty(docs) && spec.strict
                warning('ndi:subject:search:noSuchValue', '%s', ...
                    noValueMessage(f, info.values, containerWord(container)));
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
                ids = unique([ids, ndi.subject.contextIds(container, docs, spec.tolerant)], 'stable');
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
            T = ndi.subject.targetIds(container, r.target, spec);     % [] = any
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
                    docs = ndi.subject.relationDocs(container, 'directed_relation', r.name, theirs, T);
                    docs = ndi.subject.timed(container, docs, r, spec);
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
                docs = ndi.subject.relationDocs(container, 'undirected_relation', r.name, 'entity_id', T);
                docs = ndi.subject.timed(container, docs, r, spec);
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
                warning('ndi:subject:search:noSuchTime', '%s', ...
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
            % the caller then reports the property as unknown.
            ids = [];
            v = cellstr(filt.variable);
            if ~isscalar(v), return; end
            type = lower(v{1});
            types = ndi.v2.entityTypesFor(type);
            if ~isscalar(types) || ~strcmp(types{1}, type), return; end
            targets = container.database_search(ndi.v2.isaQuery(type));
            if isempty(targets), return; end
            if isfield(filt, 'value') && ~isempty(filt.value)
                keep = cellfun(@(d) entityMatches(ndi.v2.props(d), type, filt.value), targets);
                targets = targets(keep);
            end
            if isempty(targets)
                if spec.strict
                    warning('ndi:subject:search:noSuchValue', 'No %s in this %s is called %s.', ...
                        type, containerWord(container), strjoin(cellstr(filt.value), ' or '));
                end
                ids = {};
                return;
            end
            tid = cellfun(@(d) d.document_properties.base.id, targets, 'UniformOutput', false);
            r = struct('kind', 'directed_relation', 'name', {{'instance_of'}}, 'side', 'parent', ...
                'target', struct('ids', {reshape(tid, 1, [])}), 'time', struct());
            ids = ndi.subject.relatedIds(container, r, spec);
        end

        function T = targetIds(container, target, spec)
            % TARGETIDS - the ids a relation's other end may be: [] for any;
            % an ndi.entity (or several, or a cell of them); a document id; or
            % a cell describing subjects, searched with ndi.subject.search
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
                s = ndi.subject.search(container, target{:});
                T = cellfun(@(x) x.document_id, s, 'UniformOutput', false);
            else
                error('ndi:subject:search:relationTarget', ...
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

        function noSuchStatement(container, f, strict)
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
                        if ~isempty(container.database_search(ndi.v2.isaQuery(t{1}) & ...
                                ndi.query('', 'isa', 'entity', '')))
                            names{end+1} = t{1}; %#ok<AGROW>
                        end
                    end
                    props = unique([names, {'id', 'local_identifier', 'name', 'type'}]);
                    [~, o] = sort(lower(props));
                    props = props(o);
                    msg = sprintf('No subject in this %s has a property %s.', where, quoted(pats));
                    msg = [msg didYouMean(pats, props)];
                    error('ndi:subject:search:unknownVariable', '%s\nProperties in this %s: %s', ...
                        msg, where, strjoin(props, ', '));
                end
                error('ndi:subject:search:noSuchStatement', 'No %s in this %s has %s %s.', ...
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
                    error('ndi:subject:statements:args', 'Expected a kind or an option name at argument %d.', k + 1);
                end
                a = char(a);
                la = lower(a);
                if any(strcmp(la, short))
                    f = struct();
                    if k < numel(args) && iscell(args{k + 1})
                        f = ndi.subject.statementFilter(la, args{k + 1});
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
                    error('ndi:subject:statements:args', ...
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

        function L = statementLinks(container, ids, kinds, inherited, context)
            % STATEMENTLINKS - (internal) which statements hold of the subjects IDS
            %
            % L has fields about, doc, via (cell arrays, one entry per
            % subject-statement pair). The subjects' groups (member_of, up)
            % and wholes (part_of, sample_of, aliquot_of, passage_of, up) are
            % walked together, one search per step; then one statement search
            % per kind for every 200 subjects reached. A statement on a group
            % holds when it is distributive; one on a whole when it is an
            % assertion; on both, both. CONTEXT: then the containers of
            % every subject reached (contextLinks).
            if nargin < 5, context = false; end
            described = arrayfun(@(k) isfield(k.filt, 'during_statements'), kinds);
            if any(described)
                L = struct('about', {{}}, 'doc', {{}}, 'via', {{}});
                if any(~described)
                    L = ndi.subject.statementLinks(container, ids, kinds(~described), inherited, context);
                end
                for k = find(described)
                    kk = kinds(k);
                    inner = kk.filt.during_statements;
                    kk.filt = rmfield(kk.filt, 'during_statements');
                    Lk = ndi.subject.statementLinks(container, ids, kk, inherited, context);
                    tolerant = isfield(kk.filt, 'tolerant') && kk.filt.tolerant;
                    for i = 1:numel(inner), inner(i).filt.tolerant = tolerant; end
                    Lk = ndi.subject.duringLinks(container, Lk, inner, inherited, context, tolerant);
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
            ids = unique(cellstr(ids), 'stable');
            lineage = {'part_of', 'sample_of', 'aliquot_of', 'passage_of'};
            % states: start, at, hasMember, hasLineage, path
            S = struct('start', ids, 'at', ids, 'm', false, 'l', false, 'path', {''});
            all_ = S;
            frontier = S;
            depth = 0;
            while inherited && ~isempty(frontier) && depth < 16
                depth = depth + 1;
                at = unique({frontier.at}, 'stable');
                next = struct('start', {}, 'at', {}, 'm', {}, 'l', {}, 'path', {});
                for r = [{'member_of'}, lineage]
                    step = r{1};
                    E = ndi.entity.edges(container, at(:), step, 'child_id', 'parent_id');
                    if height(E) == 0, continue; end
                    for f = 1:numel(frontier)
                        hit = find(strcmp(E.from, frontier(f).at));
                        for h = reshape(hit, 1, [])
                            p = step;
                            if ~isempty(frontier(f).path), p = [frontier(f).path ' > ' step]; end
                            next(end+1) = struct('start', frontier(f).start, 'at', E.to{h}, ...
                                'm', frontier(f).m || strcmp(step, 'member_of'), ...
                                'l', frontier(f).l || ~strcmp(step, 'member_of'), 'path', p); %#ok<AGROW>
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
            reached = unique({all_.at}, 'stable');
            L = struct('about', {{}}, 'doc', {{}}, 'via', {{}});
            seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            for k = 1:numel(kinds)
                f = kinds(k).filt;
                f.subject = reached;
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
                        if (st.m && ~distributive) || (st.l && ~isAssertion), continue; end
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
                L = ndi.subject.contextLinks(container, all_, kinds, L, seen);
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
                warning('ndi:subject:context:undecided', ['%d stay(s) in a container had no ' ...
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
            Li = ndi.subject.statementLinks(container, abouts, inner, inherited, context);
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

end % classdef ndi.subject

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
    inner = ndi.subject.explainNested(target, [indent '    ']);
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

function m = noValueMessage(f, values, where)
% the warning when a variable is there and none of the values is
vals = f.filt.value;
if ~iscell(vals), vals = {vals}; end
shown = values(1:min(end, 30));
more = '';
if numel(values) > 30, more = sprintf(' (and %d more)', numel(values) - 30); end
pats = vals(cellfun(@ischar, vals));
if strcmp(f.kind, 'assertion') && isfield(f.filt, 'variable') && ischar(f.filt.variable)
    var = f.filt.variable;
    m = sprintf('No subject in this %s has %s %s.', where, var, quoted(pats));
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
