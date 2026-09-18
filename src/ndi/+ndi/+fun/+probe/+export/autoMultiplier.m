function mult = autoMultiplier(probe)
% NDI.FUN.PROBE.EXPORT.AUTOMULTIPLIER - pick a sensible int16 encode multiplier for a probe
%
% MULT = NDI.FUN.PROBE.EXPORT.AUTOMULTIPLIER(PROBE)
%
% Returns an encode multiplier for ndi.fun.probe.export.binary / .all_binary
% (which write int16 = MULT * physical) chosen from what PROBE.readtimeseries
% actually returns:
%
%   * If the probe returns integer-class samples (e.g. int16 raw ADC counts), the
%     data are already int16, so MULT = 1 passes them through losslessly.
%   * Otherwise (floating-point physical units) MULT = 1/0.195, the Intan
%     microvolt-to-int16 default used by ndi.fun.probe.export.all_binary.
%
% The floating-point default assumes Intan (uV) data; for SpikeGLX/Neuropixels
% recordings returned in volts you must instead pass 'multiplier', (512*500)/0.6
% explicitly. When in doubt, check a sample: [d,~] = probe.readtimeseries(...);
% class(d) and the magnitude of d tell you which case you are in.
%
% See also: NDI.FUN.PROBE.EXPORT.BINARY, NDI.FUN.PROBE.EXPORT.ALL_BINARY,
%   NDI.FUN.PROBE.EXPORT.ONEPROBE

    mult = 1/0.195; % Intan uV default (floating-point physical data)
    try
        et = probe.epochtable();
        if isempty(et),
            return;
        end;
        t0 = et(1).t0_t1{1}(1);
        [d,~] = probe.readtimeseries(et(1).epoch_id, t0, t0);
        if isinteger(d),
            mult = 1; % already int16-style counts: pass through unchanged
        end;
    catch
        % leave the default if we cannot sample the probe
    end
end
