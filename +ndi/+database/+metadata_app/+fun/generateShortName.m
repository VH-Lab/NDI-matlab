function shortName = generateShortName(fullName, length)
    
    words = strsplit(fullName, ' ');
    if numel(words) <= length
        shortName = fullName;
    else
        shortName = strjoin(words(1:length), ' ');
    end
end

