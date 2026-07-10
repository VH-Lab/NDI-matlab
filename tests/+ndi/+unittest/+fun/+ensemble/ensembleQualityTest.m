classdef ensembleQualityTest < matlab.unittest.TestCase
    % ENSEMBLEQUALITYTEST - Unit tests for ndi.fun.ensemble.neuronQuality
    %
    % Seeds a session with spiking-neuron 'element' documents and their
    % 'neuron_extracellular' documents (with quality_number / quality_label), and
    % verifies that neuronQuality returns the per-neuron quality aligned to the
    % requested ids, NaN/'' for a neuron with no neuron_extracellular document,
    % and an error when a neuron has more than one. No read-back is involved.

    properties
        Session
        TempDir
        SubjectId
        ProbeId
        NeuronIds  % {n1, n2, n3}; n1,n2 have quality docs, n3 does not
    end

    methods (TestMethodSetup)
        function setupSession(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            testCase.Session = ndi.session.dir('ensemble_quality_test', testCase.TempDir);
            S = testCase.Session;

            subject = ndi.subject('subject1@test', 'test subject');
            subdoc = subject.newdocument();
            S.database_add(subdoc);
            testCase.SubjectId = subdoc.id();

            probe = ndi.document('element', 'base.session_id', S.id(), ...
                'element.ndi_element_class', 'ndi.probe.timeseries.mfdaq', ...
                'element.name', 'ctx_probe', 'element.reference', 1, ...
                'element.type', 'n-trode', 'element.direct', 1);
            probe = probe.set_dependency_value('subject_id', testCase.SubjectId);
            S.database_add(probe);
            testCase.ProbeId = probe.id();

            ids = cell(1,3);
            for i = 1:3
                ids{i} = testCase.addNeuron(sprintf('neuron_%d', i), i);
            end
            testCase.NeuronIds = ids;

            % quality docs for the first two neurons only
            testCase.addQuality(ids{1}, 1, 3, 'good');
            testCase.addQuality(ids{2}, 2, 1, 'mua');
        end
    end

    methods (TestMethodTeardown)
        function teardownSession(testCase)
            if exist(testCase.TempDir, 'dir')
                rmdir(testCase.TempDir, 's');
            end
        end
    end

    methods (Test)

        function testQualityLookup(testCase)
            [qnum, qlabel] = ndi.fun.ensemble.neuronQuality(testCase.Session, testCase.NeuronIds);
            testCase.verifyEqual(qnum(1), 3);
            testCase.verifyEqual(qnum(2), 1);
            testCase.verifyTrue(isnan(qnum(3)), 'A neuron with no quality doc yields NaN.');
            testCase.verifyEqual(qlabel, {'good','mua',''});
        end

        function testOrderFollowsInput(testCase)
            ids = testCase.NeuronIds([3 1]);
            [qnum, qlabel] = ndi.fun.ensemble.neuronQuality(testCase.Session, ids);
            testCase.verifyTrue(isnan(qnum(1)));
            testCase.verifyEqual(qnum(2), 3);
            testCase.verifyEqual(qlabel, {'', 'good'});
        end

        function testMultipleDocsErrors(testCase)
            % a second quality doc for neuron 1 makes the lookup ambiguous
            testCase.addQuality(testCase.NeuronIds{1}, 9, 2, 'fair');
            testCase.verifyError(@() ndi.fun.ensemble.neuronQuality( ...
                testCase.Session, testCase.NeuronIds), ...
                'ndi:ensemble:neuronQuality:multiple');
        end

    end

    methods % helpers
        function id = addNeuron(testCase, name, ref)
            S = testCase.Session;
            elem = ndi.document('element', 'base.session_id', S.id(), ...
                'element.ndi_element_class', 'ndi.neuron', ...
                'element.name', name, 'element.reference', ref, ...
                'element.type', 'spikes', 'element.direct', 0);
            elem = elem.set_dependency_value('underlying_element_id', testCase.ProbeId);
            elem = elem.set_dependency_value('subject_id', testCase.SubjectId);
            S.database_add(elem);
            id = elem.id();
        end

        function addQuality(testCase, element_id, cluster, quality_number, quality_label)
            S = testCase.Session;
            app_struct = struct('name','test pipeline','version','1.0', ...
                'url','','os', computer,'os_version','', ...
                'interpreter','MATLAB','interpreter_version','9');
            ne = struct('number_of_samples_per_channel',30,'number_of_channels',4, ...
                'mean_waveform', zeros(30,4), 'waveform_sample_times', (1:30)', ...
                'cluster_index', cluster, 'quality_number', quality_number, ...
                'quality_label', quality_label);
            ned = ndi.document('neuron_extracellular', 'app', app_struct, ...
                'neuron_extracellular', ne, 'base.session_id', S.id());
            ned = ned.set_dependency_value('element_id', element_id);
            S.database_add(ned);
        end
    end
end
