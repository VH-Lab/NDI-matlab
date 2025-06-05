% ./+class/MDAData.m
classdef (Abstract) MDAData < handle
    %MDADATA Abstract base class for metadata application data containers. [cite: 1203]
    %   Defines a common interface for clearing data, converting to a plain
    %   struct array, and populating from a plain struct array. [cite: 1204]
    methods (Abstract)
        %CLEARALL Clears all data items from the object.
        ClearAll(obj); [cite: 1205]
        %TOSTRUCTS Converts the internal list of items to an array of plain structs. [cite: 1206]
        %   outputStructArray = TOSTRUCTS(obj)
        %   Returns an array of structs, where each struct represents an item. [cite: 1207]
        %   Should return a 0x1 struct with fields if the list is empty. [cite: 1207]
        outputStructArray = toStructs(obj); [cite: 1208]
        %FROMSTRUCTS Populates the object's internal list from an array of plain structs. [cite: 1209]
        %   FROMSTRUCTS(obj, inputStructArray)
        %   inputStructArray: An array of plain structs. [cite: 1210] Each struct should
        %                     conform to the expected item structure. [cite: 1210]
        %   This method should clear any existing items before populating. [cite: 1211]
        fromStructs(obj, inputStructArray); [cite: 1212]

        %TOALPHANUMERICSTRUCT Converts the internal list of items to an AlphaNumericStruct.
        %   alphaNumericStructArray = TOALPHANUMERICSTRUCT(obj)
        %   Returns an array of AlphaNumericStructs. An AlphaNumericStruct contains
        %   only numeric, character array, or other AlphaNumericStructs as values.
        %   Should return an appropriately shaped empty struct if the list is empty.
        alphaNumericStructArray = toAlphaNumericStruct(obj);

        %FROMALPHANUMERICSTRUCT Populates the object's internal list from an AlphaNumericStruct.
        %   FROMALPHANUMERICSTRUCT(obj, alphaNumericStructArray)
        %   alphaNumericStructArray: An array of AlphaNumericStructs.
        %   This method should clear any existing items before populating.
        fromAlphaNumericStruct(obj, alphaNumericStructArray);
    end
end