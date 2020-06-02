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
        validator;      % Java validator object
        report;         % report of the error messages
    end
    
    methods
        function ndi_validate_obj = ndi_validate(ndi_document)
            schema = ""; %TODO: extract the file path of the schema json from the ndi_document properties
            if isa(ndi_document, 'ndi_document') 
                add_javapath();
                ndi_document = jsondecode(ndi_document);
                schemaJSON = fileread(schema); 
                if schemaJSON < 0
                    error("Invalid schema path")
                end
                schema = jsonencode(fileread(schema));
                ndi_validate_obj.validator = com.ndi.Validator(ndi_document,schema, true);
                ndi_validate_obj.report = ndi_validate_obj.validator.getReport();
                throwError(ndi_validate_obj)
            else
                error("Type mismated: expect an instance of ndi_document")
            end
        end
    end
    
    methods(Static)
     
        function add_java_path()
            ndi_globals;
            javaaddpath([ndipath filesep 'database' filesep 'Java' filesep 'jar' filesep 'ndi-validator-java.jar'], 'end');
            import com.ndi.Validator;
        end
        
        function detailed_msg = throwError(ndi_validate_obj)
            detailed_msg = ndi_validate_obj.report;
            if detail_msg.size() ~= 0
                % TODO: replace this with more detailed error message
                error("Validation fail. Run detail_msg to see detailed error message");
            end
        end
    end
end