classdef TestControlCovariate < matlab.unittest.TestCase
%TESTCONTROLCOVARIATE A v1 control_stimulus_ids record as the `control
%   condition` covariate of its presentation's item value.
%
%   Decided by Jess Haley, 2026-10-22 [control as covariate] (did-schema
%   V_eta_stimulus_response_model_plan.md; data_body plan AMENDMENT 6): the
%   control of a stimulus presentation is a `logical` covariate `control
%   condition` (XCO:0000099) along the presentation dimension of the stimulus
%   `item` value, true where the presentation was a control. A v1 record
%   saying no trial was a control (NaN) gives all false; a presentation with
%   no v1 control record gives no covariate. The record becomes no V2
%   document. This replaces TestControlCalculation, which asserted the
%   superseded [control record is a calculation] and the withdrawn
%   [control record with no control] (a logical-false calculation).
%
%   Amended by Jess Haley, 2026-10-26 [control pairing is a calculation]
%   (did-schema V_eta_go_forward_class_audit.md; it replaces [control
%   selection on the presentation method]): the record is NOT dropped. It
%   becomes a `calculation` about the presentation -- software from its
%   `app`, method = the pairing rule verbatim, value = the per-trial pairing
%   -- when it can be placed whole, and is otherwise carried as v1. The
%   covariate stays.
%
%   ndi.migrate.internal.stimulusPresentationToItem builds the covariate from
%   'ControlRecords'; ndi.migrate.local's stimulus pass hands it the records
%   and drops the folded ones (TestMigrateLocalEta20211116 checks that on a
%   corpus).

    methods (TestClassSetup)
        function needsBuilder(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.covariate')), ...
                'needs DID-matlab did2.build with dimensions and covariates');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'item.json')), ...
                'DID_SCHEMA_PATH does not hold did-schema #88 (`item`)');
        end
    end

    methods (Test)
        function testTheTrialsARecordNamesAreTheControls(testCase)
            % 4 trials; per trial, v1 names the trial of its control: trials
            % 2 and 4 are the controls
            [m, ~, r] = emit(controlDoc('cs_1', [4 4 2 4]), [1 2 1 2]);
            c = covariateOf(m, 'control condition');
            testCase.verifyNotEmpty(c);
            testCase.verifyEqual(c.variable.node, 'XCO:0000099');
            testCase.verifyEqual(double(c.along(:)'), 0, ...
                'along the presentation dimension');
            testCase.verifyEqual(logical(c.logical(:)'), [false true false true]);
            testCase.verifyEqual(r.control_records, 1);
            testCase.verifyEqual(r.control_records_folded, 1);
            testCase.verifyEqual(r.control_true, 2);
            testCase.verifyEmpty(r.control_unfolded_reason);
            testCase.verifyFalse(isfield(m.item.value, 'control_item'));
        end

        function testEntriesAreTrialNumbersNotStimulusNumbers(testCase)
            % B's shape: 12 stimuli, 20 trials here; entries 11 and 20 name
            % TRIALS (both show stimulus 12, the blank). Read as stimulus
            % numbers 20 would be out of range.
            order = [6 2 10 4 11 3 1 5 9 8 12 7 8 4 9 3 2 6 1 12];
            [m, ~, r] = emit(controlDoc('cs_1', [11 11 20]), order, 12);
            c = covariateOf(m, 'control condition');
            expected = false(1, 20); expected([11 20]) = true;
            testCase.verifyEqual(logical(c.logical(:)'), expected);
            testCase.verifyEqual(r.control_true, 2);
        end

        function testNaNOrEmptyGivesAllFalse(testCase)
            % "A v1 record saying no trial was a control (NaN) gives all false"
            for v = {NaN, [], [NaN NaN]}
                [m, ~, r] = emit(controlDoc('cs_1', v{1}), [1 2 1]);
                c = covariateOf(m, 'control condition');
                testCase.verifyNotEmpty(c);
                testCase.verifyEqual(logical(c.logical(:)'), false(1, 3));
                testCase.verifyEqual(r.control_records_folded, 1);
                testCase.verifyEqual(r.control_true, 0);
            end
        end

        function testNoRecordGivesNoCovariate(testCase)
            [m, ~, r] = emit({}, [1 2 1]);
            testCase.verifyEmpty(covariateOf(m, 'control condition'));
            testCase.verifyEqual(r.control_records, 0);
            testCase.verifyEqual(r.control_records_folded, 0);
        end

        function testRecordsThatCannotBePlacedGiveNoCovariateAndSayWhy(testCase)
            % an entry outside the trials, or NaN among numbers
            for v = {[1 9], [1 NaN]}
                [m, ~, r] = emit(controlDoc('cs_1', v{1}), [1 2]);
                testCase.verifyEmpty(covariateOf(m, 'control condition'));
                testCase.verifyEqual(r.control_unfolded_reason, 'unmappable');
                testCase.verifyEqual(r.control_records_folded, 0);
            end
            % two records that disagree
            [m, ~, r] = emit({controlDoc('cs_1', [2 2]), controlDoc('cs_2', [1 1])}, [1 2]);
            testCase.verifyEmpty(covariateOf(m, 'control condition'));
            testCase.verifyEqual(r.control_unfolded_reason, 'conflicting');
            % two that agree fold together
            [m, ~, r] = emit({controlDoc('cs_1', [2 2]), controlDoc('cs_2', [2 2])}, [1 2]);
            c = covariateOf(m, 'control condition');
            testCase.verifyEqual(logical(c.logical(:)'), [false true]);
            testCase.verifyEqual(r.control_records_folded, 2);
        end

        function testOnAFrameSequenceOnlyNoControlCanBePlaced(testCase)
            % the supplied enumeration's dimension is FRAMES, not the v1
            % trials a record names: a NaN record (all false) still places;
            % a trial list does not ('no position map')
            seq = struct('item_ids', {{'g_a', 'g_b'}}, 'order', [1 2 1 2 1]);
            [m, ~, r] = emit(controlDoc('cs_1', NaN), 1, 1, seq);
            c = covariateOf(m, 'control condition');
            testCase.verifyEqual(logical(c.logical(:)'), false(1, 5));
            testCase.verifyEqual(r.control_records_folded, 1);
            [m, ~, r] = emit(controlDoc('cs_1', 1), 1, 1, seq);
            testCase.verifyEmpty(covariateOf(m, 'control condition'));
            testCase.verifyEqual(r.control_unfolded_reason, 'no position map');
        end

        function testAStandaloneItemCarriesItsControlAndValidates(testCase)
            % no subject resolves -> a standalone item; its value still gets
            % the covariate, and the document validates against the schema
            pres = presentationBody('pres_1', [1 2 1], 2);
            r = ndi.migrate.internal.bodyResolver({pres});
            [d, ~, rep] = ndi.migrate.internal.stimulusPresentationToItem(pres, r, [], ...
                'ControlRecords', {controlDoc('cs_1', [2 2 2])}, 'LeaveUnplaced', false);
            testCase.verifyTrue(rep.standalone);
            c = covariateOf(d, 'control condition');
            testCase.verifyEqual(logical(c.logical(:)'), [false true false]);
            % no subject, so no calculation: the record is carried as v1
            testCase.verifyEqual(rep.control_calculations, 0);
            testCase.verifyEmpty(rep.control_converted_ids);
            testCase.verifySubstring(rep.control_carried{1}.reason, 'standalone');
            cache = did2.schema.cache.shared();
            restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
            testCase.verifyWarningFree(@() cache.validateDocument(d));
        end

        % ============ [control pairing is a calculation] ====================

        function testARecordBecomesAPairingCalculation(testCase)
            % 4 trials; v1 pairs trials 1,2,4 with trial 4 and trial 3 with 2
            ctl = withApp(controlDoc('cs_1', [4 4 2 4]));
            [m, ~, r, sw, calcs] = emit(ctl, [1 2 1 2]);
            testCase.verifyNumElements(calcs, 1);
            c = calcs{1};
            testCase.verifyEqual(c.document_class.class_name, 'calculation');
            testCase.verifyEqual(c.base.id, 'cs_1', 'the v1 id is kept');
            testCase.verifyEqual(depValue(c, 'entity_id'), 'animal_1');
            testCase.verifyEqual(depValue(c, 'input_id'), 'pres_1');
            testCase.verifyEqual(c.statement.variable.name, 'control trial');
            testCase.verifyEqual(arrayfun(@(v) double(v.count), c.count.value(:)'), ...
                [3 3 1 3], 'per trial, the 0-based control trial');
            d = dimensionsOf(c);
            testCase.verifyNumElements(d, 1);
            testCase.verifyEqual(char(d{1}.term.node), 'OBI:0000807');
            testCase.verifyEqual(double(d{1}.n), 4);
            % the rule, verbatim
            testCase.verifyEqual(c.interaction.method.term.name, 'control stimulus pairing');
            testCase.verifyEqual(calcParam(c, 'method'), 'pseudorandom');
            testCase.verifyEqual(calcParam(c, 'controlid'), 'isblank');
            testCase.verifyEqual(calcParam(c, 'controlid_value'), 1);
            % the software, and the run environment on the calculation's edges
            ids = cellfun(@(x) x.base.id, sw, 'UniformOutput', false);
            names = cellfun(@entityName, sw, 'UniformOutput', false);
            swId = depValue(c, 'software_id');
            testCase.verifyEqual(names{strcmp(ids, swId)}, 'ndi_app_tuning_response');
            testCase.verifyEqual(names{strcmp(ids, depValue(c, 'operating_system_id'))}, 'MACA64');
            testCase.verifyEqual(names{strcmp(ids, depValue(c, 'interpreter_id'))}, 'MATLAB');
            % the time marker, as on the manipulation
            testCase.verifyEqual(depValue(c, did2.convert.mintSessionDuring('marker')), 'cs_1');
            % the covariate stays
            testCase.verifyNotEmpty(covariateOf(m, 'control condition'));
            testCase.verifyEqual(r.control_calculations, 1);
            testCase.verifyEqual(r.control_converted_ids, {'cs_1'});
            testCase.verifyEmpty(r.control_carried);
            % it validates once its time reference is minted
            v = c;
            v.depends_on = v.depends_on(~strcmp({v.depends_on.name}, ...
                did2.convert.mintSessionDuring('marker')));
            e = v.depends_on(1); e.name = 'time_reference_id';
            if isfield(e, 'document_id'), e.document_id = 'tref_1'; else, e.value = 'tref_1'; end
            v.depends_on(end+1) = e;
            cache = did2.schema.cache.shared();
            restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
            testCase.verifyWarningFree(@() cache.validateDocument(v), ...
                'the pairing calculation does not validate');
        end

        function testDabsSpellingIsKeptVerbatim(testCase)
            ctl = controlDoc('cs_1', [2 2]);
            ctl.control_stimulus_ids.control_stimulus_id_method.method = 'psuedorandom';
            [~, ~, ~, ~, calcs] = emit(ctl, [1 2]);
            testCase.verifyEqual(calcParam(calcs{1}, 'method'), 'psuedorandom');
        end

        function testANaNControlIsConvertedAsNoControl(testCase)
            % [NaN control means no control] (Jess Haley, 2026-10-26): NDI's
            % tuning_response writes NaN for a trial with no control, so the
            % record converts and the calculation records NaN for that trial.
            [~, ~, r, ~, calcs] = emit(controlDoc('cs_1', [2 NaN 2]), [1 2 1]);
            testCase.verifyEmpty(r.control_carried);
            testCase.verifyNumElements(calcs, 1);
            c = calcs{1};
            got = arrayfun(@(v) double(v.count), c.count.value(:)');
            testCase.verifyEqual(got([1 3]), [1 1]);
            testCase.verifyTrue(isnan(got(2)), 'the trial with no control records NaN');
        end

        function testTheAppsOSAndInterpreterVersionsGoToTheSoftwareEntities(testCase)
            % [control record fields split] (Jess Haley, 2026-10-27): the
            % `app` fields beyond name/version/url/os/interpreter -- the
            % writer's os_version and interpreter_version (ndi.app
            % newdocument) -- go to the software entities, as [presentation
            % app is software]: each is the version of its program's entity.
            ctl = withApp(controlDoc('cs_1', [2 2]));
            [~, ~, r, sw, calcs] = emit(ctl, [1 2]);
            testCase.verifyNumElements(calcs, 1);
            testCase.verifyEmpty(r.control_carried);
            ids = cellfun(@(x) x.base.id, sw, 'UniformOutput', false);
            lids = cellfun(@localId, sw, 'UniformOutput', false);
            testCase.verifyEqual(lids{strcmp(ids, depValue(calcs{1}, 'operating_system_id'))}, ...
                'MACA64@15.6.1');
            testCase.verifyEqual(lids{strcmp(ids, depValue(calcs{1}, 'interpreter_id'))}, ...
                'MATLAB@24.2');
        end

        function testARecordThatCannotBePlacedWholeIsCarriedAsV1(testCase)
            % empty: no pairing at all
            [~, ~, r, ~, calcs] = emit(controlDoc('cs_1', []), [1 2 1]);
            testCase.verifyEmpty(calcs);
            testCase.verifySubstring(r.control_carried{1}.reason, '[carry-091]');
            % B's shape: fewer entries than trials
            order = [6 2 10 4 11 3 1 5 9 8 12 7 8 4 9 3 2 6 1 12];
            [~, ~, r, ~, calcs] = emit(controlDoc('cs_1', [11 11 20]), order, 12);
            testCase.verifyEmpty(calcs);
            testCase.verifySubstring(r.control_carried{1}.reason, '3 pairing entr');
            % a field outside the template. [control record fields split]
            % (Jess Haley, 2026-10-27, did-schema
            % V_eta_go_forward_class_audit.md): carry-100 (malformed), no
            % longer carry-089
            ctl = controlDoc('cs_1', [2 2]);
            ctl.control_stimulus_ids.note = 'chosen by hand';
            [~, ~, r, ~, calcs] = emit(ctl, [1 2]);
            testCase.verifyEmpty(calcs);
            testCase.verifySubstring(r.control_carried{1}.reason, 'control_stimulus_ids.note');
            testCase.verifySubstring(r.control_carried{1}.reason, '[carry-100]');
            % an app field outside app.json: carry-100 too
            ctl = withApp(controlDoc('cs_1', [2 2]));
            ctl.app.build = '7';
            [~, ~, r, sw, calcs] = emit(ctl, [1 2]);
            testCase.verifyEmpty(calcs);
            testCase.verifyEmpty(sw, 'a carried record mints nothing');
            testCase.verifySubstring(r.control_carried{1}.reason, 'app.build');
            testCase.verifySubstring(r.control_carried{1}.reason, '[carry-100]');
            % an edge outside the template (the writer sets only
            % stimulus_presentation_id): carry-100 too
            ctl = controlDoc('cs_1', [2 2]);
            ctl.depends_on(end+1) = struct('name', 'element_id', 'value', 'elem_9');
            [~, ~, r, ~, calcs] = emit(ctl, [1 2]);
            testCase.verifyEmpty(calcs);
            testCase.verifySubstring(r.control_carried{1}.reason, '[carry-100]');
            testCase.verifySubstring(r.control_carried{1}.reason, 'element_id');
            % a frame sequence: the trials are not the dimension
            seq = struct('item_ids', {{'g_a', 'g_b'}}, 'order', [1 2 1 2 1]);
            [~, ~, r, ~, calcs] = emit(controlDoc('cs_1', 1), 1, 1, seq);
            testCase.verifyEmpty(calcs);
            testCase.verifySubstring(r.control_carried{1}.reason, 'frame sequence');
        end
    end
end

% ===================== driver and fixtures ================================

function d = withApp(d)
% 20211116's control record app block
d.app = struct('name', 'ndi_app_tuning_response', ...
    'version', 'fa67d45d0d957ce9ab3bb2e272a6799f02333996', ...
    'url', 'https://github.com/VH-lab/NDI-matlab', 'os', 'MACA64', ...
    'os_version', '15.6.1', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
end

function n = entityName(doc)
n = '';
if isfield(doc, 'entity') && isfield(doc.entity, 'name'); n = char(doc.entity.name); end
end

function n = localId(doc)
n = '';
if isfield(doc, 'entity') && isfield(doc.entity, 'local_identifier')
    n = char(doc.entity.local_identifier);
end
end

function v = calcParam(c, variable)
v = [];
p = c.interaction.method.parameters;
if isstruct(p); p = num2cell(p); end
for k = 1:numel(p)
    if ~strcmp(p{k}.variable.name, variable); continue; end
    e = p{k};
    if isfield(e, 'text') && ~isempty(e.text); v = e.text;
    elseif isfield(e, 'quantity') && ~isempty(e.quantity); v = e.quantity.value;
    elseif isfield(e, 'count') && ~isempty(e.count); v = e.count; end
    return;
end
end

function v = depValue(b, name)
v = '';
if ~isfield(b, 'depends_on'); return; end
for k = 1:numel(b.depends_on)
    d = b.depends_on(k);
    if ~strcmp(d.name, name); continue; end
    if isfield(d, 'document_id'); v = d.document_id; else; v = d.value; end
    if iscell(v) && ~isempty(v); v = v{1}; end
    return;
end
end

function d = dimensionsOf(b)
d = {};
if isfield(b, 'data') && isfield(b.data, 'dimensions')
    d = ndi.v2.entries(b.data.dimensions);
end
end

function [m, methods, report, software, calcs] = emit(controls, order, nStimuli, sequence)
if nargin < 3, nStimuli = max(order); end
if nargin < 4, sequence = []; end
if ~iscell(controls), controls = {controls}; end
pres = presentationBody('pres_1', order, nStimuli);
bodies = { pres, ...
    docBody('stimulus_response_scalar', 'resp_1', ...
        {'stimulus_presentation_id', 'pres_1'}, {'element_id', 'elem_9'}), ...
    docBody('element', 'elem_9', {'subject_id', 'animal_1'}) };
bodies{2}.document_class.superclasses = [ ...
    struct('definition', '$NDIDOCUMENTPATH/base.json'), ...
    struct('definition', '$NDIDOCUMENTPATH/stimulus/stimulus_response.json')];
r = ndi.migrate.internal.bodyResolver(bodies);
[m, methods, report, software, calcs] = ndi.migrate.internal.stimulusPresentationToItem(pres, r, ...
    sequence, 'ControlRecords', controls, 'LeaveUnplaced', false);
end

function b = presentationBody(id, order, nStimuli)
b = struct();
b.document_class = struct('class_name', 'stimulus_presentation');
b.depends_on = struct('name', {'stimulus_element_id'}, ...
    'value', {'4126943ebaa51186_40d4b41387c4b1a3'});
b.base = struct('id', id, 'session_id', '4126943eba883b79_40dfd8222e0301f0', ...
    'name', '', 'datestamp', '2025-09-11T12:48:21.932Z');
b.epochid = struct('epochid', 't00001');
b.stimulus_presentation = struct();
b.stimulus_presentation.presentation_order = order;
stimuli = cell(1, nStimuli);
for k = 1:nStimuli
    stimuli{k} = gratingStim(15 * k);
end
b.stimulus_presentation.stimuli = stimuli;
end

function s = gratingStim(angle)
s = struct('parameters', struct( ...
    'imageType', 2, 'animType', 4, 'flickerType', 0, 'angle', angle, ...
    'chromhigh', [255 255 255], 'chromlow', [0 0 0], ...
    'sFrequency', 0.04, 'sPhaseShift', 0, 'distance', 57, ...
    'tFrequency', 0.5, 'barWidth', 0.5, 'rect', [0 0 800 600], 'nCycles', 1, ...
    'contrast', 1, 'background', 0.5, 'backdrop', 0.5, 'barColor', 1, ...
    'nSmoothPixels', 2, 'fixedDur', 0, 'windowShape', 0, 'loops', 0, ...
    'dispprefs', {{'BGposttime', 3}}));
end

function d = controlDoc(id, ids)
d = struct();
d.document_class = struct('class_name', 'control_stimulus_ids', 'class_version', 1);
d.depends_on = struct('name', 'stimulus_presentation_id', 'value', 'pres_1');
d.base = struct('id', id, 'session_id', '4126943eba883b79_40dfd8222e0301f0', ...
    'name', '', 'datestamp', '2025-09-11T12:48:55.182Z');
d.control_stimulus_ids = struct('control_stimulus_ids', ids, ...
    'control_stimulus_id_method', struct('method', 'pseudorandom', ...
        'controlid', 'isblank', 'controlid_value', 1));
end

function b = docBody(className, id, varargin)
b = struct();
b.document_class = struct('class_name', className);
deps = struct('name', {}, 'value', {});
for k = 1:numel(varargin)
    pair = varargin{k};
    deps(end+1) = struct('name', pair{1}, 'value', pair{2}); %#ok<AGROW>
end
b.depends_on = deps;
b.base = struct('id', id);
end

function c = covariateOf(b, name)
c = [];
if ~isfield(b, 'data') || ~isfield(b.data, 'covariates'); return; end
cs = ndi.v2.entries(b.data.covariates);
for k = 1:numel(cs)
    v = cs{k}.variable;
    if iscell(v), v = v{1}; end
    if isstruct(v) && strcmp(char(v.name), name)
        c = cs{k};
        return;
    end
end
end
