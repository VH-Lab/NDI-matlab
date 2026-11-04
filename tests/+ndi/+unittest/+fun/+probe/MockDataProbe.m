classdef MockDataProbe < handle
    properties
        datafcn % function handle t -> data (samples x channels)
    end
    methods
        function obj = MockDataProbe(datafcn)
            % MOCKDATAPROBE - a minimal ndi.probe stand-in with configurable data
            %
            % OBJ = MOCKDATAPROBE(DATAFCN)
            %
            % DATAFCN is called with the column vector of sample times and must
            % return the data (samples x channels) that readtimeseries reports.
            obj.datafcn = datafcn;
        end
        function str = elementstring(obj)
            str = 'mock_data_probe';
        end
        function et = epochtable(obj)
            et = struct('epoch_id', 'epoch1', 't0_t1', {{[0 200]}});
        end
        function samples = times2samples(obj, epoch_id, t)
            samples = round(t * 1000); % sample rate 1000
        end
        function sr = samplerate(obj, epoch_id)
            sr = 1000;
        end
        function [data, t] = readtimeseries(obj, epoch_id, start_time, end_time)
            t = (start_time:(1/1000):end_time)';
            data = obj.datafcn(t);
        end
    end
end
