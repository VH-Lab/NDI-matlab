classdef ensemblePlotTest < matlab.unittest.TestCase
    % ENSEMBLEPLOTTEST - Tests for ndi.fun.ensemble.plot
    %
    % Seeds an 'ensemble' document with a known activity matrix and verifies that
    % ndi.fun.ensemble.plot draws it as a single line whose XData/YData encode the
    % expected NaN-separated tick marks, that the BottomEdge/TopEdge/Offset
    % options position the per-cell bands, and that the axis labels follow the
    % XLabel/YLabel options. Graphics are drawn into an off-screen figure.

    properties
        Session
        TempDir
        ProbeId
        NeuronIds
        NeuronNames
    end

    methods (TestMethodSetup)
        function setupSession(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            testCase.Session = ndi.session.dir('ensemble_plot_test', testCase.TempDir);
            S = testCase.Session;

            subject = ndi.subject('subject1@test', 'test subject');
            subdoc = subject.newdocument();
            S.database_add(subdoc);
            subjectId = subdoc.id();

            probe = ndi.document('element', 'base.session_id', S.id(), ...
                'element.ndi_element_class', 'ndi.probe.timeseries.mfdaq', ...
                'element.name', 'ctx_probe', 'element.reference', 1, ...
                'element.type', 'n-trode', 'element.direct', 1);
            probe = probe.set_dependency_value('subject_id', subjectId);
            S.database_add(probe);
            testCase.ProbeId = probe.id();

            n = 3;
            ids = cell(1,n); names = cell(1,n);
            for i = 1:n
                nm = sprintf('ctx_probe_neuron_%d', i);
                elem = ndi.document('element', 'base.session_id', S.id(), ...
                    'element.ndi_element_class', 'ndi.neuron', ...
                    'element.name', nm, 'element.reference', i, ...
                    'element.type', 'spikes', 'element.direct', 0);
                elem = elem.set_dependency_value('underlying_element_id', testCase.ProbeId);
                elem = elem.set_dependency_value('subject_id', subjectId);
                S.database_add(elem);
                ids{i} = elem.id();
                names{i} = nm;
            end
            testCase.NeuronIds = ids;
            testCase.NeuronNames = names;
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

        function testHashMarkCoordinates(testCase)
            % neuron 1 spikes at 0.1 and 0.2; neuron 2 at 0.5; neuron 3 silent.
            E = sparse(3,2);
            E(1,1:2) = [0.1 0.2];
            E(2,1)   = 0.5;
            doc = testCase.seedEnsemble(E);

            fig = figure('Visible','off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            axes(fig);
            h = ndi.fun.ensemble.plot(testCase.Session, doc, ...
                'BottomEdge', 0.1, 'TopEdge', 0.9, 'Offset', 1.0);

            testCase.verifyTrue(isvalid(h), 'Should return a valid line handle.');
            % find() returns entries in column-major order:
            %   (1,1)=0.1, (2,1)=0.5, (1,2)=0.2
            expX = [0.1 0.1 NaN 0.5 0.5 NaN 0.2 0.2 NaN];
            expY = [1.1 1.9 NaN 2.1 2.9 NaN 1.1 1.9 NaN];
            testCase.verifyEqual(numel(h.XData), 9, 'Three ticks, three points each.');
            testCase.verifyTrue(isequaln(h.XData(:).', expX), ...
                'X ticks should sit at the spike times, with NaN gaps.');
            testCase.verifyTrue(isequaln(h.YData(:).', expY), ...
                'Y bands should be [BottomEdge TopEdge] + cell*Offset, with NaN gaps.');
        end

        function testOffsetAndEdges(testCase)
            % Non-default edges and offset reposition the bands.
            E = sparse([1 2],[1 1],[0.3 0.4],2,1);
            doc = testCase.seedEnsemble(E);

            fig = figure('Visible','off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            axes(fig);
            h = ndi.fun.ensemble.plot(testCase.Session, doc, ...
                'BottomEdge', 0.2, 'TopEdge', 0.8, 'Offset', 2.0);

            % cell 1 -> [0.2 0.8]+2 = 2.2,2.8 ; cell 2 -> +4 = 4.2,4.8
            expY = [2.2 2.8 NaN 4.2 4.8 NaN];
            testCase.verifyTrue(isequaln(h.YData(:).', expY), ...
                'Edges and offset should set the band positions.');
        end

        function testLabelsOnByDefault(testCase)
            E = sparse([1],[1],[0.3],3,1);
            doc = testCase.seedEnsemble(E);
            fig = figure('Visible','off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            ax = axes(fig);
            ndi.fun.ensemble.plot(testCase.Session, doc);
            testCase.verifyEqual(ax.XLabel.String, 'Time(s)');
            testCase.verifyEqual(ax.YLabel.String, 'Neuron #');
        end

        function testLabelsCanBeDisabled(testCase)
            E = sparse([1],[1],[0.3],3,1);
            doc = testCase.seedEnsemble(E);
            fig = figure('Visible','off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            ax = axes(fig);
            ndi.fun.ensemble.plot(testCase.Session, doc, 'XLabel', false, 'YLabel', false);
            testCase.verifyEmpty(ax.XLabel.String);
            testCase.verifyEmpty(ax.YLabel.String);
        end

        function testColorAndLineWidth(testCase)
            E = sparse([1],[1],[0.3],2,1);
            doc = testCase.seedEnsemble(E);
            fig = figure('Visible','off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            axes(fig);
            h = ndi.fun.ensemble.plot(testCase.Session, doc, ...
                'Color', [1 0 0], 'LineWidth', 2.5);
            testCase.verifyEqual(h.Color, [1 0 0], 'Color option should be applied.');
            testCase.verifyEqual(h.LineWidth, 2.5, 'LineWidth option should be applied.');
        end

    end

    methods % helpers
        function doc = seedEnsemble(testCase, activity)
            % Build and add an 'ensemble' document with a known activity matrix.
            S = testCase.Session;
            N = size(activity,1);
            ids = testCase.NeuronIds(1:N);
            names = testCase.NeuronNames(1:N);

            af = [ndi.file.temp_name() '.ndisparse'];
            ndi.util.writeSparse(af, activity);
            nf = [ndi.file.temp_name() '.txt'];
            fid = fopen(nf, 'w');
            for i = 1:numel(names)
                fprintf(fid, '%s\n', names{i});
            end
            fclose(fid);

            doc = S.newdocument('ensemble', ...
                'ensemble.ensemble_name', 'plot', ...
                'ensemble.value_type', 'spiketimes', ...
                'ensemble.value_description', 'seeded', ...
                'ensemble.num_neurons', N, ...
                'ensemble.num_dimensions', 2, ...
                'ensemble.clocktype', 'dev_local_time', ...
                'epochid.epochid', 'epoch_1');
            doc = doc.set_dependency_value('element_id', testCase.ProbeId);
            for i = 1:numel(ids)
                doc = doc.add_dependency_value_n('neuron_id', ids{i});
            end
            doc = doc.add_file('ensemble_activity.ndisparse', af);
            doc = doc.add_file('neuron_names.txt', nf);
            S.database_add(doc);
        end
    end
end
