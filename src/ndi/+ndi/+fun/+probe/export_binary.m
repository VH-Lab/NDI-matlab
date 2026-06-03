function export_binary(probe, outputfile, options)
% NDI.FUN.PROBE.EXPORT_BINARY - export data from a probe to an int16 binary file
%
% NDI.FUN.PROBE.EXPORT_BINARY(PROBE, OUTPUTFILE, ...)
%
% Exports data from a PROBE (or ndi.element) of type n-trode to an
% int16 binary file OUTPUTFILE.  Before converting to int16, the data
% are scaled by a multiplier (see below). A tab-delimited text metadata file
% is created with the same filename as OUTPUTFILE with extension '.metadata'
% (written with ndi.util.saveStructArray, readable with ndi.util.loadStructArray).
% The metadata file has one row per epoch with columns 'epoch',
% 'epoch_sample_counts', and 'epoch_sample_rates', plus the scalar values
% 'multiplier', 'num_channels', and 'probe_name' repeated on each row.
%
% This function's parameters can be modified by passing name/value pairs:
% --------------------------------------------------------------------------
% | Parameter (default) | Description                                      |
% |---------------------|--------------------------------------------------|
% | multiplier (1)      | Multiplier value                                 |
% | verbose (1)         | 0/1 Should we be verbose?                        |
% | precision('int16')  | What output precision?                           |
% | noBinary (false)    | If true, write only the '.metadata' file and do  |
% |                     |   not write the binary OUTPUTFILE. Useful when   |
% |                     |   the spike-sorted data already exist (e.g. from |
% |                     |   SpikeGLX) and only the epoch/sample metadata   |
% |                     |   are needed to set up an import.                |
% |---------------------|--------------------------------------------------|
%

    arguments
        probe
        outputfile (1,:) char
        options.multiplier (1,1) double = 1
        options.verbose (1,1) double = 1
        options.precision (1,:) char = 'int16'
        options.noBinary (1,1) logical = false
    end

    % set up parameters
    multiplier = options.multiplier;
    verbose = options.verbose;
    precision = options.precision;
    noBinary = options.noBinary;

    % now begin
    et = probe.epochtable();

    metafile = [outputfile '.metadata'];

    epoch_sample_counts = [];
    epoch_sample_rates = [];
    num_channels = [];

    chunk_duration = 100; % read N second chunks

    if ~noBinary,
        fid = fopen(outputfile,'w','ieee-le'); % little endian, assume is needed
        if fid<0,
            error(['Unable to open ' outputfile ' for writing.']);
        end;
    end;

    for e=1:numel(et),
        if verbose,
            disp(['Processing epoch ' int2str(e) ' of ' int2str(numel(et)) '.']);
        end;
        samples_here = probe.times2samples(et(e).epoch_id, et(e).t0_t1{1});
        epoch_sample_counts(e) = samples_here(2) - samples_here(1) + 1; % total sample count for epoch e
        epoch_sample_rates(e) = probe.samplerate(et(e).epoch_id);
        single_sample_time_here = 1/epoch_sample_rates(e);

        if noBinary,
            % we still need the channel count for the metadata; read a single
            % sample (cheap) rather than the whole epoch, and write no binary
            if isempty(num_channels),
                t0 = et(e).t0_t1{1}(1);
                [data,t] = probe.readtimeseries(et(e).epoch_id, t0, t0);
                num_channels = size(data,2);
            end;
            continue;
        end;

        chunk_times = et(e).t0_t1{1}(1):chunk_duration:et(e).t0_t1{1}(2);
        for c = 1:numel(chunk_times),
            if verbose,
                disp(['  Processing epoch ' int2str(e) ', chunk ' int2str(c) ' of ' int2str(numel(chunk_times)) '.']);
            end;
            start_time = chunk_times(c);
            end_time = min(chunk_times(c) + chunk_duration - single_sample_time_here, et(e).t0_t1{1}(2));
            [data,t] = probe.readtimeseries(et(e).epoch_id, start_time, end_time);
            num_channels = size(data,2);
            fwrite(fid, multiplier*data', precision);
        end;
    end;

    if ~noBinary,
        fclose(fid);
    end;

    probe_name = probe.elementstring;

    % Write the metadata as a tab-delimited file with one row per epoch (the
    % per-epoch sample counts and rates), with the scalar fields (multiplier,
    % num_channels, probe_name) repeated on each row so the file round-trips
    % cleanly through ndi.util.loadStructArray.
    nE = numel(epoch_sample_counts);
    metastructure = struct('epoch', num2cell(1:nE), ...
        'epoch_sample_counts', num2cell(epoch_sample_counts), ...
        'epoch_sample_rates', num2cell(epoch_sample_rates), ...
        'multiplier', repmat({multiplier},1,nE), ...
        'num_channels', repmat({num_channels},1,nE), ...
        'probe_name', repmat({probe_name},1,nE));

    ndi.util.saveStructArray(metafile, metastructure);
end
