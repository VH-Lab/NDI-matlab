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
        function ndi_validate_obj = ndi_validate(ndi_document_obj)
            schema = ndi_document_obj.document_properties.document_class.validation;
            if isa(ndi_document, 'ndi_document') 
                add_javapath();
                % ndi_document has a property called 'document_properties' that has all of the 
                % data of the document. For example, all documents have 
                % ndi_document_obj.document_properties.ndi_document with fields 'id', 'session_id', etc.
                
                doc_class = ndi_document_obj.document_properties.document_class;
                for i=1:numel(doc_class.superclasses),
                    % Step 1: read in the definition of the superclass at
                    %   doc_class.superclasses(i).definition
                    % Step 2: find the validator json in the superclass, call it validator_superclass
                    % Step 3: convert the portion of the document that corresponds to this superclass to JSON
                    superclass_name = doc_class.superclasses(i).class_name;
                    mystructure = getfield(ndi_document_obj.document_properties, superclass_name);
                    mysubdoc_json = struct([superclass_name],mystucture);
                    if isfield(ndi_document_obj.document_properties,'depends_on'),
                        mydependson = getfield(ndi_document_obj.document_properties,'depends_on');
                        mysubdoc_json = setfield(mysubdoc_json, mydependson);
                    end;
                    myclassjson = jsonencode(mysubdoc_json);
                    schemaJSON = fileread( % schema is); % some work to do here
                    thispart_validation = com.ndi.Validator(myclassjson, schemaJSON, true);  
                    report = thispart_validation.getReport();
                    throwError(thispart_validation) % ???

                end;
                
                % somehow report the overall 

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
