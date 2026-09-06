function page = signedURLSetPage(apiResponse)
%SIGNEDURLSETPAGE Turn a signed-url-set HTTP response into a page struct.
%
%   PAGE = ndi.cloud.api.implementation.documents.SIGNEDURLSETPAGE(APIRESPONSE)
%
%   Inputs:
%       apiResponse - A matlab.net.http.ResponseMessage from the
%                     signed-url-set endpoint, sent with
%                     HTTPOptions('SavePayload', true) so the raw uid keys are
%                     still available.
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
        apiResponse
    end

    data = apiResponse.Body.Data;

    decodedFiles = [];
    if isstruct(data) && isfield(data, 'files')
        decodedFiles = data.files;
    end

    page = struct();
    page.files = ndi.cloud.api.implementation.documents.signedURLFileMap(...
        decodedFiles, apiResponse.Body.Payload);
    page.nextCursor = localCharField(data, 'nextCursor');
    page.expiresAt  = localCharField(data, 'expiresAt');
end

function value = localCharField(data, name)
    value = '';
    if isstruct(data) && isfield(data, name) && ~isempty(data.(name))
        v = data.(name);
        if isstring(v), v = char(v); end
        if ischar(v), value = v; end
    end
end
