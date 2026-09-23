function binary(probe, outputfile, options)
% NDI.FUN.PROBE.EXPORT.BINARY - export data from a probe to an int16 binary file
%
% NDI.FUN.PROBE.EXPORT.BINARY(PROBE, OUTPUTFILE, ...)
%
% Exports data from a PROBE (or ndi.element) of type n-trode to an
% int16 binary file OUTPUTFILE.  Before converting to int16, the data
% are scaled by a multiplier (see below). A text metadata file is created
% with the same filename as OUTPUTFILE with extension '.metadata'.
%
% Direction of the multiplier: the multiplier is applied in the ENCODE
% direction, converting the physical data returned by the probe into the
% int16 values that are written to disk:
%
%       int16_written = multiplier * physical_data
%
% It is therefore the RECIPROCAL of the scale factor that converts the stored
% int16 values back to physical units. For example, for Intan data the stored
% int16 decode to microvolts via uV = int16 * 0.195, so the encode multiplier
% is 1/0.195 (the default in ndi.fun.probe.export.all_binary).
%
% This function's parameters can be modified by passing name/value pairs:
% --------------------------------------------------------------------------
% | Parameter (default) | Description                                      |
% |---------------------|--------------------------------------------------|
% | multiplier (1)      | Encode multiplier: int16 = multiplier*physical.  |
% |                     |   = 1/(physical-per-int16 decode factor).        |
% | verbose (1)         | 0/1 Should we be verbose?                        |
% | precision('int16')  | What output precision?                           |
% | noBinary (false)    | If true, write only the '.metadata' file and do  |
% |                     |   not write the binary OUTPUTFILE. Useful when   |
% |                     |   the spike-sorted data already exist (e.g. from |
% |                     |   SpikeGLX) and only the epoch/sample metadata   |
% |                     |   are needed to set up an import.                |
% | progressfcn ([])    | Optional handle f(pct,msg) called after each     |
% |                     |   chunk is written; pct in [0,1] over all epochs.|
% |---------------------|--------------------------------------------------|
%

    arguments
        probe
        outputfile (1,:) char
        options.multiplier (1,1) double = 1
        options.verbose (1,1) double = 1
        options.precision (1,:) char = 'int16'
        options.noBinary (1,1) logical = false
        options.progressfcn = []
    end

    % set up parameters
    multiplier = options.multiplier;
    verbose = options.verbose;
    precision = options.precision;
    noBinary = options.noBinary;
    progressfcn = options.progressfcn;

    % now begin
    et = probe.epochtable();

    metafile = [outputfile '.metadata'];

    epoch_sample_counts = [];
    epoch_sample_rates = [];
    num_channels = [];

    chunk_duration = 100; % read N second chunks

    % total chunk count across all epochs, for the progress fraction
    total_chunks = 0;
    if ~noBinary && ~isempty(progressfcn),
        for e=1:numel(et),
            ct = et(e).t0_t1{1}(1):chunk_duration:et(e).t0_t1{1}(2);
            total_chunks = total_chunks + numel(ct);
        end;
        if total_chunks<1, total_chunks = 1; end;
    end;
    done_chunks = 0;

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
            done_chunks = done_chunks + 1;
            if ~isempty(progressfcn),
                progressfcn(done_chunks/total_chunks, ...
                    sprintf('epoch %d/%d, chunk %d/%d', e, numel(et), c, numel(chunk_times)));
            end;
        end;
    end;

    if ~noBinary,
        fclose(fid);
    end;

    probe_name = probe.elementstring;

    metastructure = vlt.data.var2struct('epoch_sample_counts','epoch_sample_rates','multiplier','num_channels','probe_name');

    vlt.file.saveStructArray(metafile, metastructure);
end
