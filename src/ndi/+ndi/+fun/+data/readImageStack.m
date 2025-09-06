function [imageStack,imageStack_info] = readImageStack(session,doc,fmt)
%READIMAGESTACK Reads an image stack or video from a database document.
%
%   [IMAGESTACK, INFO] = READIMAGESTACK(SESSION, DOC, FMT) retrieves a
%   binary file, specified by DOC, from a session object. The function reads
%   the file as either a multi-frame image or a video, based on the provided
%   format string FMT.
%
%   This function is designed to handle files stored in a database that may
%   lack a proper file extension, which is often required by MATLAB's reader
%   functions, particularly VideoReader.
%
% Special Handling for Videos
%
%   To work around the missing file extension requirement for videos, this
%   function creates a temporary file on disk with the correct extension. It
%   first attempts to create a symbolic link (a lightweight pointer) to the
%   original data file. If linking fails (e.g., due to system permissions),
%   it falls back to creating a temporary full copy of the file. This
%   temporary file is used to initialize the VideoReader object and is
%   automatically deleted upon completion or if an error occurs.
%
% Input Arguments
%
%   SESSION - The session object used to access the database.
%   DOC - The document object or ID that specifies the binary file to be read.
%   FMT - A character vector specifying the file format (e.g., 'tif', 'mp4').
%
% Output Arguments
%
%   IMAGESTACK - The output data. The data type of this output depends on the
%                input format:
%                - For image formats: A numeric array (HxWxCxN) containing
%                  the pixel data for all frames.
%                - For video formats: A `VideoReader` object, which provides a
%                  memory-efficient handle for reading frames on demand.
%
%   IMAGESTACK_INFO - A struct containing metadata about the image or video.
%                     The structure of this output will correspond to the
%                     output of `imfinfo` for images or `get(VideoReader)` for
%                     videos.
%
% Example
%
%   % Assume 'mySession' and 'myDoc' are valid objects, and the format is 'mp4'
%   [media, info] = readImageStack(mySession, myDoc, 'mp4');
%
%   if isa(media, 'VideoReader')
%       % It's a video, process frame by frame
%       disp(['Video has ' num2str(info.NumFrames) ' frames.']);
%       firstFrame = readFrame(media);
%       imshow(firstFrame);
%   else
%       % It's an image stack, display the first frame
%       disp(['Image stack has ' num2str(size(media, 4)) ' frames.']);
%       imshow(media(:,:,:,1));
%   end
%
%   See also: imread, imfinfo, VideoReader, copyfile, system

% Get file name
imageStackObj = session.database_openbinarydoc(doc,'imageStack');
imageStackFile = imageStackObj.fullpathfilename;

% Get supported image and video formats
imageFormats = [imformats().ext];
videoFormats = {VideoReader.getFileFormats().Extension};

if any(ismember(imageFormats,fmt))
    % --- Handle Image Files ---
    imageStack = imread(imageStackFile,fmt);
    imageStack_info = imfinfo(imageStackFile,fmt);

elseif any(ismember(videoFormats,fmt))
    % --- Handle Video Files with temporary link/copy workaround ---
    linkedFile = [imageStackFile, '.', fmt];
    
    % Ensure any lingering temp file is gone before starting
    if exist(linkedFile, 'file')
        delete(linkedFile);
    end

    try
        % First, attempt to create a symbolic link (fast, no data duplication)
        if isunix || ismac % Linux or macOS
            command = sprintf('ln -s "%s" "%s"', imageStackFile, linkedFile);
        elseif ispc % Windows
            % Note: This may require running MATLAB as an administrator
            command = sprintf('mklink "%s" "%s"', linkedFile, imageStackFile);
        end
        status = system(command);

        if status == 0
            % Link was successful, read the video
            imageStack = VideoReader(linkedFile);
            imageStack_info = get(imageStack);
        else
            % Link failed, so create a full copy as a fallback
            copyfile(imageStackFile, linkedFile);
            imageStack = VideoReader(linkedFile);
            imageStack_info = get(imageStack);
        end
    catch ME
        % If any part of the try block fails, ensure cleanup and rethrow
        if exist(linkedFile, 'file')
            delete(linkedFile);
        end
        rethrow(ME);
    end

    % Clean up the temporary link or copy
    if exist(linkedFile, 'file')
        delete(linkedFile);
    end
else
    error('readImageStack:UnsupportedFormat', 'The format "%s" is not a recognized image or video format.', fmt);
end