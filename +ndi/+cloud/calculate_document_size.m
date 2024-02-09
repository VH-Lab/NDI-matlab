function size = calculate_document_size(convertedDocs)
%CALCULATE_DOCUMENT_SIZE - Calculates the size of the OpenMinds documents
%   
% SIZE = ndi.cloud.CALCULATE_DOCUMENT_SIZE(COVERTEDDOCS)
%
%   Inputs:
%       CONVERTEDDOCS: A cell array of converted OpenMinds documents
%
%   Outputs:
%       SIZE: The size of the converted OpenMinds documents in kilobytes

size = 0;
for i=1:numel(convertedDocs)
    doc_str = did.datastructures.jsonencodenan(convertedDocs{i}.document_properties);
    info = whos('doc_str');
    size = size + info.bytes;
end
size = size / 1024; % Convert to kilobytes
end
