classdef statement
    % ndi.statement - something stated about a subject
    %
    % A V2 dataset is a set of statements about subjects: a worm's speed
    % (calculated), a plate's temperature (manipulated), a recording
    % (observed), a patch's strain (asserted). An ndi.statement is a read-only
    % view of one statement document, with the session or dataset it was
    % read from. It comes back as the right child:
    %
    %   ndi.statement
    %   |-- ndi.assertion        (species, strain, exclusion: no time or method)
    %   `-- ndi.interaction      (time, method, instrument)
    %       |-- ndi.observation
    %       |-- ndi.manipulation  (formulation, for a dose)
    %       `-- ndi.calculation   (inputs, software)
    %
    % READ THROUGH THE DATASET. A statement's software, formulation,
    % strain and instruments are stored with the dataset, and an
    % ndi.session searches only its own documents, so a statement read
    % through a session cannot reach them (software() and formulation()
    % come back empty). Read through the ndi.dataset, which reaches every
    % document; find things in a session first if that is quicker, then
    % re-read them through the dataset with fromDocument:
    %
    %   ds = ndi.dataset.dir(datasetPath);
    %   w = ndi.subject.search(ds, 'LocalIdentifier', 'concentration_worm0012');
    %   st = w{1}.statements('Variable', 'midpoint speed');
    %   v = st{1}.value();          % an ndi.data_type
    %   speed = double(v);          % metres per second, by video frame
    %   v.axes()                    % what each dimension indexes
    %
    % ndi.statement Methods:
    %   kind, document, document_properties, document_id
    %   subject        - the ndi.subject the statement is about
    %   variable       - the term; variable_name, its name
    %   value          - an ndi.data_type (decoded from its body when stored there)
    %   raw_value      - the inline value exactly as stored
    %   composite      - the value's composite class, e.g. 'velocity'
    %   axes           - table of the value's keys
    %   conditions     - table of the conditions it holds under
    %   notes          - text
    %   bodies         - the data-body documents holding the value
    %   about, via     - the subject it was asked for, and how it holds of it
    %   summary        - a table, one row per statement (ndi.summary for a cell)
    %   fromDocument, search - (static) make statements
    %
    % See also ndi.subject, ndi.data_type, ndi.interaction.

    properties (SetAccess = protected, GetAccess = public, Hidden)
        statement_document_ = []   % the ndi.document this statement reads
        container_ = []            % the ndi.session or ndi.dataset it was read from
        about_ = ''                % the subject it was asked for (ndi.subject/statements)
        via_ = ''                  % how it holds of that subject ('own', 'member_of', ...)
    end

    methods
        function obj = statement(container, doc)
            % STATEMENT - a statement for DOC, read from CONTAINER
            %
            % Use ndi.statement.fromDocument, which returns the right child.
            if nargin == 0
                return;
            end
            obj.container_ = container;
            obj.statement_document_ = doc;
        end

        function id = about(obj)
            % ABOUT - the document id of the subject this statement was asked for
            %
            % A statement read through ndi.subject/statements is about the
            % subject it was asked for, which may not be its own subject (a
            % cohort's strain, read for one of its worms). '' when the
            % statement was not read for a subject; its own subject's id is
            % then what it is about (see VIA).
            id = obj.about_;
            if isempty(id)
                ids = ndi.v2.edgeIds(obj.document_properties(), 'subject_id');
                if ~isempty(ids), id = ids{1}; end
            end
        end

        function v = via(obj)
            % VIA - how the statement holds of the subject it was asked for
            %
            % 'own' (stated about it), 'member_of' (stated about a group it
            % belongs to, distributively), 'part_of', 'sample_of', ... (an
            % assertion about a whole it is part or a sample of), or a path
            % such as 'member_of > part_of'.
            v = obj.via_;
            if isempty(v), v = 'own'; end
        end

        function T = summary(obj)
            % SUMMARY - one table row per statement
            %
            % T = SUMMARY(S) for a statement or an array of one class; for a
            % cell array of statements of any kind use ndi.summary. Columns:
            %   subject     the subject it is about (see ABOUT)
            %   kind        assertion, observation, manipulation, calculation
            %   class       the document class, e.g. 'temperature_manipulation'
            %   variable, variable_node, method, method_node, value,
            %   value_node  each term's name and its ontology node ('' when it
            %               has none yet, or the value is not a term)
            %   unit
            %   start, end  its time, the first of several references, shown
            %               in the zone it was recorded in when every row
            %               shares one (else UTC); NaT when it has none or it
            %               cannot be resolved
            %   timezone    the zone each time was recorded in
            %   stated_on   the subject it was stated about
            %   via         how it holds of SUBJECT (see VIA)
            %   id          the statement document's id
            T = ndi.statement.summaryOf(num2cell(obj));
        end

        function obj = withContext(obj, aboutId, via)
            % WITHCONTEXT - (internal) the same statement, read for subject ABOUTID by VIA
            obj.about_ = char(aboutId);
            obj.via_ = char(via);
        end

        function d = document(obj)
            % DOCUMENT - the statement's ndi.document
            d = obj.statement_document_;
        end

        function p = document_properties(obj)
            % DOCUMENT_PROPERTIES - the statement document's properties (a struct)
            p = ndi.v2.props(obj.statement_document_);
        end

        function id = document_id(obj)
            % DOCUMENT_ID - the statement document's base.id
            p = obj.document_properties();
            id = char(p.base.id);
        end

        function k = kind(obj)
            % KIND - the statement's document class, e.g. 'velocity_calculation'
            p = obj.document_properties();
            k = char(p.document_class.class_name);
        end

        function s = subject(obj)
            % SUBJECT - the ndi.subject this statement is about ([] when not found)
            s = [];
            ids = ndi.v2.edgeIds(obj.document_properties(), 'subject_id');
            if isempty(ids), return; end
            d = ndi.v2.getDocument(obj.container_, ids{1});
            if ~isempty(d)
                s = ndi.subject.fromDocument(obj.container_, d);
            end
        end

        function t = variable(obj)
            % VARIABLE - the statement's variable, a term ({node, name})
            t = ndi.v2.blockOf(obj.document_properties(), 'subject_statement', 'variable', []);
        end

        function n = variable_name(obj)
            % VARIABLE_NAME - the variable's name (its node when it has no name)
            n = ndi.v2.termName(obj.variable());
        end

        function c = composite(obj)
            % COMPOSITE - the class that holds the value, e.g. 'velocity', 'term'
            %
            % The class in the statement's chain whose own superclass is
            % data_type ('' when there is none).
            c = '';
            p = obj.document_properties();
            chain = ndi.v2.classChain(p);
            for i = 1:numel(chain)
                if any(strcmp(ndi.v2.directParents(chain{i}), 'data_type'))
                    c = chain{i};
                    return;
                end
            end
        end

        function v = raw_value(obj)
            % RAW_VALUE - the inline value exactly as stored ([] when in a body)
            v = [];
            c = obj.composite();
            if ~isempty(c)
                v = ndi.v2.blockOf(obj.document_properties(), c, 'value', []);
            end
        end

        function v = value(obj)
            % VALUE - the statement's value, an ndi.data_type
            %
            % Inline, or read from the statement's data body: a sampled body
            % is decoded into an array (its datum type, byte order and keys);
            % an opaque body (a video, an image file) gives its file paths.
            p = obj.document_properties();
            c = obj.composite();
            dt = char(ndi.v2.blockOf(p, 'data_type', 'datum_type', ''));
            ids = ndi.v2.edgeIds(p, 'value_id');
            if isempty(c) && ~isempty(ids)
                % the value is a document of its own (a shared item, a model fit)
                d = ndi.v2.getDocument(obj.container_, ids{1});
                if isempty(d)
                    error('ndi:statement:noValue', 'Statement %s names value %s, which is not in this %s.', ...
                        obj.document_id(), ids{1}, class(obj.container_));
                end
                q = ndi.v2.props(d);
                k = char(q.document_class.class_name);
                v = ndi.data_type(k, ndi.v2.blockOf(q, k, 'value', []), ...
                    'Keys', ndi.v2.blockOf(q, 'data', 'keys', []));
                return;
            end
            if ~logical(firstOr(ndi.v2.blockOf(p, 'data_type', 'data_body', false), false))
                v = ndi.data_type(c, obj.raw_value(), 'Keys', ndi.v2.blockOf(p, 'data', 'keys', []), ...
                    'DatumType', dt);
                return;
            end
            b = obj.bodies();
            if isempty(b)
                error('ndi:statement:noBody', ['Statement %s keeps its value in a data body, ' ...
                    'and no body pointing at it was found in this %s.'], obj.document_id(), ...
                    class(obj.container_));
            end
            bp = ndi.v2.props(b{1});
            % the keys are the statement's; a body that states its own is the fallback
            keys = ndi.v2.blockOf(p, 'data', 'keys', []);
            if isempty(keys), keys = ndi.v2.blockOf(bp, 'data', 'keys', []); end
            if any(strcmp(ndi.v2.classChain(bp), 'sampled_body'))
                vals = ndi.v2.readBody(obj.container_, b{1}, dt, keys);
                v = ndi.data_type(c, obj.raw_value(), 'Data', vals, 'Keys', keys, 'DatumType', dt);
            else
                files = {};
                for i = 1:numel(b)
                    q = ndi.v2.props(b{i});
                    fi = [];
                    if isfield(q, 'files') && isfield(q.files, 'file_info'), fi = q.files.file_info; end
                    for j = 1:numel(fi)
                        [tf, f] = obj.container_.database_existbinarydoc(char(q.base.id), char(fi(j).name));
                        if tf, files{end+1} = f; end %#ok<AGROW>
                    end
                end
                v = ndi.data_type(c, obj.raw_value(), 'Files', files, 'Keys', keys, 'DatumType', dt);
            end
        end

        function b = bodies(obj)
            % BODIES - the data-body documents holding this statement's value (a cell array)
            b = obj.container_.database_search(ndi.query('', 'isa', 'data_body', '') & ...
                ndi.query('', 'depends_on', 'owner_id', obj.document_id()));
        end

        function T = axes(obj)
            % AXES - table of the value's keys: variable, unit, n, coordinates
            T = ndi.v2.axesTable(ndi.v2.blockOf(obj.document_properties(), 'data', 'keys', []));
        end

        function T = conditions(obj)
            % CONDITIONS - table of the conditions the statement holds under
            %
            % One row per condition: variable, value (a number in `unit`, a
            % count, or a term's name), unit, source_value, source_unit.
            c = ndi.v2.blockOf(obj.document_properties(), 'subject_statement', 'conditions', []);
            c = ndi.v2.entries(c);
            variable = strings(0, 1); value = cell(0, 1); unit = strings(0, 1);
            source_value = cell(0, 1); source_unit = strings(0, 1);
            for i = 1:numel(c)
                x = c{i};
                variable(end+1, 1) = string(ndi.v2.termName(fieldOr(x, 'variable', ''))); %#ok<AGROW>
                unit(end+1, 1) = string(ndi.v2.termName(fieldOr(x, 'unit', ''))); %#ok<AGROW>
                source_unit(end+1, 1) = string(fieldOr(x, 'source_unit', '')); %#ok<AGROW>
                if ~isempty(fieldOr(x, 'term', []))
                    value{end+1, 1} = ndi.v2.termName(fieldOr(fieldOr(x, 'term', []), 'value', fieldOr(x, 'term', []))); %#ok<AGROW>
                    source_value{end+1, 1} = []; %#ok<AGROW>
                elseif ~isempty(fieldOr(x, 'count', []))
                    value{end+1, 1} = double(fieldOr(fieldOr(x, 'count', []), 'value', NaN)); %#ok<AGROW>
                    source_value{end+1, 1} = []; %#ok<AGROW>
                else
                    % a quantity: {value: {value, source_value}}
                    q = fieldOr(fieldOr(x, 'quantity', []), 'value', []);
                    value{end+1, 1} = double(fieldOr(q, 'value', NaN)); %#ok<AGROW>
                    source_value{end+1, 1} = fieldOr(q, 'source_value', []); %#ok<AGROW>
                end
            end
            T = table(variable, value, unit, source_value, source_unit);
        end

        function tf = distributive(obj)
            % DISTRIBUTIVE - true when the statement, made about a group,
            % holds of each of the group's members (subject_statement.distributive)
            d = ndi.v2.blockOf(obj.document_properties(), 'subject_statement', 'distributive', false);
            tf = ~isempty(d) && logical(d(1));
        end

        function n = notes(obj)
            % NOTES - the statement's notes ('' when none)
            n = char(ndi.v2.blockOf(obj.document_properties(), 'subject_interaction', 'notes', ''));
        end
    end

    methods (Static)
        function T = summaryOf(statements)
            % SUMMARYOF - the summary table of a cell array of statements (see SUMMARY)
            n = numel(statements);
            subject = strings(n, 1); kind = strings(n, 1); class = strings(n, 1);
            variable = strings(n, 1); method = strings(n, 1); value = strings(n, 1);
            variable_node = strings(n, 1); method_node = strings(n, 1); value_node = strings(n, 1);
            unit = strings(n, 1); stated_on = strings(n, 1); via = strings(n, 1); id = strings(n, 1);
            timezone = strings(n, 1);
            start = NaT(n, 1, 'TimeZone', 'UTC'); stop = NaT(n, 1, 'TimeZone', 'UTC');
            names = {'subject', 'kind', 'class', 'variable', 'variable_node', 'method', 'method_node', ...
                'value', 'value_node', 'unit', 'start', 'end', 'timezone', 'stated_on', 'via', 'id'};
            if n == 0
                T = table(subject, kind, class, variable, variable_node, method, method_node, value, ...
                    value_node, unit, start, stop, timezone, stated_on, via, id, 'VariableNames', names);
                return;
            end
            container = statements{1}.container_;
            cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            refs = cell(n, 1); own = cell(n, 1);
            for i = 1:n
                st = statements{i};
                p = st.document_properties();
                chain = ndi.v2.classChain(p);
                kinds = {'subject_assertion', 'subject_observation', 'subject_manipulation', 'subject_calculation'};
                k = find(ismember(kinds, chain), 1);
                if ~isempty(k), kind(i) = string(extractAfter(kinds{k}, 'subject_')); else, kind(i) = "statement"; end
                class(i) = string(p.document_class.class_name);
                vr = ndi.v2.blockOf(p, 'subject_statement', 'variable', '');
                variable(i) = string(ndi.v2.termName(vr)); variable_node(i) = string(nodeOf(vr));
                mr = ndi.v2.blockOf(p, 'subject_interaction', 'method', '');
                method(i) = string(ndi.v2.termName(mr)); method_node(i) = string(nodeOf(mr));
                [vk, vv, vt, vu] = ndi.v2.statementValue(p);
                if strcmp(vk, 'term'), value_node(i) = string(nodeOf(vv)); end
                if strcmp(vk, 'none') && logical(firstOr(ndi.v2.blockOf(p, 'data_type', 'data_body', false), false))
                    vt = '(data body)';
                end
                value(i) = string(vt); unit(i) = string(vu);
                o = ndi.v2.edgeIds(p, 'subject_id');
                if isempty(o), o = {''}; end
                own{i} = o{1};
                via(i) = string(st.via());
                id(i) = string(p.base.id);
                refs{i} = ndi.v2.edgeIds(p, 'time_reference_id');
            end
            allRefs = unique([refs{:}]);
            if ~isempty(allRefs)
                times = ndi.v2.timesOf(container, allRefs, cache);
                for i = 1:n
                    for r = 1:numel(refs{i})
                        if ~isKey(times, refs{i}{r}), continue; end
                        t = times(refs{i}{r});
                        if ~isnat(t.start)
                            start(i) = t.start; stop(i) = t.end;
                            timezone(i) = string(t.timezone);
                            break;
                        end
                    end
                end
            end
            aboutIds = cellfun(@(s) s.about(), statements, 'UniformOutput', false);
            ids = unique([reshape(aboutIds, 1, []), reshape(own, 1, [])]);
            ids = ids(~cellfun(@isempty, ids));
            names = containers.Map('KeyType', 'char', 'ValueType', 'char');
            if ~isempty(ids)
                ents = ndi.entity.fetchMany(container, ids);
                for e = 1:numel(ents), names(ents{e}.document_id) = char(ents{e}.name); end
            end
            nameOf = @(x) string(ifKey(names, x));
            for i = 1:n
                subject(i) = nameOf(aboutIds{i});
                stated_on(i) = nameOf(own{i});
            end
            zones = unique(timezone(timezone ~= ""));
            if isscalar(zones)
                try
                    start.TimeZone = char(zones); stop.TimeZone = char(zones);
                catch
                end
            end
            T = table(subject, kind, class, variable, variable_node, method, method_node, value, ...
                value_node, unit, start, stop, timezone, stated_on, via, id, 'VariableNames', names);
        end

        function obj = fromDocument(container, doc)
            % FROMDOCUMENT - the right statement object for a statement document
            %
            % OBJ = ndi.statement.fromDocument(CONTAINER, DOC): an
            % ndi.observation, ndi.manipulation, ndi.calculation or
            % ndi.assertion by the document's class chain (never a list of
            % leaf classes, so a new leaf needs no code), else an
            % ndi.statement. DOC may be an ndi.document or an id.
            if ischar(doc) || isstring(doc)
                d = ndi.v2.getDocument(container, char(doc));
                if isempty(d)
                    error('ndi:statement:notFound', 'No document %s in this %s.', char(doc), class(container));
                end
                doc = d;
            end
            chain = ndi.v2.classChain(ndi.v2.props(doc));
            if any(strcmp(chain, 'subject_observation'))
                obj = ndi.observation(container, doc);
            elseif any(strcmp(chain, 'subject_manipulation'))
                obj = ndi.manipulation(container, doc);
            elseif any(strcmp(chain, 'subject_calculation'))
                obj = ndi.calculation(container, doc);
            elseif any(strcmp(chain, 'subject_assertion'))
                obj = ndi.assertion(container, doc);
            else
                obj = ndi.statement(container, doc);
            end
        end

        function s = search(container, options)
            % SEARCH - the statements in a session or dataset
            %
            % S = ndi.statement.search(CONTAINER, ...) returns a cell array.
            % Filters:
            %   'Subject'   an ndi.subject (or a subject document id)
            %   'Variable'  the variable's name, e.g. 'midpoint speed'
            %   'Class'     'observation', 'manipulation', 'calculation',
            %               'assertion', 'interaction', or a document class
            %               (e.g. 'velocity_calculation')
            %   'Method'    the method's name, e.g. 'tracking by WormLab'
            arguments
                container
                options.Subject = []
                options.Variable (1,:) char = ''
                options.Class (1,:) char = ''
                options.Method (1,:) char = ''
            end
            cls = 'subject_statement';
            short = {'observation', 'manipulation', 'calculation', 'assertion', 'interaction'};
            if any(strcmp(options.Class, short))
                cls = ['subject_' options.Class];
            elseif ~isempty(options.Class)
                cls = options.Class;
            end
            q = ndi.query('', 'isa', cls, '');
            if ~isempty(options.Subject)
                sid = options.Subject;
                if isa(sid, 'ndi.subject'), sid = sid.id(); end
                q = q & ndi.query('', 'depends_on', 'subject_id', char(sid));
            end
            if ~isempty(options.Variable)
                q = q & ndi.query('subject_statement.variable.name', 'exact_string', options.Variable, '');
            end
            if ~isempty(options.Method)
                q = q & ndi.query('subject_interaction.method.name', 'exact_string', options.Method, '');
            end
            docs = container.database_search(q);
            s = cell(1, numel(docs));
            for i = 1:numel(docs)
                s{i} = ndi.statement.fromDocument(container, docs{i});
            end
        end
    end
end

function v = firstOr(x, default)
if isempty(x), v = default; else, v = x(1); end
end

function v = fieldOr(s, name, default)
v = default;
if isstruct(s) && isfield(s, name) && ~isempty(s(1).(name))
    v = s(1).(name);
end
end

function v = ifKey(m, k)
v = '';
if ~isempty(k) && isKey(m, k), v = m(k); end
end

function n = nodeOf(t)
% a term's node ('' when none)
n = '';
if iscell(t) && ~isempty(t), t = t{1}; end
if isstruct(t) && ~isempty(t) && isfield(t, 'node') && ~isempty(t(1).node), n = char(t(1).node); end
end
