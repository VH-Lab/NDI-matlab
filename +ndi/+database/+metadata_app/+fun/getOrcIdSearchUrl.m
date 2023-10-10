function apiQueryUrl = getOrcIdSearchUrl(name)
    name = urlencode(name);
    apiQueryUrl = sprintf('https://ror.org/search?query=%s', name);
end