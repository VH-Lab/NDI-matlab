function pathName = getPackageDir(packageName)
    s = what(strrep(packageName, '.', filesep));
    if isempty(s)
        error('No path was found for package "%s"', packageName)
    else
        pathName = s.path;
    end
end