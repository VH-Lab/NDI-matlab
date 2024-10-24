classdef neuron < ndi.element.timeseries
    % ndi.neuron - an ndi.element that contains data from a neuron
    %
    % An ndi.neuron object is simply an ndi.element.timeseries
    % object that has a different type so that it can be searched easily.
    %

    properties (GetAccess=public,SetAccess=protected)
    end; % properties

    methods
        function ndi_neuron_obj = neuron(varargin)
            % NEURON - creates an ndi.neuron object
            %
            % NDI_NEURON_OBJ = ndi.neuron(...)
            %
            % This function takes the same input arguments as
            % ndi.element.timeseries.
            %
            % See ndi.element.timeseries/timeseries
            ndi_neuron_obj=ndi_neuron_obj@ndi.element.timeseries(varargin{:});
        end; %neuron()
    end; % methods
end % classdef
