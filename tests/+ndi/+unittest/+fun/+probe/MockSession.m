classdef MockSession < handle
    properties
        reference = 'mock_session_reference'
        path = ''
        probeElementString = 'mock_probe'
    end
    methods
        function obj = MockSession(probeElementString)
            % MOCKSESSION - a minimal stand-in for an ndi.session
            %
            % OBJ = MOCKSESSION([PROBEELEMENTSTRING])
            %
            % PROBEELEMENTSTRING is the elementstring() of the single mock probe
            % this session returns from getprobes(); it defaults to 'mock_probe'.
            obj.path = [tempdir, 'mock_session'];
            if nargin>=1
                obj.probeElementString = probeElementString;
            end
        end
        function probes = getprobes(obj, varargin)
            % Returns a list of mock probes
            probes = {ndi.unittest.fun.probe.MockProbe(obj.probeElementString)};
        end
    end
end
