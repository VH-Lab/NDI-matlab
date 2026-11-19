classdef TestResponseParametersReused < ndi.unittest.session.buildSession
    % TESTRESPONSEPARAMETERSREUSED - the tuning app leaves no orphaned parameters documents
    %
    % NDI-matlab #1237. ndi.app.stimulus.tuning_response stores the settings
    % of a stimulus response in a 'stimulus_response_scalar_parameters_basic'
    % document that the 'stimulus_response_scalar' documents depend on.
    %
    % 1. Never reused: the search for an existing parameters document used
    %    'exact_number' on the prestimulus settings, which are empty by
    %    default, and the SQL search matches nothing for an empty value. So
    %    every computation added a new parameters document, and recomputing
    %    the responses left the old one used by nothing.
    % 2. Orphaned when the stimuli are parsed again: removing the
    %    stimulus_presentation documents removes the responses with them, but
    %    the parameters documents depend on nothing and stayed.
    %
    % Each test builds a mock stimulator, neuron, stimulus presentation and
    % mean responses with ndi.mock.fun.stimulus_response (default settings,
    % so the prestimulus settings are empty).

    methods (Test)

        function testRecomputingReusesTheParametersDocument(testCase)
            S = testCase.Session;
            [stim, spikes, stim_doc, control_doc] = testCase.mockResponses(S);

            params = testCase.parameterDocs(S);
            testCase.assertNumElements(params, 1, ...
                'The mock responses should make one parameters document.');
            p = params{1}.document_properties.stimulus_response_scalar_parameters_basic;
            % the case of the issue: the default prestimulus settings are empty
            testCase.assertEmpty(p.prestimulus_time);
            testCase.assertEmpty(p.prestimulus_normalization);
            param_id = params{1}.id();
            nResponses = numel(testCase.responseDocs(S));
            testCase.assertGreaterThan(nResponses, 0);

            r_app = ndi.app.stimulus.tuning_response(S);
            r_app.stimulus_responses(stim, spikes, 0, 1);

            params = testCase.parameterDocs(S);
            testCase.verifyNumElements(params, 1, ...
                'Recomputing the responses with the same settings must reuse the parameters document.');
            testCase.verifyEqual(params{1}.id(), param_id);
            responses = testCase.responseDocs(S);
            testCase.verifyNumElements(responses, nResponses, ...
                'The recomputed responses should replace the old ones.');
            for i=1:numel(responses)
                testCase.verifyEqual(responses{i}.dependency_value('stimulus_response_scalar_parameters_id'), ...
                    param_id);
            end
            testCase.verifyEmpty(testCase.orphanedParameterDocs(S));

            % and the same settings given explicitly also find it
            r_app.compute_stimulus_response_scalar(stim, spikes, stim_doc, control_doc, ...
                'freq_response', 0);
            params = testCase.parameterDocs(S);
            testCase.verifyNumElements(params, 1);
        end

        function testDifferentSettingsMakeADifferentParametersDocument(testCase)
            S = testCase.Session;
            [stim, spikes, stim_doc, control_doc] = testCase.mockResponses(S);
            r_app = ndi.app.stimulus.tuning_response(S);

            r_app.compute_stimulus_response_scalar(stim, spikes, stim_doc, control_doc, ...
                'freq_response', 0, 'spiketrain_dt', 0.002);
            params = testCase.parameterDocs(S);
            testCase.verifyNumElements(params, 2, ...
                'Other settings must not reuse the default parameters document.');

            % computing again with those settings reuses the second document
            r_app.compute_stimulus_response_scalar(stim, spikes, stim_doc, control_doc, ...
                'freq_response', 0, 'spiketrain_dt', 0.002);
            testCase.verifyNumElements(testCase.parameterDocs(S), 2);
            testCase.verifyEmpty(testCase.orphanedParameterDocs(S));
        end

        function testResetRemovesOnlyUnusedParametersDocuments(testCase)
            S = testCase.Session;
            [stim, spikes] = testCase.mockResponses(S);
            r_app = ndi.app.stimulus.tuning_response(S);

            r_app.stimulus_responses(stim, spikes, 1, 1);

            params = testCase.parameterDocs(S);
            testCase.verifyNumElements(params, 1, ...
                'A reset recomputation should leave one parameters document.');
            testCase.verifyNotEmpty(testCase.responseDocs(S));
            testCase.verifyEmpty(testCase.orphanedParameterDocs(S));
        end

        function testAParametersDocumentInUseIsKept(testCase)
            S = testCase.Session;
            testCase.mockResponses(S);
            params = testCase.parameterDocs(S);
            testCase.assertNumElements(params, 1);

            removed = ndi.app.stimulus.tuning_response.remove_unused_parameter_docs(S, ...
                params{1}.id());
            testCase.verifyEmpty(removed);
            testCase.verifyNumElements(testCase.parameterDocs(S), 1, ...
                'A parameters document that responses depend on must be kept.');
            testCase.verifyNotEmpty(testCase.responseDocs(S));
        end

        function testRemovingPresentationsRemovesTheirParametersDocuments(testCase)
            % parse_stimuli with RESET removes the old presentations through
            % remove_presentations
            S = testCase.Session;
            [~, ~, stim_doc] = testCase.mockResponses(S);
            testCase.assertNumElements(testCase.parameterDocs(S), 1);

            decoder = ndi.app.stimulus.decoder(S);
            decoder.remove_presentations({stim_doc});

            testCase.verifyEmpty(S.database_search(ndi.query('base.id','exact_string',stim_doc.id(),'')));
            testCase.verifyEmpty(testCase.responseDocs(S), ...
                'The responses depend on the presentation and go with it.');
            testCase.verifyEmpty(testCase.parameterDocs(S), ...
                'The parameters document that only those responses used must go too.');
        end

    end

    methods (Static, Access = private)

        function [stim, spikes, stim_doc, control_doc] = mockResponses(S)
            docs = ndi.mock.fun.stimulus_response(S, struct('contrast',1), {'contrast'}, ...
                [0; 0.5; 1], [0; 2; 4], 0, 2, 'RandomSeed', 1);
            stim = ndi.database.fun.ndi_document2ndi_object(docs{2}, S);
            spikes = ndi.database.fun.ndi_document2ndi_object(docs{3}, S);
            stim_doc = S.database_search(ndi.query('','isa','stimulus_presentation','') & ...
                ndi.query('','depends_on','stimulus_element_id',stim.id()));
            assert(numel(stim_doc)==1, 'Expected one mock stimulus_presentation document.');
            stim_doc = stim_doc{1};
            control_doc = S.database_search(ndi.query('','isa','control_stimulus_ids','') & ...
                ndi.query('','depends_on','stimulus_presentation_id',stim_doc.id()));
            assert(numel(control_doc)==1, 'Expected one mock control_stimulus_ids document.');
            control_doc = control_doc{1};
        end

        function d = parameterDocs(S)
            d = S.database_search(ndi.query('','isa','stimulus_response_scalar_parameters_basic',''));
        end

        function d = responseDocs(S)
            d = S.database_search(ndi.query('','isa','stimulus_response_scalar',''));
        end

        function d = orphanedParameterDocs(S)
            params = ndi.unittest.app.TestResponseParametersReused.parameterDocs(S);
            d = {};
            for i=1:numel(params)
                if isempty(S.database_search(ndi.query('','depends_on','*',params{i}.id())))
                    d{end+1} = params{i}; %#ok<AGROW>
                end
            end
        end

    end
end
