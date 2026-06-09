classdef ExtracellularInfoTest < matlab.unittest.TestCase
    % EXTRACELLULARINFOTEST - Unit tests for ndi.fun.probe.extracellularInfo
    %
    % Builds a small ndi.session in a temp directory and adds neuron 'element'
    % documents (whose underlying element is a probe) together with their
    % 'neuron_extracellular' documents, mirroring what
    % ndi.fun.probe.import.kilosort.probe creates. It then verifies that
    % extracellularInfo returns one entry per neuron belonging to the probe,
    % excludes neurons from other probes, sorts by cluster index, and honors the
    % quality_labels filter.

    properties
        Session
        TempDir
        ProbeId    % id of the probe under test
        OtherId    % id of a different probe (decoy)
        SubjectId  % id of a subject for the neuron elements
    end

    methods (TestMethodSetup)
        function setupSession(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            testCase.Session = ndi.session.dir('test_session', testCase.TempDir);

            % a subject for the neuron (and underlying) elements to depend on
            subject = ndi.subject('subject1@test', 'test_subject');
            subdoc = subject.newdocument();
            testCase.Session.database_add(subdoc);
            testCase.SubjectId = subdoc.id();

            % Real underlying elements (stand-ins for probes). The neuron
            % elements depend on these via underlying_element_id, so they must
            % exist in the database for dependency validation to pass.
            underlyingProbe = ndi.element(testCase.Session, 'mock_probe', 1, ...
                'n-trode', [], 0, testCase.SubjectId);
            testCase.ProbeId = underlyingProbe.id();
            underlyingOther = ndi.element(testCase.Session, 'other_probe', 1, ...
                'n-trode', [], 0, testCase.SubjectId);
            testCase.OtherId = underlyingOther.id();

            % Two neurons that belong to the probe under test (clusters 5 and 2),
            % deliberately added out of cluster order to test sorting.
            testCase.addNeuron(testCase.ProbeId, 'mock_probe_5', 5, 'good', 1);
            testCase.addNeuron(testCase.ProbeId, 'mock_probe_2', 2, 'mua',  4);

            % A decoy neuron that belongs to a DIFFERENT probe; it must not appear.
            testCase.addNeuron(testCase.OtherId, 'other_probe_0', 0, 'good', 1);
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

        function testReturnsImportedNeurons(testCase)
            probe = ndi.unittest.fun.probe.MockIdProbe(testCase.ProbeId);
            [info, summary] = ndi.fun.probe.extracellularInfo(testCase.Session, probe);

            % only the two neurons of this probe, not the decoy
            testCase.verifyEqual(numel(info), 2, 'Should find exactly the 2 neurons of this probe.');

            % sorted by cluster_index ascending: cluster 2 then cluster 5
            testCase.verifyEqual([info.cluster_index], [2 5], 'Entries should be sorted by cluster_index.');
            testCase.verifyEqual(info(1).element_name, 'mock_probe_2', 'First entry should be the cluster-2 neuron.');
            testCase.verifyEqual(info(2).element_name, 'mock_probe_5', 'Second entry should be the cluster-5 neuron.');

            % quality fields carried through from the document
            testCase.verifyEqual(info(1).quality_label, 'mua');
            testCase.verifyEqual(info(2).quality_label, 'good');
            testCase.verifyEqual(info(2).quality_number, 1);

            % pipeline string is read from the document's app.name provenance
            testCase.verifyEqual(info(1).pipeline, 'test pipeline');

            % the full neuron_extracellular property struct and the document are present
            testCase.verifyEqual(info(1).neuron_extracellular.cluster_index, 2, ...
                'neuron_extracellular sub-struct should be included.');
            testCase.verifyEqual(info(1).number_of_channels, 4);
            testCase.verifyTrue(isa(info(1).document,'ndi.document'), 'document handle should be included.');

            % summary is a non-empty multiline char array naming the probe and a neuron
            testCase.verifyTrue(ischar(summary), 'Summary should be a char array.');
            testCase.verifyTrue(contains(summary, newline), 'Summary should be multiline.');
            testCase.verifyTrue(contains(summary, 'mock_probe'), 'Summary should name the probe.');
            testCase.verifyTrue(contains(summary, 'mock_probe_5'), 'Summary should list a neuron name.');
        end

        function testQualityFilter(testCase)
            probe = ndi.unittest.fun.probe.MockIdProbe(testCase.ProbeId);
            info = ndi.fun.probe.extracellularInfo(testCase.Session, probe, ...
                'quality_labels', "good");
            testCase.verifyEqual(numel(info), 1, 'Only the good neuron should pass the filter.');
            testCase.verifyEqual(info(1).quality_label, 'good');
            testCase.verifyEqual(info(1).cluster_index, 5);
        end

        function testNoNeuronsForProbe(testCase)
            % a probe id with nothing imported
            probe = ndi.unittest.fun.probe.MockIdProbe(ndi.ido().id());
            [info, summary] = ndi.fun.probe.extracellularInfo(testCase.Session, probe);
            testCase.verifyEqual(numel(info), 0, 'A probe with no neurons should return an empty array.');
            testCase.verifyTrue(contains(summary, 'no neuron_extracellular'), ...
                'Summary should report that there are no neurons.');
        end

    end

    methods
        function addNeuron(testCase, probe_id, name, cluster, label, qnum)
            % Add a neuron 'element' document built on probe_id, plus its
            % 'neuron_extracellular' document, mirroring the kilosort importer.
            S = testCase.Session;
            app_struct = struct('name','test pipeline','version','1.0', ...
                'url','','os', computer,'os_version','', ...
                'interpreter','MATLAB','interpreter_version','9');

            elem = ndi.document('element','base.session_id', S.id(), ...
                'element.ndi_element_class','ndi.neuron', ...
                'element.name', name, 'element.reference', 1, ...
                'element.type','spikes','element.direct',0);
            elem = elem.set_dependency_value('underlying_element_id', probe_id);
            elem = elem.set_dependency_value('subject_id', testCase.SubjectId);
            S.database_add(elem);

            ne = struct('number_of_samples_per_channel',30,'number_of_channels',4, ...
                'mean_waveform', zeros(30,4), 'waveform_sample_times', (1:30)', ...
                'cluster_index', cluster, 'quality_number', qnum, 'quality_label', label);
            ned = ndi.document('neuron_extracellular','app',app_struct, ...
                'neuron_extracellular', ne, 'base.session_id', S.id());
            ned = ned.set_dependency_value('element_id', elem.id());
            S.database_add(ned);
        end
    end
end
