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
    %   fromDocument, search - (static) make statements
    %
    % See also ndi.subject, ndi.data_type, ndi.interaction.

    properties (SetAccess = protected, GetAccess = public, Hidden)
        statement_document_ = []   % the ndi.document this statement reads
        container_ = []            % the ndi.session or ndi.dataset it was read from
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
