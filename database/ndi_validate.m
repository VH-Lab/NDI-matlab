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
        validators;          % Java validator object
        reports;             % report of the error messages
        errormsg_this;       % display any type mismatch of the current object's field
        errormsg_super;      % display any type mismatch of the super class object's field
        errormsg_depends_on; % display any depends_on objects that cannot be found in the database
        is_valid             % is the ndi_document valid or not
    end
    
    methods
        function ndi_validate_obj = ndi_validate(ndi_document_obj,ndi_session_obj)
            if nargin == 0
                error("You must pass in an instance of ndi_document_obj and an instance of ndi_session_obj as arguments");
            end
            
            % Initialization
            ndi_Init;
            ndi_globals;
            add_javapath();
            has_dependencies = 0;
            ndi_validate_obj.validators = struct();
            ndi_validate_obj.reports = struct();
            ndi_validate_obj.errormsg_this = '';
            ndi_validate_obj.errormsg_super = '';
            ndi_validate_obj.errormsg_depends_on = "We cannot find the following dependencies:\n";
            ndi_validate_obj.is_valid = true;
            
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
            %property_list = getfield(ndi_document_obj.document_properties, doc_class.property_list_name);
            property_list = struct( eval( strcat('ndi_document_obj.document_properties.', doc_class.property_list_name) ) );
            property_list = eval( strcat('ndi_document_obj.document_properties.', doc_class.property_list_name));
            
            % validate all non-super class properties
            ndi_validate_obj.validators.this = com.ndi.Validator( jsonencode(property_list), schema, true );
            ndi_validate_obj.reports.this = ndi_validate_obj.validators.this.getReport();
            ndi_validate_obj.errormsg_this = strcat(doc_class.property_list_name, ":\n", readHashMap(ndi_validate_obj.reports.this), "\n");
            if ndi_validate_obj.reports.this.size() > 0
                ndi_validate_obj.is_valid = false;
            end
                
                
            % validate all of the document's superclass if it exists 
            numofsuperclasses = numel(doc_class.superclasses);
            if numofsuperclasses > 0
                ndi_validate_obj.validators.super = zeros(1, numofsuperclasses);
                ndi_validate_obj.reports.super = zeros(1, numofsuperclasses);
            end
            for i=1:numel(numofsuperclasses)
                % Step 1: read in the definition of the superclass at
                %   doc_class.superclasses(i).definition
                % Step 2: find the validator json in the superclass, call it validator_superclass
                % Step 3: convert the portion of the document that corresponds to this superclass to JSON
                superclass_name = doc_class.superclasses(i).definition;
                schema = extract_schema(superclass_name);
                superclassname_without_extension = extractnamefromdefinition(superclass_name);
                properties = struct( eval( strcat('ndi_document_obj.document_properties.', superclassname_without_extension) ) );
                %% TODO: pass depends_on here 
                if has_dependencies, 
                  properties.depends_on = ndi_document_obj.document_properties.depends_on;
                end;
                validator = com.ndi.Validator(jsonencode(properties), schema, true);
                report = validator.getReport();
                ndi_validate_obj.validators.super(i) = struct(superclassname_without_extension, validator); 
                ndi_validate_obj.reports.super(i) = struct(superclassname_without_extension,  report ); 
                ndi_validate_obj.errormsg_super = strcat(ndi_validate_obj.errormsg_super, ":\n", readHashMap(report), "\n");
                if validator.size() > 0
                    ndi_validate_obj.is_valid = false;
                end
            end
            
            % check if there is depends-on field, if it exsists we need to
            % search through the ndi_session database to check 
            if has_dependencies == 1
                numofdependencies = numel(doc.document_properties.depends_on');
                ndi_validate_obj.reports.dependencies = zeros(1,numofdependencies);
                % NOTE: this does not verify that 'depends-on' documents have the right class membership
                % might want to add this in the future
                for i = 1:numofdependencies
                    searchquery = {'ndi_document.session_id', doc.document_properties.depends_on(i).value};
                    if numel(ndi_session_obj.database_search(searchquery)) < 1
                        ndi_validate_obj.reports.dependencies(i) = struct(doc.document_properties.depends_on(i).name, 'fail');
                        ndi_validate_obj.errormsg_depends_on = strcat(ndi_validate_obj.errormsg_depends_on, doc.document_properties.depends_on(i).name, "\n");
                        ndi_validate_obj.is_valid = false;
                    else
                        ndi_validate_obj.reports.dependencies(i) = struct(doc.document_properties.depends_on(i).name, 'success');
                    end
                end
            end
                
            % somehow report the overall 
            if ~is_valid
                msg = strcat('Validation has failed. Here is a detailed report of the source of failure: \n'...
                    , "------------------------------------------------------------------------------"...
                    , ndi_validate_obj.errormsg_this...
                    , "------------------------------------------------------------------------------"... 
                    , ndi_validate_obj.errormsg_super...
                    , "------------------------------------------------------------------------------"...
                    , ndi_validate_obj.errormsg_depends_on...
                    , "------------------------------------------------------------------------------"...
                    , "To get this detailed report as a struct. Please access its instance field reports");
                error(msg);
            end
        end
        
    end
    
    methods(Static, Access = private)
        
        function add_java_path()
            javaaddpath([ndi.path.path filesep 'database' filesep 'Java' filesep 'jar' filesep 'ndi-validator-java.jar'], 'end');
            import com.ndi.Validator;
        end
        
        function schema_json = extract_schema(ndi_document_obj)
            %   EXTRACT_SCHEMA - Extract the content of the ndi_document's
            %                    corresponding schema
            %
            %   SCHEMA_JSON = EXTRACT_SCHEMA(NDI_DOCUMENT_OBJ)
            %
            schema_json = "";
            if isa(ndi_document_obj, 'ndi_document')
                schema_path = ndi_document_obj.document_properties.document_class.validation;
                schema_path = strrep(schema_path, '$NDISCHEMAPATH', ndi.path.documentschemapath);
                try
                    schema_json = fileread(schema_path);
                catch
                    error("the schema path does not exsist");
                end
            end
            if isa(ndi_document_obj, 'char') || isa(ndi_document_obj, 'string')
                if  numel( strfind(ndi_document_obj, '$NDIDOCUMENTPATH') ) ~= 0
                    schema_path = strrep(schema_path, '$NDIDOCUMENTPATH', ndi.path.documentschemapath);
                elseif numel( strfind(ndi_document_obj, '$NDISCHEMAPATH') ) ~= 0
                    schema_path = strrep(schema_path, '$NDISCHEMAPATH', ndi.path.documentsschemapath);
                end
                try
                    schema_json = fileread(schema_path);
                catch
                    error("the schema path does not exsist");
                end
            end
        end
        
        function name = extractnamefromdefinition(str)
            file_name = split(str, filesep);
            name = split(file_name(numel(file_name)), ".");
            name = name(1);
        end
        
        function str = readHashMap(java_hashmap)
            if (~isa(java_hashmap, 'java.util.HashMap'))
                error("Must pass in an instance of java.util.HashMap");
            end
            str = '[';
            keys = java_hashmap.keySet().toArray();
            len = size(java_hashmap.keySet());
            if len == 0
                str = '[]';
                return;
            end
            for i = 1:len
                str = strcat(str, keys(i), " : ", java_hashmap.get(keys(i)), "; ");
            end
            str = strcat(extractBetween(str, 1, strlength(str)-2), ']');
        end
        
    end
end
