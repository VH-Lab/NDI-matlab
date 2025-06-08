classdef UILayout < ndi.util.StructSerializable
    % UILAYOUT Describes the row and column position for a component within a GridLayout.
    
    properties
        Row (1,:) {mustBeNumeric, mustBePositive, mustBeInteger}
        Column (1,:) {mustBeNumeric, mustBePositive, mustBeInteger}
    end

    methods
        function obj = UILayout(varargin)
            % UILAYOUT - Construct an instance of the UILayout class.
            if nargin > 0
                for i = 1:2:nargin
                    if isprop(obj, varargin{i})
                        obj.(varargin{i}) = varargin{i+1};
                    else
                        error('UILayout:InvalidPropertyName', 'Invalid property name: "%s"', varargin{i});
                    end
                end
            end
        end
    end
    
end