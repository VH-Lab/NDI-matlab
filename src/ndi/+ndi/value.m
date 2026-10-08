classdef value
    % ndi.value - a statement's value: what was measured, set or computed
    %
    % Every V2 statement's value is a `value` composite (`data_type` until
    % 2026-10-08) (length, time,
    % intensity, velocity, temperature, term, label, score, dose, position,
    % model_fit, ...). A dimensioned one stores each value as a cell: the
    % number in its canonical unit (e.g. `meters`), the source value and
    % unit it came from, a tolerance and whether it is approximate (tenet
    % T14). A value is stored INLINE on the statement or, when it is an array,
    % in a data body; an ndi.value reads the same way either way.
    %
    % Get one from a statement:  v = st.value();
    %
    % ndi.value Methods:
    %   canonical    - the values in the canonical unit (numbers), or the
    %                  names (terms, labels), or the raw struct (dose, model
    %                  fit, ...); double(v) is the same for numbers
    %   unit         - the canonical unit's field name, e.g. 'meters'
    %   source       - table: source_value, source_unit (as the lab wrote it)
    %   tolerance    - [minus plus] per value, in the canonical unit
    %   approximate  - true per value that is approximate
    %   axes         - table of the value's keys (what each dimension indexes)
    %   files        - for a value kept as files (a video, an image): paths
    %
    % See also ndi.statement.

    properties (SetAccess = protected)
        class_name = ''        % the composite, e.g. 'length', 'term', 'dose'
        raw = []               % the inline value as stored (struct or array)
        data = []              % the decoded array, when the value is in a sampled body
        file_list = {}         % file paths, when the value is in an opaque body
        keys = []              % the value's keys (data.keys)
        datum_type = ''        % how the body's bytes are encoded
        canonical_field = ''   % the cell's canonical field, e.g. 'meters'
    end

    methods
        function obj = value(className, raw, options)
            % VALUE - wrap a composite value
            %
            % OBJ = ndi.value(CLASSNAME, RAW, 'Data', A, 'Files', F,
            % 'Keys', K, 'DatumType', T). Made by ndi.statement/value.
            arguments
                className (1,:) char = ''
                raw = []
                options.Data = []
                options.Files = {}
                options.Keys = []
                options.DatumType (1,:) char = ''
            end
            obj.class_name = className;
            obj.raw = raw;
            obj.data = options.Data;
            obj.file_list = options.Files;
            obj.keys = options.Keys;
            obj.datum_type = options.DatumType;
            obj.canonical_field = ndi.value.canonicalField(className);
        end

        function v = canonical(obj)
            % CANONICAL - the values in the canonical unit
            %
            % Numbers for a dimensioned value (from the body, or each cell's
            % canonical field), names for terms and labels, the raw struct
            % for a structured value (dose, item, position, model_fit).
            if ~isempty(obj.data) || ~isempty(obj.file_list)
                v = obj.data;
                return;
            end
            r = obj.raw;
            if iscell(r) && ~isempty(r) && all(cellfun(@isstruct, r))
                try r = [r{:}]; catch, end
            end
            if isstruct(r) && ~isempty(obj.canonical_field) && isfield(r, obj.canonical_field)
                v = arrayfun(@(x) double(firstOr(x.(obj.canonical_field), NaN)), r);
            elseif isstruct(r) && (isfield(r, 'name') || isfield(r, 'node')) && ...
                    all(ismember(fieldnames(r), {'node', 'name'}))
                v = strings(size(r));
                for i = 1:numel(r), v(i) = string(ndi.v2.termName(r(i))); end
            elseif isstruct(r) && isfield(r, 'text')
                % the `text` kind {text, language} (2026-10-08): the text
                v = strings(size(r));
                for i = 1:numel(r), v(i) = string(char(r(i).text)); end
            else
                v = r;
            end
        end

        function d = double(obj)
            % DOUBLE - the canonical values as numbers
            d = double(obj.canonical());
        end

        function u = unit(obj)
            % UNIT - the canonical unit's field name, e.g. 'meters' ('' when none)
            u = obj.canonical_field;
        end

        function T = source(obj)
            % SOURCE - table: source_value, source_unit, per inline value
            [r, ok] = obj.cells();
            source_value = nan(numel(r), 1); source_unit = strings(numel(r), 1);
            for i = 1:numel(r)
                if ~ok, break; end
                if isfield(r, 'source_value'), source_value(i) = double(firstOr(r(i).source_value, NaN)); end
                if isfield(r, 'source_unit'), source_unit(i) = string(r(i).source_unit); end
            end
            T = table(source_value, source_unit);
        end

        function t = tolerance(obj)
            % TOLERANCE - [minus plus] per inline value (NaN when none), canonical unit
            [r, ok] = obj.cells();
            t = nan(numel(r), 2);
            for i = 1:numel(r)
                if ~ok || ~isfield(r, 'tolerance') || isempty(r(i).tolerance), continue; end
                tl = r(i).tolerance;
                if isfield(tl, 'minus'), t(i, 1) = double(firstOr(tl.minus, NaN)); end
                if isfield(tl, 'plus'), t(i, 2) = double(firstOr(tl.plus, NaN)); end
            end
        end

        function a = approximate(obj)
            % APPROXIMATE - true per inline value marked approximate
            [r, ok] = obj.cells();
            a = false(numel(r), 1);
            for i = 1:numel(r)
                if ok && isfield(r, 'approximate') && ~isempty(r(i).approximate)
                    a(i) = logical(r(i).approximate);
                end
            end
        end

        function T = axes(obj)
            % AXES - table of the value's keys: variable, unit, n, coordinates
            T = ndi.v2.axesTable(obj.keys);
        end

        function f = files(obj)
            % FILES - the value's file paths, when it is kept as files
            f = obj.file_list;
        end
    end

    methods (Access = private)
        function [r, ok] = cells(obj)
            r = obj.raw;
            if iscell(r) && ~isempty(r) && all(cellfun(@isstruct, r))
                try r = [r{:}]; catch, end
            end
            ok = isstruct(r);
            if ~ok, r = []; end
        end
    end

    methods (Static)
        function f = canonicalField(className)
            % CANONICALFIELD - the numeric field of CLASSNAME's value cell, e.g. 'meters'
            %
            % Read from the V2 schema: the first numeric sub-field of the
            % class's `value` that is not source_value, scale_min or scale_max.
            arguments
                className (1,:) char
            end
            f = '';
            if isempty(className), return; end
            try
                s = did2.schema.cache.shared().getClass(className);
            catch
                return;
            end
            if ~isfield(s, 'fields'), return; end
            % field definitions differ in their keys, so they are walked as a
            % cell array rather than concatenated
            fs = asCell(s.fields);
            v = [];
            for k = 1:numel(fs)
                if isfield(fs{k}, 'name') && strcmp(fs{k}.name, 'value'), v = fs{k}; break; end
            end
            if isempty(v) || ~isfield(v, 'fields') || isempty(v.fields), return; end
            sub = asCell(v.fields);
            for k = 1:numel(sub)
                if isfield(sub{k}, 'type') && any(strcmp(sub{k}.type, {'double', 'integer', 'matrix'})) && ...
                        ~any(strcmp(sub{k}.name, {'source_value', 'scale_min', 'scale_max'}))
                    f = char(sub{k}.name);
                    return;
                end
            end
        end
    end
end

function v = firstOr(x, default)
if isempty(x), v = default; else, v = x(1); end
end

function c = asCell(x)
if iscell(x), c = reshape(x, 1, []); else, c = num2cell(reshape(x, 1, [])); end
end
