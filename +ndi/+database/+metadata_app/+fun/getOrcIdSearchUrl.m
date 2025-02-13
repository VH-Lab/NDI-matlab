function apiQueryUrl = getOrcIdSearchUrl(name)
    name = urlencode(name);
    apiQueryUrl = sprintf('https://orcid.org/orcid-search/search?searchQuery=%s', name);
end
