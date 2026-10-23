classdef term
    % ndi.term - an ontology term as a statement stores it
    %
    % A V2 statement names things with terms: its variable, its method, the
    % variables of its conditions, parameters and keys, units, and the value
    % of a term-valued statement. Each is stored as {node, name}: NODE a
    % CURIE ('WBls:0000038'), NAME what the import wrote ('L4 larva Ce'). An
    % ndi.term holds those two as stored and asks the ontology for the rest
    % only when a method needs it (ndi.ontology.lookup, through the on-disk
    % cache of ndi.v2.termLookup), so making thousands of them is cheap and
    % one that is never asked costs no lookup.
    %
    % The stored NAME and the ontology's LABEL are different things and can
    % differ: a name written before its term was looked up, or a dataset
    % that names a term its own way, keeps its NAME while LABEL is what the
    % ontology says now. The Haley import writes each term's ontology label
    % as its name (Jess, 2026-10-20), so there the two agree.
    %
    %   t = st.variable();            % an ndi.term
    %   t.name                        % 'organism strain'
    %   t.node                        % 'NCIT:C14419'
    %   t.definition()                % the ontology's definition
    %   t == "organism strain"        % true: by name, node or label
    %   string(t)                     % its name
    %
    % ndi.term Properties:
    %   node   - the CURIE as stored ('' for a lab label with no node)
    %   name   - the name as stored
    %
    % ndi.term Methods:
    %   label       - the ontology's name for the term
    %   definition  - the ontology's definition
    %   synonyms    - the ontology's other names (a row cell array)
    %   id          - the id the ontology gives for the node
    %   lookup      - all of the above, as a struct (ndi.v2.termLookup)
    %   prefix      - the node's prefix, as written ('' when none)
    %   key         - the node in the form nodes are compared in (ndi.v2.curieKey)
    %   iri         - the IRI the node stands for (ndi.v2.curieIri)
    %   hasNode     - true where the term has a node
    %   eq, ne      - the same term: equal keys when both have a node, else
    %                 equal names (ignoring case); against text, true when
    %                 the text is the term's node (by key), name, label
    %                 or one of its synonyms
    %   string, char - the name (the node when there is no name)
    %   toStruct    - {node, name}, as a builder takes it
    %   fromStored  - (static) ndi.term(s) from a stored term, a struct
    %                 array, a cell array of them, or text
    %
    % The ontology methods (label, definition, synonyms, id, lookup) need
    % ndi-ontology-matlab and, the first time a node is asked for, the
    % network; without either they return '' or {} rather than erroring.
    %
    % See also ndi.statement, ndi.value, ndi.v2.termLookup, ndi.ontology.

    properties (SetAccess = protected)
        node = ''   % the CURIE as stored ('' when the term is a label only)
        name = ''   % the name as stored
    end

    methods
        function obj = term(node, name)
            % TERM - make a term from its node and name
            %
            % OBJ = ndi.term(NODE, NAME). Either may be ''.
            arguments
                node {mustBeText} = ''
                name {mustBeText} = ''
            end
            obj.node = strtrim(char(node));
            obj.name = char(name);
        end

        function tf = hasNode(obj)
            % HASNODE - true where the term has a node
            tf = arrayfun(@(t) ~isempty(t.node), obj);
        end

        function p = prefix(obj)
            % PREFIX - the node's prefix as written ('' when no node)
            arguments
                obj (1,1) ndi.term
            end
            p = regexp(obj.node, '^[A-Za-z][\w.-]*(?=:)', 'match', 'once');
        end

        function k = key(obj)
            % KEY - the node in the form nodes are compared in
            % ('ncbitaxon:6239' for 'NCBITaxon:6239'; '' when no node)
            arguments
                obj (1,1) ndi.term
            end
            k = '';
            if ~isempty(obj.node), k = ndi.v2.curieKey(obj.node); end
        end

        function i = iri(obj)
            % IRI - the IRI the node stands for ('' when it cannot be made)
            arguments
                obj (1,1) ndi.term
            end
            i = '';
            if ~isempty(obj.node), i = ndi.v2.curieIri(obj.node); end
        end

        function L = lookup(obj, options)
            % LOOKUP - what the ontology says about the term: a struct with
            % found, id, label, definition, synonyms (ndi.v2.termLookup)
            arguments
                obj (1,1) ndi.term
                options.Refresh (1,1) logical = false
            end
            L = ndi.v2.termLookup(obj.node, 'Refresh', options.Refresh);
        end

        function l = label(obj)
            % LABEL - the ontology's name for the term ('' when not found)
            arguments
                obj (1,1) ndi.term
            end
            L = obj.lookup();
            l = L.label;
        end

        function d = definition(obj)
            % DEFINITION - the ontology's definition ('' when none or not found)
            arguments
                obj (1,1) ndi.term
            end
            L = obj.lookup();
            d = L.definition;
        end

        function s = synonyms(obj)
            % SYNONYMS - the ontology's other names for the term (a row cell array)
            arguments
                obj (1,1) ndi.term
            end
            L = obj.lookup();
            s = L.synonyms;
        end

        function i = id(obj)
            % ID - the id the ontology gives for the node ('' when not found)
            arguments
                obj (1,1) ndi.term
            end
            L = obj.lookup();
            i = L.id;
        end

        function tf = eq(a, b)
            % EQ - the same term, elementwise (one side may be scalar)
            %
            % Two terms are the same when both have a node and their nodes'
            % keys are equal (so 'WBStrain:00000001' == 'WormBase:WBStrain00000001'),
            % or, when either has none, when their names are equal ignoring
            % case. A term and text are the same when the text is the
            % term's node (by key), its name or its label, ignoring case.
            if ~isa(a, 'ndi.term'), [a, b] = deal(b, a); end
            if ischar(b) || isstring(b) || iscellstr(b)
                b = string(b);
                tf = sameShape(a, b, @(t, s) t.matchesText(char(s)));
            elseif isa(b, 'ndi.term')
                tf = sameShape(a, b, @(x, y) x.sameAs(y));
            else
                error('ndi:term:eq', 'An ndi.term compares with an ndi.term or text, not a %s.', class(b));
            end
        end

        function tf = ne(a, b)
            % NE - not EQ
            tf = ~eq(a, b);
        end

        function s = string(obj)
            % STRING - the name (the node when there is no name), elementwise
            s = strings(size(obj));
            for i = 1:numel(obj)
                s(i) = string(obj(i).nameOrNode());
            end
        end

        function c = char(obj)
            % CHAR - the name (the node when there is no name)
            arguments
                obj (1,1) ndi.term
            end
            c = obj.nameOrNode();
        end

        function s = toStruct(obj)
            % TOSTRUCT - {node, name} structs, as the builders take a term
            s = repmat(struct('node', '', 'name', ''), size(obj));
            for i = 1:numel(obj)
                s(i) = struct('node', obj(i).node, 'name', obj(i).name);
            end
        end

        function disp(obj)
            % DISP - "name (node)" per term
            if isempty(obj)
                fprintf('  0x0 ndi.term\n');
                return;
            end
            for i = 1:numel(obj)
                t = obj(i);
                if isempty(t.node)
                    fprintf('  %s\n', t.name);
                elseif isempty(t.name)
                    fprintf('  %s\n', t.node);
                else
                    fprintf('  %s (%s)\n', t.name, t.node);
                end
            end
        end
    end

    methods (Hidden)
        function n = nameOrNode(obj)
            n = obj.name;
            if isempty(n), n = obj.node; end
        end

        function tf = sameAs(obj, other)
            if ~isempty(obj.node) && ~isempty(other.node)
                tf = strcmp(obj.key(), other.key());
            else
                tf = strcmpi(strtrim(obj.name), strtrim(other.name)) && ~isempty(strtrim(obj.name));
            end
        end

        function tf = matchesText(obj, s)
            s = strtrim(s);
            tf = false;
            if isempty(s), return; end
            if ~isempty(obj.node) && strcmp(ndi.v2.curieKey(s), obj.key())
                tf = true;
            elseif strcmpi(s, strtrim(obj.name))
                tf = true;
            elseif ~isempty(obj.node)
                % its ontology label, or a synonym ('meter' is OM's metre),
                % from the same cached lookup (tenet T19: whichever label is
                % stored, the term is found by the names it goes by)
                tf = strcmpi(s, strtrim(obj.label())) || any(strcmpi(s, strtrim(obj.synonyms())));
            end
        end
    end

    methods (Static)
        function t = fromStored(x)
            % FROMSTORED - ndi.term(s) from what a statement stores
            %
            % T = ndi.term.fromStored(X): X is a {node, name} struct or
            % struct array, a cell array of them, an ndi.term (returned as
            % is), or text (a name, or a node when it is a CURIE). An empty
            % X gives an empty ndi.term array.
            if isa(x, 'ndi.term')
                t = x;
                return;
            end
            t = ndi.term.empty(1, 0);
            if isempty(x), return; end
            if iscell(x)
                parts = cellfun(@ndi.term.fromStored, x, 'UniformOutput', false);
                t = [t, parts{:}];
                return;
            end
            if ischar(x) || isstring(x)
                x = cellstr(x);
                for i = 1:numel(x)
                    s = strtrim(x{i});
                    if ~isempty(regexp(s, '^[A-Za-z][\w.-]*:\S+$', 'once'))
                        t(end+1) = ndi.term(s, ''); %#ok<AGROW>
                    else
                        t(end+1) = ndi.term('', s); %#ok<AGROW>
                    end
                end
                return;
            end
            if isstruct(x)
                for i = 1:numel(x)
                    t(end+1) = ndi.term(textField(x(i), 'node'), textField(x(i), 'name')); %#ok<AGROW>
                end
                return;
            end
            error('ndi:term:fromStored', 'A stored term is a struct, a cell array or text, not a %s.', class(x));
        end
    end
end

function tf = sameShape(a, b, f)
% F over the elements of A and B, one of which may be scalar
if isscalar(b)
    tf = arrayfun(@(x) f(x, b), a);
elseif isscalar(a)
    tf = arrayfun(@(y) f(a, y), b);
elseif isequal(size(a), size(b))
    tf = false(size(a));
    for i = 1:numel(a)
        tf(i) = f(a(i), b(i));
    end
else
    error('ndi:term:eq', 'Terms compare elementwise: %s against %s.', mat2str(size(a)), mat2str(size(b)));
end
end

function v = textField(s, f)
v = '';
if isfield(s, f) && ~isempty(s.(f)) && (ischar(s.(f)) || isstring(s.(f)))
    v = char(s.(f));
end
end
