function s = status(S, probe, options)
% NDI.FUN.PROBE.IMPORT.KIASORT.STATUS - KIASORT export/run/curate status for a probe
%
% S = NDI.FUN.PROBE.IMPORT.KIASORT.STATUS(S_SESSION, PROBE, ...)
%
% Reports where PROBE stands in the KIASORT pipeline for the ndi.session S_SESSION,
% by checking for the files each step produces. Returns a struct S with fields:
%
%   directory        - [S.path]/[kiasort_dir]/[probe_directory]
%
%   The [probe_directory] name comes from ndi.fun.file.elementDirectoryName;
%   for a probe named 'ctx' with reference 1 it is 'ctx_-_1'. Folders written
%   by older versions of NDI, which used a '|' separator ('ctx_|_1'), are still
%   found and used if they are present.
%
%   output_directory - the KIASORT output subfolder (holds RES_Sorted)
%   exported         - true if the exported binary exists (ready to run)
%   run              - true if KIASORT results exist (RES_Sorted/spike_idx.h5)
%   curated          - true if curated results exist (spike_idx_curated.h5)
%
% This centralizes the pipeline-status logic so GUIs (e.g. ndi.gui.app.kiasort)
% stay thin wrappers over ndi.fun.probe.*.
%
% Name/value pairs:
%   kiasort_dir ('kiasort')        - directory (within S.path) of the export/output.
%   binaryFileName ('kiasort.bin') - the exported binary in the probe's folder.
%   subdir ('kiasort_output')      - the KIASORT output subfolder.
%
% See also: NDI.FUN.PROBE.IMPORT.KIASORT.RUN, NDI.FUN.PROBE.IMPORT.KIASORT.CURATE,
%   NDI.FUN.PROBE.EXPORT.ONEPROBE

    arguments
        S
        probe
        options.kiasort_dir (1,:) char = 'kiasort'
        options.binaryFileName (1,:) char = 'kiasort.bin'
        options.subdir (1,:) char = 'kiasort_output'
    end

    d = ndi.fun.file.elementDirectory(fullfile(S.path, options.kiasort_dir), probe);
    res = fullfile(d, options.subdir, 'RES_Sorted');

    s = struct();
    s.directory        = d;
    s.output_directory = fullfile(d, options.subdir);
    s.exported         = isfile(fullfile(d, options.binaryFileName));
    s.run              = isfile(fullfile(res, 'spike_idx.h5'));
    s.curated          = isfile(fullfile(res, 'spike_idx_curated.h5'));
end
