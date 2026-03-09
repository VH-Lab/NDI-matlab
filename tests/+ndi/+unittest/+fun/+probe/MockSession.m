classdef MockSession < handle
    properties
        reference = 'mock_session_reference'
        path = ''
    end
    methods
        function obj = MockSession()
            obj.path = [tempdir, 'mock_session'];
        end
        function probes = getprobes(obj, varargin)
            % Returns a list of mock probes
            probes = {ndi.unittest.fun.probe.MockProbe()};
        end
    end
end
