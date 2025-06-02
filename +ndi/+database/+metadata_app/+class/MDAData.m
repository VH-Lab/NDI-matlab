classdef (Abstract) MDAData < handle
    %MDADATA Abstract base class for metadata application data containers.
    %   Defines a common interface for clearing data, converting to a plain
    %   struct array, and populating from a plain struct array.

    methods (Abstract)
        %CLEARALL Clears all data items from the object.
        ClearAll(obj);

        %TOSTRUCTS Converts the internal list of items to an array of plain structs.
        %   outputStructArray = TOSTRUCTS(obj)
        %   Returns an array of structs, where each struct represents an item.
        %   Should return a 0x1 struct with fields if the list is empty.
        outputStructArray = toStructs(obj);

        %FROMSTRUCTS Populates the object's internal list from an array of plain structs.
        %   FROMSTRUCTS(obj, inputStructArray)
        %   inputStructArray: An array of plain structs. Each struct should
        %                     conform to the expected item structure.
        %   This method should clear any existing items before populating.
        fromStructs(obj, inputStructArray);
    end
end
