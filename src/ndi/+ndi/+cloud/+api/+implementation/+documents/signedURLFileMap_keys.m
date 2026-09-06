function uids = signedURLFileMap_keys(rawPayload)
%SIGNEDURLFILEMAP_KEYS Extract the uid keys of the `files` object, in order.
%
%   UIDS = ndi.cloud.api.implementation.documents.SIGNEDURLFILEMAP_KEYS(RAWPAYLOAD)
%
%   Scans the raw JSON text of a signed-url-set response for the top-level
%   "files" object and returns its member names in the order they appear, as a
%   cell array of char. This exists because JSONDECODE renames object keys that
%   are not valid MATLAB identifiers, and a did.ido uid usually starts with a
%   digit; see ndi.cloud.api.implementation.documents.signedURLFileMap.
%
%   The scan is vectorized rather than a character loop. A signed URL set for a
%   lightsheet pyramid level can hold tens of thousands of entries (several MB
%   of JSON), and an interpreted per-character walk over that is seconds of
%   wall time per page.
%
%   It is a real JSON scan, not a regular expression: backslash escapes and
%   string state are tracked, so a brace, a quote, or the text `"files"`
%   appearing inside a signed URL cannot end the object early or be mistaken
%   for the member name.
%
%   Inputs:
%       rawPayload - The raw response payload, uint8 or char.
%
%   Outputs:
%       uids - Cell array of char uids, in payload order. Empty when the
%              payload has no top-level "files" object, the object is empty, or
%              the payload is malformed (unbalanced quotes or braces). The
%              caller compares this count against the decoded struct and errors
%              on a mismatch rather than mispairing uids with URLs.
%
%   See also: ndi.cloud.api.implementation.documents.signedURLFileMap

    arguments
        rawPayload
    end

    uids = {};

    if isempty(rawPayload)
        return
    end
    if isnumeric(rawPayload)
        txt = char(reshape(rawPayload, 1, []));
    elseif isstring(rawPayload)
        txt = char(rawPayload);
    elseif ischar(rawPayload)
        txt = reshape(rawPayload, 1, []);
    else
        return
    end

    n = numel(txt);
    if n == 0
        return
    end

    % --- Which quotes actually delimit strings? -------------------------
    % A quote is escaped when preceded by an odd number of backslashes.
    isBackslash = (txt == '\');
    runIndex = cumsum(isBackslash);
    runLength = runIndex - cummax(runIndex .* ~isBackslash);  % consecutive '\' ending at i
    precedingBackslashes = [0, runLength(1:end-1)];
    quotePos = find(txt == '"' & mod(precedingBackslashes, 2) == 0);

    if isempty(quotePos) || mod(numel(quotePos), 2) ~= 0
        return  % no strings, or a truncated payload
    end

    openQuote  = quotePos(1:2:end);
    closeQuote = quotePos(2:2:end);

    % --- Mask out everything inside string literals ---------------------
    marks = zeros(1, n+1);
    marks(openQuote) = 1;
    marks(closeQuote + 1) = marks(closeQuote + 1) - 1;
    inString = cumsum(marks(1:n)) > 0;   % true for quotes and their contents

    % --- Nesting depth, counting only structural braces ------------------
    delta = zeros(1, n);
    delta((txt == '{' | txt == '[') & ~inString) = 1;
    delta((txt == '}' | txt == ']') & ~inString) = -1;
    depth = cumsum(delta);   % depth AFTER the character at each index

    % --- Which strings are member names (followed by a colon)? -----------
    nextNonSpace = localNextNonSpace(txt, closeQuote);
    isName = nextNonSpace > 0;
    isName(isName) = txt(nextNonSpace(isName)) == ':';

    % --- Find the top-level "files" member and the '{' opening its value --
    filesBrace = [];
    rootNames = find(isName & depth(openQuote) == 1);   % members of the root object
    for k = rootNames
        if ~strcmp(txt(openQuote(k)+1 : closeQuote(k)-1), 'files')
            continue
        end
        afterColon = localNextNonSpace(txt, nextNonSpace(k));
        if afterColon > 0 && txt(afterColon) == '{'
            filesBrace = afterColon;
            break
        end
    end

    if isempty(filesBrace)
        return
    end

    % --- Delimit the object and collect its member names -----------------
    memberDepth = depth(filesBrace);            % depth inside the files object
    closeIdx = find(txt == '}' & ~inString & depth == memberDepth - 1 & ...
        (1:n) > filesBrace, 1, 'first');
    if isempty(closeIdx)
        return                                   % unbalanced payload
    end

    selected = isName & openQuote > filesBrace & closeQuote < closeIdx & ...
        depth(openQuote) == memberDepth;

    sel = find(selected);
    uids = cell(1, numel(sel));
    for i = 1:numel(sel)
        k = sel(i);
        uids{i} = txt(openQuote(k)+1 : closeQuote(k)-1);
    end
end

function idx = localNextNonSpace(txt, from)
%LOCALNEXTNONSPACE Index of the first non-whitespace character after each FROM.
%   Returns 0 where there is none. Vectorized over FROM: builds one
%   "next content character at or after i" lookup and indexes it, so the cost
%   is a pass over the payload rather than a scan per query.
    n = numel(txt);
    contentPos = find(~isspace(txt));

    atOrAfter = inf(1, n+1);
    atOrAfter(contentPos) = contentPos;
    atOrAfter = fliplr(cummin(fliplr(atOrAfter)));  % smallest content index >= i

    idx = zeros(size(from));
    valid = from >= 1 & from <= n;
    if ~any(valid)
        return
    end
    nextIdx = atOrAfter(from(valid) + 1);   % strictly after FROM
    nextIdx(isinf(nextIdx)) = 0;
    idx(valid) = nextIdx;
end
