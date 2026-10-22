classdef TestStimulusPresentationCohort < matlab.unittest.TestCase
%TESTSTIMULUSPRESENTATIONCOHORT Several animals: one manipulation of the
%   session's cohort, `distributive` true; never N copies.
%
%   Jess Haley, 2026-10-21 (V_eta_stimulus_model_plan.md, "Who received a
%   presentation", decision 2): several animals in one session get ONE
%   manipulation on the session's cohort -- a standing group (the animals
%   recorded together in that session), reused by every presentation in it --
%   marked `distributive`. A single-animal presentation still names its
%   animal. Stimulator links that lead to different animals are refused
%   (decision 4; TestStimulusPresentationItem). ndi.migrate.local owns the
%   cohort (one id per session); the assembler asks for it through
%   'CohortIdFor', and ndi.migrate.internal.sessionCohort builds it.
%
%   Needs did2.build and a did-schema #88 set on DID_SCHEMA_PATH.

    methods (TestClassSetup)
        function needTheV2Builder(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.statement')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(fullfile(schemaPath, 'item.json')) && ...
                isfile(fullfile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold did-schema #88 (`item`, `entity`)');
        end
    end

    methods (Test)

        function testSeveralAnimalsPointAtTheCohortDistributively(testCase)
            [m, methods, report] = emit2(testCase, @(sid) 'cohort_1');
            testCase.verifyNotEmpty(m, 'ONE manipulation');
            testCase.verifyEqual(m.base.id, 'pres_multi', 'the v1 id is kept');
            testCase.verifyEqual(depValue(m, 'entity_id'), 'cohort_1');
            testCase.verifyTrue(isequal(m.statement.distributive, true));
            testCase.verifyEqual(numel(methods), 4);
            testCase.verifyEqual(report.several_animals, 2);
            testCase.verifyEqual(sort(report.animals), {'animal_1', 'animal_2'});
            testCase.verifyTrue(report.distributive);
            testCase.verifyEmpty(report.reason);
        end

        function testTheCohortIsAskedForByTheSessionId(testCase)
            asked = containers.Map('KeyType', 'char', 'ValueType', 'double');
            emit2(testCase, @(sid) recordAndReturn(asked, sid, 'cohort_1'));
            testCase.verifyEqual(asked.keys(), {'4126943eba883b79_40dfd8222e0301f0'});
        end

        function testWithoutACohortTheyAreRefusedAndCounted(testCase)
            [m, methods, report] = emit2(testCase, []);
            testCase.verifyEmpty(m);
            testCase.verifyEmpty(methods);
            testCase.verifyEqual(report.several_animals, 2);
            testCase.verifySubstring(report.reason, 'several animals');
        end

        function testOneAnimalIsNotCountedAsSeveralNorDistributive(testCase)
            pres = presentationBody('pres_solo', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            bodies = { pres, ...
                responseScalar('resp_1', 'pres_solo', 'elem_9'), ...
                docBody('element', 'elem_9', {'subject_id', 'animal_1'}) };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [m, ~, report] = ndi.migrate.internal.stimulusPresentationToItem( ...
                pres, r, [], 'CohortIdFor', @(sid) 'cohort_1');
            testCase.verifyEqual(report.several_animals, 0);
            testCase.verifyFalse(report.distributive);
            testCase.verifyEqual(depValue(m, 'entity_id'), 'animal_1', ...
                'a single-animal presentation still names its animal');
        end

        function testTheSessionCohortIsAGroupWithMemberOfEdges(testCase)
            docs = ndi.migrate.internal.sessionCohort('cohort_1', 'sess_1', ...
                {'animal_1', 'animal_2'}, '2025-09-11T12:48:21.932Z');
            testCase.verifyEqual(numel(docs), 3);
            c = docs{1};
            testCase.verifyEqual(c.document_class.class_name, 'entity');
            testCase.verifyEqual(c.base.id, 'cohort_1');
            testCase.verifyTrue(ndi.v2.vocabIs('entity_type', c.entity.type, 'group'));
            testCase.verifyNotEmpty(c.entity.local_identifier, ...
                'a group requires a local_identifier');
            for k = 2:3
                rel = docs{k};
                testCase.verifyEqual(rel.document_class.class_name, 'directed_relation');
                testCase.verifyTrue(ndi.v2.vocabIs('relation', rel.directed_relation.relation, 'member_of'));
                testCase.verifyEqual(depValue(rel, 'parent_id'), 'cohort_1');
            end
            testCase.verifyEqual(depValue(docs{2}, 'child_id'), 'animal_1');
            testCase.verifyEqual(depValue(docs{3}, 'child_id'), 'animal_2');
        end

        function testTheResolverListsTheAnimalsRecordedInASession(testCase)
            sid = 'sess_1';
            ee1 = docBody('element_epoch', 'ee_1', {'element_id', 'unit_1'});
            ee1.base.session_id = sid; ee1.epochid = struct('epochid', 't00001');
            ee2 = docBody('element_epoch', 'ee_2', {'element_id', 'unit_2'});
            ee2.base.session_id = sid; ee2.epochid = struct('epochid', 't00002');
            ee3 = docBody('element_epoch', 'ee_3', {'element_id', 'unit_3'});
            ee3.base.session_id = 'other'; ee3.epochid = struct('epochid', 't00001');
            bodies = { ee1, ee2, ee3, ...
                docBody('element', 'unit_1', {'subject_id', 'animal_1'}), ...
                docBody('element', 'unit_2', {'subject_id', 'animal_2'}), ...
                docBody('element', 'unit_3', {'subject_id', 'animal_3'}) };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(sort(r.subjectsRecordedInSession(sid)), ...
                {'animal_1', 'animal_2'});
        end

    end
end

function id = recordAndReturn(asked, sid, id)
asked(sid) = 1; %#ok<NASGU> containers.Map is a handle
end

function [manipBody, methodBodies, report] = emit2(~, cohortIdFor)
stimuli = { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5), ...
            gratingStim(90, 0.04, 0.5), blankStim() };
pres = presentationBody('pres_multi', [1 4 2 4 3 1], stimuli);
bodies = { pres, ...
    responseScalar('resp_1', 'pres_multi', 'elem_1'), ...
    responseScalar('resp_2', 'pres_multi', 'elem_2'), ...
    docBody('element', 'elem_1', {'subject_id', 'animal_1'}), ...
    docBody('element', 'elem_2', {'subject_id', 'animal_2'}) };
r = ndi.migrate.internal.bodyResolver(bodies);
[manipBody, methodBodies, report] = ndi.migrate.internal.stimulusPresentationToItem( ...
    pres, r, [], 'CohortIdFor', cohortIdFor);
end

function b = responseScalar(id, presentationId, elementId)
b = docBody('stimulus_response_scalar', id, ...
    {'stimulus_presentation_id', presentationId}, {'element_id', elementId});
b.document_class.superclasses = [ ...
    struct('definition', '$NDIDOCUMENTPATH/base.json'), ...
    struct('definition', '$NDIDOCUMENTPATH/stimulus/stimulus_response.json')];
end

function b = stimulatorElement(id, subjectId, sessionId)
b = docBody('element', id, {'subject_id', subjectId});
b.base.session_id = sessionId;
end

function id = stimulatorIdOf(pres)
id = depValue(pres, 'stimulus_element_id');
end

function verifyNoEmptyEdges(testCase, body)
if ~isfield(body, 'depends_on') || isempty(body.depends_on)
    return;
end
for k = 1:numel(body.depends_on)
    testCase.verifyNotEmpty(depValues(body, body.depends_on(k).name), ...
        sprintf('depends_on "%s" was emitted with an empty value', ...
            body.depends_on(k).name));
    ids = depValues(body, body.depends_on(k).name);
    for j = 1:numel(ids)
        testCase.verifyNotEmpty(ids{j}, sprintf('depends_on "%s" is empty', ...
            body.depends_on(k).name));
    end
end
end

% ===================== fixtures, from real 20211116 documents =============

function b = presentationBody(id, order, stimuli)
%PRESENTATIONBODY The real shape: block = {presentation_order, stimuli}, the
%   times in an attached file, one `stimulus_element_id` dep, an epochid block.
%   Transcribed from 4126943ebbdd014f_40c471eb4e8ea86d.json and siblings.
b = struct();
b.document_class = struct('class_name', 'stimulus_presentation');
b.depends_on = struct('name', {'stimulus_element_id'}, ...
    'value', {'4126943ebaa51186_40d4b41387c4b1a3'});
b.base = struct('id', id, ...
    'session_id', '4126943eba883b79_40dfd8222e0301f0', ...
    'name', '', 'datestamp', '2025-09-11T12:48:21.932Z');
b.epochid = struct('epochid', 't00001');
b.files = struct('file_list', {{'presentation_time.bin'}});
b.stimulus_presentation = struct();
b.stimulus_presentation.presentation_order = order;
b.stimulus_presentation.stimuli = stimuli;
end

function s = gratingStim(angle, sFrequency, tFrequency)
%GRATINGSTIM The 24-key periodic-grating parameter set, verbatim from the
%   225-stimulus document (4126943ebbdf85c2_c0d0b567f5cca85b.json, stimuli[0]);
%   only the three varying quantities are arguments.
s = struct('parameters', struct( ...
    'imageType', 2, 'animType', 4, 'flickerType', 0, ...
    'angle', angle, ...
    'chromhigh', [255 255 255], 'chromlow', [0 0 0], ...
    'sFrequency', sFrequency, 'sPhaseShift', 0, 'distance', 57, ...
    'tFrequency', tFrequency, 'barWidth', 0.5, ...
    'rect', [0 0 800 600], 'nCycles', 1, 'contrast', 1, ...
    'background', 0.5, 'backdrop', 0.5, 'barColor', 1, ...
    'nSmoothPixels', 2, 'fixedDur', 0, 'windowShape', 0, 'loops', 0, ...
    'dispprefs', {{'BGposttime', 3}}, ...
    'phaseSteps', [], 'phaseSequence', []));
end

function s = blankStim()
%BLANKSTIM The 11-key blank, verbatim from stimuli[225] of the same document.
%   `randState` is elided to its first three entries -- the value carries none
%   of it, and its length is not what any assertion here turns on.
s = struct('parameters', struct( ...
    'BG', [127.5 127.5 127.5], 'dist', 1, 'values', [127.5 127.5 127.5], ...
    'rect', [0 0 1 1], 'angle', 0, 'pixSize', [1 1], 'N', 1, 'fps', 0.5, ...
    'randState', [0.8301061479240671 0.6704957765200832 0.08449867537860833], ...
    'dispprefs', {{'BGpretime', 0, 'BGposttime', 3}}, ...
    'isblank', 1));
end

function s = hartleyGeneratorStim()
%HARTLEYGENERATORSTIM The 16-key white-noise GENERATOR spec, verbatim from
%   4126943ebbdd014f_40c471eb4e8ea86d.json -- the shape 10 of the 11 20211116
%   presentations carry, as their single stimulus. Note what is NOT here:
%   angle, sFrequency, tFrequency.
s = struct('parameters', struct( ...
    'rect', [-7 -138 793 662], 'windowShape', 0, 'distance', 30, ...
    'M', 200, 'K_absmax', 20, 'L_absmax', 20, 'sfmax', 5, 'contrast', 1, ...
    'chromhigh', [255 255 255], 'chromlow', [0 0 0], ...
    'background', 0.5, 'backdrop', 0.5, 'reps', 1, 'fps', 10, ...
    'randState', [0.8301061479240671 0.6704957765200832 0.08449867537860833], ...
    'dispprefs', {{'BGposttime', 3}}));
end

function s = barStim(lineoffset)
%BARSTIM periodicstim imageType 0, windowShape 2 (oriented rectangle), a
%   7-pixel-tall rect -- one light bar of Dab's flashed-bar map (census key set
%   "periodicstim + linenumber lineoffset", 17,260 stimuli).
s = gratingStim(0, 0.1, 0);
s.parameters.imageType = 0;
s.parameters.animType = 0;
s.parameters.windowShape = 2;
s.parameters.rect = [-57 336 743 343];
s.parameters.linenumber = 1;
s.parameters.lineoffset = lineoffset;
end

function s = noiseStim(seed)
%NOISESTIM Soph's stochasticgridstim noise: key set {BG N angle dispprefs dist
%   fps pixSize randState rect values}, N 100, pixSize [50 50], rect
%   [0 0 800 600], 2-colour B/W values, angle 0, fps 15; within a
%   presentation only randState varies.
s = struct('parameters', struct( ...
    'BG', [128 128 128], 'N', 100, 'angle', 0, ...
    'dispprefs', {{'BGpretime', 0, 'BGposttime', 0}}, ...
    'dist', [1 1], 'fps', 15, 'pixSize', [50 50], ...
    'randState', [seed 0.6704957765200832 0.08449867537860833], ...
    'rect', [0 0 800 600], 'values', [0 0 0; 255 255 255]));
end

function s = blinkingStim()
%BLINKINGSTIM Dab's blinkingstim: key set {BG bgpause dispprefs fps pixSize
%   randState random rect repeat value}; BG [128 128 128], value [0 0 0],
%   random 1, repeat 30, fps 10, bgpause 0, pixSize [40 40], a 400x400 rect.
s = struct('parameters', struct( ...
    'BG', [128 128 128], 'bgpause', 0, ...
    'dispprefs', {{'BGposttime', 3}}, ...
    'fps', 10, 'pixSize', [40 40], ...
    'randState', [0.8301061479240671 0.6704957765200832 0.08449867537860833], ...
    'random', 1, 'rect', [200 100 600 500], 'repeat', 30, 'value', [0 0 0]));
end

function s = shapeMovieStim(labelName, labelValue)
%SHAPEMOVIESTIM Dab's shapemoviestim: key set {BG N dispprefs fps isi rect
%   scale} plus the experimenter's label `angle` or `disparity`; BG [0 0 0],
%   N 160, fps 100, isi 0.01, rect [0 0 800 600], scale 1, dispprefs {}.
p = struct('BG', [0 0 0], 'N', 160, 'dispprefs', {{}}, 'fps', 100, ...
    'isi', 0.01, 'rect', [0 0 800 600], 'scale', 1);
p.(labelName) = labelValue;
s = struct('parameters', p);
end

function t = trialTime(onset, offset)
%TRIALTIME One entry of the DEPRECATED inline presentation_time. No production
%   document has carried this since decoder.m moved the structure into
%   presentation_time.bin; it exists here to exercise the body-tier branch.
t = struct('clocktype', 'dev_local_time', 'stimopen', onset, ...
    'onset', onset, 'offset', offset, 'stimclose', offset, 'stimevents', []);
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

function v = depValue(b, name)
%DEPVALUE The first edge NAME's id ({name, value} in v1, {name, document_id}
%   from did2.build).
ids = depValues(b, name);
v = '';
if ~isempty(ids); v = ids{1}; end
end

function ids = depValues(b, name)
ids = {};
if ~isfield(b, 'depends_on'); return; end
for k = 1:numel(b.depends_on)
    d = b.depends_on(k);
    if ~strcmp(d.name, name); continue; end
    if isfield(d, 'document_id'); ids{end+1} = d.document_id; %#ok<AGROW>
    else; ids{end+1} = d.value; end %#ok<AGROW>
end
end

function v = methodParam(doc, variable)
%METHODPARAM The value of a `method` document's parameter VARIABLE: the
%   quantity's value, or the term's name; [] when absent.
v = [];
p = doc.method.parameters;
if isstruct(p); p = num2cell(p); end
for k = 1:numel(p)
    e = p{k};
    if strcmp(e.variable.name, variable)
        if isfield(e, 'quantity') && ~isempty(e.quantity); v = e.quantity.value;
        elseif isfield(e, 'term') && ~isempty(e.term); v = e.term.name; end
        return;
    end
end
end

function tf = isItemManipulation(m)
names = {m.document_class.superclasses.class_name};
tf = strcmp(m.document_class.class_name, 'manipulation') && any(strcmp(names, 'item'));
end
