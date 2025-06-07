classdef SimpleTestClass < handle & dynamicprops
% A simple handle class that allows dynamic properties for testing.
    properties
        Prop1
    end
    methods
        function obj = SimpleTestClass(val)
            if nargin > 0
                obj.Prop1 = val;
            end
        end
    end
end