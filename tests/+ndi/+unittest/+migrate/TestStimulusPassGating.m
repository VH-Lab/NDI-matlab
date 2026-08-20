classdef TestStimulusPassGating < matlab.unittest.TestCase
%TESTSTIMULUSPASSGATING The two stimulus emitters are MUTUALLY EXCLUSIVE, and
%   this pins it where it is enforced -- at the pass in ndi.migrate.local.
%
%   WHY A SOURCE-LEVEL TEST. Both emitters set `base.id` to the v1
%   stimulus_presentation id (that preservation is the signed model: "the
%   presentation is DECOMPOSED around its preserved id, not dissolved"), and
%   `+did2/+database/sqlitedb.m` declares `documents(id TEXT PRIMARY KEY)`.
%   So if both ever ran, two documents would claim one id and the store could
%   not hold them. The exclusivity is not expressible inside either emitter --
%   each is correct on its own input -- so it lives in the pass, and the pass
%   is a LOCAL function of ndi.migrate.local that no test can call.
%
%   The 2026-08-17 signature (DID-schema V_eta_stimulus_model_plan.md) gives
%   the sequence case to `timed_sequence_manipulation` and RETAINS
%   `visual_grating_manipulation` for the presentation-less single-grating
%   case -- "not a rival model to retire, the degenerate one".
%
%   AND THE CONSEQUENCE IS PINNED TOO, because it is not good news: the
%   flattening pass is structurally a loop over `isPresentationBody(b)`, so
%   gating it to the presentation-less case stops it firing ENTIRELY, and the
%   retained case has NO EMITTER. Nothing is stranded today -- no did_v1 class
%   carries a lone grating -- but that is a fact about the source universe,
%   not about the model, and it is counted at runtime by
%   `single_grating_candidates` rather than asserted once here.
%
%   Run with:  runtests('ndi.unittest.migrate.TestStimulusPassGating')

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

        function testThePresentationPassCallsTheDecomposition(testCase)
            verifyTrue(testCase, contains(testCase.Source, ...
                'ndi.migrate.internal.stimulusPresentationToTimedSequence'), ...
                ['ndi.migrate.local no longer calls ' ...
                 'stimulusPresentationToTimedSequence. The signed model has ' ...
                 'no other emitter, so stimulus_presentation documents are ' ...
                 'passing through undecomposed.']);
        end

        function testTheFlatteningPassHasNoCaller(testCase)
            % THE ASSERTION THAT MATTERS. If this fails, re-read the
            % 2026-08-17 signature before "fixing" it: re-enabling the
            % flattening pass alongside the decomposition puts two documents
            % on one base.id.
            verifyFalse(testCase, contains(testCase.Source, ...
                'ndi.migrate.internal.stimulusPresentationToManipulation('), ...
                ['ndi.migrate.local calls stimulusPresentationToManipulation ' ...
                 'again. Both emitters preserve the presentation id, so with ' ...
                 'both running two documents claim one base.id and the ' ...
                 'sqlite primary key rejects the second. The flattening pass ' ...
                 'is RETAINED for the presentation-less single-grating case ' ...
                 'only, and that case has no v1 source.']);
        end

        function testTheHartleyBasisIsBuiltOncePerSession(testCase)
            % Minting the basis inside the per-presentation assembler would
            % create ten copies of the same 3,360 gratings on 20211116, one
            % per presentation. It is built at the pass level for that reason.
            verifyTrue(testCase, contains(testCase.Source, ...
                'ndi.migrate.internal.hartleyBasisGratings'), ...
                ['ndi.migrate.local no longer builds the Hartley basis. The ' ...
                 'ten generator-recipe presentations of 20211116 enumerate ' ...
                 'nothing on their own and will be refused.']);
        end

        function testTheRetainedEmitterStillExists(testCase)
            % Gated off is not deleted. The signature retains the class, so
            % the emitter stays available for the day its source appears.
            verifyNotEmpty(testCase, ...
                which('ndi.migrate.internal.stimulusPresentationToManipulation'), ...
                ['stimulusPresentationToManipulation is gone. It is RETAINED ' ...
                 'by the 2026-08-17 signature for the presentation-less ' ...
                 'single-grating case, not retired.']);
        end

    end
end
