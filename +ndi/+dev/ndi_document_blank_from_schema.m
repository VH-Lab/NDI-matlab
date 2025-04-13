function doc = ndi_document_blank_from_schema(schemaFileName, options)
% NDI_DOCUMENT_BLANK_FROM_SCHEMA - Create a blank NDI document from a schema
%
% DOC = NDI_DOCUMENT_BLANK_FROM_SCHEMA(SCHEMAFILENAME)
%
% Creates a blank document structure that conforms to the schema specified
% by the JSON file SCHEMAFILENAME. The schema should follow the NDI unified
% schema format. This function enforces strict schema adherence and path resolution.
%
% DOC = NDI_DOCUMENT_BLANK_FROM_SCHEMA(SCHEMAFILENAME, Name, Value, ...)
%
% This function accepts name/value pairs to modify behavior:
%
% Name (default):                    | Description:
% --------------------------------------------------------------------------
% 'ndiUnifiedSchemaPath'             | Base path for resolving the $NDIDOCUMENTPATH variable
% (fullfile(ndi.common.PathConstants.CommonFolder,'unified_documents')) | used within schema files for references ('x_ref' field).
%                                    | All referenced JSON files must be located
%                                    | relative to this path and be valid.
%
% Inputs:
%   SCHEMAFILENAME (string)          - Path and name of the main schema file
%                                      (e.g., 'path/to/schema.json').
%
% Outputs:
%   DOC (struct)                     - A structure containing a blank document that
%                                      conforms to the schema. Contains unique superclass list.
%
% Schema Variable Substitution:
%   The variable string '$NDIDOCUMENTPATH' can be used within the JSON schema files
%   inside strings that are values of the 'x_ref' field (originally '$ref' in JSON).
%   This variable string will be replaced by the value provided for 'ndiUnifiedSchemaPath'.
%
% JSON Field Naming Note:
%   JSON fields starting with '$', like '$ref', are converted by MATLAB's
%   jsondecode into valid MATLAB field names (e.g., 'x_ref').
%   JSON arrays of uniform objects (like in 'allOf') become MATLAB structure arrays.
%
% Error Handling:
%   This version uses errors instead of warnings for most schema inconsistencies.
%
% Example:
%   mySchemaFile = 'path/to/daqsystem_schema.json';
%   doc = ndi_document_blank_from_schema(mySchemaFile); % Use default path
%
%   myNDIRootPath = '/Volumes/MyExperimentData/ndi_repo';
%   doc = ndi_document_blank_from_schema(mySchemaFile, 'ndiUnifiedSchemaPath', myNDIRootPath);
%
% See also: jsondecode, fileread, fullfile, arguments, strrep, error, ndi.common.PathConstants, unique

arguments
    schemaFileName (1,1) string % Required positional argument: path to the main schema file
    options.ndiUnifiedSchemaPath (1,1) string = fullfile(ndi.common.PathConstants.CommonFolder,'unified_documents') % NDI path
end

% The 'ndiUnifiedSchemaPath' is now directly available from the 'options' struct
ndiUnifiedSchemaPath = options.ndiUnifiedSchemaPath;

% Define path mappings using a struct array with search/replace fields
path_mappings = struct(...
    'searchString', '$NDIDOCUMENTPATH', ...
    'replaceString', ndiUnifiedSchemaPath ...
    );

% Read and decode the main schema
if ~isfile(schemaFileName)
    error('ndi_document_blank_from_schema:SchemaNotFound', ...
          'Schema file not found: %s', schemaFileName);
end
schema_text = fileread(schemaFileName);
try
    schema = jsondecode(schema_text);
catch ME
    error('ndi_document_blank_from_schema:JSONError', ...
        'Error decoding JSON from schema file %s: %s', schemaFileName, ME.message);
end

% Process the schema structure to create the document
doc = process_schema(schema, schemaFileName, path_mappings);

end % main function

% ===================== Helper Functions =====================

% --------------------- process_schema ---------------------
% Processes the decoded schema structure recursively to build the blank document.
function doc = process_schema(schema, current_schema_file, path_mappings)
% Initialize document for this level
doc = struct();

% Process inheritance first (allOf references)
if isfield(schema, 'allOf')
    if ~isstruct(schema.allOf)
         error('ndi_document_blank_from_schema:InvalidSchemaStructure', ...
               '"allOf" field in schema %s must be an array of objects (expected struct array after jsondecode), but found "%s".', current_schema_file, class(schema.allOf));
    end

    % Loop through each element of the struct array using parentheses for indexing
    for i = 1:length(schema.allOf)
        element = schema.allOf(i); % Get the current struct element

        if ~isstruct(element)
             error('ndi_document_blank_from_schema:InvalidAllOfEntry', ...
                   'Entry %d in "allOf" array in schema %s MUST be a structure (schema object), but it is a "%s".', i, current_schema_file, class(element));
        end
        if ~isfield(element, 'x_ref')
             error('ndi_document_blank_from_schema:MissingXRef', ...
                   'Structure entry %d in "allOf" array in schema %s MUST contain the "x_ref" field (expected from JSON $ref).', i, current_schema_file);
        end

        ref_path_string = element.x_ref;
        parent_schema_path = resolve_path(ref_path_string, current_schema_file, path_mappings);

        if ~isfile(parent_schema_path)
             error('ndi_document_blank_from_schema:ParentSchemaNotFound', ...
                   'Required parent schema file not found during inheritance (ref: "%s", file: %s): Resolved path "%s" does not exist.', ref_path_string, current_schema_file, parent_schema_path);
        end

        % Try reading, decoding, and processing the parent schema
        try
            parent_schema_text = fileread(parent_schema_path);
            parent_schema = jsondecode(parent_schema_text);
            parent_doc = process_schema(parent_schema, parent_schema_path, path_mappings);
            doc = merge_structures(doc, parent_doc); % Merge content

            % *** MODIFIED: Add parent ref to superclasses (will de-duplicate later) ***
            if ~isfield(doc, 'document_class') || ~isstruct(doc.document_class)
                doc.document_class = struct();
            end
            if ~isfield(doc.document_class, 'superclasses') || ~iscell(doc.document_class.superclasses)
                 doc.document_class.superclasses = {};
            end
            % Add the parent schema path - de-duplication happens at the end
            sc_entry = struct('definition', parent_schema_path);
            doc.document_class.superclasses{end+1} = sc_entry;
            % *** END MODIFICATION ***

        catch ME
             error('ndi_document_blank_from_schema:ParentSchemaError', ...
                   'Error processing parent schema %s (ref: "%s", file: %s): %s', parent_schema_path, ref_path_string, current_schema_file, ME.message);
        end
    end % end for loop
end % end if allOf

% --- Process properties defined directly in this schema level ---
if ~isfield(schema, 'properties') || ~isstruct(schema.properties)
    if ~isfield(schema, 'allOf')
         error('ndi_document_blank_from_schema:MissingProperties', ...
               'Schema file %s is missing the required "properties" field (and has no "allOf").', current_schema_file);
    end
    if ~isfield(schema,'properties')
        schema.properties = struct(); % Ensure it exists if allOf was present
    end
end

if isstruct(schema.properties)
    % Process standard NDI sections
    if isfield(schema.properties, 'document_class') && isstruct(schema.properties.document_class)
        doc = process_document_class(doc, schema.properties.document_class, current_schema_file, path_mappings);
    end
    if isfield(schema.properties, 'depends_on') && isstruct(schema.properties.depends_on)
        doc = process_depends_on(doc, schema.properties.depends_on);
    end
    if isfield(schema.properties, 'files') && isstruct(schema.properties.files)
        doc = process_files(doc, schema.properties.files, current_schema_file);
    end

    % Process custom sections
    field_names = fieldnames(schema.properties);
    standard_fields = {'document_class', 'depends_on', 'files'};
    for i = 1:length(field_names)
        field = field_names{i};
        if ~ismember(field, standard_fields)
            if isstruct(schema.properties.(field))
                doc.(field) = process_custom_properties(schema.properties.(field));
            else
                error('ndi_document_blank_from_schema:NonStructProperty',...
                      'Top-level property "%s" in schema %s must be a structure (schema object), found "%s".', field, current_schema_file, class(schema.properties.(field)));
            end
        end
    end
end

% --- Final De-duplication of Superclasses ---
if isfield(doc, 'document_class') && isstruct(doc.document_class) && ...
   isfield(doc.document_class, 'superclasses') && iscell(doc.document_class.superclasses)

    superclasses_list = doc.document_class.superclasses;
    if ~isempty(superclasses_list)
        definitions = cell(size(superclasses_list));
        valid_indices = false(size(superclasses_list)); % Track valid struct entries
        % Extract definitions and mark valid entries
        for k = 1:length(superclasses_list)
            entry = superclasses_list{k};
            if isstruct(entry) && isfield(entry, 'definition') && ...
               (ischar(entry.definition) || isstring(entry.definition)) && ~isempty(entry.definition)
                definitions{k} = char(entry.definition); % Ensure char for comparison
                valid_indices(k) = true;
            else
                 % Mark invalid entries (non-struct, missing/empty definition)
                 valid_indices(k) = false;
                 definitions{k} = ''; % Placeholder
            end
        end

        % Filter based on validity
        valid_definitions = definitions(valid_indices);
        valid_superclasses = superclasses_list(valid_indices);

        if ~isempty(valid_definitions)
            % Find indices of unique definitions, preserving the order of first appearance
            [~, unique_idx] = unique(valid_definitions, 'stable');

            % Reconstruct the superclasses list with only unique entries
            doc.document_class.superclasses = valid_superclasses(unique_idx);
        else
             % If all entries were invalid or the list was empty, result is empty cell
             doc.document_class.superclasses = {};
        end
    end
end % end superclass de-duplication

end % end process_schema function


% --------------------- process_document_class ---------------------
% Processes the 'document_class' section of the schema properties.
function doc = process_document_class(doc, document_class_schema, current_schema_file, path_mappings)
    % Initialize field if it doesn't exist
    if ~isfield(doc, 'document_class') || ~isstruct(doc.document_class)
         doc.document_class = struct();
    end

    if isfield(document_class_schema, 'properties') && isstruct(document_class_schema.properties)
        class_props = document_class_schema.properties;

        % Class Name
        if isfield(class_props, 'class_name')
            doc.document_class.class_name = get_property_default(class_props.class_name, '');
        elseif ~isfield(doc.document_class, 'class_name')
             doc.document_class.class_name = '';
        end

        % Class Version
        if isfield(class_props, 'class_version')
            doc.document_class.class_version = get_property_default(class_props.class_version, 1);
        elseif ~isfield(doc.document_class, 'class_version')
             doc.document_class.class_version = 1;
        end

        % Superclasses (process defaults defined at this level)
        if isfield(class_props, 'superclasses')
             if ~isfield(doc.document_class, 'superclasses') || ~iscell(doc.document_class.superclasses)
                 doc.document_class.superclasses = {};
             end
             if isfield(document_class_schema, 'default') && ...
                isstruct(document_class_schema.default) && ...
                isfield(document_class_schema.default, 'superclasses') && ...
                iscell(document_class_schema.default.superclasses)

                 % Process default superclasses defined here (duplicates removed later)
                 for i = 1:length(document_class_schema.default.superclasses)
                     sc_entry = document_class_schema.default.superclasses{i};
                     if isstruct(sc_entry)
                         sc = struct('definition', '');
                         if isfield(sc_entry, 'definition') && ~isempty(sc_entry.definition)
                             try
                                 sc.definition = resolve_path(sc_entry.definition, current_schema_file, path_mappings);
                             catch ME
                                 error('ndi_document_blank_from_schema:ResolvePathError',...
                                         'Could not resolve superclass default definition path "%s" (from %s): %s', ...
                                         sc_entry.definition, current_schema_file, ME.message);
                             end
                         else
                             sc.definition = '';
                         end
                         % *** MODIFIED: Always add if definition exists, de-duplicate later ***
                         if ~isempty(sc.definition)
                             doc.document_class.superclasses{end+1} = sc;
                         end
                         % *** END MODIFICATION ***
                     end
                 end % for loop
             end % if default superclasses exist
        elseif ~isfield(doc.document_class, 'superclasses')
            doc.document_class.superclasses = {};
        end % if superclasses property exists
    end % if document_class_schema has properties
end % end process_document_class function


% --------------------- process_depends_on ---------------------
% Processes the 'depends_on' section of the schema properties.
function doc = process_depends_on(doc, depends_on_schema)
    % Initialize field if it doesn't exist
    if ~isfield(doc, 'depends_on') || ~iscell(doc.depends_on)
         doc.depends_on = {};
    end

    existing_dep_names = {};
    for k=1:length(doc.depends_on)
        if isstruct(doc.depends_on{k}) && isfield(doc.depends_on{k},'name')
            existing_dep_names{end+1} = doc.depends_on{k}.name;
        end
    end

    % Add default dependencies from this level if not already present
    if isfield(depends_on_schema, 'default') && iscell(depends_on_schema.default)
        for i = 1:length(depends_on_schema.default)
            dep_entry = depends_on_schema.default{i};
            if isstruct(dep_entry)
                dep = struct('name', '', 'value', '');
                if isfield(dep_entry, 'name'), dep.name = dep_entry.name; end
                if isfield(dep_entry, 'value'), dep.value = dep_entry.value; end
                if ~isempty(dep.name) && ~ismember(dep.name, existing_dep_names)
                    doc.depends_on{end+1} = dep;
                    existing_dep_names{end+1} = dep.name;
                end
            end
        end
    end

    % Add required dependencies from this level if not already present
    if isfield(depends_on_schema, 'allOf') && iscell(depends_on_schema.allOf)
        for i = 1:length(depends_on_schema.allOf)
            allOf_entry = depends_on_schema.allOf{i};
            if isstruct(allOf_entry) && isfield(allOf_entry, 'contains') && ...
               isstruct(allOf_entry.contains) && isfield(allOf_entry.contains, 'properties') && ...
               isstruct(allOf_entry.contains.properties) && ...
               isfield(allOf_entry.contains.properties, 'name') && ...
               isstruct(allOf_entry.contains.properties.name) && ...
               isfield(allOf_entry.contains.properties.name, 'const')

                dep_name = allOf_entry.contains.properties.name.const;
                if ~isempty(dep_name) && ~ismember(dep_name, existing_dep_names)
                    dep = struct('name', dep_name, 'value', '');
                    doc.depends_on{end+1} = dep;
                    existing_dep_names{end+1} = dep_name;
                end
            end
        end
    end
    % Final de-duplication of depends_on (based on name)
    if ~isempty(doc.depends_on)
        dep_names = cellfun(@(x) x.name, doc.depends_on, 'UniformOutput', false);
        [~, unique_idx] = unique(dep_names, 'stable');
        doc.depends_on = doc.depends_on(unique_idx);
    end
end % end process_depends_on function


% --------------------- process_files ---------------------
% Processes the 'files' section of the schema properties.
function doc = process_files(doc, files_schema, current_schema_file)
    % Initialize field if it doesn't exist
    if ~isfield(doc, 'files') || ~isstruct(doc.files)
         doc.files = struct('file_list', {{}});
    elseif ~isfield(doc.files, 'file_list') || ~iscell(doc.files.file_list)
         doc.files.file_list = {};
    end

    % Add required files from 'contains' if specified at this level
    if isfield(files_schema, 'properties') && isstruct(files_schema.properties) && ...
       isfield(files_schema.properties, 'file_list') && ...
       isstruct(files_schema.properties.file_list) && ...
       isfield(files_schema.properties.file_list, 'contains') && ...
       isstruct(files_schema.properties.file_list.contains) && ...
       isfield(files_schema.properties.file_list.contains, 'const')

        required_file = files_schema.properties.file_list.contains.const;
        if (ischar(required_file) || isstring(required_file)) && ~isempty(required_file)
             if ~ismember(required_file, doc.files.file_list)
                 doc.files.file_list{end+1} = char(required_file);
             end
        else
             error('ndi_document_blank_from_schema:InvalidFileType',...
                    'Required file constant ("contains":"const") in schema %s is not a valid, non-empty string.', current_schema_file);
        end
    end
    % Final de-duplication of file_list
    if isfield(doc,'files') && isfield(doc.files,'file_list') && iscell(doc.files.file_list)
        doc.files.file_list = unique(doc.files.file_list, 'stable');
    end
end % end process_files function


% --------------------- process_custom_properties ---------------------
% Processes a generic "property" block from the schema, applying defaults.
function prop_value = process_custom_properties(prop_schema)
% Initialize as a struct, assuming the custom property represents an object
prop_value = struct();

if isfield(prop_schema, 'properties') && isstruct(prop_schema.properties)
    field_names = fieldnames(prop_schema.properties);
    for i = 1:length(field_names)
        field = field_names{i};
        if isstruct(prop_schema.properties.(field))
            prop_value.(field) = get_property_default(prop_schema.properties.(field), []);
        else
             prop_value.(field) = get_property_default(prop_schema.properties.(field), []);
             error('ndi_document_blank_from_schema:InvalidPropertySchema',...
                     'Schema definition for custom sub-property "%s" must be a structure (schema object), found "%s".', field, class(prop_schema.properties.(field)));
        end
    end
else
     prop_value = get_property_default(prop_schema, []);
     if isempty(prop_value) && isfield(prop_schema,'type') && strcmp(prop_schema.type,'object')
         prop_value = struct();
     end
end
end % end process_custom_properties function


% --------------------- get_property_default ---------------------
% Determines the default value for a property based on its schema definition.
function default_value = get_property_default(prop_schema, fallback)
if isstruct(prop_schema) && isfield(prop_schema, 'default')
    default_value = prop_schema.default;
    if iscell(default_value) && isscalar(default_value) && isstruct(default_value{1})
        default_value = default_value{1}; % Handle potential cell wrapper
    end
else
    default_value = fallback;
    if isstruct(prop_schema) && isempty(default_value) && isfield(prop_schema, 'type')
         type_info = prop_schema.type;
         primary_type = '';
         if iscell(type_info) && ~isempty(type_info)
             non_null_types = type_info(~strcmp(type_info, 'null'));
             if ~isempty(non_null_types), primary_type = non_null_types{1}; else, primary_type = 'null'; end
         elseif ischar(type_info) || isstring(type_info)
             primary_type = char(type_info);
         end
         switch primary_type
            case 'string', default_value = '';
            case 'integer', default_value = 0;
            case 'number', default_value = 0.0;
            case 'array', default_value = {};
            case 'object', default_value = struct();
            case 'boolean', default_value = false;
            case 'null', default_value = [];
            otherwise, default_value = fallback;
         end
    end
    if isstruct(prop_schema) && isempty(default_value) && isfield(prop_schema, 'anyOf') && iscell(prop_schema.anyOf) && ~isempty(prop_schema.anyOf)
        first_option = prop_schema.anyOf{1};
        if isstruct(first_option) && isfield(first_option, 'type')
             first_type = first_option.type;
             switch first_type % Default based on first type in anyOf
                case 'string', default_value = ''; case 'integer', default_value = 0;
                case 'number', default_value = 0.0; case 'array', default_value = {};
                case 'object', default_value = struct(); case 'boolean', default_value = false;
                case 'null', default_value = [];
             end
        end
    end
end
if isempty(default_value) % Final fallback if still empty
    default_value = fallback;
end
end % end get_property_default function


% --------------------- resolve_path ---------------------
% Resolves path variables (e.g., $NDIDOCUMENTPATH) and handles relative paths.
function path = resolve_path(ref_path_string, current_schema_file, path_mappings)
path = char(ref_path_string);
for i = 1:numel(path_mappings)
    path = strrep(path, path_mappings(i).searchString, path_mappings(i).replaceString);
end
is_absolute = startsWith(path, '/') || startsWith(path, filesep) || ...
              (ispc && numel(path)>1 && path(2)==':' && (path(1)>='A'&&path(1)<='Z' || path(1)>='a'&&path(1)<='z'));
if ~is_absolute
    [schema_dir, ~, ~] = fileparts(current_schema_file);
    if isempty(schema_dir), schema_dir = pwd; end
    path = fullfile(schema_dir, path);
end
try % Normalize path
    jFile = java.io.File(path);
    path = char(jFile.getCanonicalPath());
catch ME
    error('ndi_document_blank_from_schema:PathNormalizationError',...
            'Could not normalize path "%s" (ref: "%s", file: %s): %s.', path, ref_path_string, current_schema_file, ME.message);
end
end % end resolve_path function


% --------------------- merge_structures ---------------------
% Merges fields from source struct 'src' into destination struct 'dst' recursively.
function dst = merge_structures(dst, src)
if ~isstruct(src), dst = src; return; end
if ~isstruct(dst), dst = src; return; end
fields = fieldnames(src);
for i = 1:length(fields)
    field = fields{i};
    if ~isfield(dst, field)
        dst.(field) = src.(field); % Add new field
    else
        src_val = src.(field); dst_val = dst.(field);
        if isstruct(src_val) && isstruct(dst_val)
            dst.(field) = merge_structures(dst_val, src_val); % Merge sub-structs
        elseif iscell(src_val) && iscell(dst_val) % Merge cell arrays
             if size(dst_val, 2) > 1, dst_val = dst_val(:); end % Ensure column
             if size(src_val, 2) > 1, src_val = src_val(:); end % Ensure column
             try
                 dst.(field) = [dst_val; src_val]; % Append (de-duplicate later if needed)
             catch ME
                  error('ndi_document_blank_from_schema:MergeConcatError', ...
                          'Could not concatenate cell arrays for field "%s": %s.', field, ME.message);
             end
        else
            dst.(field) = src_val; % Overwrite non-struct/non-cell or mismatched types
        end
    end
end
end % end merge_structures function