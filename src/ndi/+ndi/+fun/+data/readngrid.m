function x = readngrid(fileName_or_fileObj, dataSize, dataType)
%READNGRID - Read an n-dimensional matrix from a binary file.
%
%   Reads an n-dimensional matrix from a binary file, given the file path
%   or a file object, the size of the matrix, and the data type of its
%   elements. The data are read as little-endian ('ieee-le'), the format
%   WRITENGRID writes.
%
%   Syntax:
%       x = READNGRID(fileName_or_fileObj, dataSize)
%       x = READNGRID(fileName_or_fileObj, dataSize, dataType)
%
%   Input Arguments:
%       fileName_or_fileObj - Character vector or string with the full path
%                  and filename of the input binary file, OR a file object
%                  of type did.file.fileobj (for example the
%                  did.file.readonly_fileobj returned by
%                  ndi.session/database_openbinarydoc).
%                  A file object that is already open is read from its
%                  current position and left open, so that the caller can
%                  close it (e.g. with database_closebinarydoc). A file
%                  object that is not yet open is opened read-only here and
%                  closed again after reading.
%       dataSize - Numeric vector specifying the dimensions of the
%                  n-dimensional matrix to be read (e.g., [100, 100, 5]).
%       dataType - (Optional) Character vector specifying the data type of
%                  the elements in the binary file. Defaults to 'double' if
%                   not provided. Valid data types include 'double',
%                  'single', 'int8', 'uint8', 'int16', 'uint16', 'int32',
%                   'uint32', 'int64', 'uint64', etc.
%
%   Output Arguments:
%       x        - n-dimensional matrix read from the binary file, of size
%                  dataSize.
%
%   Error Handling:
%       - 'READNGRID:unknownDataType': If the dataType provided is not
%           recognized by fread a warning is issued.
%       - 'READNGRID:invalidFilePath': If the specified file cannot be
%           opened for reading.
%       - 'READNGRID:incorrectDataSize': If the number of elements read by
%           fread does not match the expected number based on dataSize a
%           warning is issued, and x is returned as a column vector of the
%           elements that were read.
%
%   Example (reading a file attached to a document):
%       f = S.database_openbinarydoc(doc, 'myfile.ngrid');
%       x = ndi.fun.data.readngrid(f, doc.document_properties.ngrid.data_dim, ...
%           doc.document_properties.ngrid.data_type);
%       S.database_closebinarydoc(f);
%
%   See also: WRITENGRID.

    arguments
        fileName_or_fileObj (1,:) {mustBeA(fileName_or_fileObj,{'char', 'string', 'did.file.fileobj'})}
        dataSize (1,:) double {mustBePositive, mustBeInteger}
        dataType (1,:) char {mustBeTextScalar} = 'double'
    end

    % Check if the data type is valid.
    validDataTypes = {'double', 'single', 'int8', 'uint8', 'int16', 'uint16', ...
                      'int32', 'uint32', 'int64', 'uint64', 'char', 'logical'};

    if strcmp(dataType, 'ubit1')
        % skip warning
    elseif ~any(strcmp(dataType, validDataTypes))
        warning('READNGRID:unknownDataType',['Data type ''' dataType ...
            ''' is not a standard MATLAB data type. ' ...
            'fread may interpret it incorrectly. Proceed with caution.']);
    end

    % fread accepts only a scalar or a 2-element size, so read the number of
    % elements and reshape afterwards; this also supports 3 or more
    % dimensions.
    expectedNumElements = prod(dataSize);

    if isa(fileName_or_fileObj, 'did.file.fileobj')
        x = readFromFileObj(fileName_or_fileObj, expectedNumElements, dataType);
    else
        x = readFromPath(char(fileName_or_fileObj), expectedNumElements, dataType);
    end

    % Check if the number of elements read matches the expected size.
    actualNumElements = numel(x);
    if actualNumElements ~= expectedNumElements
        warning('READNGRID:incorrectDataSize',['Number of elements read (' ...
            num2str(actualNumElements) ') does not match ' ...
            'the expected number (' num2str(expectedNumElements) '). ' ...
            'Check the dataSize argument.']);
        return;
    end

    if isscalar(dataSize)
        x = reshape(x, [dataSize 1]);
    else
        x = reshape(x, dataSize);
    end

end

function x = readFromPath(filePath, numElements, dataType)
% READFROMPATH - read NUMELEMENTS elements from a file given by its path
    fid = fopen(filePath, 'r', 'ieee-le'); % Force little-endian
    if fid < 0
        error('READNGRID:invalidFilePath',...
            ['Could not open file ''' filePath ''' for reading. ' ...
            'Ensure the path is correct and the file exists.']);
    end
    try
        x = fread(fid, numElements, dataType);
    catch ME
        fclose(fid);
        rethrow(ME); % Re-throw the original error.
    end
    fclose(fid);
end

function x = readFromFileObj(fileObj, numElements, dataType)
% READFROMFILEOBJ - read NUMELEMENTS elements from a did.file.fileobj
%
% An object that is already open (fid >= 0), such as the one returned by
% database_openbinarydoc, is read as it is and left open for its owner to
% close: reopening it would close the caller's handle first
% (did.file.fileobj/fopen closes an open file before opening), and a
% did.file.readonly_fileobj rejects any permission other than 'rb'.
% An object that is not open is opened read-only here and closed after.
    openedHere = false;
    if fileObj.fid < 0
        fileObj = fopen(fileObj, 'rb', 'ieee-le');
        if fileObj.fid < 0
            error('READNGRID:invalidFilePath',...
                ['Could not open file ''' char(fileObj.fullpathfilename) ''' for reading. ' ...
                'Ensure the path is correct and the file exists.']);
        end
        openedHere = true;
    end
    try
        x = fread(fileObj, numElements, dataType, 0, 'ieee-le');
    catch ME
        if openedHere
            fclose(fileObj);
        end
        rethrow(ME); % Re-throw the original error.
    end
    if openedHere
        fclose(fileObj);
    end
end
