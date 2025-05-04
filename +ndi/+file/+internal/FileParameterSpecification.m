classdef FileParameterSpecification
%FileParameterSpecification Specification for a DAQ System file parameter
%
%   This specification is used by the DAQ System Configurator for
%   interactively picking and adding file parameters to a DAQ system
%   configuration template
    
    properties
        % OriginalFilename - The original filename used to select a file parameter.
        %   This is the exact filename of a file belonging to a specific
        %   session and epoch.
        OriginalFilename (1,1) string = missing
        
        % ClassType - The type of class to use for reading file
        %   This should be one of "DAQ Reader", "Metadata Reader" or "Epoch Probe Map"
        ClassType (1,1) string {mustBeMember(ClassType, ["DAQ Reader", "Metadata Reader", "Epoch Probe Map"])} = "DAQ Reader"
        
        % ClassName - The full name of the matlab class to use for reading file
        ClassName (1,1) string = missing

        % UseRegularExpression - Whether to use a regular expression to find file
        %   If this is true, a regular expression is used to find the file,
        %   otherwise the full name in OriginalFilename is used.
        UseRegularExpression (1,1) logical = false

        % RegularExpression - A regular expression for finding file.
        %   This should be non-missing if UseRegularExpression is true
        RegularExpression (1,1) string = missing
    end
    
    methods
        function obj = FileParameterSpecification(propertyValues)
            arguments
                propertyValues.?ndi.file.internal.FileParameterSpecification
            end

            for fieldName = string(fieldnames(propertyValues)')
                obj.(fieldName) = propertyValues.(fieldName);
            end
        end
    end
end
