function status = oneProbe(S, probe, options)
% NDI.FUN.PROBE.EXPORT.ONEPROBE - export a single probe's data + channel map for a sorter
%
% STATUS = NDI.FUN.PROBE.EXPORT.ONEPROBE(S, PROBE, ...)
%
% Exports one PROBE of the ndi.session S to the flat int16 binary format used by
% Kilosort / KIASORT, writing (per probe) into
%
%       [S.path]/[binary_dir]/[probe_elementstring]/[binaryFileName]
%
% and, unless disabled, a Kilosort-style 'channel_map.mat' alongside it built from
% the probe's assigned electrode geometry (ndi.fun.probe.geometry.toKilosortMap). If
% the probe has no geometry, a default single-column linear map is written instead
% (ndi.fun.probe.geometry.writeKilosortMap) and STATUS.hadGeometry is false.
%
% This is the single-probe building block behind the Electrode Data Export GUI; it
% complements ndi.fun.probe.export.all_binary, which exports every n-trode probe at
% once with a fixed multiplier.
%
% The int16 encode multiplier defaults to ndi.fun.probe.export.autoMultiplier(PROBE)
% (1 for integer-class data, 1/0.195 for floating-point uV data). Pass 'multiplier'
% to override (e.g. (512*500)/0.6 for SpikeGLX volts).
%
% Name/value pairs:
% ---------------------------------------------------------------------------------
% | Parameter (default)     | Description                                          |
% |-------------------------|------------------------------------------------------|
% | binary_dir ('kiasort')  | Directory (within S.path) to export into.            |
% | binaryFileName          | Name of the binary file in the probe's subfolder.    |
% |  ('kiasort.bin')        |                                                      |
% | multiplier ([])         | int16 = multiplier*physical. [] = auto-detect.       |
% | channelMap (true)       | Also write channel_map.mat (from geometry, else a    |
% |                         |   linear placeholder).                               |
% | verbose (1)             | 0/1 Should we be verbose?                            |
% ---------------------------------------------------------------------------------
%
% STATUS is a struct with fields:
%   binaryFile      - the binary file written
%   multiplier      - the multiplier used
%   channelMapFile  - the channel_map.mat written ('' if none)
%   hadGeometry     - true if the channel map came from an assigned geometry
%
% See also: NDI.FUN.PROBE.EXPORT.ALL_BINARY, NDI.FUN.PROBE.EXPORT.BINARY,
%   NDI.FUN.PROBE.EXPORT.AUTOMULTIPLIER, NDI.FUN.PROBE.GEOMETRY.TOKILOSORTMAP

    arguments
        S
        probe
        options.binary_dir (1,:) char = 'kiasort'
        options.binaryFileName (1,:) char = 'kiasort.bin'
        options.multiplier double = []
        options.channelMap (1,1) logical = true
        options.progressfcn = []
        options.verbose (1,1) double = 1
    end

    elestr = probe.elementstring();
    elestr(elestr==' ') = '_';
    probedir = fullfile(S.path, options.binary_dir, elestr);
    if ~isfolder(probedir),
        mkdir(probedir);
    end;
    binaryfile = fullfile(probedir, options.binaryFileName);

    mult = options.multiplier;
    if isempty(mult),
        mult = ndi.fun.probe.export.autoMultiplier(probe);
    end;

    ndi.fun.probe.export.binary(probe, binaryfile, 'multiplier', mult, ...
        'verbose', options.verbose, 'progressfcn', options.progressfcn);

    status = struct('binaryFile', binaryfile, 'multiplier', mult, ...
        'channelMapFile', '', 'hadGeometry', false);

    if options.channelMap,
        cmf = fullfile(probedir, 'channel_map.mat');
        tf = ndi.fun.probe.geometry.toKilosortMap(S, probe, cmf, 'verbose', options.verbose);
        status.hadGeometry = tf;
        if ~tf,
            % no geometry on file: write a linear placeholder if we know the channel count
            nch = ndi.fun.probe.channelCount(probe);
            if ~isempty(nch),
                ndi.fun.probe.geometry.writeKilosortMap(cmf, 'num_channels', nch, ...
                    'verbose', options.verbose);
            end;
        end;
        if isfile(cmf),
            status.channelMapFile = cmf;
        end;
    end;
end
