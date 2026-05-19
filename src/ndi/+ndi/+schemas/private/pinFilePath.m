function p = pinFilePath()
%PINFILEPATH Absolute path to the NDI schema pin file.
    p = fullfile(ndi.common.PathConstants.CommonFolder, 'schemas', 'pin.json');
end
