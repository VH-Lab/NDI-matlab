function cache = getCache()

    persistent cachedCache
    if isempty(cachedCache)
        cachedCache = ndi.cache();
    end
    cache = cachedCache;
end
