classdef MockNamedProbe < handle
    % MOCKNAMEDPROBE - a minimal stand-in for an ndi.probe with a name, reference and id
    %
    % ndi.fun.probe.import.resolveExistingNeurons only reads probe.name and
    % probe.reference and calls probe.elementstring(), so this mock supplies just those.
    properties
        name
        reference
    end
    methods
        function obj = MockNamedProbe(name, reference)
            obj.name = name;
            obj.reference = reference;
        end
        function s = elementstring(obj)
            s = [obj.name ' | ' int2str(obj.reference)];
        end
    end
end
