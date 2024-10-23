classdef validate
    % Validate a ndi_document to ensure that the type of its properties
    % match with the expected type according to its schema. Most of the logic
    % behind is implemented by Java using everit-org's json-schema library:
    % https://github.com/everit-org/json-schema, a JSON Schema Validator
    % for Java, based on org.json API. It implements the DRAFT 7 version
    % of the JSON Schema: https://json-schema.org/

    % ndi_validates takes an ndi.document and the database as input
    % need to check that all the input type match with the expected type
    % correctly. If there is a depends-on fields, we also need to search
    % through the database to ensure this actually exists

    properties(SetAccess = protected, GetAccess = public)
        validators;          % Java validator object
        reports;             % report of the error messages
        is_valid             % is the ndi.document valid or not
        errormsg;
    end

    properties(SetAccess = private, GetAccess = public)
        errormsg_this;       % display any type mismatch of the current object's field
        errormsg_super;      % display any type mismatch of the super class object's field
        errormsg_depends_on; % display any depends_on objects that cannot be found in the database
    end

    methods
        function ndi_validate_obj = validate(ndi_document_obj,ndi_session_obj)
            if nargin == 0
                error("You must pass in an instance of ndi_document_obj and an instance of ndi_session_obj as arguments");
            end

            % Initialization
            ndi.validate.checkJavaPath()
            import com.ndi.*;
            import org.json.*;
            import org.everit.*;
            has_dependencies = 0;
            ndi_validate_obj.validators = struct();
            ndi_validate_obj.reports = struct();
            ndi_validate_obj.errormsg_this = "no error found" + newline;
            ndi_validate_obj.errormsg_super = "no error found" + newline;
            ndi_validate_obj.errormsg_depends_on = "no error found" + newline;
            ndi_validate_obj.errormsg = '';
            ndi_validate_obj.is_valid = true;
            persistent format_validators_list;
            if isempty(format_validators_list)
                try
                    format_validators_list = ndi.validate.load_format_validator();
                catch e
                    warning("Format validators aren't initialized properly: Here are the error messages" + newline + e.message);
                end
            end
            % Allow users to pass in only one argument if ndi_document_obj
            % does not have depends-on fields (since we don't really need
            % the ndi_session_obj)
            if nargin == 1
                ndi_session_obj = 0;
            end

            % Check if the user has passed in a valid ndi_document_obj
            if ~isa(ndi_document_obj, 'ndi.document')
                error('You must pass in an instance of ndi.document as your first argument');
            end

            % Only check if the user passed in a valid instance of
            % ndi.session if ndi_document_obj has dependency
            if isfield(ndi_document_obj.document_properties, 'depends_on')
                has_dependencies = 1;
                if ~isa(ndi_session_obj, 'ndi.session')
                    error('You must pass in an instnce of ndi.session as your second argument to check for dependency')
                end
            end

            % ndi.document has a property called 'document_properties' that has all of the
            % data of the document. For example, all documents have
            % ndi_document_obj.document_properties.ndi_document with fields 'id', 'session_id', etc.
            schema = ndi.validate.extract_schema(ndi_document_obj);
            doc_class = ndi_document_obj.document_properties.document_class;
            % property_list = getfield(ndi_document_obj.document_properties, doc_class.property_list_name);
            property_list = eval( strcat('ndi_document_obj.document_properties.', doc_class.property_list_name));
            if has_dependencies == 1
                % pass depends_on here
                property_list.depends_on = ndi_document_obj.document_properties.depends_on;
            end

            % validate all non-super class properties
            try
                ndi_validate_obj.validators.this = com.ndi.Validator( jsonencode(property_list), schema );
                if ~isempty(format_validators_list)
                    ndi_validate_obj.validators.this = ndi_validate_obj.validators.this.addValidators(format_validators_list);
                end
            catch e
                error("Fail to verify the ndi.document. This is likely caused by json-schema not formatted correctly"...
                    + "Here is the detail Java exception error: " + e.message)
            end
            ndi_validate_obj.reports.this = '';
            if ndi_validate_obj.validators.this.getReport().size() > 0
                ndi_validate_obj.is_valid = false;
                ndi_validate_obj.reports.this = ndi_validate_obj.validators.this.getReport();
                ndi_validate_obj.errormsg_this = string(doc_class.property_list_name) +  ":" ...
                    +string(newline) + ndi.validate.readHashMap(ndi_validate_obj.reports.this) + string(newline);
            end

            % validate all of the document's superclass if it exists
            numofsuperclasses = numel(doc_class.superclasses);
            if numofsuperclasses > 0
                emptystruct(1,numofsuperclasses) = struct;
                ndi_validate_obj.validators.super = emptystruct;
                ndi_validate_obj.reports.super = emptystruct;
            end
            for i=1:numel(numofsuperclasses)
                % Step 1: read in the definition of the superclass at
                %   doc_class.superclasses(i).definition
                % Step 2: find the validator json in the superclass, call it validator_superclass
                % Step 3: convert the portion of the document that corresponds to this superclass to JSON
                superclass_name = doc_class.superclasses(i).definition;
                schema = ndi.validate.extract_schema(superclass_name);
                superclassname_without_extension = ndi.validate.extractnamefromdefinition(superclass_name);
                properties = struct( eval( strcat('ndi_document_obj.document_properties.', superclassname_without_extension) ) );
                % pass depends_on here
                if has_dependencies == 1
                    properties.depends_on = ndi_document_obj.document_properties.depends_on;
                end
                validator = 0;
                try
                    validator = com.ndi.Validator( jsonencode(properties), schema );
                    if ~isempty(format_validators_list)
                        ndi_validate_obj.validators.this = ndi_validate_obj.validators.this.addValidators(format_validators_list);
                    end
                catch e
                    error("Fail to verify the ndi.document. This is likely caused by json-schema not formatted correctly"...
                        + "Here is the detail Java exception error: " + e.message)
                end
                report = validator.getReport();
                if report.size() > 0
                    ndi_validate_obj.is_valid = false;
                    ndi_validate_obj.validators.super(i).(superclassname_without_extension) = validator;
                    ndi_validate_obj.reports.super(i).(superclassname_without_extension) = report;
                    ndi_validate_obj.errormsg_super = string(superclassname_without_extension) +  ":"...
                        + newline + ndi.validate.readHashMap(report) + string(newline);
                end
            end

            % check if there is depends-on field, if it exsists we need to
            % search through the ndi.session database to check
            has_dependencies_error = 0;
            if has_dependencies == 1
                numofdependencies = numel(ndi_document_obj.document_properties.depends_on);
                % emptystruct(1,numofdependencies) = struct;
                ndi_validate_obj.reports.dependencies = struct();
                % NOTE: this does not verify that 'depends-on' documents have the right class membership
                % might want to add this in the future
                errormsgdependencies = "We cannot find the following necessary dependency from the database:" + newline;
                for i = 1:numofdependencies
                    searchquery = {'base.id', ndi_document_obj.document_properties.depends_on(i).value};
                    if numel(ndi_session_obj.database_search(searchquery)) < 1
                        ndi_validate_obj.reports.dependencies.(ndi_document_obj.document_properties.depends_on(i).name) = 'fail';
                        errormsgdependencies = errormsgdependencies + ndi_document_obj.document_properties.depends_on(i).name + newline;
                        ndi_validate_obj.is_valid = false;
                        has_dependencies_error = 1;
                    else
                        ndi_validate_obj.reports.dependencies(i).(ndi_document_obj.document_properties.depends_on(i).name) = "success";
                    end
                end
                if has_dependencies_error == 1
                    ndi_validate_obj.errormsg_depends_on = errormsgdependencies;
                end
            end

            % preparing for the overall report
            if ~ndi_validate_obj.is_valid
                msg = "Validation has failed. Here is a detailed report of the source of failure:"...
                    + newline...
                    + "Here are the errors for the this instance of ndi.document class:" + newline...
                    + "------------------------------------------------------------------------------" + newline...
                    + ndi_validate_obj.errormsg_this + newline...
                    + "------------------------------------------------------------------------------" + newline...
                    + "Here are the errors for its super class(es)" + newline...
                    + "------------------------------------------------------------------------------" + newline...
                    + ndi_validate_obj.errormsg_super + newline...
                    + "------------------------------------------------------------------------------" + newline ...
                    + "Here are the errors relating to its dependencies" + newline...
                    + "------------------------------------------------------------------------------" + newline ...
                    + ndi_validate_obj.errormsg_depends_on + newline...
                    + "------------------------------------------------------------------------------" + newline...
                    + "To get this detailed report as a struct. Please access its instance field report";
                ndi_validate_obj.errormsg = msg;
            else
                ndi_validate_obj.errormsg = 'This ndi_document contains no type error';
            end
        end

        function throw_error(ndi_validate_obj)
            if ~(ndi_validate_obj.is_valid)
                error(ndi_validate_obj.errormsg)
            end
        end

    end

    methods(Static, Access = public)

        function format_validator_list = load_format_validator()
            %
            %  LOAD the the list of FormatValidator configurated based on
            %  the JSON file ndi_validate_config.json
            %
            ndi.validate.checkJavaPath()
            import com.ndi.*;
            import org.json.*;
            import org.everit.*;
            json_path = [ndi.common.PathConstants.DocumentFolder filesep 'ndi_validate_config.json'];
            schema_path = [ndi.common.PathConstants.DocumentSchemaFolder filesep 'ndi_validate_config_schema.json'];
            json_object = JSONObject(fileread(json_path));
            schema_json_object = JSONObject(fileread(schema_path));
            report = Validator(json_object, schema_json_object).getReport();
            if (report.size() > 0)
                error("ndi_validate_config.json is not formatted correctly: check the following fields" + newline + ndi_validate.readHashMap(report))
            end
            json_array = json_object.getJSONArray("string_format");
            for i = 0:json_array.length()-1
                format_validator_json = json_array.getJSONObject(i);
                filepath = ndi.validate.replace_ndipath( string(json_array.getJSONObject(i).getString("filePath")) );
                format_validator_json = format_validator_json.put("filePath", filepath);
                json_array = json_array.put(i, format_validator_json);
            end
            json_object = json_object.put("string_format", json_array);
            format_validator_list = EnumFormatValidator.buildFromJSON(json_object);
        end
    end

    methods (Static, Access = public)

        function checkJavaPath()
            % checkJavaPath - Check that ndi-validator is on the java class path
            ndiValidatorJavaFilepath = fullfile(ndi.common.PathConstants.RootFolder, ...
                'java', 'ndi-validator-java', 'jar', 'ndi-validator-java.jar');

            if ~any(strcmp(javaclasspath, ndiValidatorJavaFilepath))
                javaaddpath(ndiValidatorJavaFilepath, 'end')
            end
        end

        function new_path = replace_ndipath(path)
            fn = properties(ndi.common.PathConstants);

            for i = 1:numel(fn)
                ndiDocPlaceholder = ndi.common.PathConstants.getNdiPathPlaceholderName(fn{i});
                if numel( strfind(path, ndiDocPlaceholder) ) ~= 0
                    new_path = strrep(path, ndiDocPlaceholder, ndi.common.PathConstants.(fn{i}));
                    return;
                end
            end
            new_path = path;
        end

        function schema_json = extract_schema(ndi_document_obj)
            %   EXTRACT_SCHEMA - Extract the content of the ndi.document's
            %                    corresponding schema
            %
            %   SCHEMA_JSON = EXTRACT_SCHEMA(NDI_DOCUMENT_OBJ)
            %
            schema_json = "";
            if isa(ndi_document_obj, 'ndi.document')
                schema_path = ndi_document_obj.document_properties.document_class.validation;
                schema_path = strrep(schema_path, '$NDISCHEMAPATH', ndi.common.PathConstants.DocumentSchemaFolder);
                try
                    schema_json = fileread(schema_path);
                catch
                    error("the schema path does not exsist");
                end
            end
            if isa(ndi_document_obj, 'char') || isa(ndi_document_obj, 'string')
                schema_path = string(ndi_document_obj).replace('.json', '_schema.json');
                if  numel( strfind(ndi_document_obj, '$NDIDOCUMENTPATH') ) ~= 0
                    schema_path = strrep(schema_path, '$NDIDOCUMENTPATH', ndi.common.PathConstants.DocumentSchemaFolder);
                elseif numel( strfind(ndi_document_obj, '$NDISCHEMAPATH') ) ~= 0
                    schema_path = strrep(schema_path, '$NDISCHEMAPATH', ndi.common.PathConstants.DocumentSchemaFolder);
                end
                try
                    schema_json = fileread(schema_path);
                catch
                    error('The schema path does not exsist. Verify that you have created a schema file in the $NDIDOCUMENTSCHEMAPATH folder.');
                end
            end
        end

        function name = extractnamefromdefinition(str)
            %   STR - File name contains ".json" extension
            %   Remove the file extension
            %
            %   NAME = EXTRACTNAME(STR)
            %
            file_name = split(str, filesep);
            name = split(file_name(numel(file_name)), ".");
            name = string(name(1));
        end

        function str = readHashMap(java_hashmap)
            %   java_hashmap - an instance of java.util.HashMAP
            %   turn an instance of java.util.hashmap into string useful
            %   for displaying the error messages
            %
            %   STR = READHASHMAP(JAVA_HASHMAP)
            %
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
                str = strcat(str, keys(i), " : ", java_hashmap.get(keys(i)), "]");
                str = str + newline + "[";
            end
            str = strcat(extractBetween(str, 1, strlength(str)-3), ']');
        end
    end
end
