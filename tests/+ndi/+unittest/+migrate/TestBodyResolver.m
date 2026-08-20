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

        % ============ the IS-A widening, 2026-08-17 ======================

        function testASubclassOfStimulusResponseResolves(testCase)
            % THE CASE PRODUCTION ACTUALLY WRITES. The exact-name match this
            % replaced could not fire on real data: measured over the
            % 20211116 corpus (1220 documents read), 0 documents are named
            % `stimulus_response` and 273 are named
            % `stimulus_response_scalar`, all 273 carrying BOTH
            % `stimulus_presentation_id` and `element_id`.
            bodies = { ...
                responseScalar('resp_1', 'pres_1', 'elem_9'), ...
                element('elem_9', 'animal_1') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(r.subjectsForPresentation('pres_1'), {'animal_1'});
        end

        function testTheVetaSpellingOfASuperclassAlsoResolves(testCase)
            % A body set can arrive in either vintage -- v1 superclass entries
            % carry `definition`, V_eta ones carry `class_name` -- so both
            % spellings are read.
            b = docBody('stimulus_response_scalar', 'resp_1', ...
                {'stimulus_presentation_id', 'pres_1'}, {'element_id', 'elem_9'});
            b.document_class.superclasses = ...
                struct('class_name', 'stimulus_response', 'class_version', '1.0.0');
            r = ndi.migrate.internal.bodyResolver({ b, element('elem_9', 'animal_1') });
            testCase.verifyEqual(r.subjectsForPresentation('pres_1'), {'animal_1'});
        end

        function testAnUnrelatedClassWithTheSameEdgesDoesNotResolve(testCase)
            % The widening is by DECLARED superclass, not by name shape or by
            % which edges a document happens to carry. 20211116 holds 273
            % `stimulus_response_scalar_parameters_basic` documents, and they
            % must not be read as responses.
            bodies = { ...
                docBody('stimulus_response_scalar_parameters_basic', 'p_1', ...
                    {'stimulus_presentation_id', 'pres_1'}, ...
                    {'element_id', 'elem_9'}), ...
                element('elem_9', 'animal_1') };
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

function b = responseScalar(id, presentationId, elementId)
%RESPONSESCALAR The class production writes, carrying the v1 template's OWN
%   superclass declaration -- verbatim from ndi_common/database_documents/
%   stimulus/stimulus_response_scalar.json, and matched by every one of the
%   273 such documents in the 20211116 corpus. That declaration is what the
%   resolver reads, so a fixture without it would exercise nothing.
b = docBody('stimulus_response_scalar', id, ...
    {'stimulus_presentation_id', presentationId}, {'element_id', elementId});
b.document_class.superclasses = [ ...
    struct('definition', '$NDIDOCUMENTPATH/base.json'), ...
    struct('definition', '$NDIDOCUMENTPATH/stimulus/stimulus_response.json')];
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
