function result = docfun(functionHandle, ndiDocuments)
% docfun - Apply a function to each NDI document in an array of documents.
% 
% Syntax:
%   result = ndi.docs.docfun(functionHandle, ndiDocuments) 
% 
% Input Arguments:
%   - functionHandle (function_handle) - A function to be applied to each 
%       NDI document.
%   - ndiDocuments (array) - An array of NDI documents to which the function
%       will be applied.
% 
% Output Arguments:
%   result (cell array) - A cell array containing the results of applying
%   the function to each NDI document.

    arguments
        functionHandle (1,1) function_handle
        ndiDocuments (1,:) {mustBeNdiDocuments}
    end

    isCellArray = iscell(ndiDocuments); % could be cell or ndi.document array
    
    numDocuments = numel(ndiDocuments);
    result = cell(1, numDocuments);

    if isCellArray
        for iDocument = 1:numDocuments
            result{iDocument} = functionHandle( ndiDocuments{iDocument} );
        end
    else
        for iDocument = 1:numDocuments
            result{iDocument} = functionHandle( ndiDocuments(iDocument) );
        end
    end
end

function mustBeNdiDocuments(ndiDocuments)
    if isa(ndiDocuments, 'ndi.document')
        return
    elseif isa(ndiDocuments, 'cell')
        tf = false(1, numel(ndiDocuments));
        for j = 1:numel(ndiDocuments)
            tf(j) = isa(ndiDocuments{j}, 'ndi.document');
        end
        assert(all(tf), 'NDI:Docfun:NotNDIDocuments', ...
            'All elements of cell array must be of type `ndi.document`')
    else
        error('NDI:Docfun:NotNDIDocuments', ...
            ['Expected an array or a cell array of ndi.documents, ', ...
            'instead the was a `%s`'], class(ndiDocuments))
    end
end
