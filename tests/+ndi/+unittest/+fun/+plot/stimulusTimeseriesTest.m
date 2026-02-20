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
            % Call with default options
            ndi.fun.plot.stimulusTimeseries(timeref, 0);

            % Check if figure has children (plot objects)
            ax = gca;
            testCase.verifyNotEmpty(ax.Children, 'Plot should have content');

            % Call with options
            ndi.fun.plot.stimulusTimeseries(timeref, 1, 'linewidth', 3, 'linecolor', [1 0 0]);

            % Cleanup
            close(f);
        end
    end
end
