classdef Organization
    %ORGANIZATION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        digitalIdentifier
        fullName
    end
    
    methods
        function obj = Organization()
            %ORGANIZATION Construct an instance of this class
            obj.digitalIdentifier.identifier = '';
            obj.fullName = '';
        end

        function obj = updateName(obj, value)
        %updateProperty Update the value in a field 
            obj.fullName = value;
        end

        function obj = updateIdentifier(obj, value)
        %updateProperty Update the value in a field 
            obj.digitalIdentifier.identifier = value;
        end

        function name = getName(obj)
            %getName Get the value in a field 
            name = obj.fullName;
        end
    end
end

