function [prefix,number] = channelname2prefixnumber(channelname)
    % CHANNELNAME2PREFIXNUMBER - identify the prefix, number from channel name string
    %
    % [PREFIX, NUMBER] = CHANNELNAME2PREFIXNUMBER(CHANNELNAME)
    %
    % Given a channel name like 'ai5', return the prefix (in this case 'ai')
    % and the number (in this case, 5) as PREFIX and NUMBER, respectively.
    %
    % Example:
    %  [prefix,number] = ndi.fun.channelname2prefixnumber('ai5')
    %   % prefix == 'ai', number == 5

    if ~(isa(channelname,'char') | isa(channelname,'string')),
        error(['channelname must be a character array or a string.']);
    end;

    channelname = char(channelname);

    numeric_chars = find(channelname>=char('0') & channelname<=char('9'));

    if isempty(numeric_chars),
        error(['No numeric characters found for string ' channelname '.']);
    end;

    if numeric_chars(1)==1,
        error(['No non-numeric characters found at prefix.']);
    end;

    prefix = channelname(1:numeric_chars(1)-1);

    prefix = strtrim(prefix); % remove whitespace

    number = str2num(channelname(numeric_chars(1:end)));


