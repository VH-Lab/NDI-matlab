function [imageStack,imageStack_info] = readImageStack(session,doc,fmt)
%READIMAGESTACK Summary of this function goes here
%   Detailed explanation goes here

% Get file name
imageStackObj = session.database_openbinarydoc(doc,'imageStack');
imageStackFile = imageStackObj.fullpathfilename;

% Get supported image and video formats
imageFormats = [imformats().ext];
videoFormats = {VideoReader.getFileFormats().Extension};

if any(ismember(imageFormats,fmt))
    imageStack = imread(imageStackFile,fmt);
    imageStack_info = imfinfo(imageStackFile,fmt);
elseif any(ismember(videoFormats,fmt))

    % Try to create a symbolic link
    try
        linkedFile = [imageStackFile,'.',fmt];
        if isunix || ismac % Linux or macOS
            command = sprintf('ln -s "%s" "%s"', imageStackFile, linkedFile);
        elseif ispc % Windows
            % Note: This may require running MATLAB as an administrator
            command = sprintf('mklink "%s" "%s"', linkedFile, imageStackFile);
        end
        status = system(command);
        if status == 0
            imageStack = VideoReader(linkedFile);
            imageStack_info = get(imageStack);
        end
        delete(linkedFile);
        return;
    catch ME
        % If link failed, try making a copy of the file
        delete(linkedFile);
        try
            copyfile(imageStackFile, linkedFile);
            imageStack = VideoReader(linkedFile);
            imageStack_info = get(imageStack);
            delete(linkedFile);
            return;
        catch ME
            delete(linkedFile);
            rethrow(ME);
        end
    end
    
else
    error()
end