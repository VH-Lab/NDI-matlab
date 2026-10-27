classdef testCalcTuningCurve < ndi.unittest.session.buildSession
    % TESTCALCTUNINGCURVE - test the tuningcurve calculator

    methods (Test)
        function testTuningCurveCalc(testCase)
            % TESTTUNINGCURVECALC - test the tuningcurve calculator
            %
            % Runs every self-test the calculator declares and verifies each one.
            % The number of tests comes from numberOfSelfTests, so it does not have
            % to be repeated here. requireDistinct additionally requires that the
            % tests give different answers from one another, and that their stored
            % expectations differ.

            S = ndi.calc.stimulus.tuningcurve(testCase.Session);
            S.verifySelfTests(testCase,'requireDistinct',true);
        end

        function testDealSingleProperty(testCase)
            % TESTDEALSINGLEPROPERTY - dealing one property makes one curve per value
            %
            % Builds a mock contrast x spatial_frequency stimulus set, computes
            % contrast tuning curves with spatial_frequency dealt, and checks that
            % each curve is built at a different spatial frequency: its
            % stim_property_list value differs from the others, and every stimid
            % in the curve points at a stimulus with that spatial frequency.

            S = testCase.Session;
            tc = ndi.calc.stimulus.tuningcurve(S);

            contrastValues = [0.25 0.5 1];
            sfValues = [0.1 0.5 1 2];
            [C, SF] = ndgrid(contrastValues, sfValues);
            X = [C(:) SF(:)];
            R = 2 + 10*C(:) .* SF(:);
            paramStruct = struct('spatial_frequency',0.5,'angle',0,'contrast',1);

            docs = ndi.mock.fun.stimulus_response(S, paramStruct, ...
                {'contrast','spatial_frequency'}, X, R, 0, 2, 'RandomSeed', 1);

            stimResponseDoc = {};
            for k=1:numel(docs)
                if isa(docs{k},'ndi.document') && ...
                        strcmpi(docs{k}.document_properties.document_class.class_name,'stimulus_response_scalar')
                    stimResponseDoc{end+1} = docs{k}; %#ok<AGROW>
                end
            end
            testCase.assertNotEmpty(stimResponseDoc, 'No stimulus_response_scalar document was made.');
            stimResponseDoc = stimResponseDoc{1};

            stimPresDoc = S.database_search(ndi.query('base.id','exact_string', ...
                stimResponseDoc.dependency_value('stimulus_presentation_id'),''));
            testCase.assertNumElements(stimPresDoc, 1);
            stimuli = stimPresDoc{1}.document_properties.stimulus_presentation.stimuli;

            parameters.input_parameters.independent_label = 'contrast';
            parameters.input_parameters.independent_parameter = 'contrast';
            parameters.input_parameters.best_algorithm = 'empirical_maximum';
            parameters.input_parameters.selection = ...
                struct('property','contrast','operation','hasfield','value','varies');
            parameters.input_parameters.selection(2) = ...
                struct('property','spatial_frequency','operation','hasfield','value','deal');
            parameters.depends_on = struct('name','stimulus_response_scalar_id','value',stimResponseDoc.id());

            tcDocs = tc.run('Replace',parameters);
            if ~iscell(tcDocs)
                tcDocs = {tcDocs};
            end
            testCase.assertNumElements(tcDocs, numel(sfValues), ...
                'Expected one tuning curve per dealt spatial_frequency value.');

            dealtValues = nan(1,numel(tcDocs));
            for k=1:numel(tcDocs)
                props = tcDocs{k}.document_properties;
                testCase.verifyEqual(cellstr(props.tuningcurve_calc.stim_property_list.names), {'spatial_frequency'});
                dealtValues(k) = props.tuningcurve_calc.stim_property_list.values;
                testCase.verifySubstring(props.tuningcurve_calc.log, ...
                    ['dealing spatial_frequency = ' num2str(dealtValues(k))]);

                stimids = props.stimulus_tuningcurve.stimid;
                stimids = stimids(~isnan(stimids));
                testCase.verifyNumElements(stimids, numel(contrastValues));
                for n=1:numel(stimids)
                    p = stimuli(stimids(n)).parameters;
                    testCase.verifyEqual(p.spatial_frequency, dealtValues(k), 'AbsTol', 1e-12, ...
                        sprintf('Curve %d (spatial_frequency %g) includes stimid %d at spatial_frequency %g.', ...
                        k, dealtValues(k), stimids(n), p.spatial_frequency));
                end
            end

            testCase.verifyEqual(sort(dealtValues), sfValues, 'AbsTol', 1e-12, ...
                'Each tuning curve should be built at a different dealt value.');
        end
    end
end
