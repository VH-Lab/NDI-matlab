classdef TestNumericShapeReaders < matlab.unittest.TestCase
%TESTNUMERICSHAPEREADERS NDI's readers of list items and values read the new numeric shape only.
%
%   did-schema docs/plans/did_v2_numeric_shape_plan.md, decided by Jess Haley,
%   2026-11-17 [one shape for measured numbers], [numeric shape details]: a
%   list item (condition, method or compression parameter, covariate) becomes
%   flat -- `numeric` (canonical) with `unit`, `source_numeric`,
%   `source_unit`, `tolerance` beside it, or plain `origin` / `spacing`
%   numbers with `source_origin` / `source_spacing` -- with no `quantity`
%   wrapper and no `matrix`; a value class's `source_value` becomes
%   `source_numeric` and a series is ONE cell whose canonical field is an
%   array; `logical.value` becomes the block {logical}. Step 2 of the plan's
%   section 9 switched the writers; step 4 drops the old shape from the
%   readers ([no migrated database is kept], Jess Haley, 2026-11-19: "No
%   database exists that was already migrated that we care to keep").
%
%   Each case reads a thing written in the new shape, and checks that the
%   same thing written in the old shape is not read as numbers: it is the
%   error 'ndi:v2:oldNumericShapeReMigrate' (the database is migrated again
%   from v1). The items are written by hand, as a stored document holds
%   them, and (where DID-matlab's builders take 'Shape') by did2.build.

    methods (Test)

        % ---------------- ndi.v2.entryValue ------------------------------

        function testEntryValueReadsANumberAndRefusesTheOldShape(testCase)
            old = struct('variable', t('x'), 'unit', t('second'), ...
                'quantity', struct('value', 0.5, 'source_value', '500'));
            new = struct('variable', t('x'), 'unit', t('second'), ...
                'numeric', 0.5, 'source_numeric', 500);
            testCase.verifyError(@() ndi.v2.entryValue(old), OLD, 'old shape: quantity');
            % a parameter written before 2026-10-19: a bare `value`
            testCase.verifyError(@() ndi.v2.entryValue(struct('variable', t('x'), ...
                'value', struct('value', 0.5, 'source_value', '500'))), OLD, 'old shape: value');
            [v, sv, k] = ndi.v2.entryValue(new);
            testCase.verifyEqual({v, sv, k}, {0.5, "500", 'quantity'}, 'new shape');
        end

        function testEntryValueTakesTheOldFormsBlanksForNoNumber(testCase)
            % a blank `quantity` or `matrix` (a schema's empty default) holds no
            % old number, so the entry is read by the form that holds one
            e = struct('variable', t('x'), 'quantity', struct('value', [], 'source_value', ''), ...
                'matrix', [], 'numeric', 3, 'source_numeric', 3);
            [v, ~, k] = ndi.v2.entryValue(e);
            testCase.verifyEqual({v, k}, {3, 'quantity'});
        end

        function testEntryValueKeepsTheSourcesText(testCase)
            % [numeric shape details] (1): text v1 stored stays text
            e = struct('variable', t('threshold'), 'numeric', 0.03, 'source_numeric', '0.030');
            [v, sv, k] = ndi.v2.entryValue(e);
            testCase.verifyEqual({v, sv, k}, {0.03, "0.030", 'quantity'});
            % a number is read back as the shortest text that reads as it
            e.source_numeric = 0.1;
            [~, sv] = ndi.v2.entryValue(e);
            testCase.verifyEqual(sv, "0.1");
            e.source_numeric = 1/3;
            [~, sv] = ndi.v2.entryValue(e);
            testCase.verifyEqual(str2double(sv), 1/3);
            % no source number: "" as for an old quantity with none
            e = struct('variable', t('x'), 'numeric', 7);
            [v, sv, k] = ndi.v2.entryValue(e);
            testCase.verifyEqual({v, sv, k}, {7, "", 'quantity'});
        end

        function testEntryValueReadsAnArrayAndRefusesTheOldMatrix(testCase)
            old = struct('variable', t('x'), 'matrix', [1 2; 3 4]);
            new = struct('variable', t('x'), 'numeric', [1 2; 3 4]);
            testCase.verifyError(@() ndi.v2.entryValue(old), OLD, 'old shape: matrix');
            [v, ~, k] = ndi.v2.entryValue(new);
            testCase.verifyEqual({v, k}, {[1 2; 3 4], 'matrix'}, 'new shape');
            % as JSON reads it back: rows as cells, a null as []
            [v, ~, k] = ndi.v2.entryValue(struct('variable', t('x'), 'numeric', {{{1, 2}, {3, 4}}}));
            testCase.verifyEqual({v, k}, {[1 2; 3 4], 'matrix'});
            [v, ~, k] = ndi.v2.entryValue(struct('variable', t('x'), 'numeric', {{1; []; 3}}));
            testCase.verifyEqual(k, 'matrix');
            testCase.verifyTrue(isequaln(v, [1; NaN; 3]));
        end

        function testEntryValueNewShapeBesideTheOtherFormsBlanks(testCase)
            b = struct('variable', t('x'), 'term', t(''), 'count', 0, 'text', '', ...
                'logical', false, 'numeric', []);
            e = b; e.numeric = 2.5; e.source_numeric = 2500;
            [v, sv, k] = ndi.v2.entryValue(e);
            testCase.verifyEqual({v, sv, k}, {2.5, "2500", 'quantity'});
            e = b; e.count = 4;
            [v, ~, k] = ndi.v2.entryValue(e);
            testCase.verifyEqual({v, k}, {4, 'count'}, 'a blank numeric is no number');
            e = b; e.logical = true;
            [v, ~, k] = ndi.v2.entryValue(e);
            testCase.verifyEqual({v, k}, {true, 'logical'});
        end

        function testEntryValueReadsWhatTheBuilderWrites(testCase)
            needBuilders(testCase);
            c = one(did2.build.condition(t('x'), 'Value', 0.25, 'SourceValue', '250', ...
                'Shape', 'new'));
            [v, sv, k] = ndi.v2.entryValue(c);
            testCase.verifyEqual({v, k}, {0.25, 'quantity'});
            testCase.verifyEqual(str2double(sv), 250);
            c = one(did2.build.condition(t('x'), 'Matrix', [11 12 13], 'Shape', 'new'));
            [v, ~, k] = ndi.v2.entryValue(c);
            testCase.verifyEqual({double(v(:)'), k}, {[11 12 13], 'matrix'});
            % the same conditions in the old shape are refused
            c = one(did2.build.condition(t('x'), 'Value', 0.25, 'SourceValue', '250', ...
                'Shape', 'old'));
            testCase.verifyError(@() ndi.v2.entryValue(c), OLD, 'old shape: quantity');
            c = one(did2.build.condition(t('x'), 'Matrix', [11 12 13], 'Shape', 'old'));
            testCase.verifyError(@() ndi.v2.entryValue(c), OLD, 'old shape: matrix');
        end

        % ---------------- ndi.v2.covariateValues -------------------------

        function testCovariateValuesReadsARegularAxisAndRefusesTheOldShape(testCase)
            dims = struct('term', t('time'), 'n', 4);
            old = struct('variable', t('time'), 'along', 0, 'unit', t('second'), ...
                'origin', struct('value', 1, 'source_value', 1000), ...
                'spacing', struct('value', 0.5, 'source_value', 500));
            new = struct('variable', t('time'), 'along', 0, 'origin', 1, 'spacing', 0.5, ...
                'unit', t('second'), 'source_origin', 1000, 'source_spacing', 500);
            testCase.verifyError(@() ndi.v2.covariateValues(old, dims), OLD, ...
                'old shape: origin/spacing blocks');
            [v2, f2] = ndi.v2.covariateValues(new, dims);
            testCase.verifyEqual({v2, f2}, {[1; 1.5; 2; 2.5], "origin_spacing"}, 'new shape');
        end

        function testCovariateValuesReadsNumbersAndRefusesTheOldQuantity(testCase)
            dims = struct('term', t('channel'), 'n', 3);
            old = struct('variable', t('scale'), 'along', 0, 'unit', t('volt'), ...
                'quantity', struct('value', [1 2 3] * 1e-6, 'source_value', [1 2 3]));
            new = struct('variable', t('scale'), 'along', 0, 'numeric', [1 2 3] * 1e-6, ...
                'unit', t('volt'), 'source_numeric', [1 2 3]);
            testCase.verifyError(@() ndi.v2.covariateValues(old, dims), OLD, 'old shape: quantity');
            [v2, f2] = ndi.v2.covariateValues(new, dims);
            testCase.verifyEqual({v2, f2}, {[1; 2; 3] * 1e-6, "quantity"}, 'new shape');
            % a unitless numeric with no source, one per position
            [v3, f3] = ndi.v2.covariateValues(struct('variable', t('offset'), 'along', 0, ...
                'numeric', [5 6 7]), dims);
            testCase.verifyEqual({v3, f3}, {[5; 6; 7], "quantity"});
        end

        function testCovariateValuesReadsAnArrayAtEachPositionAndRefusesTheOldMatrix(testCase)
            dims = struct('term', t('trial'), 'n', 2);
            m = [1 2 3; 4 5 6];
            old = struct('variable', t('x'), 'along', 0, 'matrix', m);
            new = struct('variable', t('x'), 'along', 0, 'numeric', m);
            testCase.verifyError(@() ndi.v2.covariateValues(old, dims), OLD, 'old shape: matrix');
            [v2, f2] = ndi.v2.covariateValues(new, dims);
            testCase.verifyEqual({v2, f2}, {m, "matrix"}, 'new shape');
        end

        function testCovariateValuesReadsWhatTheBuilderWrites(testCase)
            needBuilders(testCase);
            timeTerm = struct('node', 'om:Time', 'name', 'time');
            dims = struct('term', timeTerm, 'n', 3);
            second = struct('node', 'om:second-Time', 'name', 'second');
            c = one(did2.build.covariate(timeTerm, 0, 'Origin', 0, 'Spacing', 0.25, ...
                'Unit', second, 'Shape', 'new'));
            [v, f] = ndi.v2.covariateValues(c, dims);
            testCase.verifyEqual({v, f}, {[0; 0.25; 0.5], "origin_spacing"});
            c = one(did2.build.covariate(t('x'), 0, 'Value', [4 5 6], 'Shape', 'new'));
            [v, f] = ndi.v2.covariateValues(c, dims);
            testCase.verifyEqual({v, f}, {[4; 5; 6], "quantity"});
            % the same covariates in the old shape are refused
            c = one(did2.build.covariate(timeTerm, 0, 'Origin', 0, 'Spacing', 0.25, ...
                'Unit', second, 'Shape', 'old'));
            testCase.verifyError(@() ndi.v2.covariateValues(c, dims), OLD, 'old shape: origin');
            c = one(did2.build.covariate(t('x'), 0, 'Value', [4 5 6], 'Shape', 'old'));
            testCase.verifyError(@() ndi.v2.covariateValues(c, dims), OLD, 'old shape: quantity');
        end

        % ---------------- ndi.v2.statementValue --------------------------

        function testStatementValueReadsALogicalAndRefusesTheBareOne(testCase)
            needSchema(testCase);
            testCase.verifyError(@() ndi.v2.statementValue(statementProps('logical', true)), ...
                OLD, 'old shape: bare');
            [k, v, txt] = ndi.v2.statementValue(statementProps('logical', struct('logical', true)));
            testCase.verifyEqual({k, v, txt}, {'logical', true, 'true'}, 'new shape: {logical}');
            [k, v] = ndi.v2.statementValue(statementProps('logical', struct('logical', false)));
            testCase.verifyEqual({k, v}, {'logical', false});
        end

        function testStatementValueReadsANumberAndRefusesTheOldShape(testCase)
            needSchema(testCase);
            old = struct('volts', 0.002, 'source_value', 2, 'source_unit', t('millivolt'));
            new = struct('volts', 0.002, 'source_numeric', 2, 'source_unit', t('millivolt'));
            testCase.verifyError(@() ndi.v2.statementValue(statementProps('voltage', old)), ...
                OLD, 'old shape: source_value');
            [k, v, ~, u] = ndi.v2.statementValue(statementProps('voltage', new));
            testCase.verifyEqual({k, v, u}, {'number', 0.002, 'volts'}, 'new shape');
        end

        % ---------------- ndi.value --------------------------------------

        function testValueReadsASeriesAndRefusesOneCellPerReading(testCase)
            needSchema(testCase);
            mv = t('millivolt');
            tol = struct('minus', 1e-4, 'plus', 1e-4);
            % old: one cell per reading
            old = struct('volts', {0.001; 0.002; 0.003}, 'source_value', {1; 2; 3}, ...
                'source_unit', mv, 'approximate', true, 'tolerance', tol);
            % new: one cell, arrays ([one shape for measured numbers] section 8, answer 4)
            new = struct('volts', [0.001; 0.002; 0.003], 'source_numeric', [1; 2; 3], ...
                'source_unit', mv, 'approximate', true, 'tolerance', tol);
            testCase.verifyError(@() ndi.value('voltage', old), OLD, 'old shape: a cell per reading');
            % one cell per reading even without a source_value
            testCase.verifyError(@() ndi.value('voltage', struct('volts', {0.001; 0.002})), ...
                OLD, 'old shape: a cell per reading, no source');
            b = ndi.value('voltage', new);
            testCase.verifyEqual(b.unit(), 'volts');
            testCase.verifyEqual(b.canonical(), [0.001; 0.002; 0.003], 'AbsTol', 1e-15);
            sb = b.source();
            testCase.verifyEqual(sb.source_value, [1; 2; 3], 'one source row per reading');
            testCase.verifyEqual(sb.source_unit, repmat("millivolt", 3, 1));
            testCase.verifyEqual(b.tolerance(), repmat([1e-4 1e-4], 3, 1));
            testCase.verifyEqual(b.approximate(), true(3, 1));
        end

        function testValueReadsOneReadingAndRefusesTheOldSourceValue(testCase)
            needSchema(testCase);
            testCase.verifyError(@() ndi.value('mass', struct('grams', 25.1, ...
                'source_value', 25.1, 'source_unit', t('gram'))), OLD, 'old shape: source_value');
            new = ndi.value('mass', struct('grams', 25.1, 'source_numeric', 25.1, 'source_unit', t('gram')));
            testCase.verifyEqual(new.canonical(), 25.1);
            sn = new.source();
            testCase.verifyEqual(sn.source_value, 25.1);
            testCase.verifyEqual(sn.source_unit, "gram");
            testCase.verifyTrue(all(isnan(new.tolerance())) && isequal(size(new.tolerance()), [1 2]));
            testCase.verifyEqual(new.approximate(), false);
        end

        function testValueKeepsCellsOfAClassWithNoSourceNumeric(testCase)
            % count and date are not numeric value classes (no source_numeric):
            % their cells, one per reading, are read as before
            needSchema(testCase);
            c = ndi.value('count', struct('count', {3; 4}));
            testCase.verifyEqual(c.canonical(), [3; 4]);
        end

        function testValueReadsALogicalAndRefusesTheBareOne(testCase)
            testCase.verifyError(@() ndi.value('logical', [true false]), OLD, 'old shape: bare');
            new = ndi.value('logical', struct('logical', [true false]));
            testCase.verifyEqual(new.canonical(), [true false], 'new shape: {logical}');
        end

        function testValueReadsWhatTheBuilderWrites(testCase)
            needBuilders(testCase);
            cells = did2.build.valueCell('voltage', [0.001 0.002], 'SourceValue', [1 2], ...
                'Shape', 'new');
            v = ndi.value('voltage', cells);
            src = v.source();
            testCase.verifyEqual(reshape(v.canonical(), 1, []), [0.001 0.002], 'AbsTol', 1e-15);
            testCase.verifyEqual(reshape(src.source_value, 1, []), [1 2]);
            testCase.verifyEqual(size(v.tolerance(), 1), 2);
            old = did2.build.valueCell('voltage', [0.001 0.002], 'SourceValue', [1 2], ...
                'Shape', 'old');
            testCase.verifyError(@() ndi.value('voltage', old), OLD, 'old shape');
            lv = did2.build.valueCell('logical', true, 'Shape', 'new');
            lvv = ndi.value('logical', lv);
            testCase.verifyEqual(lvv.canonical(), true);
        end
    end
end

% =====================================================================

function id = OLD
% the error a reader gives for the old numeric shape
id = 'ndi:v2:oldNumericShapeReMigrate';
end

function x = t(name)
x = struct('node', '', 'name', name);
end

function e = one(x)
% the one entry a builder returned (a struct, or a cell holding it)
e = x;
if iscell(e), e = e{1}; end
e = e(1);
end

function needBuilders(testCase)
testCase.assumeTrue(~isempty(which('did2.build.numericShape')) && ...
    ~isempty(which('did2.schema.cache')) && did2.schema.cache.shared().hasClass('entity'), ...
    'no DID-matlab v2 builders that write both numeric shapes, or no v2 schema set');
% the made-up variables here are no registered terms
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

function needSchema(testCase)
testCase.assumeTrue(~isempty(which('did2.schema.cache')) && ...
    did2.schema.cache.shared().hasClass('voltage'), 'no v2 schema set');
end

function p = statementProps(kind, value)
% an observation's properties whose value kind is KIND, holding VALUE
p = struct();
p.document_class = struct('class_name', 'observation', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'statement', kind}), 'schema_version', 'did_v2');
p.base = struct('id', 'obs_1');
p.statement = struct('variable', t('x'));
p.(kind) = struct('value', value);
end
