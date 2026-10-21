classdef etaShape
%ETASHAPE The did-schema #88 V_eta document shapes the second pass writes and
%   reads, in one place.
%
%   did-schema #88 (V_eta_entity_composition_plan.md, V_eta_method_plan.md,
%   V_eta_relation_inheritance_plan.md, all signed) changed four things every
%   second-pass assembler touches:
%
%     * ONE `entity` class with a bound `type` replaces `subject`, `strain`,
%       `product`, `software`, `session`, `dataset`, `epoch`, ... (sec. 4).
%     * A statement is its DIRECTION (`assertion`, `observation`,
%       `manipulation`, `calculation`) plus ONE value-kind MIXIN listed after
%       the direction's own chain in `document_class.superclasses` (sec. 1):
%       the 39 `<kind>_<direction>` join leaves are gone. The statement's
%       `variable` lives on the `statement` block (`subject_statement` before)
%       and it points at what it is about through `entity_id` (`subject_id`).
%     * `method {term, parameters}` replaces `method` + `method_parameters`;
%       `time_reference_id` (repeated) replaces `time_reference_1, _2, ...`;
%       a directed relation's ends are `child_id` / `parent_id`.
%     * `base.session_id` is the `session_id` edge (withSessionId decides
%       which, from the schema in use).
%
%   This class is pure struct assembly: no schema cache, no converter, no
%   database. Every minted body is tagged schema_version 'V_eta' and is
%   folded back through did2.convert.v1_to_v2 by its caller, where
%   ensureClassBlocks rewrites the superclass list from the loaded schema
%   (reading the value kind at the position this class writes it) and
%   validation runs. The superclass lists below are therefore the #88 chains
%   written out in the order the validator reads them -- the direction's own
%   ancestors, nearest first, then the kind and its ancestors -- so that the
%   kind sits at index numel(own)+1 (did2.schema.cache/documentValueKind).
%
%   The READERS accept both the #88 spelling and the pre-#88 one, so an
%   assembler reads pass-1 output from either DID-matlab line; the WRITERS
%   emit #88 only.
%
%   See also ndi.migrate.internal.withSessionId.

    methods (Static)

        % ================= writers =========================================

        function dc = docClass(className, kind)
            %DOCCLASS document_class for CLASSNAME with value kind KIND ('' none).
            if nargin < 2
                kind = '';
            end
            own = ndi.migrate.internal.etaShape.ancestors(className);
            names = own;
            if ~isempty(kind)
                extra = [{kind}, ndi.migrate.internal.etaShape.ancestors(kind)];
                for j = 1:numel(extra)
                    if ~any(strcmp(names, extra{j}))
                        names{end+1} = extra{j}; %#ok<AGROW>
                    end
                end
            end
            sc = struct('class_name', {}, 'class_version', {});
            for k = 1:numel(names)
                sc(end+1) = struct('class_name', names{k}, ...
                    'class_version', '1.0.0'); %#ok<AGROW>
            end
            dc = struct('class_name', className, 'class_version', '1.0.0', ...
                'superclasses', sc, 'schema_version', 'V_eta');
        end

        function names = ancestors(className)
            %ANCESTORS The #88 superclasses of CLASSNAME, nearest first.
            switch className
                case {'base'}
                    names = {};
                case {'entity', 'statement', 'relation', 'time_reference', ...
                        'data', 'method', 'acquisition_channels'}
                    names = {'base'};
                case {'assertion', 'interaction'}
                    names = {'statement', 'base'};
                case {'observation', 'manipulation', 'calculation'}
                    names = {'interaction', 'statement', 'base'};
                case {'directed_relation', 'undirected_relation'}
                    names = {'relation', 'base'};
                case {'relative_time_reference', 'absolute_time_reference'}
                    names = {'time_reference', 'base'};
                case {'value', 'data_body'}
                    names = {'data', 'base'};
                case {'sampled_body', 'opaque_body'}
                    names = {'data_body', 'data', 'base'};
                otherwise
                    % a value kind (term, text, time, frequency, dose, ...)
                    names = {'value', 'data', 'base'};
            end
        end

        function body = entity(type, fields, varargin)
            %ENTITY An `entity` of TYPE ('organism', 'tissue', 'strain', ...).
            %   FIELDS: name, local_identifier, description, global_identifier
            %   (cellstr). Options: Id, SessionId, Datestamp, TimeReferenceIds.
            opts = ndi.migrate.internal.etaShape.options(struct('Id', '', ...
                'SessionId', '', 'Datestamp', '', 'TimeReferenceIds', {{}}), varargin);
            if isempty(fields)
                fields = struct();
            end
            body = struct();
            body.document_class = ndi.migrate.internal.etaShape.docClass('entity');
            body.depends_on = ndi.migrate.internal.etaShape.noEdges();
            for k = 1:numel(opts.TimeReferenceIds)
                body = ndi.migrate.internal.etaShape.addEdge(body, ...
                    'time_reference_id', opts.TimeReferenceIds{k});
            end
            body.base = ndi.migrate.internal.etaShape.baseBlock(opts.Id, opts.Datestamp);
            ent = struct('type', struct('node', '', 'name', type));
            for n = {'name', 'local_identifier', 'description'}
                if isfield(fields, n{1}) && ~isempty(fields.(n{1}))
                    ent.(n{1}) = char(fields.(n{1}));
                end
            end
            if isfield(fields, 'global_identifier') && ~isempty(fields.global_identifier)
                g = fields.global_identifier;
                if ischar(g) || isstring(g)
                    g = cellstr(g);
                end
                g = g(~cellfun(@isempty, g));
                if ~isempty(g)
                    ent.global_identifier = reshape(g, 1, []);
                end
            end
            body.entity = ent;
            body = ndi.migrate.internal.withSessionId(body, opts.SessionId);
        end

        function body = statement(direction, kind, entityId, variable, value, varargin)
            %STATEMENT A statement: VARIABLE of ENTITYID has VALUE.
            %   DIRECTION is assertion | observation | manipulation |
            %   calculation; KIND its value kind ('term', 'text', 'time', ...);
            %   VALUE the kind block's `value` ([] to leave it out).
            %   OPTS: Id, SessionId, Datestamp, TimeReferenceIds (cellstr),
            %   InstrumentId, SoftwareId, MethodId, Method (a term),
            %   MethodParameters (struct array of parameter entries),
            %   Conditions (struct array), Notes, Edges (N x 2 cell).
            opts = ndi.migrate.internal.etaShape.options(struct('Id', '', ...
                'SessionId', '', 'Datestamp', '', 'TimeReferenceIds', {{}}, ...
                'InstrumentId', '', 'SoftwareId', '', 'MethodId', '', ...
                'Method', [], 'MethodParameters', [], 'Conditions', [], ...
                'Notes', '', 'Edges', {cell(0, 2)}), varargin);
            S = ndi.migrate.internal.etaShape;
            body = struct();
            body.document_class = S.docClass(direction, kind);
            body.depends_on = S.noEdges();
            body = S.addEdge(body, 'entity_id', entityId);
            for k = 1:numel(opts.TimeReferenceIds)
                body = S.addEdge(body, 'time_reference_id', opts.TimeReferenceIds{k});
            end
            entityId = char(entityId);
            if ~isempty(opts.InstrumentId)
                body = S.addEdge(body, 'instrument_id', opts.InstrumentId);
            end
            if ~isempty(opts.SoftwareId)
                body = S.addEdge(body, 'software_id', opts.SoftwareId);
            end
            if ~isempty(opts.MethodId)
                body = S.addEdge(body, 'method_id', opts.MethodId);
            end
            for k = 1:size(opts.Edges, 1)
                body = S.addEdge(body, opts.Edges{k, 1}, opts.Edges{k, 2});
            end
            body.base = S.baseBlock(opts.Id, opts.Datestamp);
            st = struct('variable', S.asTerm(variable));
            if ~isempty(opts.Conditions)
                st.conditions = opts.Conditions;
            end
            if ~isempty(opts.Notes)
                st.notes = opts.Notes;
            end
            body.statement = st;
            if ~strcmp(direction, 'assertion') && ...
                    (~isempty(opts.Method) || ~isempty(opts.MethodParameters))
                m = struct();
                if ~isempty(opts.Method)
                    m.term = S.asTerm(opts.Method);
                end
                if ~isempty(opts.MethodParameters)
                    m.parameters = opts.MethodParameters;
                end
                body.interaction = struct('method', m);
            end
            if ~isempty(kind) && ~isempty(value)
                body.(kind) = struct('value', value);
            end
            body = ndi.migrate.internal.withSessionId(body, opts.SessionId);
        end

        function body = relation(childId, parentId, relationTerm, varargin)
            %RELATION A directed_relation CHILDID <RELATIONTERM> PARENTID.
            %   OPTS: Id, SessionId, Datestamp, Sequence, EpochId,
            %   TimeReferenceIds, Method (a term).
            opts = ndi.migrate.internal.etaShape.options(struct('Id', '', ...
                'SessionId', '', 'Datestamp', '', 'Sequence', [], 'EpochId', '', ...
                'TimeReferenceIds', {{}}, 'Method', []), varargin);
            S = ndi.migrate.internal.etaShape;
            body = struct();
            body.document_class = S.docClass('directed_relation');
            body.depends_on = S.noEdges();
            body = S.addEdge(body, 'child_id', childId);
            body = S.addEdge(body, 'parent_id', parentId);
            for k = 1:numel(opts.TimeReferenceIds)
                body = S.addEdge(body, 'time_reference_id', opts.TimeReferenceIds{k});
            end
            if ~isempty(opts.EpochId)
                body = S.addEdge(body, 'epoch_id', opts.EpochId);
            end
            body.base = S.baseBlock(opts.Id, opts.Datestamp);
            blk = struct('relation', S.asTerm(relationTerm));
            if ~isempty(opts.Sequence)
                blk.sequence = opts.Sequence;
            end
            body.directed_relation = blk;
            if ~isempty(opts.Method)
                body.relation = struct('method', struct('term', S.asTerm(opts.Method)));
            end
            body = ndi.migrate.internal.withSessionId(body, opts.SessionId);
        end

        function body = relativeTimeReference(referentId, value, varargin)
            %RELATIVETIMEREFERENCE A relative_time_reference to REFERENTID.
            %   VALUE is the `value` struct {relation, clock, start, duration,
            %   end}; each time is {seconds, ...}.
            opts = ndi.migrate.internal.etaShape.options(struct('Id', '', ...
                'SessionId', '', 'Datestamp', ''), varargin);
            S = ndi.migrate.internal.etaShape;
            body = struct();
            body.document_class = S.docClass('relative_time_reference');
            body.depends_on = S.noEdges();
            body = S.addEdge(body, 'referent_id', referentId);
            body.base = S.baseBlock(opts.Id, opts.Datestamp);
            body.relative_time_reference = struct('value', value);
            body = ndi.migrate.internal.withSessionId(body, opts.SessionId);
        end

        function opts = options(defaults, args)
            %OPTIONS Name-value pairs ARGS over DEFAULTS (a later pair wins).
            %   Plain parsing rather than an arguments block, so the pure
            %   struct assembly also runs where name-value arguments blocks do
            %   not (an Octave check of the fast gate).
            opts = defaults;
            if mod(numel(args), 2) ~= 0
                error('ndi:migrate:etaShape:badOptions', ...
                    'Options must be name-value pairs.');
            end
            for k = 1:2:numel(args)
                name = char(args{k});
                if ~isfield(defaults, name)
                    error('ndi:migrate:etaShape:unknownOption', ...
                        'Unknown option "%s".', name);
                end
                opts.(name) = args{k + 1};
            end
        end

        function t = term(node, name)
            %TERM An ontology term {node, name}.
            t = struct('node', char(node), 'name', char(name));
        end

        function t = anatomicalLocationVariable()
            %ANATOMICALLOCATIONVARIABLE The variable of a site statement:
            %   NCIT:C13717 "Anatomic Site" (did-schema #88 term registry,
            %   row decided 2026-10-21). Older documents wrote the label
            %   'anatomical location' with an empty node; isVariable accepts both.
            t = struct('node', 'NCIT:C13717', 'name', 'Anatomic Site');
        end

        function t = anatomicalStructureVariable()
            %ANATOMICALSTRUCTUREVARIABLE The variable of a region part's kind
            %   assertion: UBERON:0000061 "anatomical structure" (did-schema #88
            %   term registry, row decided 2026-10-21). Older documents wrote
            %   the same label with an empty node.
            t = struct('node', 'UBERON:0000061', 'name', 'anatomical structure');
        end

        function tf = isVariable(s, which)
            %ISVARIABLE True when statement S's variable is WHICH
            %   ('anatomical location' or 'anatomical structure'): by node
            %   (compared case-insensitively, so 'ncit:c13717' matches), or by
            %   the registered label, or by the legacy label-only form.
            S = ndi.migrate.internal.etaShape;
            switch which
                case 'anatomical location'
                    want = S.anatomicalLocationVariable();
                case 'anatomical structure'
                    want = S.anatomicalStructureVariable();
                otherwise
                    error('NDI:migrate:etaShape:unknownVariable', ...
                        'No registered variable for "%s".', which);
            end
            v = S.variable(s);
            node = strtrim(char(v.node));
            name = strtrim(char(v.name));
            if ~isempty(node)
                tf = strcmpi(node, want.node);
            else
                tf = any(strcmpi(name, {want.name, which}));
            end
        end

        function t = asTerm(v)
            %ASTERM A term from a term struct or a bare name.
            if isstruct(v)
                t = struct('node', '', 'name', '');
                if isfield(v, 'node'); t.node = char(v.node); end
                if isfield(v, 'name'); t.name = char(v.name); end
            else
                t = struct('node', '', 'name', char(v));
            end
        end

        function e = noEdges()
            e = struct('name', {}, 'value', {});
        end

        function b = baseBlock(id, datestamp)
            %BASEBLOCK The base block: a fresh id unless ID is given, and the
            %   creation_timestamp (the sentinel jBase states when none).
            if isempty(id)
                id = did.ido.unique_id();
            end
            if isempty(datestamp)
                datestamp = '2024-01-01T00:00:00.000Z';
            end
            b = struct('id', char(id), 'creation_timestamp', char(datestamp));
        end

        function body = addEdge(body, name, value)
            %ADDEDGE Append a depends_on entry {NAME, VALUE}; an empty VALUE
            %   writes nothing (never an empty edge).
            if isempty(value)
                return;
            end
            value = char(value);
            if ~isfield(body, 'depends_on') || isempty(body.depends_on)
                body.depends_on = struct('name', name, 'value', value);
                return;
            end
            deps = body.depends_on;
            if iscell(deps)
                deps = [deps{:}];
            end
            f = fieldnames(deps);
            add = cell2struct(cell(numel(f), 1), f, 1);
            for k = 1:numel(f)
                add.(f{k}) = '';
            end
            add.name = name;
            if isfield(deps, 'value') || ~isfield(deps, 'document_id')
                add.value = value;
            else
                add.document_id = value;
            end
            body.depends_on = [reshape(deps, 1, []), add];
        end

        function body = setEdge(body, name, value)
            %SETEDGE Point every edge NAME at VALUE (append when absent).
            found = false;
            if isfield(body, 'depends_on') && isstruct(body.depends_on)
                for k = 1:numel(body.depends_on)
                    if strcmp(char(body.depends_on(k).name), name)
                        if isfield(body.depends_on, 'value')
                            body.depends_on(k).value = char(value);
                        end
                        if isfield(body.depends_on, 'document_id')
                            body.depends_on(k).document_id = char(value);
                        end
                        found = true;
                    end
                end
            end
            if ~found
                body = ndi.migrate.internal.etaShape.addEdge(body, name, value);
            end
        end

        % ================= readers (#88 and pre-#88) =======================

        function c = className(s)
            c = '';
            if isstruct(s) && isfield(s, 'document_class') && isstruct(s.document_class) ...
                    && isfield(s.document_class, 'class_name')
                c = char(s.document_class.class_name);
            end
        end

        function names = superNames(s)
            %SUPERNAMES The superclass names a body lists.
            names = {};
            if ~isstruct(s) || ~isfield(s, 'document_class') ...
                    || ~isfield(s.document_class, 'superclasses')
                return;
            end
            sc = s.document_class.superclasses;
            if isstruct(sc)
                sc = num2cell(sc);
            end
            for k = 1:numel(sc)
                if isstruct(sc{k}) && isfield(sc{k}, 'class_name')
                    names{end+1} = char(sc{k}.class_name); %#ok<AGROW>
                elseif ischar(sc{k}) || isstring(sc{k})
                    names{end+1} = char(sc{k}); %#ok<AGROW>
                end
            end
        end

        function tf = isEntity(s, types)
            %ISENTITY True for an entity (#88 `entity`; pre-#88 `subject`),
            %   optionally of one of TYPES (cellstr; a pre-#88 `subject` counts
            %   as any of the physical types).
            if nargin < 2
                types = {};
            end
            c = ndi.migrate.internal.etaShape.className(s);
            if strcmp(c, 'entity')
                if isempty(types)
                    tf = true;
                else
                    tf = any(strcmp(ndi.migrate.internal.etaShape.entityType(s), types));
                end
            elseif strcmp(c, 'subject')
                physical = {'organism', 'culture', 'tissue', 'cell', 'group', ...
                    'device', 'material'};
                tf = isempty(types) || any(ismember(types, physical));
            else
                tf = false;
            end
        end

        function t = entityType(s)
            %ENTITYTYPE The `entity.type` name, '' when none.
            t = '';
            if isstruct(s) && isfield(s, 'entity') && isstruct(s.entity) ...
                    && isfield(s.entity, 'type')
                v = s.entity.type;
                if isstruct(v) && isfield(v, 'name')
                    t = char(v.name);
                elseif ischar(v) || isstring(v)
                    t = char(v);
                end
            end
        end

        function lid = localIdentifier(s)
            %LOCALIDENTIFIER entity.local_identifier (subject.local_identifier
            %   before #88).
            lid = '';
            for blk = {'entity', 'subject'}
                if isstruct(s) && isfield(s, blk{1}) && isstruct(s.(blk{1})) ...
                        && isfield(s.(blk{1}), 'local_identifier') ...
                        && ~isempty(s.(blk{1}).local_identifier)
                    lid = char(s.(blk{1}).local_identifier);
                    return;
                end
            end
        end

        function d = direction(s)
            %DIRECTION 'assertion' | 'observation' | 'manipulation' |
            %   'calculation' for a statement in either spelling, '' otherwise.
            %   A named calculator (tuning_curve_calculation, ...) is a
            %   'calculation'.
            d = '';
            c = ndi.migrate.internal.etaShape.className(s);
            dirs = {'assertion', 'observation', 'manipulation', 'calculation'};
            if any(strcmp(c, dirs))
                d = c;
                return;
            end
            sup = ndi.migrate.internal.etaShape.superNames(s);
            for k = 1:numel(dirs)
                if any(strcmp(sup, dirs{k})) || endsWith(c, ['_' dirs{k}])
                    d = dirs{k};
                    return;
                end
            end
        end

        function k = valueKind(s)
            %VALUEKIND The statement's value kind ('term', 'time', ...): the
            %   mixin named after the direction's chain (#88), or the prefix of
            %   a pre-#88 `<kind>_<direction>` leaf.
            k = '';
            S = ndi.migrate.internal.etaShape;
            c = S.className(s);
            d = S.direction(s);
            if isempty(d)
                return;
            end
            if strcmp(c, d)
                own = S.ancestors(d);
                sup = S.superNames(s);
                rest = sup(~ismember(sup, [own, {d}]));
                rest = rest(~ismember(rest, {'value', 'data', 'base'}));
                if ~isempty(rest)
                    k = rest{1};
                end
                return;
            end
            if endsWith(c, ['_' d])
                k = c(1:end - numel(d) - 1);
            end
        end

        function tf = isStatement(s, direction, kind)
            %ISSTATEMENT True for a statement, optionally of DIRECTION and KIND.
            if nargin < 2; direction = ''; end
            if nargin < 3; kind = ''; end
            S = ndi.migrate.internal.etaShape;
            d = S.direction(s);
            tf = ~isempty(d) && (isempty(direction) || strcmp(d, direction)) ...
                && (isempty(kind) || strcmp(S.valueKind(s), kind));
        end

        function id = aboutId(s)
            %ABOUTID What a statement is about: `entity_id` (#88) or
            %   `subject_id` (before).
            id = ndi.migrate.internal.etaShape.edge(s, 'entity_id');
            if isempty(id)
                id = ndi.migrate.internal.etaShape.edge(s, 'subject_id');
            end
        end

        function s = setAbout(s, id)
            %SETABOUT Repoint what a statement is about, in the spelling it
            %   already carries.
            S = ndi.migrate.internal.etaShape;
            if isempty(S.edge(s, 'entity_id')) && ~isempty(S.edge(s, 'subject_id'))
                s = S.setEdge(s, 'subject_id', id);
            else
                s = S.setEdge(s, 'entity_id', id);
            end
        end

        function v = variable(s)
            %VARIABLE The statement's variable term ({node,name}, blank when none).
            v = struct('node', '', 'name', '');
            for blk = {'statement', 'subject_statement'}
                if isstruct(s) && isfield(s, blk{1}) && isstruct(s.(blk{1})) ...
                        && isfield(s.(blk{1}), 'variable')
                    v = ndi.migrate.internal.etaShape.asTerm(s.(blk{1}).variable);
                    return;
                end
            end
        end

        function t = termValue(s)
            %TERMVALUE The first term of a term statement's value.
            t = struct('node', '', 'name', '');
            blk = struct();
            if isstruct(s) && isfield(s, 'term') && isstruct(s.term)
                blk = s.term;
            elseif isstruct(s) && isfield(s, 'term_assertion') && isstruct(s.term_assertion)
                blk = s.term_assertion;
            end
            if ~isfield(blk, 'value') || ~isstruct(blk.value) || isempty(blk.value)
                return;
            end
            v = blk.value(1);
            t = ndi.migrate.internal.etaShape.asTerm(v);
        end

        function ids = timeReferenceIds(s)
            %TIMEREFERENCEIDS The statement's time references, in order:
            %   `time_reference_id` (repeated, #88) or `time_reference_N`.
            ids = {};
            if ~isstruct(s) || ~isfield(s, 'depends_on') || ~isstruct(s.depends_on)
                return;
            end
            for k = 1:numel(s.depends_on)
                n = char(s.depends_on(k).name);
                if strcmp(n, 'time_reference_id') || ~isempty(regexp(n, '^time_reference_\d+$', 'once'))
                    v = ndi.migrate.internal.etaShape.entryValue(s.depends_on(k));
                    if ~isempty(v)
                        ids{end+1} = v; %#ok<AGROW>
                    end
                end
            end
        end

        function [child, parent] = relationEnds(s)
            %RELATIONENDS child_id / parent_id (child / parent before #88).
            S = ndi.migrate.internal.etaShape;
            child = S.edge(s, 'child_id');
            if isempty(child); child = S.edge(s, 'child'); end
            parent = S.edge(s, 'parent_id');
            if isempty(parent); parent = S.edge(s, 'parent'); end
        end

        function n = relationName(s)
            n = '';
            if isstruct(s) && isfield(s, 'directed_relation') && isstruct(s.directed_relation) ...
                    && isfield(s.directed_relation, 'relation')
                r = s.directed_relation.relation;
                if isstruct(r) && isfield(r, 'name')
                    n = char(r.name);
                elseif ischar(r)
                    n = r;
                end
            end
        end

        function v = edge(s, name)
            %EDGE The id the first depends_on entry NAME names, '' when absent.
            v = '';
            if ~isstruct(s) || ~isfield(s, 'depends_on') || ~isstruct(s.depends_on)
                return;
            end
            for k = 1:numel(s.depends_on)
                d = s.depends_on(k);
                if isfield(d, 'name') && strcmp(char(d.name), name)
                    v = ndi.migrate.internal.etaShape.entryValue(d);
                    if ~isempty(v)
                        return;
                    end
                end
            end
        end

        function v = entryValue(d)
            v = '';
            for f = {'value', 'document_id', 'id'}
                if isfield(d, f{1}) && ~isempty(d.(f{1}))
                    x = d.(f{1});
                    if iscell(x); x = x{1}; end
                    v = char(x);
                    return;
                end
            end
        end

        function g = curie(raw)
            %CURIE A global identifier from an openMINDS ontologyIdentifier.
            %   Written as given, with ONE rewrite the signed plan names
            %   (V_eta_entity_composition_plan.md sec. 6): Bioregistry has no
            %   `wbstrain`, so `WBStrain:00041972` is `WormBase:WBStrain00041972`
            %   (the prefix spelled as WormBase cites it,
            %   V_eta_prefix_spelling_plan.md).
            g = strtrim(char(raw));
            tok = regexp(g, '^(?i)wbstrain:(\d+)$', 'tokens', 'once');
            if ~isempty(tok)
                g = ['WormBase:WBStrain' tok{1}];
            end
        end

    end
end
