classdef TestBodyResolver < matlab.unittest.TestCase
%TESTBODYRESOLVER Unit tests for ndi.migrate.internal.bodyResolver (pure struct
%   graph lookups; no database, schema, or MATLAB toolbox needed).
%
%   Focus: subjectsForPresentation -- the animal a stimulus_presentation was shown
%   to, reached through the response link (stimulus_response carries both
%   stimulus_presentation_id and the responding element_id -> its subject). A
%   presentation only names the stimulator, so this is how the V_eta second pass
%   puts the stimulus manipulation on the animal.
%
%   Run with:  runtests('ndi.unittest.migrate.TestBodyResolver')

    methods (Test)

        function testSubjectViaResponseLink(testCase)
            bodies = { ...
                stimPresentation('pres_1', 'stimulator_5'), ...
                stimResponse('resp_1', 'pres_1', 'elem_9'), ...
                element('elem_9', 'animal_1') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(r.subjectsForPresentation('pres_1'), {'animal_1'});
        end

        function testDedupMultipleRespondersSameAnimal(testCase)
            % two neurons of the same animal both responded -> one animal subject
            bodies = { ...
                stimResponse('resp_1', 'pres_1', 'elem_9'), ...
                stimResponse('resp_2', 'pres_1', 'elem_10'), ...
                element('elem_9', 'animal_1'), ...
                element('elem_10', 'animal_1') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(r.subjectsForPresentation('pres_1'), {'animal_1'});
        end

        function testDerivedElementFollowsUpChain(testCase)
            % a derived responding element (no own subject) resolves via
            % underlying_element_id, exactly like subjectOfElement.
            bodies = { ...
                stimResponse('resp_1', 'pres_1', 'derived_2'), ...
                derivedElement('derived_2', 'elem_9'), ...
                element('elem_9', 'animal_1') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(r.subjectsForPresentation('pres_1'), {'animal_1'});
        end

        function testNoResponseNoSubject(testCase)
            bodies = { stimPresentation('pres_1', 'stimulator_5') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEmpty(r.subjectsForPresentation('pres_1'));
        end

        function testUnresolvableElementSkipped(testCase)
            % a response to an element that is not in the body set -> skipped, not error
            bodies = { stimResponse('resp_1', 'pres_1', 'missing_element') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEmpty(r.subjectsForPresentation('pres_1'));
        end

    end
end

% ===================== fixtures ===========================================

function b = stimPresentation(id, stimulatorId)
b = docBody('stimulus_presentation', id, {'stimulus_element_id', stimulatorId});
end

function b = stimResponse(id, presentationId, elementId)
b = docBody('stimulus_response', id, ...
    {'stimulus_presentation_id', presentationId}, {'element_id', elementId});
end

function b = element(id, subjectId)
b = docBody('element', id, {'subject_id', subjectId});
end

function b = derivedElement(id, underlyingId)
% a derived element carries no subject of its own, only underlying_element_id
b = docBody('element', id, {'underlying_element_id', underlyingId});
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
