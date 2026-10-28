function dirname = stacyFixtureDirectory(parentFolder, options)
% STACYFIXTUREDIRECTORY - Make a small experiment directory in the layout of the Stacy LGN data.
%
% DIRNAME = ndi.test.helper.stacyFixtureDirectory(PARENTFOLDER, ...)
%
% Creates the experiment directory PARENTFOLDER/2020-07-16 with everything
% that ndi.setup.conv.vhlab.validateStacyDirectory checks for, so that it
% passes validation with no errors or warnings: subject.txt, dob.txt,
% testdirinfo.txt, a grating_training_run file, analysis/experiment with one
% cell, and one epoch directory (t00001) with the vhintan and vhvis_spike2
% files. The data files are placeholders; they hold no recorded data.
%
% Name/value pairs:
%   'WriteSubjectFiles' (true)  - write subject.txt and dob.txt
%   'Types' ('preDirSF')        - the types of t00001 in testdirinfo.txt
%
% Returns the full path of the experiment directory.

    arguments
        parentFolder (1,:) char
        options.WriteSubjectFiles (1,1) logical = true
        options.Types (1,:) char = 'preDirSF'
    end

    dirname = fullfile(parentFolder, '2020-07-16');
    epochDir = fullfile(dirname, 't00001');
    mkdir(epochDir);
    mkdir(fullfile(dirname, 'analysis'));

    if options.WriteSubjectFiles
        writeText(fullfile(dirname, 'subject.txt'), 'ferret_361.1521@vhlab.org');
        writeText(fullfile(dirname, 'dob.txt'), '2020-06-14');
    end
    writeText(fullfile(dirname, 'testdirinfo.txt'), ...
        sprintf('testdir\ttypes\nt00001\t%s', options.Types));

    currenttime = 737988.4; %#ok<NASGU> a datenum, as saved by the training program
    save(fullfile(dirname, 'grating_training_run1.mat'), 'currenttime');

    % the experiment file has no extension, so save it with one and rename it
    cell_extra10_001_251_2020_07_16 = struct('placeholder', 1); %#ok<NASGU>
    save(fullfile(dirname, 'analysis', 'experiment.mat'), 'cell_extra10_001_251_2020_07_16');
    movefile(fullfile(dirname, 'analysis', 'experiment.mat'), fullfile(dirname, 'analysis', 'experiment'));

    writeText(fullfile(epochDir, 'reference.txt'), sprintf('name\tref\ttype\nextra10\t1\textracellular'));
    for f = {'vhintan_channelgrouping.txt', 'vhintan_intan2spike2time.txt', ...
            'stimtimes.txt', 'verticalblanking.txt', 'spike2data.smr', 'recording.rhd'}
        writeText(fullfile(epochDir, f{1}), '');
    end
    placeholder = 1; %#ok<NASGU>
    save(fullfile(epochDir, 'stims.mat'), 'placeholder');
end

function writeText(filename, text)
    fid = fopen(filename, 'w');
    if fid < 0
        error('Could not open %s for writing.', filename);
    end
    fprintf(fid, '%s\n', text);
    fclose(fid);
end
