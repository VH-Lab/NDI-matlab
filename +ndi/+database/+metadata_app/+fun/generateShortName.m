function shortName = generateShortName(FullName, length)
    
    words = strsplit(FullName, ' ');
    if numel(words) <= length
        shortName = fullName;
    else
        shortName = strjoin(words(1:length), ' ');
    end
end

