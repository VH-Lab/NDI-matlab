classdef AddMultipleTest < matlab.unittest.TestCase
    % ADDMULTIPLETEST - Unit tests for ndi.element.timeseries.addMultiple
    %
    % Builds a small ndi.session in a temp directory with a subject and an
    % underlying ndi.element (standing in for a probe), then uses
    % ndi.element.timeseries.addMultiple to create several ndi.neuron elements,
    % each with multiple epochs of spike data and a neuron_extracellular
    % "extra document". It verifies that the right number of element,
    % element_epoch, and neuron_extracellular documents are created with the
    % correct element_id dependencies, that chunking does not change the result,
    % and that an empty spec list is a no-op.

    properties
        Session
        TempDir
        Underlying    % an ndi.element that the neurons are built on
        SubjectId
    end

    methods (TestMethodSetup)
        function setupSession(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            testCase.Session = ndi.session.dir('test_session', testCase.TempDir);

            % a subject for the elements to depend on
            subject = ndi.subject('subject1@test', 'test_subject');
            subdoc = subject.newdocument();
            testCase.Session.database_add(subdoc);
            testCase.SubjectId = subdoc.id();

            % an underlying element (stands in for a probe); its subject_id is
            % what addMultiple propagates to the new neuron elements
            testCase.Underlying = ndi.element(testCase.Session, 'mock_probe', 1, ...
                'n-trode', [], 0, testCase.SubjectId);
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

        function testCreatesElementsEpochsAndExtraDocs(testCase)
            S = testCase.Session;
            nNeurons = 3;
            nEpochs  = 2;
            specs = testCase.buildSpecs(nNeurons, nEpochs);

            neurons = ndi.element.timeseries.addMultiple(S, testCase.Underlying, specs, ...
                'element_class','ndi.neuron');

            % returns one object per neuron, of the requested class
            testCase.verifyEqual(numel(neurons), nNeurons);
            testCase.verifyClass(neurons(1), 'ndi.neuron');

            % exactly nNeurons ndi.neuron element documents were created
            edocs = testCase.neuronElementDocs();
            testCase.verifyEqual(numel(edocs), nNeurons, ...
                'Should create one element doc per neuron.');

            % one neuron_extracellular per neuron, each depending on a created element
            ndocs = S.database_search(ndi.query('','isa','neuron_extracellular',''));
            testCase.verifyEqual(numel(ndocs), nNeurons, ...
                'Should create one neuron_extracellular per neuron.');
            elemIds = cellfun(@(d) d.id(), edocs, 'UniformOutput', false);
            for i=1:numel(ndocs),
                testCase.verifyTrue(ismember(ndocs{i}.dependency_value('element_id'), elemIds), ...
                    'Each neuron_extracellular should depend on a created element.');
            end;

            % nNeurons * nEpochs epoch documents, each depending on a created element
            epdocs = S.database_search(ndi.query('','isa','element_epoch',''));
            testCase.verifyEqual(numel(epdocs), nNeurons*nEpochs, ...
                'Should create one element_epoch per neuron per epoch.');
            for i=1:numel(epdocs),
                testCase.verifyTrue(ismember(epdocs{i}.dependency_value('element_id'), elemIds), ...
                    'Each element_epoch should depend on a created element.');
            end;
        end

        function testChunkingMatches(testCase)
            % A chunksize smaller than the number of neurons must still create
            % every neuron and all of its documents.
            S = testCase.Session;
            nNeurons = 5;
            nEpochs  = 2;
            specs = testCase.buildSpecs(nNeurons, nEpochs);

            ndi.element.timeseries.addMultiple(S, testCase.Underlying, specs, ...
                'element_class','ndi.neuron','chunksize',2);

            testCase.verifyEqual(numel(testCase.neuronElementDocs()), nNeurons);
            testCase.verifyEqual(numel(S.database_search(ndi.query('','isa','element_epoch',''))), ...
                nNeurons*nEpochs);
            testCase.verifyEqual(numel(S.database_search(ndi.query('','isa','neuron_extracellular',''))), ...
                nNeurons);
        end

        function testEmptySpecsIsNoOp(testCase)
            S = testCase.Session;
            specs = struct('name',{},'reference',{},'type',{},'epochs',{},'extra_documents',{});
            neurons = ndi.element.timeseries.addMultiple(S, testCase.Underlying, specs);
            testCase.verifyEmpty(neurons);
            testCase.verifyEqual(numel(testCase.neuronElementDocs()), 0);
        end

    end

    methods
        function specs = buildSpecs(testCase, nNeurons, nEpochs)
            % build a spec array: nNeurons neurons, each with nEpochs epochs and
            % a neuron_extracellular extra document
            S = testCase.Session;
            app_struct = struct('name','test pipeline','version','1.0', ...
                'url','','os', computer,'os_version','', ...
                'interpreter','MATLAB','interpreter_version','9');
            specs = struct('name',{},'reference',{},'type',{},'epochs',{},'extra_documents',{});
            for i=1:nNeurons,
                clear epochs;
                for e=1:nEpochs,
                    tp = (1:(i*e))';           % a few "spike times"
                    epochs(e) = struct('epoch_id', ['epoch' int2str(e)], ...
                        'epoch_clock', 'dev_local_time', ...
                        't0_t1', {[0 100]}, 'timepoints', {tp}, ...
                        'datapoints', {ones(size(tp))}); %#ok<AGROW>
                end;
                ne = struct('number_of_samples_per_channel',30,'number_of_channels',4, ...
                    'mean_waveform', zeros(30,4), 'waveform_sample_times', (1:30)', ...
                    'cluster_index', i, 'quality_number', 1, 'quality_label', 'good');
                ned = ndi.document('neuron_extracellular','app',app_struct, ...
                    'neuron_extracellular', ne, 'base.session_id', S.id());
                specs(end+1) = struct('name', ['n_' int2str(i)], 'reference', i, ...
                    'type', 'spikes', 'epochs', {epochs}, ...
                    'extra_documents', {{ned}}); %#ok<AGROW>
            end;
        end

        function edocs = neuronElementDocs(testCase)
            % element documents whose ndi_element_class is ndi.neuron (excludes
            % the underlying 'mock_probe' element)
            q = ndi.query('','isa','element','') & ...
                ndi.query('element.ndi_element_class','exact_string','ndi.neuron','');
            edocs = testCase.Session.database_search(q);
        end
    end
end
