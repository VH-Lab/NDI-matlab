function downloadList = buildGenericFileDownloadList(documents, namingStrategy)
%BUILDGENERICFILEDOWNLOADLIST Flatten generic_file documents into a per-file download list.
%
%   DOWNLOADLIST = ndi.cloud.download.internal.buildGenericFileDownloadList( ...
%       DOCUMENTS, NAMINGSTRATEGY)
%
%   Extracted from downloadGenericFiles so the per-file record shape --
%   uid, filename, documentId -- can be unit-tested without a live cloud
%   dataset. downloadGenericFiles calls this once before iterating the
%   list to fetch each file.
%
%   Each entry names one file the download loop should fetch, keyed on:
%
%       uid         - The uid recorded in the document's files.file_info.
%                     Uniquely identifies the file's bytes in the cloud.
%       filename    - The local filename to write, chosen by
%                     NAMINGSTRATEGY.
%       documentId  - The id of the document the file came from. Used by
%                     the batch presign cache (NDI-matlab#962) so the
%                     download loop can key one getSignedURLSet call per
%                     document instead of one getFileDetails call per uid.
%
%   Inputs:
%       documents        - A cell array of ndi.document objects. Only
%                          documents whose has_files() returns true
%                          contribute entries.
%       namingStrategy   - "original" | "id" | "id_original". Chooses
%                          the local filename shape:
%                            "original"    -> "<name>.<ext>"
%                            "id"          -> "<docId>.<ext>"
%                            "id_original" -> "<docId>_<name>.<ext>"
%                          The name-and-extension pair comes from the
%                          document's generic_file.filename when set,
%                          and from the file_info entry's own name
%                          otherwise; a URL-style location ending in
%                          ".zip" (with no extension recovered above)
%                          picks ".zip".
%
%   Outputs:
%       downloadList  - A struct array with fields uid, filename,
%                       documentId. Empty when no documents have files.
%
%   See also: ndi.cloud.download.downloadGenericFiles

    arguments
        documents cell
        namingStrategy (1,1) string
    end

    downloadList = struct('uid', {}, 'filename', {}, 'documentId', {});

    for i = 1:numel(documents)
        doc = documents{i};
        if ~doc.has_files(), continue, end

        fileInfo = doc.document_properties.files.file_info;
        for j = 1:numel(fileInfo)
            if ~isfield(fileInfo(j), 'locations') || isempty(fileInfo(j).locations)
                continue
            end
            uid = fileInfo(j).locations(1).uid;

            originalFullname = doc.document_properties.generic_file.filename;
            [~, name_part, ext_part] = fileparts(originalFullname);
            if isempty(name_part)
                [~, name_part, ext_part] = fileparts(fileInfo(j).name);
            end
            if contains(fileInfo(j).locations.location, '.zip') && isempty(ext_part)
                ext_part = '.zip';
            end

            switch namingStrategy
                case "id"
                    filename = [doc.id() ext_part];
                case "id_original"
                    filename = [doc.id() '_' name_part ext_part];
                case "original"
                    filename = [name_part ext_part];
                otherwise
                    error('NDI:downloadGenericFiles:UnknownNamingStrategy', ...
                        'Unknown naming strategy "%s".', namingStrategy);
            end

            downloadList(end+1).uid = uid; %#ok<AGROW>
            downloadList(end).filename = filename;
            downloadList(end).documentId = doc.id();
        end
    end
end
