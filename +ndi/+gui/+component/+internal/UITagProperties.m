classdef UITagProperties
    % UITAGPROPERTIES - A class to hold all configuration for a single UI component.

    properties
        tag (1,:) char = ''
        type (1,:) char {mustBeMember(type, {'StaticText','EditText','TextArea','ListBox','CheckBox','Radio','PopupMenu','Table','Tree','unknown'})} = 'unknown'
        FieldMap (1,:) ndi.gui.components.internal.UIFieldMap
        hoverHelp (1,:) char = ''
        UIFromDataMethod (1,:) char {mustBeMember(UIFromDataMethod, {'default','custom'})} = 'default'
        DataFromUIMethod (1,:) char {mustBeMember(DataFromUIMethod, {'default','custom'})} = 'default'
        OnEmptyFill (1,1) ndi.gui.components.internal.UIOnEmptyFill = ndi.gui.components.internal.UIOnEmptyFill()
    end

    methods
        function obj = UITagProperties(tag, varargin)
            % Constructor to allow for easy creation of UITagProperties objects.
            % The tag is the only required argument.
            % Example:
            %   props = ndi.gui.components.internal.UITagProperties('MyEditField', 'type', 'EditText', ...);

            arguments
                tag (1,:) char
            end
            arguments (Repeating)
                varargin
            end
            
            obj.tag = tag;
            
            % Process name-value pairs
            if ~isempty(varargin)
                for i = 1:2:numel(varargin)
                    propName = varargin{i};
                    propValue = varargin{i+1};
                    if isprop(obj, propName)
                        obj.(propName) = propValue;
                    else
                        error('Invalid property name: %s', propName);
                    end
                end
            end
        end
    end
end