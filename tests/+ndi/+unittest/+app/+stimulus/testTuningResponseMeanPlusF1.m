classdef testTuningResponseMeanPlusF1 < ndi.unittest.session.buildSession
    % TESTTUNINGRESPONSEMEANPLUSF1 - tests for the 'mean+F1' stimulus response
    %
    % Tests ndi.app.stimulus.tuning_response.meanPlusF1, which combines per-trial
    % mean (F0) and F1 responses, and the 'mean+F1' stimulus_response_scalar
    % documents that compute_stimulus_response_scalar writes.

    methods (Test)

        function testSumOfMagnitudesWithPhase(testCase)
            % The averaged mean+F1 response is mean(F0) + abs(mean(F1)), whatever the F1 phase
            stimIds = [1 1 1 2 2 2 3 3 3];
            meanResp = [10 12 14   5 5 5   20 18 22];
            phases = [pi/2 pi/2 pi/2   -2.5 -2.5 -2.5   1 1 1];
            f1Mag = [8 10 12   3 3 3   0.5 0.5 0.5];
            f1Resp = f1Mag .* exp(1i*phases);
            [r, c] = ndi.app.stimulus.tuning_response.meanPlusF1(stimIds, meanResp, f1Resp, ...
                zeros(1,9), zeros(1,9));
            for s = 1:3
                trials = stimIds==s;
                expected = mean(meanResp(trials)) + abs(mean(f1Resp(trials)));
                testCase.verifyEqual(abs(mean(r(trials))), expected, 'AbsTol', 1e-10);
            end
            testCase.verifyEqual(abs(c), zeros(1,9), 'AbsTol', 1e-12);
            testCase.verifySize(r, [1 9]);
        end

        function testPhaseVariesAcrossTrials(testCase)
            % F1 is vector averaged: per-trial phase scatter lowers the F1 term,
            % it is not inflated as an average of per-trial magnitudes would be
            stimIds = [1 1];
            meanResp = [10 10];
            f1Resp = [5 5i]; % same magnitude, 90 degrees apart
            r = ndi.app.stimulus.tuning_response.meanPlusF1(stimIds, meanResp, f1Resp, [0 0], [0 0]);
            expected = 10 + abs(mean(f1Resp)); % 10 + 5/sqrt(2), not 15
            testCase.verifyEqual(abs(mean(r)), expected, 'AbsTol', 1e-10);
        end

        function testControlUsesItsOwnPhase(testCase)
            stimIds = [1 1 2 2];
            meanCtrl = [2 2 3 3];
            f1Ctrl = [1i 1i -1 -1];
            [~, c] = ndi.app.stimulus.tuning_response.meanPlusF1(stimIds, [1 1 1 1], [1 1 1 1], ...
                meanCtrl, f1Ctrl);
            testCase.verifyEqual(abs(mean(c(1:2))), 3, 'AbsTol', 1e-10);
            testCase.verifyEqual(abs(mean(c(3:4))), 4, 'AbsTol', 1e-10);
        end

        function testNoFundamentalFrequencyGivesMean(testCase)
            % trials of stimuli without a fundamental frequency (e.g., a blank) get mean+F1 == mean
            stimIds = [1 1 2 2];
            meanResp = [4 6 7 9];
            f1Resp = [4 6 1i 1i]; % for stim 1, vlt's "F1" at frequency 0 is the mean itself
            hasF1 = [false false true true];
            r = ndi.app.stimulus.tuning_response.meanPlusF1(stimIds, meanResp, f1Resp, ...
                zeros(1,4), zeros(1,4), hasF1);
            testCase.verifyEqual(real(r(1:2)), [4 6], 'AbsTol', 1e-12);
            testCase.verifyEqual(imag(r(1:2)), [0 0], 'AbsTol', 1e-12);
            testCase.verifyEqual(abs(mean(r(3:4))), 8 + 1, 'AbsTol', 1e-10);
        end

        function testNaNTrialsAreOmittedFromPhase(testCase)
            stimIds = [1 1 1];
            meanResp = [10 10 10];
            f1Resp = [2i NaN 2i];
            r = ndi.app.stimulus.tuning_response.meanPlusF1(stimIds, meanResp, f1Resp, [0 0 0], [0 0 0]);
            testCase.verifyTrue(isnan(r(2)));
            testCase.verifyEqual(real(r([1 3])), [0 0], 'AbsTol', 1e-10);
            testCase.verifyEqual(imag(r([1 3])), [12 12], 'AbsTol', 1e-10);
        end

        function testSizeMismatchErrors(testCase)
            testCase.verifyError(@() ndi.app.stimulus.tuning_response.meanPlusF1([1 1], [1 1], 1, [0 0], [0 0]), ...
                'NDI:tuning_response:meanPlusF1:sizeMismatch');
        end

        function testStimulusResponsesWritesMeanPlusF1(testCase)
            % End to end: with a temporal frequency, stimulus_responses writes mean, F1, F2, and mean+F1,
            % and the mean+F1 values combine the mean and F1 documents of the same run
            S = testCase.Session;
            paramStruct = struct('angle', 0, 'contrast', 1, 'tFrequency', 4);
            X = [0; 90; 180; 270];
            R = [10; 20; 30; 40];
            docs = ndi.mock.fun.stimulus_response(S, paramStruct, {'angle'}, X, R, 0, 3, 'RandomSeed', 1);

            stimulator = S.getelements('base.id', docs{2}.id());
            spikes = S.getelements('base.id', docs{3}.id());
            testCase.assertNumElements(stimulator, 1);
            testCase.assertNumElements(spikes, 1);

            app = ndi.app.stimulus.tuning_response(S);
            app.stimulus_responses(stimulator{1}, spikes{1}, 0, 0);

            meanDoc = testCase.findResponseDocs(S, spikes{1}, 'mean');
            f1Doc = testCase.findResponseDocs(S, spikes{1}, 'F1');
            testCase.findResponseDocs(S, spikes{1}, 'F2');
            mpfDoc = testCase.findResponseDocs(S, spikes{1}, 'mean+F1');

            % mean+F1 shares the F1 parameter document
            testCase.verifyEqual(mpfDoc.dependency_value('stimulus_response_scalar_parameters_id'), ...
                f1Doc.dependency_value('stimulus_response_scalar_parameters_id'));

            m = meanDoc.document_properties.stimulus_response_scalar.responses;
            f = f1Doc.document_properties.stimulus_response_scalar.responses;
            p = mpfDoc.document_properties.stimulus_response_scalar.responses;
            testCase.verifyEqual(p.stimid(:), m.stimid(:));
            mResp = m.response_real(:) + 1i*m.response_imaginary(:);
            fResp = f.response_real(:) + 1i*f.response_imaginary(:);
            pResp = p.response_real(:) + 1i*p.response_imaginary(:);
            stimIds = unique(p.stimid);
            for k = 1:numel(stimIds)
                trials = p.stimid(:)==stimIds(k);
                expected = mean(mResp(trials),'omitnan') + abs(mean(fResp(trials),'omitnan'));
                testCase.verifyEqual(abs(mean(pResp(trials),'omitnan')), expected, 'AbsTol', 1e-8);
            end

            % tuning curves: the mean+F1 curve is the sum of the mean and F1 curves, and
            % f0_f1_responses on it reports the F0 and F1 of its mean and F1 partners
            tcArgs = {'independent_parameter', {'angle'}, 'independent_label', {'angle'}};
            tcMean = app.tuning_curve(meanDoc, tcArgs{:});
            tcF1 = app.tuning_curve(f1Doc, tcArgs{:});
            tcMpf = app.tuning_curve(mpfDoc, tcArgs{:});
            rMean = tcMean.document_properties.stimulus_tuningcurve.response_mean;
            rF1 = tcF1.document_properties.stimulus_tuningcurve.response_mean;
            rMpf = tcMpf.document_properties.stimulus_tuningcurve.response_mean;
            testCase.verifyEqual(rMpf(:), rMean(:) + rF1(:), 'AbsTol', 1e-8);

            [f0, f1] = ndi.fun.stimulus.f0_f1_responses(S, tcMpf, 2);
            [f0Expected, f1Expected] = ndi.fun.stimulus.f0_f1_responses(S, tcMean, 2);
            testCase.verifyEqual(f0, f0Expected, 'AbsTol', 1e-10);
            testCase.verifyEqual(f1, f1Expected, 'AbsTol', 1e-10);
            testCase.verifyFalse(isnan(f0));
            testCase.verifyFalse(isnan(f1));

            % recomputing replaces rather than duplicates
            app.stimulus_responses(stimulator{1}, spikes{1}, 0, 0);
            testCase.findResponseDocs(S, spikes{1}, 'mean+F1');
            testCase.findResponseDocs(S, spikes{1}, 'F1');

            % an F1-only computation does not delete the existing mean+F1 document
            stimDoc = S.database_search(ndi.query('base.id','exact_string', ...
                mpfDoc.dependency_value('stimulus_presentation_id'),''));
            controlDoc = S.database_search(ndi.query('base.id','exact_string', ...
                mpfDoc.dependency_value('stimulus_control_id'),''));
            app.compute_stimulus_response_scalar(stimulator{1}, spikes{1}, stimDoc{1}, controlDoc{1}, ...
                'freq_response', 1);
            testCase.findResponseDocs(S, spikes{1}, 'mean+F1');
            testCase.findResponseDocs(S, spikes{1}, 'F1');
        end

        function testMeanOnlyWritesNoMeanPlusF1(testCase)
            S = testCase.Session;
            paramStruct = struct('angle', 0, 'contrast', 1, 'tFrequency', 4);
            X = [0; 90; 180; 270];
            R = [10; 20; 30; 40];
            docs = ndi.mock.fun.stimulus_response(S, paramStruct, {'angle'}, X, R, 0, 2, 'RandomSeed', 1);
            q = ndi.query('','isa','stimulus_response_scalar','') & ...
                ndi.query('','depends_on','element_id',docs{3}.id()) & ...
                ndi.query('stimulus_response_scalar.response_type','exact_string','mean+F1','');
            testCase.verifyEmpty(S.database_search(q));
        end

    end

    methods (Static, Access = private)
        function doc = findResponseDocs(S, element, responseType)
            % returns the single stimulus_response_scalar document of RESPONSETYPE for ELEMENT,
            % erroring if there is not exactly one
            q = ndi.query('','isa','stimulus_response_scalar','') & ...
                ndi.query('','depends_on','element_id',element.id()) & ...
                ndi.query('stimulus_response_scalar.response_type','exact_string',responseType,'');
            d = S.database_search(q);
            if numel(d)~=1
                error('testTuningResponseMeanPlusF1:count', ...
                    'Expected exactly 1 ''%s'' response document, found %d.', responseType, numel(d));
            end
            doc = d{1};
        end
    end
end
