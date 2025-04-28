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
%      a. Retrieves the list of associated binary files.
%      b. Copies each binary file to the 'TARGET/files' directory.
%      c. Creates a modified copy of the document in memory where the file references
%         point to the newly copied files in 'TARGET/files'. The original documents
%         within D remain unchanged.
%   4. Saves all the modified document objects into a single .mat file named
%      'copied_documents.mat' within the 'TARGET/documents' directory.
%   5. Returns a cell array MODIFIED_DOCS containing all the modified document objects.
%
%   This function allows creating a self-contained snapshot of the documents and
%   their associated files, which can be useful for archiving, sharing, or
%   reconstructing parts of an NDI session/dataset without altering the original.
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
%       copied_docs = ndi.fun.dataset.copySessionDocs(mySession, target_folder); % Example call from namespace
%       disp(['Documents and files copied to ' target_folder]);
%       % Now, '/path/to/backup/session_copy/documents/copied_documents.mat'
%       % contains the document metadata, and '/path/to/backup/session_copy/files/'
%       % contains copies of the associated binary files.
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
q = ndi.query('','isa','base'); % [cite: 37, 57]
docs_original = D.database_search(q); % [cite: 37]
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
    disp(['Processing document ' num2str(i) '/' num2str(numel(docs_original)) ': ID ' doc_orig.id()]); % [cite: 615, 618]

    try
        % Create a copy to modify, leaving the original untouched
        doc_copy = ndi.document(doc_orig.document_properties); % Create a copy

        file_list = doc_copy.current_file_list(); % [cite: 612, 653] Get list of files for this doc
        new_file_info = {}; % To store parameters for add_file

        if ~isempty(file_list)
            disp(['  Found ' num2str(numel(file_list)) ' associated files. Copying...']);

            for k = 1:numel(file_list)
                fname = file_list{k};
                disp(['    Copying file: ' fname]);

                % Find original file path using database_existbinarydoc
                [tf, src_path] = D.database_existbinarydoc(doc_copy.id(), fname); % [cite: 442, 458, 480, 521]

                % Use isfile instead of exist(...,'file')
                if tf && isfile(src_path)
                    dest_path = fullfile(files_dir, fname);
                    try
                        copyfile(src_path, dest_path);
                        % Prepare info for re-adding the file reference
                        % Use minimal info, assuming defaults for ingest/delete
                         new_file_info{end+1} = {fname, dest_path, 'ingest', 0, 'delete_original', 0}; % [cite: 632]
                    catch copy_err
                        warning(['Could not copy file ' src_path ' to ' dest_path '. Error: ' copy_err.message]);
                        % Skip adding this file reference back if copy failed
                    end
                else
                    warning(['Could not find source path for file ' fname ' associated with document ' doc_copy.id() '. Skipping copy.']);
                end
            end % loop over files
        else
            disp('  No associated files found for this document.');
        end

        % Reset file info on the copy and add back the new references
        doc_copy = doc_copy.reset_file_info(); % [cite: 622, 694]
        for k=1:numel(new_file_info)
            doc_copy = doc_copy.add_file(new_file_info{k}{:}); % [cite: 611, 632]
        end

        modified_docs{end+1} = doc_copy; % Add the modified document to our list

    catch doc_process_err
        warning(['Error processing document ID ' doc_orig.id() ': ' doc_process_err.message '. Skipping this document.']);
        continue; % Skip to the next document
    end
end
disp('Finished processing documents.');

% --- Step 6: Save modified documents to .mat file ---
mat_file_path = fullfile(doc_dir, 'copied_documents.mat');
disp(['Saving modified documents to ' mat_file_path '...']);
try
    save(mat_file_path, 'modified_docs', '-v7.3'); % Use v7.3 for potentially large files
    disp('Saving complete.');
catch save_err
    error(['Could not save the modified documents to ' mat_file_path '. Error: ' save_err.message]);
end

disp('NDI document copy process finished.');

end % main function

