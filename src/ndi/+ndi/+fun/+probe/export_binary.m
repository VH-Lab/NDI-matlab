function export_binary(probe, outputfile)
% NDI.FUN.PROBE.EXPORT_BINARY - export data from a probe to an int16 binary file
%
% NDI.FUN.PROBE.EXPORT_BINARY(PROBE, OUTPUTFILE, ...)
%
% Exports data from a PROBE (or ndi.element) of type n-trode to an
% int16 binary file OUTPUTFILE.  Before converting to int16, the data
% are scaled by a multiplier (see below). A text metadata file is created
% with the same filename as OUTPUTFILE with extension '.metadata'.
%
% This function's parameters can be modified by passing name/value pairs:
% --------------------------------------------------------------------------
% | Parameter (default) | Description                                      |
% |---------------------|--------------------------------------------------|
% | multiplier (1)      | Multiplier value                                 |
% | verbose (1)         | 0/1 Should we be verbose?                        |
% | precision('int16')  | What output precision?
% |---------------------|--------------------------------------------------|
%

    arguments
        probe
        outputfile (1,:) char
        options.multiplier (1,1) double = 1
        options.verbose (1,1) double = 1
        options.precision (1,:) char = 'int16'
    end

    % set up parameters
    multiplier = options.multiplier;
    verbose = options.verbose;
    precision = options.precision;

    % now begin
    et = probe.epochtable();

    metafile = [outputfile '.metadata'];

    epoch_sample_counts = [];
    epoch_sample_rates = [];

    chunk_duration = 100; % read N second chunks

    fid = fopen(outputfile,'w','ieee-le'); % little endian, assume is needed
    if fid<0,
        error(['Unable to open ' outputfile ' for writing.']);
    end;

    for e=1:numel(et),
        if verbose,
            disp(['Processing epoch ' int2str(e) ' of ' int2str(numel(et)) '.']);
        end;
        samples_here = probe.times2samples(et(e).epoch_id, et(e).t0_t1{1});
        epoch_sample_counts(e) = samples_here(2) - samples_here(1) + 1; % total sample count for epoch e
        epoch_sample_rates(e) = probe.samplerate(et(e).epoch_id);
        single_sample_time_here = 1/epoch_sample_rates(e);

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

    fclose(fid);

    probe_name = probe.elementstring;

    metastructure = vlt.data.var2struct('epoch_sample_counts','epoch_sample_rates','multiplier','num_channels','probe_name');

    vlt.file.saveStructArray(metafile, metastructure);
end
