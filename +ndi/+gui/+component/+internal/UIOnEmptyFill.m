classdef UIOnEmptyFill
    % UIONEMPTYFILL - Defines placeholder behavior for a UI component.

    properties
        UIProperty (1,:) char = 'Value' % The property to check for emptiness (usually 'Value' or 'Text')
        value                          % The placeholder value to set if the property is empty
    end

    methods
        function obj = UIOnEmptyFill(varargin)
            % Constructor to allow for easy creation of UIOnEmptyFill objects.
            % Example:
            %   onEmpty = ndi.gui.components.internal.UIOnEmptyFill('value', 'Enter a name...');
            
            if nargin > 0
                for i = 1:2:nargin
                    if isprop(obj, varargin{i})
                        obj.(varargin{i}) = varargin{i+1};
                    else
                        error('Invalid property name: %s', varargin{i});
                    end
                end
            end
        end
    end
end