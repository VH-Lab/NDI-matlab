function mult = autoMultiplier(probe)
% NDI.FUN.PROBE.EXPORT.AUTOMULTIPLIER - pick a sensible int16 encode multiplier for a probe
%
% MULT = NDI.FUN.PROBE.EXPORT.AUTOMULTIPLIER(PROBE)
%
% Returns an encode multiplier for ndi.fun.probe.export.binary / .all_binary
% (which write int16 = MULT * physical) chosen from what PROBE.readtimeseries
% actually returns for a short stretch at the start of the first epoch:
%
%   * If the probe returns raw ADC counts, the data are already int16-style, so
%     MULT = 1 passes them through losslessly. Counts are recognized either by an
%     integer class (e.g. int16) or by floating-point values that are all whole
%     numbers (e.g. SpikeGLX counts returned as double).
%   * Otherwise (floating-point physical units) MULT = 1/0.195, the Intan
%     microvolt-to-int16 default used by ndi.fun.probe.export.all_binary.
%
% If the stretch read is entirely zero the check is inconclusive and the
% floating-point default is returned.
%
% The floating-point default assumes Intan (uV) data; for SpikeGLX/Neuropixels
% recordings returned in volts you must instead pass 'multiplier', (512*500)/0.6
% explicitly. When in doubt, check a sample: [d,~] = probe.readtimeseries(...);
% class(d) and the magnitude of d tell you which case you are in.
%
% See also: NDI.FUN.PROBE.EXPORT.BINARY, NDI.FUN.PROBE.EXPORT.ALL_BINARY,
%   NDI.FUN.PROBE.EXPORT.ONEPROBE

    mult = 1/0.195; % Intan uV default (floating-point physical data)
    n_check = 100; % number of samples to examine
    try
        et = probe.epochtable();
        if isempty(et),
            return;
        end;
        t0 = et(1).t0_t1{1}(1);
        try
            t1 = min(t0 + (n_check-1)/probe.samplerate(et(1).epoch_id), et(1).t0_t1{1}(2));
        catch
            t1 = t0; % no sample rate available: examine a single sample
        end
        [d,~] = probe.readtimeseries(et(1).epoch_id, t0, t1);
        if isinteger(d)
            mult = 1; % already int16-style counts: pass through unchanged
            return
        end
        d = d(isfinite(d));
        if ~isempty(d) && any(d~=0) && all(d==round(d))
            mult = 1; % whole-number counts stored as floating point
        end
    catch
        % leave the default if we cannot sample the probe
    end
end
