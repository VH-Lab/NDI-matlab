classdef ResolveExistingNeuronsTest < matlab.unittest.TestCase
    % RESOLVEEXISTINGNEURONSTEST - tests for ndi.fun.probe.import.resolveExistingNeurons
    %
    % Builds a session holding neurons from two imports of the same probe, the way the
    % spike-sorting importers write them: a 'current' import (a kilosort_clusters
    % document with one neuron) and an 'earlier' one whose cluster document the
    % importer would not find (a second neuron with the same name, plus another
    % neuron). A neuron of a different probe is added too, and must never be touched.

    properties
        sessionDir
        S
        probe
        currentKc
        staleKc
        currentNeuron
        strayNeurons
        otherNeuron
    end

    methods (TestMethodSetup)
        function makeSession(testCase)
            testCase.sessionDir = tempname;
            mkdir(testCase.sessionDir);
            testCase.addTeardown(@() rmdir(testCase.sessionDir, 's'));
            testCase.S = ndi.session.dir('resolveexisting', testCase.sessionDir);
            testCase.probe = ndi.unittest.fun.probe.MockNamedProbe('ctx', 1);

            testCase.currentKc = testCase.addClusterDoc();
            testCase.staleKc = testCase.addClusterDoc();
            testCase.currentNeuron = testCase.addNeuron('ctx_1_5', 1, testCase.currentKc);
            testCase.strayNeurons = { ...
                testCase.addNeuron('ctx_1_5', 1, testCase.staleKc), ...
                testCase.addNeuron('ctx_1_7', 1, testCase.staleKc)};
            testCase.otherNeuron = testCase.addNeuron('ctx_2_5', 2, []);
        end
    end

    methods (Test)
        function testRemoveDeletesOnlyEarlierNeurons(testCase)
            n = ndi.fun.probe.import.resolveExistingNeurons(testCase.S, testCase.probe, ...
                {testCase.currentKc}, 'ExistingNeurons', 'remove', 'verbose', false);
            testCase.verifyEqual(n, 2);
            testCase.verifyTrue(testCase.exists(testCase.currentNeuron));
            testCase.verifyTrue(testCase.exists(testCase.currentKc));
            testCase.verifyTrue(testCase.exists(testCase.otherNeuron));
            for i=1:numel(testCase.strayNeurons)
                testCase.verifyFalse(testCase.exists(testCase.strayNeurons{i}));
            end
            % their neuron_extracellular documents and the stale cluster document are gone
            q = ndi.query('','depends_on','spike_clusters_id', testCase.staleKc.id());
            testCase.verifyEmpty(testCase.S.database_search(q));
            testCase.verifyFalse(testCase.exists(testCase.staleKc));
            % and the name is unique again
            q = ndi.query('element.name','exact_string','ctx_1_5','');
            testCase.verifyNumElements(testCase.S.database_search(q), 1);
        end

        function testErrorLeavesDatabaseUnchanged(testCase)
            testCase.verifyError(@() ndi.fun.probe.import.resolveExistingNeurons( ...
                testCase.S, testCase.probe, {testCase.currentKc}, ...
                'ExistingNeurons', 'error', 'verbose', false), ...
                'ndi:fun:probe:import:existingNeurons');
            testCase.verifyTrue(testCase.exists(testCase.strayNeurons{1}));
            testCase.verifyTrue(testCase.exists(testCase.strayNeurons{2}));
        end

        function testDryRunLeavesDatabaseUnchanged(testCase)
            n = ndi.fun.probe.import.resolveExistingNeurons(testCase.S, testCase.probe, ...
                {testCase.currentKc}, 'ExistingNeurons', 'remove', 'dryRun', true);
            testCase.verifyEqual(n, 0);
            testCase.verifyTrue(testCase.exists(testCase.strayNeurons{1}));
            testCase.verifyTrue(testCase.exists(testCase.strayNeurons{2}));
        end

        function testNothingToDoWhenAllNeuronsAreOwned(testCase)
            % passing both cluster documents means every ctx_1 neuron is accounted for
            n = ndi.fun.probe.import.resolveExistingNeurons(testCase.S, testCase.probe, ...
                {testCase.currentKc, testCase.staleKc}, 'ExistingNeurons', 'error', ...
                'verbose', false);
            testCase.verifyEqual(n, 0);
        end
    end

    methods
        function kc = addClusterDoc(testCase)
            kc = ndi.document('kilosort_clusters', 'base.session_id', testCase.S.id(), ...
                'kilosort_clusters.kilosort_directory', 'kilosort/ctx_-_1', ...
                'kilosort_clusters.curated_output_MD5_checksum', did.ido.unique_id());
            testCase.S.database_add(kc);
        end

        function edoc = addNeuron(testCase, name, reference, kc)
            edoc = ndi.document('element', 'base.session_id', testCase.S.id(), ...
                'element.ndi_element_class', 'ndi.neuron', ...
                'element.name', name, ...
                'element.reference', reference, ...
                'element.type', 'spikes', ...
                'element.direct', 0);
            testCase.S.database_add(edoc);
            if ~isempty(kc)
                ne = struct('number_of_samples_per_channel', 1, 'number_of_channels', 1, ...
                    'mean_waveform', 0, 'waveform_sample_times', 0, 'cluster_index', 5, ...
                    'quality_number', 1, 'quality_label', 'good');
                nd = ndi.document('neuron_extracellular', 'neuron_extracellular', ne, ...
                    'base.session_id', testCase.S.id());
                nd = nd.set_dependency_value('element_id', edoc.id());
                nd = nd.set_dependency_value('spike_clusters_id', kc.id());
                testCase.S.database_add(nd);
            end
        end

        function b = exists(testCase, doc)
            b = ~isempty(testCase.S.database_search(ndi.query('base.id','exact_string',doc.id(),'')));
        end
    end
end
