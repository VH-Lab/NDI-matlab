classdef MockSession < handle
    properties
        reference = 'mock_session_reference'
        path = ''
        probeElementString = 'mock_probe'
        probes = {} % if non-empty, returned by getprobes() instead of a MockProbe
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
            if ~isempty(obj.probes)
                probes = obj.probes;
                return;
            end
            probes = {ndi.unittest.fun.probe.MockProbe(obj.probeElementString)};
        end
    end
end
