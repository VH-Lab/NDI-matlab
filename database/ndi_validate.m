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
    
    properties(SetAccess = protected, GetAccess = public)
        ndi_document;   % the ndi_document, which will be validated
        schema;         % its corresponding schema
        validator;      % Java validator object
        report;         % report of the error messages
    end
    
    methods
        function ndi_validate_obj = ndi_validate(ndi_document, schema)
            if isa(ndi_document, 'ndi_document') && isa(schema, str)
                add_javapath();
                ndi_validate_obj.ndi_document = jsondecode(ndi_document);
                ndi_validate_obj.schema = jsonencode(fileread(schema));
                ndi_validate_obj.validator = javaObject('com.ndi.Validator', ndi_document, schema);
            end
        end
    end
    
    methods(Static)
     
        function add_java_path()
            ndi_globals;
            javaaddpath([ndipath filesep 'database' filesep 'Java' filesep 'jar'], 'end');
        end
        
        function extract_report()
            %TODO extract java.util.hashtable into MATLAB strcut 
        end
        
    end
end