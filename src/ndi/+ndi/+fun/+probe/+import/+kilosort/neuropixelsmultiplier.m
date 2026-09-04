function [multiplier, info] = neuropixelsmultiplier(probeType)
% NDI.FUN.PROBE.IMPORT.KILOSORT.NEUROPIXELSMULTIPLIER - int16 encode multiplier for a Neuropixels probe
%
% [MULTIPLIER, INFO] = NDI.FUN.PROBE.IMPORT.KILOSORT.NEUROPIXELSMULTIPLIER(PROBETYPE)
%
% Returns the encode multiplier that converts physical volts to the int16 counts
% stored in a raw SpikeGLX/Neuropixels AP-band recording, for the probe generation
% named by PROBETYPE. The decode used elsewhere in the importer is
%
%       volts = double(int16) / MULTIPLIER
%
% so MULTIPLIER is the reciprocal of the volts-per-bit scale factor. That scale is
% fixed by three probe-specific quantities,
%
%       volts_per_bit = Vmax / (Imax * gain),   MULTIPLIER = (Imax * gain) / Vmax
%
% which differ between Neuropixels generations:
%
%   PROBETYPE 'NP1' (Neuropixels 1.0): Vmax = 0.6 V, Imax = 512,  gain = 500
%       -> MULTIPLIER = (512  * 500) / 0.6  (~2.34 uV/bit; the SpikeGLX default
%          used throughout NDI, see ndi.fun.probe.export.all_binary)
%   PROBETYPE 'NP2' (Neuropixels 2.0): Vmax = 0.5 V, Imax = 8192, gain = 80
%       -> MULTIPLIER = (8192 * 80)  / 0.5  (~0.763 uV/bit)
%
% These assume the default AP-band gain for each generation. Recordings made at a
% non-default gain (the true value lives in the SpikeGLX '.meta' 'imroTbl') will
% need a scaled multiplier; the multiplier only sets the amplitude units of the
% recovered waveform and never affects its shape, so a wrong gain rescales but does
% not distort the spike shapes.
%
% PROBETYPE is matched case-insensitively and accepts a few common spellings:
%   'NP1', 'NP1.0', '1', 'neuropixels1', 'neuropixels 1.0'  -> Neuropixels 1.0
%   'NP2', 'NP2.0', '2', 'neuropixels2', 'neuropixels 2.0'  -> Neuropixels 2.0
%
% INFO is a struct with the underlying constants (Vmax, Imax, gain, uV_per_bit) and
% a canonical 'name' ('NP1' or 'NP2'), useful for reporting.
%
% See also: NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE, NDI.FUN.PROBE.EXPORT.ALL_BINARY

    arguments
        probeType (1,:) char
    end

    key = lower(strtrim(probeType));
    key(key==' ' | key=='.' | key=='_' | key=='-') = []; % 'NP 1.0' -> 'np10'

    switch key,
        case {'np1','np10','1','10','neuropixels1','neuropixels10'},
            canonical = 'NP1'; Vmax = 0.6; Imax = 512;  gain = 500;
        case {'np2','np20','2','20','neuropixels2','neuropixels20'},
            canonical = 'NP2'; Vmax = 0.5; Imax = 8192; gain = 80;
        otherwise,
            error('ndi:fun:probe:import:kilosort:neuropixelsmultiplier:badType', ...
                ['Unrecognized probe type ''%s''. Use ''NP1'' (Neuropixels 1.0) ' ...
                'or ''NP2'' (Neuropixels 2.0).'], probeType);
    end;

    multiplier = (Imax * gain) / Vmax;

    info = struct('name', canonical, 'Vmax', Vmax, 'Imax', Imax, ...
        'gain', gain, 'uV_per_bit', 1e6 / multiplier);

end
