function unified_doc_structure = ndi_buildunifieddoc(schema_file_path, embed_schema_info)
%NDI_BUILDUNIFIEDDOC Builds a blank NDI document structure from a schema file,
%   optionally embedding schema information.
%
%   UNIFIED_DOC_STRUCTURE = NDI_BUILDUNIFIEDDOC(SCHEMA_FILE_PATH, EMBED_SCHEMA_INFO)
%   takes the file path to an NDI schema JSON file and a boolean flag
%   indicating whether to embed schema information into the blank document.
%
%   Input:
%       SCHEMA_FILE_PATH (char or string): Path to the NDI schema JSON file.
%       EMBED_SCHEMA_INFO (logical): If true, embeds some schema information
%                                    into the blank document.
%
%   Output:
%       UNIFIED_DOC_STRUCTURE (struct): A MATLAB structure representing the
%                                       blank NDI document, ready to be used
%                                       with ndi.document.

    try
        % Read the schema JSON file
        schema_text = fileread(schema_file_path);
        schema = jsondecode(schema_text);

        % Initialize the blank document structure
        unified_doc_structure = struct();

        % --- Embed document_class information ---
        unified_doc_structure.document_class = struct();
        unified_doc_structure.document_class.class_name = schema.classname;
        unified_doc_structure.document_class.property_list_name = schema.classname;
        unified_doc_structure.document_class.class_version = 1;
        unified_doc_structure.document_class.definition = ['$NDIDOCUMENTPATH/', schema.classname, '.json'];
        % As per feedback, validation schema should be the same as definition
        unified_doc_structure.document_class.validation = ['$NDIDOCUMENTPATH/', schema.classname, '.json'];

        % Handle superclasses
        superclass_schemas = {}; % To store schemas of superclasses
        if isfield(schema, 'superclasses') && ~isempty(schema.superclasses)
            superclasses_list = {};
            if ischar(schema.superclasses)
                superclasses_list = {schema.superclasses};
            elseif iscell(schema.superclasses)
                superclasses_list = schema.superclasses;
            end

            unified_doc_structure.document_class.superclasses = cell(1, numel(superclasses_list));
            for i = 1:numel(superclasses_list)
                superclass_name = superclasses_list{i};
                unified_doc_structure.document_class.superclasses{i} = struct('definition', ['$NDIDOCUMENTPATH/', superclass_name, '.json']);

                % Recursively load superclass schema to include its properties
                % Assuming superclass schema files are in the same directory as the main schema
                [schema_dir, ~, ~] = fileparts(schema_file_path);
                superclass_schema_path = fullfile(schema_dir, [superclass_name, '_schema.json']);
                if exist(superclass_schema_path, 'file') == 2
                    superclass_schema_text = fileread(superclass_schema_path);
                    superclass_schemas{end+1} = jsondecode(superclass_schema_text);
                else
                    warning('NDI:SchemaNotFound', 'Superclass schema file not found: %s', superclass_schema_path);
                end
            end
        else
            unified_doc_structure.document_class.superclasses = [];
        end

        % --- Embed depends_on information and create blank values ---
        unified_doc_structure.depends_on = [];
        if isfield(schema, 'depends_on') && ~isempty(schema.depends_on)
            unified_doc_structure.depends_on = schema.depends_on; % Embed the constraints
            for i = 1:numel(unified_doc_structure.depends_on)
                unified_doc_structure.depends_on(i).value = ''; % Add a 'value' field for the blank value
            end
        end

        % --- Create the main property list field with default values and optional schema info ---
        % Start with current class properties
        property_list_name = schema.classname;
        unified_doc_structure.(property_list_name) = struct();

        if isfield(schema, property_list_name) && ~isempty(schema.(property_list_name))
            property_definitions = schema.(property_list_name);
            for i = 1:numel(property_definitions)
                prop_name = property_definitions(i).name;
                unified_doc_structure.(property_list_name).(prop_name) = property_definitions(i).default_value;
                % Optionally embed type and parameters
                if embed_schema_info
                    type_field_name = [prop_name '_type'];
                    parameters_field_name = [prop_name '_parameters'];
                    unified_doc_structure.(property_list_name).(type_field_name) = property_definitions(i).type;
                    if ~isempty(property_definitions(i).parameters)
                        unified_doc_structure.(property_list_name).(parameters_field_name) = property_definitions(i).parameters;
                    end
                end
            end
        end

        % Add properties from superclasses
        for k = 1:numel(superclass_schemas)
            current_superclass_schema = superclass_schemas{k};
            superclass_property_list_name = current_superclass_schema.classname;

            if isfield(current_superclass_schema, superclass_property_list_name) && ~isempty(current_superclass_schema.(superclass_property_list_name))
                superclass_property_definitions = current_superclass_schema.(superclass_property_list_name);
                for i = 1:numel(superclass_property_definitions)
                    prop_name = superclass_property_definitions(i).name;
                    % Only add if not already defined in the current class
                    if ~isfield(unified_doc_structure.(property_list_name), prop_name)
                        unified_doc_structure.(property_list_name).(prop_name) = superclass_property_definitions(i).default_value;
                        if embed_schema_info
                            type_field_name = [prop_name '_type'];
                            parameters_field_name = [prop_name '_parameters'];
                            unified_doc_structure.(property_list_name).(type_field_name) = superclass_property_definitions(i).type;
                            if ~isempty(superclass_property_definitions(i).parameters)
                                unified_doc_structure.(property_list_name).(parameters_field_name) = superclass_property_definitions(i).parameters;
                            end
                        end
                    end
                end
            end
        end

    catch ME
        error('Error building unified document structure: %s', ME.message);
    end
end