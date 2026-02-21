classdef stimulusTimeseriesTest < matlab.unittest.TestCase

    methods (Test)
        function testPlot(testCase)
            % Setup
            % Instantiate mocks
            import ndi.unittest.fun.plot.MockSession;
            import ndi.unittest.fun.plot.MockProbe;

            session = MockSession();
            probe = MockProbe(session);
            timeref = ndi.time.timereference(probe, ndi.time.clocktype('dev_local_time'), 1, 0);

            % Execution
            f = figure;
            % Call with default options and verify outputs
            [h, htext, d, t] = ndi.fun.plot.stimulusTimeseries(probe, timeref, 0);

            % Check if figure has children (plot objects)
            ax = gca;
            testCase.verifyNotEmpty(ax.Children, 'Plot should have content');

            % Verify outputs
            testCase.verifyEqual(d.stimid, [1 2 3], 'Stimulus data returned incorrectly');
            testCase.verifyEqual(t.stimon, [0 10 20], 'Stimulus time data (stimon) returned incorrectly');
            testCase.verifyEqual(t.stimoff, [5 15 25], 'Stimulus time data (stimoff) returned incorrectly');

            % Call with options
            ndi.fun.plot.stimulusTimeseries(probe, timeref, 1, 'linewidth', 3, 'linecolor', [1 0 0]);

            % Cleanup
            close(f);
        end
    end
end
