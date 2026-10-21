classdef TestStimulusPassGating < matlab.unittest.TestCase
%TESTSTIMULUSPASSGATING Which stimulus emitters ndi.migrate.local wires in.
%
%   did-schema #88 (V_eta_method_plan.md, TEAM-SIGN-OFF [method] 2026-10-21)
%   deletes `visual_grating`, and V_eta_study_plan.md replaces
%   `timed_sequence` with `item`. So the second pass has ONE stimulus
%   emitter, stimulusPresentationToItem, and the flattening pass
%   (stimulusPresentationToManipulation, which wrote the deleted
%   `visual_grating_manipulation`) is gone with nothing calling it. These are
%   source checks: they read local.m and the path, nothing else.

    properties
        Source
    end

    methods (TestClassSetup)
        function readSource(testCase)
            p = which('ndi.migrate.local');
            assertNotEmpty(testCase, p, ...
                'ndi.migrate.local is not on the path; nothing to read');
            testCase.Source = fileread(p);
        end
    end

    methods (Test)

        function testThePresentationPassCallsTheItemDecomposition(testCase)
            verifyTrue(testCase, contains(testCase.Source, ...
                'ndi.migrate.internal.stimulusPresentationToItem'), ...
                ['ndi.migrate.local no longer calls stimulusPresentationToItem, ' ...
                 'so stimulus_presentation documents pass through undecomposed.']);
        end

        function testNoEmitterOfADeletedClassRemains(testCase)
            for name = {'stimulusPresentationToManipulation', ...
                    'stimulusPresentationToTimedSequence', 'gratingValueFromParameters'}
                verifyEmpty(testCase, which(['ndi.migrate.internal.' name{1}]), ...
                    sprintf(['%s is back. It wrote visual_grating / ' ...
                    'timed_sequence shapes did-schema #88 deleted.'], name{1}));
                verifyFalse(testCase, contains(testCase.Source, name{1}), ...
                    sprintf('ndi.migrate.local names %s again.', name{1}));
            end
        end

        function testTheHartleyBasisIsBuiltOncePerSession(testCase)
            verifyTrue(testCase, contains(testCase.Source, ...
                'ndi.migrate.internal.hartleyBasisGratings'), ...
                ['ndi.migrate.local no longer builds the Hartley basis. The ' ...
                 'ten generator-recipe presentations of 20211116 enumerate ' ...
                 'nothing on their own and will be refused.']);
        end

        function testTheSessionCohortIsMintedByThePass(testCase)
            verifyTrue(testCase, contains(testCase.Source, ...
                'ndi.migrate.internal.sessionCohort'), ...
                ['ndi.migrate.local no longer mints the session cohort, so a ' ...
                 'several-animal presentation has no entity to point at.']);
        end

    end
end
