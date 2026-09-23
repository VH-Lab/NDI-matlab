classdef MockProbe < handle
    properties
        elestr = 'mock_probe'
    end
    methods
        function obj = MockProbe(elestr)
            % MOCKPROBE - a minimal stand-in for an ndi.probe
            %
            % OBJ = MOCKPROBE([ELESTR])
            %
            % ELESTR is the string returned by elementstring(); it defaults to
            % 'mock_probe'. Pass something like 'ctx | 1' to exercise the
            % separator handling of ndi.fun.file.elementDirectoryName.
            if nargin>=1
                obj.elestr = elestr;
            end
        end
        function str = elementstring(obj)
            str = obj.elestr;
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
            data = [t, t*2];
        end
    end
end
