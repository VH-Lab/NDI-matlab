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
%   Decided by Jess Haley, 2026-10-26 [control selection on the presentation
%   method] (did-schema V_eta_go_forward_class_audit.md): the record's
%   `control_stimulus_id_method` becomes method parameters on the
%   presentation's manipulation, and its `app` a `software` entity. Before
%   that decision both were dropped with the record.
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
                isfile(fullfile(schemaPath, 'item.json')), ...
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
            % no subject resolves -> a standalone item; a record with no
            % control selection still folds into its covariate, and the
            % document validates against the schema
            pres = presentationBody('pres_1', [1 2 1], 2);
            r = ndi.migrate.internal.bodyResolver({pres});
            ctl = controlDoc('cs_1', [2 2 2]);
            ctl.control_stimulus_ids = rmfield(ctl.control_stimulus_ids, ...
                'control_stimulus_id_method');
            [d, ~, rep] = ndi.migrate.internal.stimulusPresentationToItem(pres, r, [], ...
                'ControlRecords', {ctl}, 'LeaveUnplaced', false);
            testCase.verifyTrue(rep.standalone);
            c = covariateOf(d, 'control condition');
            testCase.verifyEqual(logical(c.logical(:)'), [false true false]);
            testCase.verifyEqual(rep.control_records_folded, 1);
            cache = did2.schema.cache.shared();
            restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
            testCase.verifyWarningFree(@() cache.validateDocument(d));
        end

        % ============ [control selection on the presentation method] =========

        function testAStandaloneItemLeavesARecordWithAMethodAsV1(testCase)
            % INVERTED (it folded the record and lost the method): an item
            % has no method, so under [generic stage is lossless] the record
            % is not folded -- no covariate, reason 'unplaced' -- and the end
            % of ndi.migrate.local carries it as v1
            pres = presentationBody('pres_1', [1 2 1], 2);
            r = ndi.migrate.internal.bodyResolver({pres});
            [d, ~, rep] = ndi.migrate.internal.stimulusPresentationToItem(pres, r, [], ...
                'ControlRecords', {controlDoc('cs_1', [2 2 2])}, 'LeaveUnplaced', false);
            testCase.verifyTrue(rep.standalone);
            testCase.verifyEmpty(covariateOf(d, 'control condition'));
            testCase.verifyEqual(rep.control_unfolded_reason, 'unplaced');
            testCase.verifyEqual(rep.control_unplaced_fields, ...
                {'control_stimulus_ids.control_stimulus_id_method'});
            testCase.verifyEqual(rep.control_records_folded, 0);
            testCase.verifyEqual(rep.control_method_parameters, 0);
        end

        function testARecordFieldTheFoldCannotPlaceLeavesItAsV1(testCase)
            ctl = controlDoc('cs_1', [2 2]);
            ctl.control_stimulus_ids.note = 'chosen by hand';
            [m, ~, r] = emit(ctl, [1 2]);
            testCase.verifyEmpty(covariateOf(m, 'control condition'));
            testCase.verifyEmpty(manipParam(m, 'control selection method'));
            testCase.verifyEqual(r.control_unfolded_reason, 'unplaced');
            testCase.verifyEqual(r.control_unplaced_fields, {'control_stimulus_ids.note'});
            ctl = withApp(controlDoc('cs_1', [2 2]), 'ndi_app_tuning_response', 'v9');
            ctl.app.build = '7';
            [~, ~, r] = emit(ctl, [1 2]);
            testCase.verifyEqual(r.control_unplaced_fields, {'app.build'});
            testCase.verifyEqual(r.software_minted, 0, 'an unfolded record mints nothing');
        end

        function testTheControlSelectionIsMethodParametersOnTheManipulation(testCase)
            % 20211116's record: method "pseudorandom", controlid "isblank",
            % controlid_value 1. Each a label variable with one value form.
            [m, ~, r] = emit(controlDoc('cs_1', [4 4 2 4]), [1 2 1 2]);
            testCase.verifyEqual(m.interaction.method.term.name, 'visual stimulation', ...
                'the delivery method is unchanged');
            testCase.verifyEqual(manipParam(m, 'control selection method'), 'pseudorandom');
            testCase.verifyEqual(manipParam(m, 'control identifier parameter'), 'isblank');
            testCase.verifyEqual(manipParam(m, 'control identifier value'), 1);
            testCase.verifyEqual(r.control_method_parameters, 3);
            testCase.verifyFalse(r.control_method_not_placed);
            % Dab's spelling is kept verbatim
            dab = controlDoc('cs_1', [4 4 2 4]);
            dab.control_stimulus_ids.control_stimulus_id_method.method = 'psuedorandom';
            m = emit(dab, [1 2 1 2]);
            testCase.verifyEqual(manipParam(m, 'control selection method'), 'psuedorandom');
        end

        function testNoFoldedRecordWritesNoControlSelection(testCase)
            [m, ~, r] = emit({}, [1 2 1]);
            testCase.verifyEmpty(manipParam(m, 'control selection method'));
            testCase.verifyEqual(r.control_method_parameters, 0);
            % a record that cannot be placed stays v1 whole: nothing of it
            % is written
            [m, ~, r] = emit(controlDoc('cs_1', [1 9]), [1 2]);
            testCase.verifyEmpty(manipParam(m, 'control selection method'));
            testCase.verifyEqual(r.control_method_parameters, 0);
            testCase.verifyEqual(r.software_minted, 0);
        end

        function testRecordsThatDisagreeOnTheMethodAreConflicting(testCase)
            a = controlDoc('cs_1', [2 2]);
            b = controlDoc('cs_2', [2 2]);
            b.control_stimulus_ids.control_stimulus_id_method.method = 'sequential';
            [m, ~, r] = emit({a, b}, [1 2]);
            testCase.verifyEmpty(covariateOf(m, 'control condition'));
            testCase.verifyEqual(r.control_unfolded_reason, 'conflicting');
            testCase.verifyTrue(r.control_method_conflict);
            testCase.verifyEqual(r.control_records_folded, 0);
            testCase.verifyEmpty(manipParam(m, 'control selection method'));
        end

        function testTheControlAppBecomesASoftwareEntity(testCase)
            % the presentation has no app: the control's is the software_id
            ctl = withApp(controlDoc('cs_1', [2 2]), 'ndi_app_tuning_response', 'v9');
            [m, ~, r, sw] = emit(ctl, [1 2]);
            testCase.verifyNumElements(sw, 2, 'the entity and its version assertion');
            testCase.verifyEqual(sw{1}.entity.name, 'ndi_app_tuning_response');
            testCase.verifyEqual(sw{1}.entity.local_identifier, 'ndi_app_tuning_response@v9');
            testCase.verifyEqual(depValue(m, 'software_id'), sw{1}.base.id);
            testCase.verifyEqual(r.software_minted, 1);
            testCase.verifyEqual(r.software_unreferenced, 0);
            % the presentation has its own app: software_id is ONE edge, so
            % the control's program is minted and counted unreferenced
            pres = withApp(presentationBody('pres_1', [1 2], 2), ...
                'ndi_app_stimulus_decoder', 'v9');
            [m, ~, r, sw] = emitPres(pres, ctl);
            testCase.verifyNumElements(sw, 4);
            testCase.verifyEqual(depValue(m, 'software_id'), sw{1}.base.id);
            testCase.verifyEqual(sw{1}.entity.name, 'ndi_app_stimulus_decoder');
            testCase.verifyEqual(r.software_minted, 2);
            testCase.verifyEqual(r.software_unreferenced, 1);
            % the same program and version: one entity
            same = withApp(controlDoc('cs_1', [2 2]), 'ndi_app_stimulus_decoder', 'v9');
            [~, ~, r, sw] = emitPres(pres, same);
            testCase.verifyNumElements(sw, 2);
            testCase.verifyEqual(r.software_minted, 1);
            % the run environment has no slot on a manipulation: counted
            testCase.verifyEqual(sort(r.app_environment_not_written), sort({ ...
                'app.os', 'app.interpreter', ...
                'control_stimulus_ids.app.os', 'control_stimulus_ids.app.interpreter'}));
        end
    end
end

% ===================== driver and fixtures ================================

function [m, methods, report, software] = emitPres(pres, controls)
bodies = { pres, ...
    docBody('stimulus_response_scalar', 'resp_1', ...
        {'stimulus_presentation_id', pres.base.id}, {'element_id', 'elem_9'}), ...
    docBody('element', 'elem_9', {'subject_id', 'animal_1'}) };
bodies{2}.document_class.superclasses = [ ...
    struct('definition', '$NDIDOCUMENTPATH/base.json'), ...
    struct('definition', '$NDIDOCUMENTPATH/stimulus/stimulus_response.json')];
r = ndi.migrate.internal.bodyResolver(bodies);
if ~iscell(controls), controls = {controls}; end
[m, methods, report, software] = ndi.migrate.internal.stimulusPresentationToItem( ...
    pres, r, [], 'ControlRecords', controls, 'LeaveUnplaced', false);
end

function d = withApp(d, name, version)
% the v1 app block as NDI's app.json writes it (20211116's values)
d.app = struct('name', name, 'version', version, ...
    'url', 'https://github.com/VH-lab/NDI-matlab', 'os', 'MACA64', ...
    'os_version', '', 'interpreter', 'MATLAB', 'interpreter_version', '');
end

function v = manipParam(m, variable)
% the value of the manipulation's inline method parameter VARIABLE, or []
v = [];
if ~isfield(m, 'interaction') || ~isfield(m.interaction, 'method') ...
        || ~isfield(m.interaction.method, 'parameters')
    return;
end
p = m.interaction.method.parameters;
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
    return;
end
end

function [m, methods, report, software] = emit(controls, order, nStimuli, sequence)
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
[m, methods, report, software] = ndi.migrate.internal.stimulusPresentationToItem(pres, r, ...
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
