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
        validators;      % Java validator object
        reports;         % report of the error messages
    end
    
    methods
        function ndi_validate_obj = ndi_validate(ndi_document_obj,ndi_session_obj)
            % Initialization
            ndi_Init;
            ndi_globals;
            add_javapath();
            has_dependencies = 0;
            ndi_validate_obj.validators = struct();
            ndi_validate_obj.reports = struct();
            
            % Allow users to pass in only one argument if ndi_document_obj
            % does not have depends-on fields (since we don't really need
            % the ndi_session_obj)
            if nargin == 1
                ndi_session_obj = 0;
            end
            
            % Check if the user has passed in a valid ndi_document_obj
            if ~isa(ndi_document_document, 'ndi_document')
                error('You must pass in an instance of ndi_document as your first argument');
            end
            
            % Only check if the user passed in a valid instance of
            % ndi_session if ndi_document_obj has dependency
            if isfield(ndi_document_obj.document_properties, 'depends_on')
                has_dependencies = 1;
                if ~isa(ndi_session_obj, 'ndi_session')
                    error('You must pass in an instnce of ndi_session as your second argument to check for dependency')
                end
            end 
            
            % ndi_document has a property called 'document_properties' that has all of the 
            % data of the document. For example, all documents have 
            % ndi_document_obj.document_properties.ndi_document with fields 'id', 'session_id', etc.
            schema = extrct_schema(ndi_document_obj);
            doc_class = ndi_document_obj.document_properties.document_class;
            property_list = struct( eval( strcat('ndi_document_obj.document_properties.', doc_class.property_list_name) ) );
            
            % validate all non-super class properties
            ndi_validate_obj.validators.this = com.ndi.Validator( jsonencode(property_list), schema, true );
            ndi_validate_obj.reports.this = ndi_validate_obj.validators.this.getReport();
                
                
            % validate all of the document's superclass if it exists 
            for i=1:numel(doc_class.superclasses)
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
                    end
                    myclassjson = jsonencode(mysubdoc_json);
                    schemaJSON = fileread( % schema is); % some work to do here
                    thispart_validation = com.ndi.Validator(myclassjson, schemaJSON, true);  
                    report = thispart_validation.getReport();
                    throwError(thispart_validation) % ???
            end
            
            % check if there is depends-on field, if it exsists 
            if has_dependencies == 1
            end
                
            % somehow report the overall 
            ndi_validate_obj.validator = com.ndi.Validator(ndi_document,schema, true);
            ndi_validate_obj.report = ndi_validate_obj.validator.getReport();
            throwError(ndi_validate_obj)
        end
        
    end
    
    methods(Static, Access = private)
        
        function add_java_path()
            javaaddpath([ndi.path.path filesep 'database' filesep 'Java' filesep 'jar' filesep 'ndi-validator-java.jar'], 'end');
            import com.ndi.Validator;
        end
        
        function detailed_msg = throwError(ndi_validate_obj)
            detailed_msg = ndi_validate_obj.report;
            if detail_msg.size() ~= 0
                % TODO: replace this with more detailed error message
                error("Validation fail. Run detail_msg to see detailed error message");
            end
        end
        
        function schema_json = extract_schema(ndi_document_obj)
            %   EXTRACT_SCHEMA - Extract the content of the ndi_document's
            %                    corresponding schema
            %
            %   SCHEMA_JSON = EXTRACT_SCHEMA(NDI_DOCUMENT_OBJ)
            %
            schema_path = ndi_document_obj.document_properties.document_class.validation;
            schema_path = strrep(schema_path, '$NDISCHEMAPATH', ndi.path.documentschemapath);
            schema_json = fileread(schema_path);
        end
        
    end
end
