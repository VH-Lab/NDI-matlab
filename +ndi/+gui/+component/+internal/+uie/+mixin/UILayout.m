classdef UILayout
    % UILAYOUT Describes the row and column position for a component within a GridLayout.
    
    properties
        Row (1,:) {mustBeNumeric, mustBePositive, mustBeInteger} = double.empty(1,0)
        Column (1,:) {mustBeNumeric, mustBePositive, mustBeInteger} = double.empty(1,0)
    end
    methods
        function obj = UILayout(varargin) % because it is used as a default value in a property list it needs a constructor
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

