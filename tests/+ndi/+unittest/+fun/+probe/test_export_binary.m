function test_export_binary()
    disp('Testing ndi.fun.probe.export_binary');

    mockProbe = ndi.unittest.fun.probe.MockProbe();

    outputfile = [tempdir, 'test_export.bin'];

    if exist(outputfile, 'file')
        delete(outputfile);
    end
    metafile = [outputfile, '.metadata'];
    if exist(metafile, 'file')
        delete(metafile);
    end

    ndi.fun.probe.export_binary(mockProbe, outputfile, 'multiplier', 2, 'verbose', 0, 'precision', 'int16');

    assert(exist(outputfile, 'file') > 0, 'Output file not created');
    assert(exist(metafile, 'file') > 0, 'Metadata file not created');

    % Verify metadata contents - vlt.file.saveStructArray saves a tab-delimited text file
    % We can read it back using vlt.file.loadStructArray
    meta = vlt.file.loadStructArray(metafile);

    assert(isfield(meta, 'multiplier'), 'Metadata missing multiplier field');
    assert(meta(1).multiplier == 2, 'Metadata multiplier value incorrect');
    assert(isfield(meta, 'probe_name'), 'Metadata missing probe_name field');
    assert(strcmp(meta(1).probe_name, 'mock_probe'), 'Metadata probe_name value incorrect');

    disp('Test passed.');
end
