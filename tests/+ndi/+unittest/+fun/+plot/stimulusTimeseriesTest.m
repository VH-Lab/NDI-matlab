classdef stimulusTimeseriesTest < matlab.unittest.TestCase

    methods (Test)
        function testPlot(testCase)
            % Setup
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

classdef MockSession < ndi.session
    methods
        function obj = MockSession()
            obj = obj@ndi.session('mock_session');
        end
    end
end

classdef MockProbe < ndi.epoch.epochset
    properties
        session
    end
    methods
        function obj = MockProbe(session)
            obj.session = session;
        end
        function [data, t, timeref] = readtimeseries(obj, timeref, t0, t1)
             data.stimid = [1 2 3];
             t.stimon = [0 10 20];
             t.stimoff = [5 15 25];
             % Return the input timeref as the output timeref
             timeref = timeref;
        end

        function name = epochsetname(obj)
            name = 'mock_probe';
        end

        function eid = epochid(obj, epoch_number)
            eid = 'epoch_1';
        end

        function et = epochtable(obj)
             et = struct('epoch_id', 'epoch_1', 'epoch_clock', {ndi.time.clocktype('dev_local_time')}, ...
                 't0_t1', {[0 30]}, 'epoch_session_id', obj.session.id());
        end
    end
end
