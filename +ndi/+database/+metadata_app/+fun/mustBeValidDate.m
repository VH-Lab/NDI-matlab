function mustBeValidDate(value)

    if ~isempty(value)
        matchedPattern = regexp(value, '^\d{4}\-(0[1-9]|1[012])\-(0[1-9]|[12][0-9]|3[01])$', 'match');
        isValid = ~isempty(matchedPattern);
        if ~isValid()
            error('"%s" is not a valid email adress', value)
        end
    end
end

