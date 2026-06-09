function all_binary(S, options)
% NDI.FUN.PROBE.EXPORT.ALL_BINARY - export NDI probes to binary format
%
% NDI.FUN.PROBE.EXPORT.ALL_BINARY(S, ...)
%
% Exports probe data from ndi in a format useable by external tools like Kilosort.
%
% Creates a folder 'kilosort' (by default) in the path of the ndi.session object S.
% A subdirectory with the name of each probe is created, and the raw data from
% the probe in binary format is stored as 'kilosort.bin' (by default).
%
% Direction of the multiplier: the multiplier is applied in the ENCODE
% direction, converting the physical data returned by the probe into the
% int16 values written to disk:
%
%       int16_written = multiplier * physical_data
%
% so the multiplier is the RECIPROCAL of the scale factor that converts the
% stored int16 back to physical units. The default (1/0.195) assumes Intan
% data, whose int16 decode to microvolts via uV = int16 * 0.195.
%
% For SpikeGLX/Neuropixels data, the stored int16 decode to volts via
%
%       volts = double(int16) * 0.6 / (512 * 500)
%
% so the correct encode multiplier to pass is the reciprocal:
%
%       'multiplier', (512 * 500) / 0.6
%
% This function's parameters can be modified by passing name/value pairs:
% --------------------------------------------------------------------------
% | Parameter (default) | Description                                      |
% |---------------------|--------------------------------------------------|
% | binary_dir          | Name of output directory                         |
% |  ('kilosort')       |                                                  |
% | binaryFileName      | Name of the binary file written in each probe's  |
% |  ('kilosort.bin')   |   subdirectory. (Kilosort/phy do not require a   |
% |                     |   particular name.)                              |
% | verbose (1)         | 0/1 Should we be verbose?                        |
% | multiplier(1/0.195) | Encode multiplier: int16 = multiplier*physical.  |
% |                     |   = 1/(physical-per-int16 decode factor).        |
% |                     |   Default 1/0.195 assumes Intan (uV) data. For   |
% |                     |   SpikeGLX use (512*500)/0.6.                    |
% | noBinary (false)    | If true, create the per-probe subdirectories and |
% |                     |   write only the '.metadata' files; do not write |
% |                     |   the binary files. Useful for setting up the    |
% |                     |   folder structure and epoch/sample metadata     |
% |                     |   when the spike-sorted data already exist       |
% |                     |   (e.g. from SpikeGLX) and you intend to drop    |
% |                     |   your own kilosort/phy files into each probe    |
% |                     |   subdirectory for import.                       |
% |---------------------|--------------------------------------------------|
%
%
% Example:
%
% prefix = '/Volumes/van-hooser-lab/Projects/Vikko_Laminar_Organization/Analyzed';
% expnames = {'2022-01-05'}; % just one experiment for now
% for i=1:numel(expnames),
%    S = ndi.session.dir([prefix filesep expnames{i}]);
%    ndi.fun.probe.export.all_binary(S,'verbose',1);
% end;
%
% Example (set up folders and metadata only, no binary):
%    ndi.fun.probe.export.all_binary(S,'noBinary',true);
%

    arguments
        S
        options.binary_dir (1,:) char = 'kilosort'
        options.binaryFileName (1,:) char = 'kilosort.bin'
        options.verbose (1,1) double = 1
        options.multiplier (1,1) double = 1/0.195
        options.noBinary (1,1) logical = false
    end

    binary_dir = options.binary_dir;
    binaryFileName = options.binaryFileName;
    verbose = options.verbose;
    multiplier = options.multiplier;
    noBinary = options.noBinary;

    if verbose,
        disp(['About to look for probes in ' S.reference]);
    end;
    probe_list = S.getprobes('type','n-trode');

    if verbose,
        disp(['Found ' int2str(numel(probe_list)) ' probe(s) of type ''n-trode''.']);
    end;

    binary_path = [S.path filesep binary_dir];
    if ~isfolder(binary_path),
        mkdir(binary_path);
    end;

    for p=1:numel(probe_list),
        elestr = probe_list{p}.elementstring();
        if verbose,
            disp(['Now working on probe ' elestr '.']);
        end;
        elestr(find(elestr==' ')) = '_';
        this_path = [binary_path filesep elestr];
        if ~isfolder(this_path),
            mkdir(this_path);
        end;
        outfile = [this_path filesep binaryFileName];
        ndi.fun.probe.export.binary(probe_list{p}, outfile, 'verbose',verbose,'multiplier',multiplier,'noBinary',noBinary);
    end;

    if verbose,
        disp(['Done processing ' S.reference]);
    end;
end
