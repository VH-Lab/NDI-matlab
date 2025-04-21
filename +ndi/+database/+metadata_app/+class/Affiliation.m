classdef Affiliation
    %AFFILIATION Summary of this class goes here
    %   Detailed explanation goes here

    properties
        memberOf
    end

    methods
        function obj = Affiliation()
            %AFFILIATION Construct an instance of this class
            %   Detailed explanation goes here
            obj.memberOf = ndi.database.metadata_app.class.Organization();
        end

        function obj = updateName(obj, value)
            %updateName Update the value in a field
            obj.memberOf.fullName = value;
        end

        function obj = updateIdentifier(obj, value)
            %updateIdentifier Update the value in a field
            obj.memberOf.digitalIdentifier.identifier = value;
        end

        function obj = getName(obj)
            %getName Get the value in a field
            obj.memberOf.getName();
        end

        function S = getTableStruct(obj)
            %getTableStruct Get the value in a field
            S = struct;
            S.Name = obj.memberOf.getName();
        end
    end
end
