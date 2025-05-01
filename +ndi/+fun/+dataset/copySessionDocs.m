function modified_docs = copySessionDocs(D, target)
%COPYSESSIONDOCS - Copies NDI documents and their associated files to a new location.
%
%   MODIFIED_DOCS = COPYSESSIONDOCS(D, TARGET)
%
%   Takes an ndi.session or ndi.dataset object D and a target folder location TARGET.
%   It performs the following steps:
%   1. Creates two subdirectories within TARGET: 'documents' and 'files'.
%   2. Searches D for all documents that are of class 'base' (ndi.document objects).
%   3. For each found document:
%      a. Retrieves the list of associated binary files (by their logical names).
%      b. For each file, constructs a unique filename based on the document ID
%         and the logical filename (e.g., 'docID__logicalName').
%      c. Copies the binary file content from the source database to the
%         'TARGET/files' directory using the unique filename. If any copy fails,
%         an error is thrown and the function terminates.
%      d. Creates a modified copy of the document in memory. The file references
%         in this copy point to the newly copied files (with unique names)
%         in 'TARGET/files', but retain their original logical names internally.
%      e. If any step in processing a document fails, an error is thrown.
%   4. Saves all the successfully modified document objects into a single .mat file named
%      'copied_documents.mat' within the 'TARGET/documents' directory.
%   5. Returns a cell array MODIFIED_DOCS containing all the modified document objects.
%
%   This function allows creating a self-contained snapshot of the documents and
%   their associated files, ensuring file uniqueness in the target directory.
%   It is intended to be placed in the +ndi/+fun/+dataset namespace.
%
%   Inputs:
%       D - An ndi.session or ndi.dataset object.
%       TARGET - A character vector or string specifying the target folder path.
%
%   Outputs:
%       MODIFIED_DOCS - A cell array of the modified ndi.document objects.
%
%   Example:
%       % Assuming 'mySession' is an existing ndi.session object
%       % and '/path/to/backup' is the desired backup location
%       target_folder = '/path/to/backup/session_copy';
%       try
%           copied_docs = ndi.fun.dataset.copySessionDocs(mySession, target_folder); % Example call from namespace
%           disp(['Documents and files copied to ' target_folder]);
%       catch ME
%           disp(['ERROR during copy process: ' ME.identifier ' - ' ME.message]);
%       end
%       % If successful, '/path/to/backup/session_copy/documents/copied_documents.mat'
%       % contains the document metadata, and '/path/to/backup/session_copy/files/'
%       % contains copies of the associated binary files (with unique names).
%

% --- Input Validation ---
arguments
    D (1,1) {mustBeA(D, ["ndi.session","ndi.dataset"])} % Validate class directly
    target (1,1) string {mustBeNonempty}               % Validate target path
end
% Convert target to char if needed
target = char(target);

% --- Step 1 & 2: Create target directories ---
disp(['Creating target directories in ' target '...']);
doc_dir = fullfile(target, 'documents');
files_dir = fullfile(target, 'files');
% Use isfolder instead of exist(...,'dir')
if ~isfolder(target)
    mkdir(target);
end
if ~isfolder(doc_dir)
    mkdir(doc_dir);
end
if ~isfolder(files_dir)
    mkdir(files_dir);
end
disp('Directories created.');

% --- Step 3: Search for base documents ---
disp('Searching for all base documents...');
% Search for all documents that are derived from 'base'
q = ndi.query('','isa','base'); %
docs_original = D.database_search(q); %
disp(['Found ' num2str(numel(docs_original)) ' documents.']);

if isempty(docs_original)
    warning('No documents found in the provided NDI object.');
    modified_docs = {};
    return;
end

% --- Step 4 & 5: Process each document (copy files, modify doc) ---
disp('Processing documents: copying files and updating references...');
modified_docs = {}; % Initialize cell array for modified documents

for i = 1:numel(docs_original)
    doc_orig = docs_original{i};
    current_doc_id = doc_orig.id(); % Get ID once for messages
    disp(['Processing document ' num2str(i) '/' num2str(numel(docs_original)) ': ID ' current_doc_id]); %
    
    try
        % Create a copy to modify, leaving the original untouched
        doc_copy = ndi.document(doc_orig.document_properties); % Create a copy
        
        file_list = doc_copy.current_file_list(); % Get list of files for this doc
        new_file_info = {}; % To store parameters for add_file
        
        if ~isempty(file_list)
            disp(['  Found ' num2str(numel(file_list)) ' associated files. Copying...']);
            
            for k = 1:numel(file_list)
                fname = file_list{k}; % This is the logical name
                
                % ** MODIFICATION START: Create unique filename **
                % Sanitize the original filename part for use in the new name
                safe_fname_part = matlab.lang.makeValidName(fname);
                % Create a unique name using doc ID and sanitized original name
                unique_dest_fname = [current_doc_id '__' safe_fname_part];
                disp(['    Logical name: ' fname ' -> Unique physical name: ' unique_dest_fname]);
                % ** MODIFICATION END **

                % Find original file path using database_existbinarydoc
                [tf, src_path] = D.database_existbinarydoc(current_doc_id, fname); %

                if tf && isfile(src_path)
                    % ** MODIFICATION: Use unique filename for destination **
                    dest_path = fullfile(files_dir, unique_dest_fname);
                    try
                        copyfile(src_path, dest_path);
                        % Prepare info for re-adding the file reference
                        % Use the ORIGINAL logical name 'fname', but the NEW path 'dest_path'
                        % Set ingest=0, delete_original=0 because the file now physically exists at dest_path
                         new_file_info{end+1} = {fname, dest_path, 'ingest', 0, 'delete_original', 0}; %
                    catch copy_err
                        % Throw error if copy fails
                        error('ndi:copySessionDocs:FileCopyFailed', ...
                              'Could not copy source file %s for logical name %s (document %s) to %s. Original error: %s', ...
                              src_path, fname, current_doc_id, dest_path, copy_err.message);
                    end
                else
                     % Throw error if source file is missing
                    error('ndi:copySessionDocs:SourceFileNotFound', ...
                          'Could not find source path or file for logical name %s associated with document %s.', ...
                           fname, current_doc_id);
                end
            end % loop over files
        else
            disp('  No associated files found for this document.');
        end
        
        % Reset file info on the copy and add back the new references
        doc_copy = doc_copy.reset_file_info(); %
        for k=1:numel(new_file_info)
            % new_file_info{k}{1} is the original logical name
            % new_file_info{k}{2} is the new physical path (with unique filename)
            doc_copy = doc_copy.add_file(new_file_info{k}{:}); %
        end
        
        modified_docs{end+1} = doc_copy; % Add the modified document to our list
        
    catch doc_process_err
        % Any error during document processing is now fatal
        error('ndi:copySessionDocs:DocumentProcessingFailed', ...
              'Error processing document ID %s: %s', ...
              current_doc_id, doc_process_err.message);
    end
end
disp('Finished processing documents.');

% --- Step 6: Save modified documents to .mat file ---
% This part is reached only if all documents and files were processed without error
mat_file_path = fullfile(doc_dir, 'copied_documents.mat');
disp(['Saving successfully processed documents to ' mat_file_path '...']);
try
    save(mat_file_path, 'modified_docs', '-v7.3'); % Use v7.3 for potentially large files
    disp('Saving complete.');
catch save_err
    error(['Could not save the modified documents to ' mat_file_path '. Error: ' save_err.message]);
end

disp('NDI document copy process finished successfully.');

end % main function