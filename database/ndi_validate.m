classdef ndi_validate
    % Validate a ndi_document to ensure that the type of its properties 
    % match with the expected type according to its schema. Most of the logic
    % behind is implemented by Java using everit-org's json-schema library: 
    % https://github.com/everit-org/json-schema, a JSON Schema Validator 
    % for Java, based on org.json API. It implements the DRAFT 7 version
    % of the JSON Schema: https://json-schema.org/

    % Todo: ndi_validates takes an ndi_document and the database as input
    % need to check that all the input type match with the expected type
    % correctly. If there is a depends-on fields, we also need to search
    % through the database to ensure this actually exists

end