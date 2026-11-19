function ranges = documentBatchRanges(documentSizes, maxCount, maxBytes)
% DOCUMENTBATCHRANGES - Split documents into upload batches by count and size.
%
%   RANGES = ndi.cloud.upload.internal.documentBatchRanges(DOCUMENTSIZES, MAXCOUNT, MAXBYTES)
%
%   Walks the documents in order and starts a new batch whenever adding the
%   next document would put the current batch over MAXCOUNT documents or
%   over MAXBYTES bytes of JSON. A document that is by itself larger than
%   MAXBYTES gets a batch of its own (it is never dropped).
%
%   Bulk document uploads are ingested by a server Lambda with limited
%   scratch disk; one very large JSON file per zip (e.g. 100000 documents,
%   638 MB) failed there with no documents ingested. Capping each batch's
%   size keeps every zip small and limits what one failed batch can lose.
%
%   Inputs:
%       documentSizes - Numeric vector, the encoded JSON size of each
%                       document in bytes (in upload order).
%       maxCount      - Maximum documents per batch (positive; Inf for none).
%       maxBytes      - Maximum JSON bytes per batch (positive; Inf for none).
%
%   Output:
%       ranges - 1xN cell array; ranges{k} is a row vector of the indexes
%                (into DOCUMENTSIZES) of the documents in batch k. Empty
%                (1x0 cell) when DOCUMENTSIZES is empty.
%
%   Example:
%       ranges = ndi.cloud.upload.internal.documentBatchRanges([10 10 10], 2, Inf);
%       % ranges = {[1 2], 3}
%
%   See also: ndi.cloud.upload.uploadDocumentCollection

    arguments
        documentSizes (1,:) double {mustBeNonnegative}
        maxCount (1,1) double {mustBePositive}
        maxBytes (1,1) double {mustBePositive}
    end

    ranges = cell(1, 0);
    n = numel(documentSizes);
    if n == 0
        return;
    end

    batchStart = 1;
    batchBytes = 0;
    for i = 1:n
        batchCount = i - batchStart;  % documents already in the batch
        if batchCount > 0 && (batchCount + 1 > maxCount || batchBytes + documentSizes(i) > maxBytes)
            ranges{end+1} = batchStart:(i-1); %#ok<AGROW>
            batchStart = i;
            batchBytes = 0;
        end
        batchBytes = batchBytes + documentSizes(i);
    end
    ranges{end+1} = batchStart:n;
end
