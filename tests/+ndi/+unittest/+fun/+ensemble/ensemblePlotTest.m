classdef ensemblePlotTest < matlab.unittest.TestCase
    % ENSEMBLEPLOTTEST - Tests for ndi.fun.ensemble.plot (element-based)
    %
    % Builds an ensemble element from a probe with spiking neurons, then verifies
    % that ndi.fun.ensemble.plot draws it as a single line whose XData/YData
    % encode the NaN-separated tick marks (spike time on X; [BottomEdge TopEdge]
    % + column*Offset on Y), that a [T0 T1] window limits what is drawn, and that
    % the axis labels follow the XLabel/YLabel options. Graphics are drawn into an
    % off-screen figure. Like ensembleElementTest, these exercise readtimeseries.

    properties
        Session
        TempDir
        Probe
    end

    methods (TestMethodSetup)
        function setupSession(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            S = ndi.session.dir('ensemble_plot_test', testCase.TempDir);

            subject = ndi.subject('subject1@test', 'test subject');
            subdoc = subject.newdocument();
            S.database_add(subdoc);
            subjectId = subdoc.id();

            utc = ndi.time.clocktype('UTC');
            probe = ndi.element.timeseries(S, 'ctx_probe', 1, 'n-trode', [], 0, subjectId);
            probe = probe.addepoch('epoch_1', utc, [0 100], [], []);

            spikes = { [10 50 90], [20 60], [30 70 80 95] };
            for i = 1:numel(spikes)
                e = ndi.element.timeseries(S, sprintf('neuron_%d', i), i, 'spikes', ...
                    probe, 0, subjectId);
                t = spikes{i}(:);
                e = e.addepoch('epoch_1', utc, [0 100], t, ones(size(t))); %#ok<NASGU>
            end

            testCase.Probe = probe;
            testCase.Session = S;
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
            S = testCase.Session;
            ens = ndi.fun.ensemble.create(S, testCase.Probe, 'epoch_1');
            [colindex, t] = ens.readtimeseries('epoch_1', -Inf, Inf);
            colindex = round(colindex(:).');
            t = t(:).';
            n = numel(t);

            fig = figure('Visible','off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            axes(fig);
            h = ndi.fun.ensemble.plot(S, ens, 'epoch_1', ...
                'BottomEdge', 0.1, 'TopEdge', 0.9, 'Offset', 1.0);

            testCase.verifyTrue(isvalid(h), 'Should return a valid line handle.');
            testCase.verifyEqual(numel(h.XData), 3*n, 'Three points per spike.');
            testCase.verifyEqual(h.XData(1:3:end), t, 'AbsTol', 1e-9, ...
                'Tick X positions are the spike times.');
            testCase.verifyEqual(h.XData(2:3:end), t, 'AbsTol', 1e-9);
            testCase.verifyTrue(all(isnan(h.XData(3:3:end))), 'NaN gaps between ticks.');
            testCase.verifyEqual(h.YData(1:3:end), 0.1 + colindex, 'AbsTol', 1e-9, ...
                'Tick bottoms are BottomEdge + column*Offset.');
            testCase.verifyEqual(h.YData(2:3:end), 0.9 + colindex, 'AbsTol', 1e-9, ...
                'Tick tops are TopEdge + column*Offset.');
        end

        function testWindowedRead(testCase)
            S = testCase.Session;
            ens = ndi.fun.ensemble.create(S, testCase.Probe, 'epoch_1');
            fig = figure('Visible','off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            axes(fig);
            h = ndi.fun.ensemble.plot(S, ens, 'epoch_1', 'T0', 25, 'T1', 75);
            x = h.XData(1:3:end);
            testCase.verifyTrue(all(x>=25 & x<=75), ...
                'Only spikes within the window should be drawn.');
        end

        function testLabelsOnByDefault(testCase)
            S = testCase.Session;
            ens = ndi.fun.ensemble.create(S, testCase.Probe, 'epoch_1');
            fig = figure('Visible','off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            ax = axes(fig);
            ndi.fun.ensemble.plot(S, ens, 'epoch_1');
            testCase.verifyEqual(ax.XLabel.String, 'Time(s)');
            testCase.verifyEqual(ax.YLabel.String, 'Neuron #');
        end

        function testLabelsCanBeDisabled(testCase)
            S = testCase.Session;
            ens = ndi.fun.ensemble.create(S, testCase.Probe, 'epoch_1');
            fig = figure('Visible','off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            ax = axes(fig);
            ndi.fun.ensemble.plot(S, ens, 'epoch_1', 'XLabel', false, 'YLabel', false);
            testCase.verifyEmpty(ax.XLabel.String);
            testCase.verifyEmpty(ax.YLabel.String);
        end

        function testColorAndLineWidth(testCase)
            S = testCase.Session;
            ens = ndi.fun.ensemble.create(S, testCase.Probe, 'epoch_1');
            fig = figure('Visible','off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            axes(fig);
            h = ndi.fun.ensemble.plot(S, ens, 'epoch_1', 'Color', [1 0 0], 'LineWidth', 2.5);
            testCase.verifyEqual(h.Color, [1 0 0]);
            testCase.verifyEqual(h.LineWidth, 2.5);
        end

    end
end
