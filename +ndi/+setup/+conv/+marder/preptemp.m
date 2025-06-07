function [out] = preptemp(t, d, temp_table, options)
    % PREPTEMP - identify temperature parameters for a temperature record
    %
    % OUT = PREPTEMP(T, D, TEMP_TABLE, ...)
    %
    % Identify the temperature of a Marder lab record. The timestamps of the
    % record are provided in T, and the data in degrees C are provided in
    % D.
    %
    % The program attempts to identify which of several command temperatures
    % in TEMP_TABLE are employed in the record.
    %
    % The record is categorized as 'constant' or 'change' if the record exhibits
    % a change greater than 'change_threshold'.
    %
    % OUT is a structure with fields:
    %   'type':  takes the value 'constant or 'change'
    %   'temp': that contains the values in TEMP_TABLE that most closely match
    %           the record. In the case of a 'constant' record,
    %           'temp' will have one value; in the case of a 'change' record,
    %           it will have two values (the beginning and end values).
    %   'raw':  the raw temperature values before they are translated to
    %           table entries.
    % 'range':  the observed temperature range
    %
    %
    % The function takes name/value pairs that modify its default behavior:
    % |----------------------------|--------------------------------------|
    % | Parameter (default)        | Description                          |
    % |----------------------------|--------------------------------------|
    % | change_threshold (3)       | Threshold at which to describe the   |
    % |                            |   record as a 'change'.              |
    % | beginning_time (2)         | Time in seconds that constitutes the |
    % |                            |   beginning of the record.           |
    % | ending_time (2)            | Time in seconds from the end of the  |
    % |                            |   record that constitutes the ending |
    % |                            |   time to be averaged.               |
    % | filter ( ones(5,1)/5 )     | A convolution filter to smooth data  |
    % | interactive (false)        | Should we ask the user for input?    |
    % |----------------------------|--------------------------------------|
    %
    %

    arguments
        t
        d
        temp_table
        options.change_threshold = 3
        options.beginning_time = 2
        options.ending_time = 2
        options.filter = ones(5,1)/5;
        options.interactive = false
    end

    % filter the signal

    fs = numel(options.filter);
    pad0 = repmat(d(1),fs,1);
    pad1 = repmat(d(end),fs,1);

    filtered_signal = conv( [pad0; d(:); pad1], options.filter,'same');
    filtered_signal = filtered_signal(fs+1:end-fs);

    range = max(filtered_signal(:)) - min(filtered_signal(:));

    if range<options.change_threshold
        type = 'constant';
        raw = mean(filtered_signal);
        [i,temp] = vlt.data.findclosest(temp_table,raw);
    else
        type = 'change';
        i0 = find(t<=options.beginning_time);
        i1 = find(t>=(t(end)-options.ending_time));
        i1(i1>numel(filtered_signal)) = [];
        raw = [ mean(filtered_signal(i0)) mean(filtered_signal(i1)) ];
        [i,temp0] = vlt.data.findclosest(temp_table,raw(1));
        [i,temp1] = vlt.data.findclosest(temp_table,raw(2));
        temp = [ temp0 temp1 ];
    end;

    out = vlt.data.var2struct('type','temp','raw','range');
