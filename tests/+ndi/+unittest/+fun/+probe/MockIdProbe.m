classdef MockIdProbe < handle
    % MOCKIDPROBE - a minimal stand-in for an ndi.probe for extracellularInfo tests
    %
    % ndi.fun.probe.extracellularInfo only calls probe.id() and
    % probe.elementstring() on its probe argument, so this mock supplies just
    % those, with an id that the test controls.
    properties
        theid
        elestr
    end
    methods
        function obj = MockIdProbe(theid, elestr)
            obj.theid = theid;
            if nargin<2, elestr = 'mock_probe'; end
            obj.elestr = elestr;
        end
        function i = id(obj)
            i = obj.theid;
        end
        function s = elementstring(obj)
            s = obj.elestr;
        end
    end
end
