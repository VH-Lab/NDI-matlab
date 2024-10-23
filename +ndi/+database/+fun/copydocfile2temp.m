function [tname,tname_without_extension] = copydocfile2temp(doc, S, filename, extension)
    % COPYDOC2FILENAME - copy a file from an ndi.document to the file system
    %
    % [TNAME,TNAME_WITHOUT_EXT] = COPYDOCFILE2TEMP(DOC, S, FILENAME, EXTENSION)
    %
    % Copies a file associated with an ndi.document to the file system.
    %
    % Note: This function (at present) assumes the entire file can be read into
    % memory at once.
    %
    % Inputs:
    %   DOC - the ndi.document that has the file to be copied
    %   S   - the ndi.session that the document belongs to
    %   FILENAME - the file of DOC to be copied
    %   EXTENSION - the extension of the filename. Should include the leading period.
    %
    % Ouptut:
    %   TNAME - the temporary filename that is created.
    %   TNAME_WITHOUT_EXT - the temporary filename without the extension.
    %
    % The calling program should delete the file TNAME when finished using delete(TNAME).
    %


    % note: this function could be expanded to include a cache so that if the same document
    % is copied again, it can be skipped, until the cache is full and the oldest or least
    % prioritized copy can be removed

    tname_without_extension = ndi.file.temp_name();
    tname = [ tname_without_extension extension ];

    f = S.database_openbinarydoc(doc,filename);
    data = f.fread(Inf);

    fid = fopen(tname,'wb','ieee-le');
    fwrite(fid,data,'uint8');
    fclose(fid);


