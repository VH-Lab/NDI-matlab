function generated_json_path = ndi_buildunifieddoc(schema_file_path, output_dir, embed_schema_info)
%NDI_BUILDUNIFIEDDOC Builds a blank NDI document from a schema file and saves it as a JSON file,
%   optionally embedding schema information.
%
%   GENERATED_JSON_PATH = NDI_BUILDUNIFIEDDOC(SCHEMA_FILE_PATH, OUTPUT_DIR, EMBED_SCHEMA_INFO)
%   takes the file path to an NDI schema JSON file, an output directory, and a boolean flag
%   indicating whether to embed schema information into the blank document.
%
%   Input:
%       SCHEMA_FILE_PATH (char or string): Path to the NDI schema JSON file.
%       OUTPUT_DIR (char or string): Path to the directory where the JSON
%                                    file should be saved.
%       EMBED_SCHEMA_INFO (logical): If true, embeds some schema information
%                                    into the blank document.
%
%   Output:
%       GENERATED_JSON_PATH (char or string): Path to the generated JSON file.

    try
        % Read the schema JSON file
        schema_text = fileread(schema_file_path);
        schema = jsondecode(schema_text);

        % Initialize the blank document structure
        unified_doc = struct();

        % Optionally add a $schema field (if you decide on a standard)
        % if embed_schema_info
        %     unified_doc.$schema = 'http://json-schema.org/draft-07/schema#';
        % end

        % --- Embed document_class information ---
        unified_doc.document_class = struct();
        unified_doc.document_class.class_name = schema.classname;
        unified_doc.document_class.property_list_name = schema.classname;
        unified_doc.document_class.class_version = 1;
        unified_doc.document_class.definition = ['$NDIDOCUMENTPATH/', schema.classname, '.json'];
        unified_doc.document_class.validation = ['$NDISCHEMAPATH/', schema.classname, '_schema.json'];

        % Handle superclasses
        if isfield(schema, 'superclasses') && ~isempty(schema.superclasses)
            if ischar(schema.superclasses)
                unified_doc.document_class.superclasses = {struct('definition', ['$NDIDOCUMENTPATH/', schema.superclasses, '.json'])};
            elseif iscell(schema.superclasses)
                unified_doc.document_class.superclasses = cell(1, numel(schema.superclasses));
                for i = 1:numel(schema.superclasses)
                    unified_doc.document_class.superclasses{i} = struct('definition', ['$NDIDOCUMENTPATH/', schema.superclasses{i}, '.json']);
                end
            else
                unified_doc.document_class.superclasses = [];
            end
        else
            unified_doc.document_class.superclasses = [];
        end

        % --- Embed depends_on information and create blank values ---
        unified_doc.depends_on = [];
        if isfield(schema, 'depends_on') && ~isempty(schema.depends_on)
            unified_doc.depends_on = schema.depends_on; % Embed the constraints
            for i = 1:numel(unified_doc.depends_on)
                unified_doc.depends_on(i).value = ''; % Add a 'value' field for the blank value
            end
        end

        % --- Create the main property list field with default values and optional schema info ---
        property_list_name = schema.classname;
        unified_doc.(property_list_name) = struct();
        if isfield(schema, property_list_name) && ~isempty(schema.(property_list_name))
            property_definitions = schema.(property_list_name);
            for i = 1:numel(property_definitions)
                prop_name = property_definitions(i).name;
                unified_doc.(property_list_name).(prop_name) = property_definitions(i).default_value;
                % Optionally embed type and parameters
                if embed_schema_info
                    type_field_name = [prop_name '_type'];
                    parameters_field_name = [prop_name '_parameters'];
                    unified_doc.(property_list_name).(type_field_name) = property_definitions(i).type;
                    if ~isempty(property_definitions(i).parameters)
                        unified_doc.(property_list_name).(parameters_field_name) = property_definitions(i).parameters;
                    end
                end
            end
        end

        % --- Convert the MATLAB struct to JSON ---
        json_text = jsonencode(unified_doc, 'PrettyPrint', true);

        % --- Create the output file path ---
        [~, filename, ~] = fileparts(schema_file_path);
        generated_json_path = fullfile(output_dir, [filename, '_unified.json']); % Use '_unified' suffix

        % --- Write the JSON string to a file ---
        fid = fopen(generated_json_path, 'w');
        if fid == -1
            error('Could not open file "%s" for writing.', generated_json_path);
        end
        fprintf(fid, '%s', json_text);
        fclose(fid);

    catch ME
        error('Error building and saving unified document: %s', ME.message);
    end
end