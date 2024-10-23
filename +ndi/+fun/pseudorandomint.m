function t = pseudorandomint()
    % ndi.fun.pseudorandomint - generate a random integer based on the date and time and a random number
    %
    % T = ndi.fun.pseudorandomint()
    %
    % Generates a pseudorandom integer that is linked to the current date/time.
    %
    % Generates 1000 possible numbers for each second. The portion of the
    % number greater than 1000 is deterministic based on the date (works
    % through the year 2200 at least).
    %
    % Example:
    %    t = ndi.fun.pseudorandomint()

    t_offset = datenum(now) - datenum('2022-06-01');
    t_offset = fix(t_offset * 24*60*60); % number of seconds
    t = t_offset*1000 + randi(1000) -1; % number of seconds * 1000 + random number between 1 and 1000, -1
