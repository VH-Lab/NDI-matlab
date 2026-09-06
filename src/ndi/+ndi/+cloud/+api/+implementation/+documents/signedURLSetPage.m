function page = signedURLSetPage(decodedData, rawPayload)
%SIGNEDURLSETPAGE Turn a signed-url-set response body into a page struct.
%
%   PAGE = ndi.cloud.api.implementation.documents.SIGNEDURLSETPAGE(DECODEDDATA, RAWPAYLOAD)
%
%   Takes the two halves of the response rather than the ResponseMessage
%   itself, so a test can exercise it without constructing one: a
%   matlab.net.http.MessageBody's Payload is set by the framework, which makes
%   a synthetic response awkward to build and easy to get subtly wrong.
%
%   Inputs:
%       decodedData - The decoded response body (apiResponse.Body.Data): a
%                     struct with fields files, nextCursor and expiresAt.
%       rawPayload  - The raw response bytes (apiResponse.Body.Payload),
%                     retained by sending with HTTPOptions('SavePayload',true).
%                     Needed because JSONDECODE renames uid keys.
%
%   Outputs:
%       page - struct with fields:
%                files      - containers.Map from uid (char) to signed URL (char)
%                nextCursor - char cursor for the next page, '' when this was
%                             the last page
%                expiresAt  - char timestamp when the signed URLs expire, ''
%                             if the server did not supply one
%
%   See also: ndi.cloud.api.implementation.documents.signedURLFileMap

    arguments
        decodedData
        rawPayload
    end

    decodedFiles = [];
    if isstruct(decodedData) && isfield(decodedData, 'files')
        decodedFiles = decodedData.files;
    end

    page = struct();
    page.files = ndi.cloud.api.implementation.documents.signedURLFileMap(...
        decodedFiles, rawPayload);
    page.nextCursor = localCharField(decodedData, 'nextCursor');
    page.expiresAt  = localCharField(decodedData, 'expiresAt');
end

function value = localCharField(data, name)
    value = '';
    if isstruct(data) && isfield(data, name) && ~isempty(data.(name))
        v = data.(name);
        if isstring(v), v = char(v); end
        if ischar(v), value = v; end
    end
end
