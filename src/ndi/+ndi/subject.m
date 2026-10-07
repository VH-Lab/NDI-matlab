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
        %%% ndi.subject.fromDocument / ndi.subject.find. They return empty on
        %%% a subject that was not (no container to search).

        function t = get.type(ndi_subject_obj)
            % TYPE - the subject's coarse kind: 'organism', 'group', 'culture', 'material', ...
            %   ('' for a subject with no V2 document)
            t = '';
            if isempty(ndi_subject_obj.entity_document_), return; end
            t = ndi.v2.termName(ndi.v2.blockOf(ndi_subject_obj.document_properties(), 'subject', 'type', ''));
        end % get.type()

        function s = statements(ndi_subject_obj, varargin)
            % STATEMENTS - the statements about this subject
            %
            % S = STATEMENTS(NDI_SUBJECT_OBJ, ...) returns a cell array of
            % ndi.statement objects (each the right child: ndi.observation,
            % ndi.manipulation, ndi.calculation, ndi.assertion). Takes the
            % filters of ndi.statement.find: 'Variable', 'Class', 'Method'.
            %
            % 'Inherited', true also returns what holds of this subject
            % because it was stated on a group the subject is a member of:
            % the groups are found by following member_of upward (groups of
            % groups too), and of each group's statements only those marked
            % `distributive` are kept -- the schema's flag for "stated on the
            % group, holds of each member" (did-schema #84). Default false:
            % only statements whose subject is this one. An inherited
            % statement's subject() is the group it was stated on.
            % Relations other than member_of (contained_in, part_of) are not
            % followed: they do not make a statement hold of the subject.
            s = {};
            if isempty(ndi_subject_obj.container_), return; end
            [inherited, rest] = ndi.subject.takeOption(varargin, 'Inherited', false);
            s = ndi.statement.find(ndi_subject_obj.container_, 'Subject', ndi_subject_obj, rest{:});
            if ~inherited
                return;
            end
            seen = {ndi_subject_obj.document_id};
            queue = ndi_subject_obj.memberOf();
            while ~isempty(queue)
                g = queue{1};
                queue(1) = [];
                if ~isa(g, 'ndi.subject') || any(strcmp(seen, g.document_id))
                    continue;
                end
                seen{end+1} = g.document_id; %#ok<AGROW>
                gs = ndi.statement.find(ndi_subject_obj.container_, 'Subject', g, rest{:});
                for k = 1:numel(gs)
                    if gs{k}.distributive()
                        s{end+1} = gs{k}; %#ok<AGROW>
                    end
                end
                queue = [queue, g.memberOf()]; %#ok<AGROW>
            end
        end % statements()

        function T = assertions(ndi_subject_obj, varargin)
            % ASSERTIONS - table of what is asserted about the subject
            %
            % T = ASSERTIONS(NDI_SUBJECT_OBJ) has columns variable, value,
            % node and stated_on (the local identifier of the subject it was
            % stated on), e.g. species 'Caenorhabditis elegans', strain 'N2',
            % inclusion in analysis 'excluded'. 'Inherited', true adds what
            % is stated distributively on the subject's groups (see
            % STATEMENTS): a worm's species and strain, stated on its cohort.
            [inherited, ~] = ndi.subject.takeOption(varargin, 'Inherited', false);
            variable = strings(0, 1); value = strings(0, 1); node = strings(0, 1);
            stated_on = strings(0, 1);
            a = ndi_subject_obj.statements('Class', 'assertion', 'Inherited', inherited);
            for i = 1:numel(a)
                v = a{i}.raw_value();
                variable(end+1, 1) = string(a{i}.variable_name()); %#ok<AGROW>
                value(end+1, 1) = string(ndi.v2.termName(v)); %#ok<AGROW>
                nd = '';
                if isstruct(v) && isfield(v, 'node'), nd = char(v(1).node); end
                node(end+1, 1) = string(nd); %#ok<AGROW>
                on = ndi_subject_obj.local_identifier;
                if ~strcmp(statedOnId(a{i}), ndi_subject_obj.document_id)
                    sub = a{i}.subject();
                    if ~isempty(sub), on = sub.local_identifier; else, on = statedOnId(a{i}); end
                end
                stated_on(end+1, 1) = string(on); %#ok<AGROW>
            end
            T = table(variable, value, node, stated_on);
        end % assertions()

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

        function s = find(container, varargin)
            % FIND - the subjects in a session or dataset, by what is true of them
            %
            % S = ndi.subject.find(CONTAINER, PROPERTY, VALUE, ...) returns a
            % cell array of ndi.subject: those for which every pair holds.
            % With no pairs, every subject (instruments included,
            % V2_Object_Layer.md, Q2).
            %
            %   ndi.subject.find(ds, 'type', 'organism', ...
            %       'species', 'Caenorhabditis elegans', 'strain', {'N2', 'CB*'})
            %   ndi.subject.find(ds, 'manipulation', {'method', 'heating'})
            %   ndi.subject.find(ds, 'manipulation', ...
            %       {'variable', 'NGM agar', 'value', '>=0.02'})
            %
            % A PROPERTY is one of:
            %   'type', 'name', 'local_identifier'   the subject's own fields
            %   'statement', 'assertion', 'interaction', 'observation',
            %   'manipulation', 'calculation'        a statement of that kind
            %       (and its children: an interaction is an observation,
            %       manipulation or calculation) about the subject; VALUE is a
            %       cell of filters, all on the SAME statement:
            %         'variable', 'method' (not for an assertion), 'value',
            %         'formulation' (a dose's: its name or type)
            %       Giving the key twice asks for two statements, perhaps
            %       different ones.
            %   'inherited'   true (default) or false, below
            %   anything else: an asserted variable -- 'strain', 'N2' is
            %       'assertion', {'variable', 'strain', 'value', 'N2'}
            % Property names ignore case.
            %
            % A pattern matches a term's name ignoring case or its node
            % exactly ('NCBITaxon:6239'); a cell array is any of them; '*' is
            % a wildcard, '\*' a literal star. A value is compared by its kind:
            % numbers and dates take '>', '>=', '<', '<=' ('>=0.02',
            % '>2023-11-16'); see ndi.v2.findStatements. Different pairs must
            % all hold.
            %
            % 'inherited' (default true): a statement about a group holds of
            % its members when it is marked distributive, all the way down
            % member_of -- so it does not matter whether a strain was stated on
            % a worm or on its cohort. contained_in and part_of are not
            % followed (a plate's statements are not its worms'). false: only
            % what was stated about the subject itself. The group a statement
            % was about always matches too; 'type', 'organism' leaves it out.
            %
            % An asserted variable no assertion uses, or a kind / variable /
            % method no statement has, is an error; values none of which
            % match is a warning naming the values there are ("none" may be
            % the answer).
            [own, filters, inherited] = ndi.subject.findPairs(varargin);
            ids = [];                       % [] = not narrowed yet; {} = nothing
            for k = 1:numel(filters)
                these = ndi.subject.subjectsOf(container, filters(k), inherited);
                if isempty(ids) && ~iscell(ids)
                    ids = these;
                else
                    ids = ids(ismember(ids, these));
                end
                if isempty(ids), s = {}; return; end
            end
            if iscell(ids)
                s = ndi.entity.fetchMany(container, ids);
            else
                q = ndi.query('', 'isa', 'subject', '');
                lid = own(strcmp(own(:, 1), 'local_identifier'), 2);
                if isscalar(lid) && ischar(lid{1}) && ~ndi.v2.hasWildcard(lid{1})
                    q = q & ndi.query('subject.local_identifier', 'exact_string_anycase', ...
                        strrep(lid{1}, '\*', '*'), '');
                end
                docs = container.database_search(q);
                s = cellfun(@(d) ndi.subject.fromDocument(container, d), docs, 'UniformOutput', false);
            end
            s = reshape(s, 1, []);
            keep = cellfun(@(x) isa(x, 'ndi.subject'), s);
            for k = 1:size(own, 1)
                for i = find(keep)
                    x = s{i};
                    switch own{k, 1}
                        case 'type', v = x.type;
                        case 'name', v = x.name;
                        case 'local_identifier', v = x.local_identifier;
                    end
                    keep(i) = ndi.v2.matchTerm(v, own{k, 2});
                end
            end
            s = reshape(s(keep), 1, []);
        end % find()

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
        function [own, filters, inherited] = findPairs(args)
            % FINDPAIRS - find's PROPERTY, VALUE pairs: the subject's own
            % fields, statement filters, and the 'inherited' switch
            if mod(numel(args), 2)
                error('ndi:subject:find:pairs', 'ndi.subject.find takes PROPERTY, VALUE pairs.');
            end
            kinds = {'statement', 'assertion', 'interaction', 'observation', 'manipulation', 'calculation'};
            own = cell(0, 2); inherited = true;
            filters = struct('kind', {}, 'filt', {}, 'label', {});
            for k = 1:2:numel(args)
                p = args{k};
                if ~(ischar(p) || (isstring(p) && isscalar(p)))
                    error('ndi:subject:find:pairs', 'A property name must be text (argument %d).', k + 1);
                end
                p = char(p);
                v = args{k + 1};
                if isstring(v), v = cellstr(v); if isscalar(v), v = v{1}; end, end
                key = lower(strrep(p, '_', ''));
                if strcmp(key, 'inherited')
                    inherited = logical(v);
                elseif any(strcmp(key, {'type', 'name'}))
                    own(end+1, :) = {key, v}; %#ok<AGROW>
                elseif strcmp(key, 'localidentifier')
                    own(end+1, :) = {'local_identifier', v}; %#ok<AGROW>
                elseif any(strcmp(lower(p), kinds))
                    filters(end+1) = struct('kind', lower(p), ...
                        'filt', ndi.subject.statementFilter(lower(p), v), 'label', lower(p)); %#ok<AGROW>
                else
                    if ~iscell(v), v = {v}; end      % a cell is already "any of"
                    filters(end+1) = struct('kind', 'assertion', ...
                        'filt', struct('variable', p, 'value', {v}), 'label', p); %#ok<AGROW>
                end
            end
        end

        function filt = statementFilter(kind, c)
            % STATEMENTFILTER - {'variable', V, 'method', M, ...} as a struct
            if ~iscell(c) || mod(numel(c), 2)
                error('ndi:subject:find:statementFilter', ...
                    '''%s'' takes a cell of filters, e.g. {''variable'', ''NGM agar'', ''value'', ''>=0.02''}.', kind);
            end
            filt = struct();
            for k = 1:2:numel(c)
                n = lower(char(c{k}));
                if ~any(strcmp(n, {'variable', 'method', 'value', 'formulation'}))
                    error('ndi:subject:find:statementFilter', ...
                        'Unknown filter ''%s'' for ''%s'': variable, method, value, formulation.', c{k}, kind);
                end
                v = c{k + 1};
                if isstring(v), v = cellstr(v); if isscalar(v), v = v{1}; end, end
                filt.(n) = v;
            end
            if strcmp(kind, 'assertion') && isfield(filt, 'method')
                error('ndi:subject:find:assertionMethod', 'An assertion has no method.');
            end
        end

        function ids = subjectsOf(container, f, inherited)
            % SUBJECTSOF - ids of the subjects filter F holds of: the statements'
            % subjects, and (INHERITED) every member, all the way down
            % member_of, of a subject whose statement is distributive
            [docs, info] = ndi.v2.findStatements(container, f.kind, f.filt);
            if info.structural == 0
                ndi.subject.noSuchStatement(container, f);   % errors unless each part exists
                ids = {};
                return;
            elseif isempty(docs)
                shown = info.values(1:min(end, 30));
                more = '';
                if numel(info.values) > 30, more = sprintf(' (and %d more)', numel(info.values) - 30); end
                warning('ndi:subject:find:noSuchValue', 'No %s matches %s. Values there: %s%s.', ...
                    f.kind, describe(f.filt), strjoin(shown, ', '), more);
            end
            ids = {}; groups = {};
            for i = 1:numel(docs)
                p = ndi.v2.props(docs{i});
                sid = ndi.v2.edgeIds(p, 'subject_id');
                ids = [ids, sid]; %#ok<AGROW>
                d = ndi.v2.blockOf(p, 'subject_statement', 'distributive', false);
                if inherited && ~isempty(d) && (islogical(d) || isnumeric(d)) && logical(d(1))
                    groups = [groups, sid]; %#ok<AGROW>
                end
            end
            ids = unique(ids, 'stable');
            groups = unique(groups, 'stable');
            if isempty(groups), return; end
            G = ndi.entity.fetchMany(container, groups);
            G = G(cellfun(@(x) isa(x, 'ndi.subject'), G));
            if isempty(G), return; end
            m = descendants([G{:}], 'Relation', 'member_of');
            ids = unique([ids, cellfun(@(x) x.document_id, m, 'UniformOutput', false)], 'stable');
        end

        function noSuchStatement(container, f)
            % NOSUCHSTATEMENT - no statement matched F's kind, variable and
            % method together. When one of them matches nothing on its own,
            % that is an error (for an assertion's variable, naming the
            % variables there are); when each exists but never on one
            % statement, the answer is simply none.
            for part = {'variable', 'method'}
                if ~isfield(f.filt, part{1}), continue; end
                [~, info] = ndi.v2.findStatements(container, f.kind, struct(part{1}, {f.filt.(part{1})}));
                if info.structural > 0, continue; end
                if strcmp(f.kind, 'assertion') && strcmp(part{1}, 'variable')
                    docs = container.database_search(ndi.query('', 'isa', 'subject_assertion', ''));
                    names = unique(cellfun(@(d) ndi.v2.termName(ndi.v2.blockOf(ndi.v2.props(d), ...
                        'subject_statement', 'variable', '')), docs, 'UniformOutput', false));
                    error('ndi:subject:find:unknownVariable', ...
                        'No subject has an assertion about %s. Asserted here: %s.', ...
                        describe(struct('variable', {f.filt.variable})), strjoin(names, ', '));
                end
                error('ndi:subject:find:noSuchStatement', 'No %s here has %s.', f.kind, ...
                    describe(struct(part{1}, {f.filt.(part{1})})));
            end
        end
    end
end % classdef ndi.subject

function id = statedOnId(st)
% the document id the statement is about (its subject_id edge)
ids = ndi.v2.edgeIds(st.document_properties(), 'subject_id');
id = '';
if ~isempty(ids), id = ids{1}; end
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

function s = rmfieldIf(s, f)
if isfield(s, f), s = rmfield(s, f); end
end
