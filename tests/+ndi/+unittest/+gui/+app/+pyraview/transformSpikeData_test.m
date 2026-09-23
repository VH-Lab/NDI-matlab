classdef transformSpikeData_test < matlab.unittest.TestCase
    % TRANSFORMSPIKEDATA_TEST - Unit test for ndi.gui.app.pyraview.transformSpikeData

    methods (Test)
        function testWindowFiltering(testCase)
            % Spikes outside the visible window [t0, t1] should be filtered out
            % so that the number of plotted segments stays proportional to what
            % is on screen rather than the whole epoch.

            % Mock spiking_info
            % Structure array with spike_times and best_channel
            spiking_info = struct();
            spiking_info(1).spike_times = [10, 20, 30];
            spiking_info(1).best_channel = 1;

            selectedIdx = 1;
            t0 = 15;
            t1 = 25;
            spacing = 100;

            % Call function
            [X, Y] = ndi.gui.app.pyraview.transformSpikeData(spiking_info, selectedIdx, t0, t1, spacing);

            % Verification
            % Only the spike at t=20 is inside [15, 25]; 10 and 30 are excluded.
            % X format is [t; t; NaN] for each spike

            testCase.verifyFalse(any(X == 10), 'X should not contain spike at t=10 (before window)');
            testCase.verifyTrue(any(X == 20), 'X should contain spike at t=20 (inside window)');
            testCase.verifyFalse(any(X == 30), 'X should not contain spike at t=30 (after window)');

            % Verify Y structure
            % Should have 1 segment (1 visible spike) * 3 points = 3 points
            testCase.verifyEqual(numel(X), 3, 'Should have 3 points in X');
            testCase.verifyEqual(numel(Y), 3, 'Should have 3 points in Y');

        end

        function testWindowBoundariesInclusive(testCase)
            % Spikes exactly at t0 and t1 should be included.
            spiking_info = struct();
            spiking_info(1).spike_times = [15, 25];
            spiking_info(1).best_channel = 1;

            [X, ~] = ndi.gui.app.pyraview.transformSpikeData(spiking_info, 1, 15, 25, 100);

            testCase.verifyTrue(any(X == 15), 'X should contain spike at t0=15');
            testCase.verifyTrue(any(X == 25), 'X should contain spike at t1=25');
            testCase.verifyEqual(numel(X), 6, 'Should have 6 points (2 spikes x 3)');
        end

        function testMultipleNeurons(testCase)
            % Test with multiple neurons selected

            spiking_info(1).spike_times = [10];
            spiking_info(1).best_channel = 1;
            spiking_info(2).spike_times = [40];
            spiking_info(2).best_channel = 2;

            selectedIdx = [1, 2];
            t0 = 0; t1 = 100; spacing = 100;

            [X, Y] = ndi.gui.app.pyraview.transformSpikeData(spiking_info, selectedIdx, t0, t1, spacing);

            testCase.verifyTrue(any(X == 10), 'X should contain t=10');
            testCase.verifyTrue(any(X == 40), 'X should contain t=40');

            % Verify Y Levels
            % Neuron 1 (best_channel 1): Base 0. Y range 40..60
            % Neuron 2 (best_channel 2): Base 100. Y range 140..160

            mask1 = (X == 10);
            y1 = Y(mask1);
            y1_vals = y1(~isnan(y1));
            testCase.verifyTrue(all(y1_vals >= 40 & y1_vals <= 60), 'Neuron 1 Y values correct');

            mask2 = (X == 40);
            y2 = Y(mask2);
            y2_vals = y2(~isnan(y2));
            testCase.verifyTrue(all(y2_vals >= 140 & y2_vals <= 160), 'Neuron 2 Y values correct');
        end

        function testShowBox(testCase)
            % With show_box true, a 2 ms wide box spanning low_channel..high_channel
            % is emitted in addition to the vertical tick.
            spiking_info = struct();
            spiking_info(1).spike_times = 20;
            spiking_info(1).best_channel = 3;
            spiking_info(1).low_channel = 2;
            spiking_info(1).high_channel = 5;

            spacing = 100;
            [X, Y] = ndi.gui.app.pyraview.transformSpikeData(spiking_info, 1, 0, 100, spacing, true);

            % Box corners should be at t +/- 0.001 s (2 ms total width).
            testCase.verifyTrue(any(abs(X - (20 - 0.001)) < 1e-9), 'Box left edge at t-1ms');
            testCase.verifyTrue(any(abs(X - (20 + 0.001)) < 1e-9), 'Box right edge at t+1ms');

            % Box vertical extent: (low-1)*spacing = 100 to (high-1)*spacing = 400.
            yvals = Y(~isnan(Y));
            testCase.verifyEqual(min(yvals), 100, 'Box bottom at (low_channel-1)*spacing');
            testCase.verifyEqual(max(yvals), 400, 'Box top at (high_channel-1)*spacing');

            % Without show_box, no box edges appear (only the tick at t=20).
            [X2, ~] = ndi.gui.app.pyraview.transformSpikeData(spiking_info, 1, 0, 100, spacing);
            testCase.verifyFalse(any(abs(X2 - (20 - 0.001)) < 1e-9), 'No box when show_box is false');
        end
    end
end
