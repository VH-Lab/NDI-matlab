classdef ensemblePlotTest < matlab.unittest.TestCase
    % ENSEMBLEPLOTTEST - Unit tests for ndi.fun.ensemble.plot (structure form)
    %
    % Plots an ensemble structure (as produced by ndi.fun.ensemble.read /
    % filter) and verifies that the single line's XData/YData encode the
    % NaN-separated tick marks (spike time on X; [BottomEdge TopEdge] +
    % row*Offset on Y), that filtering before plotting re-indexes the rows, and
    % that the style/label options are honored. This uses only the structure
    % form, so no database or read-back is involved; graphics go to an off-screen
    % figure.

    methods
        function E = makeEnsemble(~)
            % 3 neurons; neuron 1 spikes at 0.1,0.2; neuron 2 at 0.5; neuron 3 silent.
            A = sparse(3,2);
            A(1,1:2) = [0.1 0.2];
            A(2,1)   = 0.5;
            E = struct();
            E.activity = A;
            E.neuron_ids = {'id1','id2','id3'};
            E.neuron_names = {'A','B','C'};
            E.epoch = 'epoch_1';
            E.info = struct('num_neurons', 3);
        end
    end

    methods (Test)

        function testHashMarkCoordinates(testCase)
            E = testCase.makeEnsemble();
            fig = figure('Visible','off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            axes(fig);
            h = ndi.fun.ensemble.plot(E, 'BottomEdge', 0.1, 'TopEdge', 0.9, 'Offset', 1.0);

            testCase.verifyTrue(isvalid(h), 'Should return a valid line handle.');
            % find() is column-major: (1,1)=0.1, (2,1)=0.5, (1,2)=0.2
            expX = [0.1 0.1 NaN 0.5 0.5 NaN 0.2 0.2 NaN];
            expY = [1.1 1.9 NaN 2.1 2.9 NaN 1.1 1.9 NaN];
            testCase.verifyTrue(isequaln(h.XData, expX), 'X ticks at spike times, NaN gaps.');
            testCase.verifyTrue(isequaln(h.YData, expY), 'Y bands = [0.1 0.9] + row*offset.');
        end

        function testFilterThenPlotReindexes(testCase)
            % keep 2 of 4 neurons, then plot: the kept neurons become rows 1..2.
            A = sparse(4,3);
            A(1,1) = 11; A(2,1:2) = [21 22]; A(3,1:3) = [31 32 33]; A(4,1) = 41;
            E = struct('activity', A, 'neuron_ids', {{'id1','id2','id3','id4'}}, ...
                'neuron_names', {{'A','B','C','D'}}, 'epoch', 'epoch_1', ...
                'info', struct('num_neurons',4));
            E = ndi.fun.ensemble.filter(E, 'IncludeNames', {'B','D'});

            fig = figure('Visible','off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            axes(fig);
            h = ndi.fun.ensemble.plot(E, 'BottomEdge', 0.1, 'TopEdge', 0.9, 'Offset', 1.0);
            % filtered activity is [21 22; 41 0]; find col-major: (1,1)=21,(2,1)=41,(1,2)=22
            expY = [1.1 1.9 NaN 2.1 2.9 NaN 1.1 1.9 NaN];
            testCase.verifyTrue(isequaln(h.YData, expY), ...
                'Kept neurons should be re-indexed to rows 1..K.');
        end

        function testLabelsOnByDefault(testCase)
            fig = figure('Visible','off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            ax = axes(fig);
            ndi.fun.ensemble.plot(testCase.makeEnsemble());
            testCase.verifyEqual(ax.XLabel.String, 'Time(s)');
            testCase.verifyEqual(ax.YLabel.String, 'Neuron #');
        end

        function testLabelsCanBeDisabled(testCase)
            fig = figure('Visible','off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            ax = axes(fig);
            ndi.fun.ensemble.plot(testCase.makeEnsemble(), 'XLabel', false, 'YLabel', false);
            testCase.verifyEmpty(ax.XLabel.String);
            testCase.verifyEmpty(ax.YLabel.String);
        end

        function testColorAndLineWidth(testCase)
            fig = figure('Visible','off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            axes(fig);
            h = ndi.fun.ensemble.plot(testCase.makeEnsemble(), 'Color', [1 0 0], 'LineWidth', 2.5);
            testCase.verifyEqual(h.Color, [1 0 0]);
            testCase.verifyEqual(h.LineWidth, 2.5);
        end

    end
end
