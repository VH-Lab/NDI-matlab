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
            % like the real session, 'name' is a regular expression
            name = varargin{2};
            d = {};
            fn = fieldnames(obj.DAQs);
            for i=1:numel(fn)
                if ~isempty(regexp(fn{i}, name, 'once'))
                    d{end+1} = obj.DAQs.(fn{i}); %#ok<AGROW>
                end
            end
        end
        function docs = database_search(obj, query)
            docs = {};
        end
    end
end
