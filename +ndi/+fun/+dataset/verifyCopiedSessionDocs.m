function [B, MSG] = verifyCopiedSessionDocs(S, target)
%VERIFYCOPIEDSESSIONDOCS - Verifies the integrity of copied NDI session documents and files.
%
%   [B, MSG] = VERIFYCOPIEDSESSIONDOCS(S, TARGET)
%
%   Compares documents and associated files in an original ndi.session or
%   ndi.dataset object S with a copied version located in the TARGET directory
%   (presumably created by ndi.fun.dataset.copySessionDocs).
%
%   The verification checks:
%   1. Existence of the expected directory structure in TARGET ('documents', 'files',
%      and 'documents/copied_documents.mat').
%   2. That the number of 'base' documents in S matches the number loaded from TARGET.
%   3. That for each document ID present in both:
%      a. The document properties (excluding file info) are identical. This includes
%         checking that the base.session_id matches, assuming the copy/recreation
%         process preserves the session ID.
%      b. The list of associated file names is identical.
%      c. The content of each associated file in S matches the content of the
%         corresponding file copied into TARGET/files. The path to the copied
%         file is retrieved from the copied document's properties.
%
%   Inputs:
%       S      - The original ndi.session or ndi.dataset object.
%       TARGET - Path to the directory containing the copied session structure.
%
%   Outputs:
%       B      - Boolean. True if verification passes, False otherwise.
%       MSG    - Cell array of strings. Contains messages detailing verification
%                failures, or {'Verification successful.'} if B is true.
%
%   Example:
%       originalSession = ndi.session.dir('/path/to/original/session');
%       copiedSessionDir = '/path/to/copied/session';
%       % Assume copySessionDocs(originalSession, copiedSessionDir) was run previously
%       [isValid, messages] = ndi.fun.dataset.verifyCopiedSessionDocs(originalSession, copiedSessionDir);
%       if isValid
%           disp('Copied session verified successfully.');
%       else
%           disp('Verification failed:');
%           disp(messages);
%       end
%

% --- Input Validation ---
arguments
    S (1,1) {mustBeA(S, ["ndi.session","ndi.dataset"])}
    target (1,1) string {mustBeFolder} % Target directory must exist
end
target = char(target); % Ensure char vector

% --- Initial Setup ---
B = true; % Assume success initially
MSG = {};
chunkSize = 1024*1024; % 1MB chunk size for file comparison

% --- Verify Target Directory Structure ---
disp(['Verifying target directory structure in ' target '...']);
doc_dir = fullfile(target, 'documents');
files_dir = fullfile(target, 'files'); % Location of copied files
mat_file_path = fullfile(doc_dir, 'copied_documents.mat');

if ~isfolder(doc_dir)
    MSG{end+1} = 'Target directory missing required subfolder: documents';
    B = false;
end
if ~isfolder(files_dir)
    MSG{end+1} = 'Target directory missing required subfolder: files';
    B = false;
end
if ~isfile(mat_file_path)
    MSG{end+1} = ['Required .mat file not found: ' mat_file_path];
    B = false;
end

if ~B % If structure is wrong, no point proceeding
    disp('Target directory structure verification failed.');
    return;
end
disp('Target structure verified.');

% --- Load Copied Documents ---
disp(['Loading copied documents from ' mat_file_path '...']);
try
    loaded_data = load(mat_file_path, 'modified_docs');
catch load_err
    MSG{end+1} = ['Failed to load data from ' mat_file_path '. Error: ' load_err.message];
    B = false;
    return;
end

if ~isfield(loaded_data, 'modified_docs')
    MSG{end+1} = ['The .mat file ' mat_file_path ' does not contain the expected variable ''modified_docs''.'];
    B = false;
    return;
end
if ~iscell(loaded_data.modified_docs)
     MSG{end+1} = 'Variable ''modified_docs'' in .mat file must be a cell array.';
     B = false;
     return;
end
copied_docs = loaded_data.modified_docs;
disp(['Loaded ' num2str(numel(copied_docs)) ' copied documents.']);

% --- Search Original Documents ---
disp('Searching for original documents in source session/dataset...');
try
    docs_original = S.database_search(ndi.query('','isa','base')); %
catch search_err
    MSG{end+1} = ['Failed to search original session/dataset. Error: ' search_err.message];
    B = false;
    return;
end
disp(['Found ' num2str(numel(docs_original)) ' original documents.']);

% --- Compare Document Counts ---
if numel(docs_original) ~= numel(copied_docs)
    MSG{end+1} = ['Mismatch in document count: Original=' num2str(numel(docs_original)) ...
                  ', Copied=' num2str(numel(copied_docs))];
    B = false;
    % Don't return yet, could compare matching IDs
end

% --- Build ID Maps for Efficient Lookup ---
map_orig_id_to_index = containers.Map('KeyType','char','ValueType','double');
for i=1:numel(docs_original)
    map_orig_id_to_index(docs_original{i}.id()) = i;
end
map_copy_id_to_index = containers.Map('KeyType','char','ValueType','double');
for i=1:numel(copied_docs)
     if isa(copied_docs{i}, 'ndi.document') % Ensure it's a document before getting ID
        map_copy_id_to_index(copied_docs{i}.id()) = i;
     else
         warning('Item %d in copied_docs is not an ndi.document.', i);
     end
end

% --- Compare Individual Documents and Files ---
disp('Comparing documents and file contents...');
original_ids = map_orig_id_to_index.keys;

for i = 1:numel(original_ids)
    orig_id = original_ids{i};
    orig_idx = map_orig_id_to_index(orig_id);
    doc_orig = docs_original{orig_idx};

    if ~map_copy_id_to_index.isKey(orig_id)
        MSG{end+1} = ['Document ID ' orig_id ' exists in original session but not in copied data.'];
        B = false;
        continue; % Check next original document
    end

    copy_idx = map_copy_id_to_index(orig_id);
    doc_copy = copied_docs{copy_idx};

    % --- a) Compare Document Metadata (excluding file info) ---
    try
        props_orig = doc_orig.document_properties;
        props_copy = doc_copy.document_properties;

        % Remove the 'files' structure as its contents will differ.
        % Keep base.session_id for comparison.
        if isfield(props_orig,'files') % Use correct field name 'files'
             props_orig = rmfield(props_orig,'files');
        end
         if isfield(props_copy,'files') % Use correct field name 'files'
             props_copy = rmfield(props_copy,'files');
        end

        % Use isequaln for robust comparison (handles NaNs, struct order)
        if ~isequaln(props_orig, props_copy)
            MSG{end+1} = ['Document properties differ for ID ' orig_id];
            B = false;
        end
    catch meta_err
        MSG{end+1} = ['Error comparing metadata for document ID ' orig_id ': ' meta_err.message];
        B = false;
    end

    % --- b) Compare File Lists and Contents ---
    try
        file_list_orig = doc_orig.current_file_list(); %
        file_list_copy = doc_copy.current_file_list(); %

        if ~isequal(sort(file_list_orig), sort(file_list_copy))
            MSG{end+1} = ['File lists differ for document ID ' orig_id];
            B = false;
        else
            % File lists match, now compare content
            if ~isempty(file_list_orig)
                disp(['  Comparing ' num2str(numel(file_list_orig)) ' files for doc ' orig_id '...']);
                for k = 1:numel(file_list_orig)
                    fname = file_list_orig{k}; % This is the logical name
                    disp(['    Comparing file: ' fname]);

                    binDocOrig = []; % Handle for original binary doc
                    fidCopy = -1;    % Handle for copied file

                    try
                        % Open original file via database
                        binDocOrig = S.database_openbinarydoc(orig_id, fname); %
                        if isempty(binDocOrig)
                            error('Could not open original binary document from database.');
                        end

                        % ** MODIFICATION START: Access correct path location **
                        % Get path to copied file from the copied doc's properties
                        if isfield(doc_copy.document_properties,'files') && isfield(doc_copy.document_properties.files,'file_info')
                            file_info_copy = doc_copy.document_properties.files.file_info;
                        else
                            error(['Copied document ' orig_id ' is missing file information structure.']);
                        end
                        file_match_idx = find(strcmp(fname, {file_info_copy.name}));
                        if isempty(file_match_idx)
                             error(['File name ' fname ' not found in copied document''s file_info struct.']);
                        end

                        % Check if the nested locations structure exists
                        if ~isfield(file_info_copy(file_match_idx(1)), 'locations') || ...
                           isempty(file_info_copy(file_match_idx(1)).locations) || ...
                           ~isstruct(file_info_copy(file_match_idx(1)).locations)
                             error(['Field ''locations'' is missing, empty, or not a struct in file_info for file ' fname ', doc ' orig_id '.']);
                        end
                        locations_struct = file_info_copy(file_match_idx(1)).locations;

                        % Check if the 'location' field exists within the locations struct(array)
                        % Assume we use the first location entry if there are multiple
                        if ~isfield(locations_struct(1), 'location')
                             error(['Field ''location'' is missing in file_info.locations struct for file ' fname ', doc ' orig_id '.']);
                        end
                        copied_file_path = locations_struct(1).location; % Access path here
                        % ** MODIFICATION END **

                        if ~isfile(copied_file_path)
                            % If path from doc is wrong, maybe it IS target/files/fname? Check as fallback.
                            % Construct expected unique name based on convention used in copySessionDocs
                            safe_fname_part = matlab.lang.makeValidName(fname);
                            unique_dest_fname = [orig_id '__' safe_fname_part]; % Match the convention
                            fallback_path = fullfile(files_dir, unique_dest_fname);

                            if isfile(fallback_path)
                                 warning('Path in copied document (field: files.file_info.locations.location) for file %s (doc %s) is wrong or file missing [%s]. Using expected location [%s] instead.', fname, orig_id, copied_file_path, fallback_path);
                                 copied_file_path = fallback_path;
                            else
                                 error(['Copied file path from document properties does not exist or is not a file: ' copied_file_path ', and expected fallback path ' fallback_path ' also not found.']);
                            end
                        end

                        % Open copied file directly
                        fidCopy = fopen(copied_file_path, 'r');
                        if fidCopy == -1
                             error(['Could not open copied file: ' copied_file_path]);
                        end

                        % Compare content chunk by chunk
                        while (true) % Loop until break
                            dataOrig = binDocOrig.fread(chunkSize, '*uint8'); %
                            dataCopy = fread(fidCopy, chunkSize, '*uint8'); %

                            eofOrig = binDocOrig.feof(); %
                            eofCopy = feof(fidCopy); %

                            if ~isequal(dataOrig, dataCopy)
                                MSG{end+1} = ['Content mismatch for file ' fname ' in document ID ' orig_id];
                                B = false;
                                break; % Exit inner while loop
                            end

                            if eofOrig ~= eofCopy
                                MSG{end+1} = ['EOF status mismatch for file ' fname ' in document ID ' orig_id];
                                B = false;
                                break; % Exit inner while loop
                            end

                            if eofOrig % If both are EOF, we are done comparing this file
                                break; % Exit inner while loop
                            end
                        end % while true (chunk comparison)

                    catch file_err % Catch errors during file open/read/compare
                        MSG{end+1} = ['Error comparing file ' fname ' for document ID ' orig_id ': ' file_err.message];
                        B = false;
                    end % try/catch for file processing

                    % Cleanup: Close files within the loop for each file
                    if ~isempty(binDocOrig)
                        try
                           S.database_closebinarydoc(binDocOrig); %
                        catch close_err
                           warning(['Could not close original binary doc for file ' fname ', doc ' orig_id '. Error: ' close_err.message]);
                        end
                    end
                    if fidCopy ~= -1
                        fclose(fidCopy); %
                    end

                    if ~B % If a file comparison failed, stop comparing files for this doc
                         break;
                    end

                end % loop k (files)
            end % if ~isempty(file_list_orig)
        end % file list check
    catch file_list_err
         MSG{end+1} = ['Error processing file list for document ID ' orig_id ': ' file_list_err.message];
         B = false;
    end % try/catch for file list/content

end % loop i (original documents)

% --- Check for documents in copy but not original ---
copied_ids = map_copy_id_to_index.keys;
for i = 1:numel(copied_ids)
    if ~map_orig_id_to_index.isKey(copied_ids{i})
        MSG{end+1} = ['Document ID ' copied_ids{i} ' exists in copied data but not in original session.'];
        B = false;
    end
end

% --- Final Result ---
if B
    MSG = {'Verification successful.'};
    disp('Verification successful.');
else
    disp('Verification failed. See MSG output for details.');
end

end % main function