function fileUids = getFileUidsFromDocuments(ndiDocuments)
% GETFILEUIDSFROMDOCUMENTS Extracts all unique file UIDs from a cell array of NDI documents.
%
%   FILEUIDS = ndi.cloud.sync.internal.GETFILEUIDSFROMDOCUMENTS(NDIDOCUMENTS)
%
%   Inputs:
%       ndiDocuments (cell): A cell array of ndi.document objects.
%
%   Outputs:
%       fileUids (cellstr): A cell array of unique file UIDs found in the
%           documents. Returns an empty cell array if no files are found or
%           if ndiDocuments is empty.
%
%   This function iterates through each document, and if the document has files,
%   it extracts the UIDs from the file_info.locations.
%

    arguments
        ndiDocuments (1,:) cell % Cell array of ndi.document objects
    end

    fileUidsList = {};

    if isempty(ndiDocuments)
        fileUids = {};
        return;
    end

    for i = 1:numel(ndiDocuments)
        document = ndiDocuments{i};
        if isa(document, 'ndi.document') && document.has_files()
            fileInfo = document.document_properties.files.file_info;
            for j = 1:numel(fileInfo)
                % Each fileInfo(j) can have multiple locations, each with a UID
                if isfield(fileInfo(j), 'locations') && ~isempty(fileInfo(j).locations)
                    for k = 1:numel(fileInfo(j).locations)
                        if isfield(fileInfo(j).locations(k), 'uid') && ~isempty(fileInfo(j).locations(k).uid)
                            fileUidsList{end+1} = fileInfo(j).locations(k).uid; %#ok<AGROW>
                        end
                    end
                end
            end
        end
    end
    
    if ~isempty(fileUidsList)
        fileUids = unique(fileUidsList(:), 'stable'); % Return unique UIDs as a column vector
    else
        fileUids = {};
    end
end
