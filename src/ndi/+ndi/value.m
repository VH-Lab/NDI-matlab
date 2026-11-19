classdef value
    % ndi.value - a statement's value: what was measured, set or computed
    %
    % Every v2 statement's value is a `value` composite (`data_type` until
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
    %   terms        - a term-valued value's terms, as ndi.term objects
    %   unit         - the canonical unit's field name, e.g. 'meters'
    %   source       - table: source_value, source_unit (as the lab wrote it; on a
    %                  schema where source_unit is a term, the term's name)
    %   tolerance    - [minus plus] per value, in the canonical unit
    %   approximate  - true per value that is approximate
    %   axes         - table of the value's dimensions (what each axis is)
    %   covariates   - table of the value's covariates (what is known along
    %                  the dimensions: onset times, a control flag, ...)
    %   files        - for a value kept as files (a video, an image): paths
    %
    % See also ndi.statement.

    properties (SetAccess = protected)
        class_name = ''        % the composite, e.g. 'length', 'term', 'dose'
        raw = []               % the inline value as stored (struct or array)
        data = []              % the decoded array, when the value is in a sampled body
        file_list = {}         % file paths, when the value is in an opaque body
        dimensions = []        % the value's dimensions (data.dimensions)
        covariate_list = []    % the value's covariates (data.covariates)
        datum_type = ''        % how the body's bytes are encoded
        canonical_field = ''   % the cell's canonical field, e.g. 'meters'
    end

    methods
        function obj = value(className, raw, options)
            % VALUE - wrap a composite value
            %
            % OBJ = ndi.value(CLASSNAME, RAW, 'Data', A, 'Files', F,
            % 'Dimensions', D, 'Covariates', C, 'DatumType', T). Made by
            % ndi.statement/value.
            arguments
                className (1,:) char = ''
                raw = []
                options.Data = []
                options.Files = {}
                options.Dimensions = []
                options.Covariates = []
                options.DatumType (1,:) char = ''
            end
            obj.class_name = className;
            obj.raw = raw;
            obj.data = options.Data;
            obj.file_list = options.Files;
            obj.dimensions = options.Dimensions;
            obj.covariate_list = options.Covariates;
            obj.datum_type = options.DatumType;
            obj.canonical_field = ndi.value.canonicalField(className, raw);
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
                if ~any(arrayfun(@(x) numberCount(x.(obj.canonical_field)) > 1, r))
                    v = arrayfun(@(x) double(firstOr(x.(obj.canonical_field), NaN)), r);
                else
                    % the new numeric shape: a series is ONE cell whose
                    % canonical field is an array (did-schema
                    % did_v2_numeric_shape_plan.md section 8 answer 4)
                    v = seriesOf(r, obj.canonical_field);
                end
            elseif isstruct(r) && isscalar(r) && isequal(fieldnames(r), {'logical'})
                % the new numeric shape: logical's value is the block
                % {logical} (did-schema did_v2_numeric_shape_plan.md section 3)
                v = logical(r.logical);
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

        function t = terms(obj)
            % TERMS - a term-valued value's terms, an ndi.term array
            %
            % One ndi.term per stored term, as CANONICAL gives their names;
            % an empty ndi.term array for a value that holds no terms.
            t = ndi.term.empty(1, 0);
            r = obj.raw;
            if iscell(r) && ~isempty(r) && all(cellfun(@isstruct, r))
                try r = [r{:}]; catch, end
            end
            if isstruct(r) && ~isempty(r) && (isfield(r, 'name') || isfield(r, 'node')) && ...
                    all(ismember(fieldnames(r), {'node', 'name'}))
                t = reshape(ndi.term.fromStored(r), size(r));
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
            %
            % The source's number is the cell's `source_value` (old numeric
            % shape) or `source_numeric` (new: did-schema
            % did_v2_numeric_shape_plan.md, [one shape for measured
            % numbers], Jess Haley, 2026-11-17). A new-shape series is one
            % cell holding every reading: one row per reading, each with the
            % cell's source_unit.
            [r, ok] = obj.cells();
            [n, series] = obj.readings(r, ok);
            if ~series
                source_value = nan(numel(r), 1); source_unit = strings(numel(r), 1);
                for i = 1:numel(r)
                    if ~ok, break; end
                    if isfield(r, 'source_numeric') && ~isempty(r(i).source_numeric)
                        source_value(i) = sourceNumbers(r(i).source_numeric, 1);
                    elseif isfield(r, 'source_value'), source_value(i) = double(firstOr(r(i).source_value, NaN)); end
                    if isfield(r, 'source_unit'), source_unit(i) = string(ndi.v2.termName(r(i).source_unit)); end
                end
                T = table(source_value, source_unit);
                return;
            end
            source_value = nan(0, 1); source_unit = strings(0, 1);
            for i = 1:numel(r)
                sv = [];
                if isfield(r, 'source_numeric') && ~isempty(r(i).source_numeric)
                    sv = r(i).source_numeric;
                elseif isfield(r, 'source_value') && ~isempty(r(i).source_value)
                    sv = r(i).source_value;
                end
                source_value = [source_value; sourceNumbers(sv, n(i))]; %#ok<AGROW>
                u = "";
                if isfield(r, 'source_unit'), u = string(ndi.v2.termName(r(i).source_unit)); end
                source_unit = [source_unit; repmat(u, n(i), 1)]; %#ok<AGROW>
            end
            T = table(source_value, source_unit);
        end

        function t = tolerance(obj)
            % TOLERANCE - [minus plus] per inline value (NaN when none), canonical unit
            %
            % A new-shape series (one cell, every reading) states one
            % tolerance for the series: it is given on each reading's row.
            [r, ok] = obj.cells();
            [n, series] = obj.readings(r, ok);
            if ~series, n = ones(1, numel(r)); end
            t = nan(sum(n), 2);
            row = 0;
            for i = 1:numel(r)
                rows = row + (1:n(i));
                row = row + n(i);
                if ~ok || ~isfield(r, 'tolerance') || isempty(r(i).tolerance), continue; end
                tl = r(i).tolerance;
                if isfield(tl, 'minus'), t(rows, 1) = double(firstOr(tl.minus, NaN)); end
                if isfield(tl, 'plus'), t(rows, 2) = double(firstOr(tl.plus, NaN)); end
            end
        end

        function a = approximate(obj)
            % APPROXIMATE - true per inline value marked approximate
            %
            % A new-shape series states one `approximate` for the series:
            % it is given on each reading.
            [r, ok] = obj.cells();
            [n, series] = obj.readings(r, ok);
            if ~series, n = ones(1, numel(r)); end
            a = false(sum(n), 1);
            row = 0;
            for i = 1:numel(r)
                rows = row + (1:n(i));
                row = row + n(i);
                if ok && isfield(r, 'approximate') && ~isempty(r(i).approximate)
                    a(rows) = logical(r(i).approximate);
                end
            end
        end

        function T = axes(obj)
            % AXES - table of the value's dimensions: dimension, term, n,
            % unit, coordinates, covariates (see ndi.v2.axesTable)
            T = ndi.v2.axesTable(obj.dimensions, obj.covariate_list);
        end

        function T = covariates(obj)
            % COVARIATES - table of the value's covariates: variable, along,
            % form, unit, values (see ndi.v2.covariatesTable)
            T = ndi.v2.covariatesTable(obj.covariate_list, obj.dimensions);
        end

        function f = files(obj)
            % FILES - the value's file paths, when it is kept as files
            f = obj.file_list;
        end
    end

    methods (Access = private)
        function [n, series] = readings(obj, r, ok)
            % N(i): how many readings cell i holds. SERIES: some cell holds
            % more than one (the new numeric shape's series, one cell whose
            % canonical field or source_numeric is an array); in the old
            % shape every cell holds one, and SERIES is false.
            n = ones(1, numel(r));
            series = false;
            if ~ok, n = zeros(1, 0); return; end
            f = obj.canonical_field;
            for i = 1:numel(r)
                k = 1;
                if ~isempty(f) && isfield(r, f), k = max(k, numberCount(r(i).(f))); end
                if isfield(r, 'source_numeric')
                    k = max(k, numberCount(r(i).source_numeric));
                end
                n(i) = k;
            end
            series = any(n > 1);
        end

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
        function f = canonicalField(className, raw)
            % CANONICALFIELD - the numeric field of CLASSNAME's value cell, e.g. 'meters'
            %
            % Read from the v2 schema: the first numeric sub-field of the
            % class's `value` that is not source_value (source_numeric in the
            % new numeric shape), scale_min or scale_max.
            % A class with several canonical slots (concentration: molar,
            % grams_per_liter, ..., particles_per_liter, optical_density) gives the
            % first one that the stored cells RAW fill, when RAW is given and
            % fills one; else the first declared.
            arguments
                className (1,:) char
                raw = []
            end
            f = '';
            if iscell(raw) && ~isempty(raw) && all(cellfun(@isstruct, raw))
                try raw = [raw{:}]; catch, raw = []; end
            end
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
                        ~any(strcmp(sub{k}.name, {'source_value', 'source_numeric', 'scale_min', 'scale_max'}))
                    name = char(sub{k}.name);
                    if isempty(f), f = name; end
                    if ~isstruct(raw) || isempty(raw), return; end
                    if isfield(raw, name) && any(arrayfun(@(x) ~isempty(x.(name)), raw))
                        f = name;
                        return;
                    end
                end
            end
        end
    end
end

function v = firstOr(x, default)
arguments
    x % any array; its first element is returned
    default
end
if isempty(x), v = default; else, v = x(1); end
end

function n = numberCount(x)
% how many numbers X holds (a numeric or logical array, or a cell of them as
% JSON gives an array with a null back); 1 for anything else
n = 1;
if isnumeric(x) || islogical(x) || iscell(x)
    n = max(1, numel(x));
end
end

function v = seriesOf(r, f)
% every cell's readings of canonical field F, in order (an empty field is
% one NaN, a JSON null in an array NaN). One cell (the new shape's series)
% keeps the stored array's orientation, as one cell per reading keeps the
% cell array's; several are joined as a column.
parts = cell(1, numel(r));
for i = 1:numel(r)
    x = r(i).(f);
    if iscell(x), x = cellfun(@(e) double(firstOr(e, NaN)), x); end
    if isempty(x), x = NaN; end
    parts{i} = double(x);
end
if isscalar(parts)
    v = parts{1};
else
    v = cell2mat(cellfun(@(x) reshape(x, [], 1), parts(:), 'UniformOutput', false));
end
end

function x = sourceNumbers(sv, n)
% N source numbers as a column: numbers as they are, text read as a number
% (NaN when it is not one), NaN-padded to N
if iscell(sv)
    x = cellfun(@(e) oneNumber(e), sv);
elseif ischar(sv) || isstring(sv)
    x = str2double(string(sv));
elseif isnumeric(sv) || islogical(sv)
    x = double(sv);
else
    x = [];
end
x = reshape(x, [], 1);
if numel(x) < n, x(end+1:n, 1) = NaN; end
if numel(x) > n, x = x(1:n); end
end

function y = oneNumber(e)
y = NaN;
if (isnumeric(e) || islogical(e)) && ~isempty(e)
    y = double(e(1));
elseif ischar(e) || isstring(e)
    y = str2double(string(e));
end
end

function c = asCell(x)
arguments
    x % a cell, or any array (split into a cell per element)
end
if iscell(x), c = reshape(x, 1, []); else, c = num2cell(reshape(x, 1, [])); end
end
