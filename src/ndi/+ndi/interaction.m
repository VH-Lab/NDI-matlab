classdef (Abstract) interaction < ndi.statement
    % ndi.interaction - a statement about something done to, with or about a subject
    %
    % The shared parent of ndi.observation, ndi.manipulation and
    % ndi.calculation: each happened at a time, by a method, possibly with an
    % instrument. It is abstract: ndi.statement.fromDocument always returns
    % one of the three.
    %
    % ndi.interaction Methods (beyond ndi.statement):
    %   time              - when: a struct array, one per time reference
    %   method            - the method's term ({node, name}); method_name, its name
    %   method_parameters - table of the method's parameters
    %   instrument        - the instrument subject(s) (a cell array of ndi.subject)
    %   software          - the software entity (a cell array of ndi.entity)
    %
    % See also ndi.statement, ndi.v2.timeOf.

    methods
        function obj = interaction(container, doc)
            if nargin == 0
                container = []; doc = [];
            end
            obj = obj@ndi.statement(container, doc);
        end

        function t = time(obj)
            % TIME - when the statement holds, one struct per time reference
            %
            % T = TIME(OBJ) is a struct array (see ndi.v2.timeOf): kind,
            % start, end (datetime, UTC, NaT when it cannot be resolved),
            % offsets, relation, clock, referent_id, approximate, tolerance,
            % resolved_by. Empty when the statement has no time reference.
            t = [];
            ids = ndi.v2.edgeIds(obj.document_properties(), 'time_reference_id');
            for i = 1:numel(ids)
                d = ndi.v2.getDocument(obj.container_, ids{i});
                if isempty(d), continue; end
                r = ndi.v2.timeOf(obj.container_, d);
                if isempty(t), t = r; else, t(end+1) = r; end %#ok<AGROW>
            end
        end

        function m = method(obj)
            % METHOD - the method's term ({node, name}); [] when none
            m = ndi.v2.blockOf(obj.document_properties(), 'subject_interaction', 'method', []);
        end

        function n = method_name(obj)
            % METHOD_NAME - the method's name ('' when none)
            n = ndi.v2.termName(obj.method());
        end

        function T = method_parameters(obj)
            % METHOD_PARAMETERS - table: variable, value, unit, source_unit
            %
            % One row per parameter stored on the statement. VALUE is the
            % number in the canonical unit, a term's name, or text.
            m = ndi.v2.blockOf(obj.document_properties(), 'subject_interaction', 'method_parameters', []);
            m = ndi.v2.entries(m);
            variable = strings(0, 1); value = cell(0, 1); unit = strings(0, 1); source_unit = strings(0, 1);
            for i = 1:numel(m)
                x = m{i};
                variable(end+1, 1) = string(ndi.v2.termName(fieldOf(x, 'variable'))); %#ok<AGROW>
                unit(end+1, 1) = string(ndi.v2.termName(fieldOf(x, 'unit'))); %#ok<AGROW>
                source_unit(end+1, 1) = string(char(fieldOf(x, 'source_unit'))); %#ok<AGROW>
                if ~isempty(fieldOf(x, 'term'))
                    value{end+1, 1} = ndi.v2.termName(fieldOf(x, 'term')); %#ok<AGROW>
                elseif ~isempty(fieldOf(x, 'text'))
                    value{end+1, 1} = char(fieldOf(x, 'text')); %#ok<AGROW>
                else
                    value{end+1, 1} = fieldOf(x, 'value'); %#ok<AGROW>
                end
            end
            T = table(variable, value, unit, source_unit);
        end

        function s = instrument(obj)
            % INSTRUMENT - the instrument subject(s), a cell array of ndi.subject
            s = obj.entitiesAt('instrument_id');
        end

        function s = software(obj)
            % SOFTWARE - the software entity(s), a cell array of ndi.entity
            s = obj.entitiesAt('software_id');
        end
    end

    methods (Access = protected)
        function e = entitiesAt(obj, edge)
            e = {};
            ids = ndi.v2.edgeIds(obj.document_properties(), edge);
            for i = 1:numel(ids)
                d = ndi.v2.getDocument(obj.container_, ids{i});
                if ~isempty(d)
                    e{end+1} = ndi.entity.fromDocument(obj.container_, d); %#ok<AGROW>
                end
            end
        end
    end
end

function v = fieldOf(s, name)
v = [];
if isstruct(s) && isfield(s, name), v = s.(name); end
end
