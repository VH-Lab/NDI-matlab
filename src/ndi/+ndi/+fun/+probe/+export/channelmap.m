function channelmap(outputfile, options)
% NDI.FUN.PROBE.EXPORT.CHANNELMAP - write a Kilosort-style channel map for KIASORT
%
% NDI.FUN.PROBE.EXPORT.CHANNELMAP(OUTPUTFILE, ...)
%
% Writes a channel-map .mat file OUTPUTFILE in the Kilosort convention. KIASORT's
% load_channel_map accepts exactly this convention (chanMap / chanMap0ind,
% connected, xcoords, ycoords, optional kcoords), so this file can be passed to
% run_kiasort_nogui(..., channelMapFile, ...) or selected in the KIASORT GUI to
% describe the geometry of an exported probe.
%
% The number of channels is taken from OPTIONS.num_channels, or read from the
% '.metadata' sidecar written by ndi.fun.probe.export.binary when
% OPTIONS.metadataFile is given (or when OUTPUTFILE sits next to a 'kilosort.bin' /
% 'kiasort.bin' with a '.metadata' file).
%
% By default a simple single-column linear geometry is written (xcoords all 0,
% ycoords spaced by OPTIONS.spacing microns, all channels connected). This is a
% reasonable placeholder that lets KIASORT run; for best sorting, pass the real
% probe geometry via OPTIONS.xcoords / OPTIONS.ycoords (and OPTIONS.kcoords for
% multi-shank probes). A warning is issued when the default linear geometry is used.
%
% Name/value pairs:
% ---------------------------------------------------------------------------------
% | Parameter (default) | Description                                              |
% |---------------------|----------------------------------------------------------|
% | num_channels ([])   | Number of channels. If empty, read from metadataFile.    |
% | metadataFile ('')   | Path to a '.metadata' sidecar to read num_channels from. |
% |                     |   If '' and num_channels is empty, this function looks    |
% |                     |   for '<OUTPUTFILE dir>/kiasort.bin.metadata' then        |
% |                     |   'kilosort.bin.metadata'.                               |
% | chanMap ([])        | 1-based channel map (default 1:num_channels).            |
% | connected ([])      | logical vector of included channels (default all true).  |
% | xcoords ([])        | x coordinate (microns) of each channel (default zeros).  |
% | ycoords ([])        | y coordinate (microns) of each channel (default linear   |
% |                     |   0:spacing:(n-1)*spacing).                              |
% | kcoords ([])        | shank index of each channel (default ones).             |
% | spacing (20)        | Spacing (microns) between channels for the default       |
% |                     |   linear ycoords.                                        |
% | verbose (1)         | 0/1 Should we be verbose?                               |
% ---------------------------------------------------------------------------------
%
% Example:
%    % after ndi.fun.probe.export.all_binary(S,'binary_dir','kiasort',...)
%    d = fullfile(S.path,'kiasort',elestr);
%    ndi.fun.probe.export.channelmap(fullfile(d,'channel_map.mat'), ...
%        'metadataFile', fullfile(d,'kiasort.bin.metadata'));
%
% See also: NDI.FUN.PROBE.EXPORT.ALL_BINARY, NDI.FUN.PROBE.EXPORT.BINARY,
%   NDI.FUN.PROBE.IMPORT.KIASORT.PROBE

    arguments
        outputfile (1,:) char
        options.num_channels double = []
        options.metadataFile (1,:) char = ''
        options.chanMap double = []
        options.connected = []
        options.xcoords double = []
        options.ycoords double = []
        options.kcoords double = []
        options.spacing (1,1) double = 20
        options.verbose (1,1) double = 1
    end

    num_channels = options.num_channels;

    % determine number of channels from a metadata sidecar if not given
    if isempty(num_channels),
        metafile = options.metadataFile;
        if isempty(metafile),
            outdir = fileparts(outputfile);
            candidates = {fullfile(outdir,'kiasort.bin.metadata'), fullfile(outdir,'kilosort.bin.metadata')};
            for c=1:numel(candidates),
                if isfile(candidates{c}), metafile = candidates{c}; break; end;
            end;
        end;
        if isempty(metafile) || ~isfile(metafile),
            error(['num_channels was not provided and no .metadata sidecar was found. ' ...
                'Provide ''num_channels'' or ''metadataFile''.']);
        end;
        try
            meta = vlt.file.loadStructArray(metafile);
        catch ME
            error(['Could not read the metadata sidecar ' metafile ' (' ME.message '). ' ...
                'Pass ''num_channels'' explicitly instead.']);
        end;
        if ~isfield(meta,'num_channels'),
            error(['The metadata file ' metafile ' does not contain a num_channels field.']);
        end;
        num_channels = double(meta(1).num_channels);
    end;

    num_channels = double(num_channels);
    if isempty(num_channels) || num_channels<1 || mod(num_channels,1)~=0,
        error('num_channels must be a positive integer.');
    end;

    % assemble the map fields, defaulting where not supplied
    default_geometry = false;

    chanMap = options.chanMap;
    if isempty(chanMap), chanMap = (1:num_channels)'; end;
    chanMap = double(chanMap(:));
    chanMap0ind = chanMap - 1;

    connected = options.connected;
    if isempty(connected), connected = true(num_channels,1); end;
    connected = logical(connected(:));

    xcoords = options.xcoords;
    ycoords = options.ycoords;
    if isempty(xcoords) && isempty(ycoords),
        default_geometry = true;
    end;
    if isempty(xcoords), xcoords = zeros(num_channels,1); end;
    if isempty(ycoords), ycoords = (0:num_channels-1)' * options.spacing; end;
    xcoords = double(xcoords(:));
    ycoords = double(ycoords(:));

    kcoords = options.kcoords;
    if isempty(kcoords), kcoords = ones(num_channels,1); end;
    kcoords = double(kcoords(:));

    % length checks
    if numel(chanMap)~=num_channels || numel(connected)~=num_channels || ...
            numel(xcoords)~=num_channels || numel(ycoords)~=num_channels || ...
            numel(kcoords)~=num_channels,
        error('chanMap, connected, xcoords, ycoords, and kcoords must all have num_channels (%d) elements.', num_channels);
    end;

    if default_geometry && options.verbose,
        warning('ndi:fun:probe:export:channelmap:defaultGeometry', ...
            ['No probe geometry was provided; writing a default single-column linear ' ...
            'geometry (%d channels, %g um spacing). Pass ''xcoords''/''ycoords'' for the ' ...
            'real geometry for best KIASORT results.'], num_channels, options.spacing);
    end;

    outdir = fileparts(outputfile);
    if ~isempty(outdir) && ~isfolder(outdir),
        mkdir(outdir);
    end;

    save(outputfile, 'chanMap', 'chanMap0ind', 'connected', 'xcoords', 'ycoords', 'kcoords', '-v7');

    if options.verbose,
        disp(['Wrote Kilosort-style channel map (' int2str(num_channels) ' channels) to ' outputfile '.']);
    end;

end
