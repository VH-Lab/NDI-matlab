classdef MockSession < handle
    properties
        DAQs
    end
    methods
        function obj = MockSession()
            obj.DAQs = struct();
        end
        function addDAQ(obj, daq)
            obj.DAQs.(daq.name) = daq;
        end
        function d = daqsystem_load(obj, varargin)
            % varargin: 'name', name
            name = varargin{2};
            if isfield(obj.DAQs, name)
                d = {obj.DAQs.(name)};
            else
                d = {};
            end
        end
        function docs = database_search(obj, query)
            docs = {};
        end
    end
end
