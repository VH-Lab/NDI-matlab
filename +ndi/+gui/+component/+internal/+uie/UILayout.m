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
    
    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, options)
            % FROMALPHANUMERICSTRUCT Create a UILayout from an alphanumeric struct
            arguments
                alphaS_in (1,1) struct
                options.errorIfFieldNotPresent (1,1) logical = false
            end
            % For this class, the alphanumeric struct is the same as the standard struct.
            S_in = alphaS_in; 
            obj = ndi.util.StructSerializable.fromStruct(mfilename('class'), S_in, 'errorIfFieldNotPresent', options.errorIfFieldNotPresent);
        end
    end
end