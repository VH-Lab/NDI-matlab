function doi = createNewDOI()
% createNewDOI - Create a doi string using a random and opaque DOI Suffix
    randomSuffix = generateRandomDOISuffix();
    doiSuffix = sprintf('ndic.%d.%s', year(datetime("now")), randomSuffix);

    ndiPrefix = ndi.cloud.admin.crossref.Constants.DOIPrefix;
    doi = sprintf('%s/%s', ndiPrefix, doiSuffix);
end

function suffix = generateRandomDOISuffix(len)
%GENERATERANDOMDOISUFFIX Generate a random DOI suffix of specified length.
%   suffix = generateRandomDOISuffix(len) returns a random string of
%   lowercase letters and digits with the given length (default 8).

    if nargin < 1
        len = 8;  % Default length
    end

    chars = ['a':'z', '0':'9'];
    idx = randi(numel(chars), 1, len);
    suffix = chars(idx);
end