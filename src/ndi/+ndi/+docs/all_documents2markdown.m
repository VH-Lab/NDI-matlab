function t = all_documents2markdown(options)
%ALL_DOCUMENTS2MARKDOWN Recursively convert all NDI document types to Markdown.
%
%   t = ndi.docs.all_documents2markdown(Name, Value, ...)
%
%   This function recursively scans a source directory (`input_path`) for NDI 
%   document `.json` files. It converts each document into a Markdown file and 
%   saves it to a destination directory (`output_path`).
%
%   Simultaneously, it generates a YAML-formatted string that maps the document
%   titles to their relative locations (`doc_output_path`), suitable for building a
%   table of contents in documentation systems like MkDocs.
%
%   ## Path Variable Roles
%   * **`input_path`**: The source folder on your computer where the function
%       looks for the original `.json` document files.
%   * **`output_path`**: The destination folder on your computer where the
%       function will write the converted `.md` markdown files.
%   * **`doc_output_path`**: A relative path string used to construct the URL links
%       within the generated `documents.yml` file. This should match the path
%       structure of your documentation site.
%
%   ## Name-Value Pairs
%   **'spaces'** (default: `6`)
%       A non-negative integer for the number of spaces to indent the current 
%       level in the output YAML string.
%
%   **'input_path'** (default: `ndi.common.PathConstants.DocumentFolder`)
%       The full path to the directory to search for `.json` files.
%
%   **'output_path'** (default: `.../docs/NDI-matlab/documents/`)
%       The full path to the directory where generated `.md` files will be saved.
%
%   **'doc_output_path'** (default: `'NDI-matlab/documents/'`)
%       The relative URL path prefix for documents in the generated YAML file.
%
%   **'write_yml'** (default: `true`)
%       A logical flag (`true` or `false`) indicating whether to write the
%       `documents.yml` file. This is automatically set to `false` in recursive calls.
%
%   ## Outputs
%   **t**
%       A character vector containing the generated YAML content.
%
%   ## Example
%   ```matlab
%   % Generate all markdown files using default paths.
%   yml_text = ndi.docs.all_documents2markdown();
%   ```

arguments
    options.spaces (1,1) {mustBeInteger, mustBeNonnegative} = 6
    options.input_path {mustBeText} = ndi.common.PathConstants.DocumentFolder
    options.output_path {mustBeText} = [ndi.common.PathConstants.RootFolder filesep 'docs' filesep 'NDI-matlab' filesep 'documents' filesep]
    options.doc_output_path {mustBeText} = 'NDI-matlab/documents/'
    options.write_yml (1,1) {mustBeNumericOrLogical} = true
end

t = ''; % Initialize output as an empty character vector

% --- Process JSON files in the current directory ---
json_files = dir(fullfile(options.input_path, '*.json'));

for i = 1:numel(json_files)
    % Skip special configuration file only at the top level of the recursion
    if options.spaces == 6 && strcmp(json_files(i).name, 'ndi_validate_config.json')
        continue;
    end
    
    % Get document name from filename (without extension)
    [~, doc_name] = fileparts(json_files(i).name);
    doc = ndi.document(doc_name);
    
    % Convert the NDI document to Markdown
    [md, info] = ndi.docs.document2markdown(doc);
    
    % Write the markdown file to the output_path
    output_file_path = fullfile(options.output_path, info.localurl);
    vlt.file.createpath(output_file_path);
    vlt.file.str2text(output_file_path, md);
    
    % Construct the relative URL path for the YAML file using doc_output_path
    yaml_link_path = [options.doc_output_path, info.localurl];
    % Ensure forward slashes for cross-platform compatibility in web URLs
    yaml_link_path = strrep(yaml_link_path, filesep, '/');
    [~, url_name] = fileparts(info.localurl);
    
    % Append the YAML entry to the output string
    indent = repmat(' ', 1, options.spaces);
    t = [t, sprintf('%s- %s : ''%s''\n', indent, url_name, yaml_link_path)];
end

% --- Recursively process subdirectories ---
subfolders = vlt.file.dirlist_trimdots(dir(options.input_path));

for i = 1:numel(subfolders)
    folder_name = subfolders{i};
    
    % Append the YAML entry for the subdirectory
    indent = repmat(' ', 1, options.spaces);
    t = [t, sprintf('%s- %s:\n', indent, folder_name)];
    
    % Call this function recursively for the subdirectory
    t_new = ndi.docs.all_documents2markdown(...
        'spaces', options.spaces + 2, ...
        'input_path', fullfile(options.input_path, folder_name), ...
        'output_path', fullfile(options.output_path, folder_name), ...
        'doc_output_path', [options.doc_output_path, folder_name, '/'], ...
        'write_yml', false); % Never write the yml file in recursive calls
        
    t = [t, t_new];
end

% --- Write YAML file on top-level call ---
if options.write_yml
    vlt.file.str2text(fullfile(options.output_path, 'documents.yml'), t);
end

end