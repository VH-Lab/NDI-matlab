function image_tiffstack(dirname)
% IMAGE_TIFFSTACK - end-to-end test of the imageseries DAQ machinery
%
%   ndi.test.daq.image_tiffstack([DIRNAME])
%
% Builds a small session containing an ndi.daq.system.image whose reader is
% the thin NDR bridge ndi.daq.reader.image.ndr('tiffstack'), with two epochs:
%
%   epoch 'stackA' - a clockless image stack (no frame-times sidecar): the
%                    epoch clock is 'no_time' and frames are addressed by index.
%   epoch 'movieB' - a movie (with a '<name>_frametimes.txt' sidecar): the
%                    epoch clock is 'dev_local_time' and each frame has a time.
%
% It then checks, with assert():
%   1. The live frame API on the daq.system (numframes, framesize, datatype,
%      epochclock, frametimes, readframes round-trip).
%   2. Reading frames through the ndi.probe.image / ndi.element.image with the
%      NDI epoch-clock system, including a time-windowed read of the movie that
%      returns the correct frames and their timestamps.
%   3. Ingestion, and that reading the same frames/times back from the ingested
%      documents matches the live read.
%
% If DIRNAME is omitted a fresh temporary directory is created and removed at
% the end.
%

    cleanup_dir = false;
    if nargin<1
        dirname = tempname();
        mkdir(dirname);
        cleanup_dir = true;
    end
    cleaner = onCleanup(@() localCleanup(cleanup_dir, dirname));

    % ---- synthesize two epochs of TIFF data -------------------------------
    Y = 10; X = 8; T = 6;
    truthA = localMakeStack(Y,X,T,0);      % clockless stack
    truthB = localMakeStack(Y,X,T,1000);   % movie

    fileA = fullfile(dirname,'stackA.tif');
    fileB = fullfile(dirname,'movieB.tif');
    localWriteMultipageTiff(fileA, truthA);
    localWriteMultipageTiff(fileB, truthB);

    % movie frame-times sidecar (dev_local_time, seconds)
    timesB = (0:T-1)' * 0.05 + 100;
    localWriteAscii(fullfile(dirname,'movieB_frametimes.txt'), timesB);

    % epochprobemap files: one imaging probe 'camera' on daq 'image1'
    localWriteProbeMap(fullfile(dirname,'stackA.epochprobemap.ndi'));
    localWriteProbeMap(fullfile(dirname,'movieB.epochprobemap.ndi'));

    % ---- build the session and image daq.system ---------------------------
    E = ndi.session.dir('imgexp', dirname);
    E.database_clear('yes');

    subject = ndi.subject('mouse1@nosuchlab.org','');
    E.database_add(subject.newdocument());

    nav = ndi.file.navigator(E, {'#.tif', '#.epochprobemap.ndi'}, ...
        'ndi.epoch.epochprobemap_daqsystem', {'(.*)\.epochprobemap.ndi'});
    reader = ndi.daq.reader.image.ndr('tiffstack');
    dev = ndi.daq.system.image('image1', nav, reader);
    E.daqsystem_add(dev);
    E.cache.clear();

    % ---- map epoch ids to our two known epochs ----------------------------
    et = dev.epochtable();
    assert(numel(et)==2, ['Expected 2 epochs, found ' int2str(numel(et)) '.']);
    [epochA, truthA2] = localFindEpoch(dev, et, 'stackA', truthA, truthB);
    [epochB, truthB2] = localFindEpoch(dev, et, 'movieB', truthA, truthB);

    % ---- (1) live frame API on the daq.system -----------------------------
    assert(dev.numframes(epochA)==T, 'numframes (clockless) mismatch.');
    assert(isequal(dev.framesize(epochA),[Y X 1 1 T]), 'framesize (clockless) mismatch.');
    assert(strcmp(dev.datatype(epochA),'uint16'), 'datatype mismatch.');

    ecA = dev.epochclock(epochA);
    assert(strcmp(ecA{1}.type,'no_time'), 'clockless epoch clock should be no_time.');
    ecB = dev.epochclock(epochB);
    assert(strcmp(ecB{1}.type,'dev_local_time'), 'movie epoch clock should be dev_local_time.');

    framesA = dev.readframes(epochA);
    assert(isequal(framesA, truthA2), 'clockless frames did not round-trip (live).');
    framesB = dev.readframes(epochB);
    assert(isequal(framesB, truthB2), 'movie frames did not round-trip (live).');

    ftB = dev.frametimes(epochB);
    assert(isequal(ftB(:), timesB), 'movie frametimes mismatch (live).');
    ftA = dev.frametimes(epochA);
    assert(all(isnan(ftA)), 'clockless frametimes should be NaN (live).');

    % ---- (2) read through the probe / element with the epoch-clock system -
    probes = dev.getprobes();
    assert(~isempty(probes), 'Expected an imaging probe from the daq.system.');
    p = E.getprobes('name','camera');
    if iscell(p), p = p{1}; end
    assert(isa(p,'ndi.probe.image'), 'Imaging probe should be an ndi.probe.image.');

    % time-windowed read of the movie: pick frames whose times are in [t_lo,t_hi]
    t_lo = timesB(2); t_hi = timesB(4);
    [imgs, tt] = p.readframes(epochB, t_lo, t_hi);
    assert(size(imgs,5)==3, 'Time-windowed movie read should return 3 frames.');
    assert(isequal(tt(:), timesB(2:4)), 'Time-windowed movie read returned wrong timestamps.');
    assert(isequal(imgs, truthB2(:,:,:,:,2:4)), 'Time-windowed movie read returned wrong frames.');

    % element.image (direct) delegates to the probe
    elem = ndi.element.image(E, 'camera_elem', 1, 'wide-field-imaging', p, 1);
    [imgs2, tt2] = elem.readframes(epochB, t_lo, t_hi);
    assert(isequal(imgs2, imgs) && isequal(tt2(:), tt(:)), 'element.image read disagreed with probe read.');

    % ---- (3) ingest, then read back from the ingested documents -----------
    [b, ~] = dev.ingest();
    assert(b==1, 'ingest() did not report success.');
    E.cache.clear();

    framesA_i = dev.readframes(epochA);
    assert(isequal(framesA_i, truthA2), 'clockless frames did not round-trip (ingested).');
    framesB_i = dev.readframes(epochB);
    assert(isequal(framesB_i, truthB2), 'movie frames did not round-trip (ingested).');
    ftB_i = dev.frametimes(epochB);
    assert(isequal(ftB_i(:), timesB), 'movie frametimes mismatch (ingested).');
    ecB_i = dev.epochclock(epochB);
    assert(strcmp(ecB_i{1}.type,'dev_local_time'), 'movie epoch clock should be dev_local_time (ingested).');

    disp('ndi.test.daq.image_tiffstack passed.');
end

% ---- local helpers --------------------------------------------------------

function [epoch_id, truth_match] = localFindEpoch(dev, et, stem, truthA, truthB)
    epoch_id = '';
    truth_match = [];
    for i=1:numel(et)
        ef = et(i).underlying_epochs.underlying;
        joined = strjoin(ef, ' ');
        if ~isempty(strfind(joined, [stem '.tif']))
            epoch_id = et(i).epoch_id;
            if ~isempty(strfind(stem,'stackA'))
                truth_match = truthA;
            else
                truth_match = truthB;
            end
            return;
        end
    end
    error(['Could not find epoch for stem ' stem '.']);
end

function s = localMakeStack(Y,X,T,offset)
    s = zeros(Y,X,1,1,T,'uint16');
    for i=1:T
        s(:,:,1,1,i) = uint16( reshape(1:(Y*X), Y, X) + (i-1)*100 + offset );
    end
end

function localWriteMultipageTiff(filename, data)
    sz = size(data);
    if numel(sz)<5, sz(end+1:5) = 1; end
    T = sz(5);
    t = Tiff(filename,'w');
    c = onCleanup(@() t.close());
    for i=1:T
        tags.ImageLength = sz(1);
        tags.ImageWidth = sz(2);
        tags.Photometric = Tiff.Photometric.MinIsBlack;
        tags.BitsPerSample = 16;
        tags.SamplesPerPixel = sz(3);
        tags.SampleFormat = Tiff.SampleFormat.UInt;
        tags.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
        tags.Compression = Tiff.Compression.None;
        t.setTag(tags);
        t.write(squeeze(data(:,:,:,1,i)));
        if i<T, t.writeDirectory(); end
    end
end

function localWriteAscii(filename, v)
    fid = fopen(filename,'w');
    c = onCleanup(@() fclose(fid));
    fprintf(fid,'%.10g\n', v);
end

function localWriteProbeMap(filename)
    fid = fopen(filename,'wt');
    if fid<0, error(['Could not open ' filename ' for writing.']); end
    c = onCleanup(@() fclose(fid));
    fprintf(fid,'name\treference\ttype\tdevicestring\tsubjectstring\n');
    fprintf(fid,'camera\t1\twide-field-imaging\timage1:image1\tmouse1@nosuchlab.org\n');
end

function localCleanup(cleanup_dir, dirname)
    if cleanup_dir && isfolder(dirname)
        try, rmdir(dirname,'s'); catch, end
    end
end
