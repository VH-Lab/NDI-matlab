function doc = storeDoc(session, doc, fileNames, filePaths)
% STOREDOC - attach files to a document and add it to the database
%
%   DOC = STOREDOC(SESSION, DOC, FILENAMES, FILEPATHS)
%
%   The single place in ndi.fun.doc.gene where a document acquires files
%   and enters the database. Every maker function routes through here, so
%   a mistake in the document API is one correction rather than several.
%
%   Inputs:
%   SESSION   - an ndi.session or ndi.dataset
%   DOC       - an ndi.document
%   FILENAMES - cellstr of names declared in the document's file_list. A
%               name may be a numbered form such as 'tile.bin_12' when the
%               file_list declares 'tile.bin_#'.
%   FILEPATHS - cellstr of the same length; the file on disk for each name
%
%   Files are ingested, so ndi.document/add_file deletes each original
%   once ndi.database/add_doc has copied it. Pass copies if the caller
%   still needs them.
%
arguments
    session (1,1) {mustBeA(session,{'ndi.session','ndi.dataset','ndi.session.dir'})}
    doc (1,1) ndi.document
    fileNames cell
    filePaths cell
end

if numel(fileNames) ~= numel(filePaths)
    error('NDI:gene:storeDoc:lengthMismatch', ...
        'FILENAMES and FILEPATHS must be the same length (%d, %d).', ...
        numel(fileNames), numel(filePaths));
end

for i = 1:numel(fileNames)
    if ~isfile(filePaths{i})
        error('NDI:gene:storeDoc:missingFile', ...
            'File ''%s'' for document entry ''%s'' does not exist.', ...
            filePaths{i}, fileNames{i});
    end
    [b, msg] = doc.is_in_file_list(fileNames{i});
    if ~b
        error('NDI:gene:storeDoc:notInFileList', ...
            'Document does not accept a file named ''%s'': %s', fileNames{i}, msg);
    end
    doc = doc.add_file(fileNames{i}, filePaths{i});
end

session.database_add(doc);

end % storeDoc
