# CLASS ndi.database.binarydoc

  NDI_BINARYDOC - a binary file class that handles reading/writing

## Superclasses
**handle**

## Properties

*none*


## Methods 

| Method | Description |
| --- | --- |
| *addlistener* | ADDLISTENER  Add listener for event. |
| *binarydoc* | a binary file class that handles reading/writing |
| *delete* | close an ndi.database.binarydoc and delete its handle |
| *eq* | == (EQ)   Test handle equality. |
| *fclose* | FCLOSE Close file. |
| *feof* | of-file. |
| *findobj* | FINDOBJ   Find objects matching specified conditions. |
| *findprop* | FINDPROP   Find property of MATLAB handle object. |
| *fopen* | FOPEN  Open file. |
| *fread* | FREAD  Read binary data from file. |
| *fseek* | FSEEK Set file position indicator. |
| *ftell* | FTELL Get file position indicator. |
| *fwrite* | FWRITE Write binary data to file. |
| *ge* | >= (GE)   Greater than or equal relation for handles. |
| *gt* | > (GT)   Greater than relation for handles. |
| *isvalid* | ISVALID   Test handle validity. |
| *le* | <= (LE)   Less than or equal relation for handles. |
| *listener* | LISTENER  Add listener for event without binding the listener to the source object. |
| *lt* | < (LT)   Less than relation for handles. |
| *ne* | ~= (NE)   Not equal relation for handles. |
| *notify* | NOTIFY   Notify listeners of event. |


### Methods help 

**addlistener** - *ADDLISTENER  Add listener for event.*

el = ADDLISTENER(hSource, Eventname, callbackFcn) creates a listener
    for the event named Eventname.  The source of the event is the handle 
    object hSource.  If hSource is an array of source handles, the listener
    responds to the named event on any handle in the array.  callbackFcn
    is a function handle that is invoked when the event is triggered.
 
    el = ADDLISTENER(hSource, PropName, Eventname, Callback) adds a 
    listener for a property event.  Eventname must be one of
    'PreGet', 'PostGet', 'PreSet', or 'PostSet'. Eventname can be
    a string scalar or character vector.  PropName must be a single 
    property name specified as string scalar or character vector, or a 
    collection of property names specified as a cell array of character 
    vectors or a string array, or as an array of one or more 
    meta.property objects.  The properties must belong to the class of 
    hSource.  If hSource is scalar, PropName can include dynamic 
    properties.
    
    For all forms, addlistener returns an event.listener.  To remove a
    listener, delete the object returned by addlistener.  For example,
    delete(el) calls the handle class delete method to remove the listener
    and delete it from the workspace.
 
    ADDLISTENER binds the listener's lifecycle to the object that is the 
    source of the event.  Unless you explicitly delete the listener, it is
    destroyed only when the source object is destroyed.  To control the
    lifecycle of the listener independently from the event source object, 
    use listener or the event.listener constructor to create the listener.
 
    See also LISTENER, EVENT.LISTENER, NDI.DATABASE.BINARYDOC, NOTIFY, DELETE, META.PROPERTY, EVENTS

Help for ndi.database.binarydoc/addlistener is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.database.binarydoc/addlistener


---

**binarydoc** - *a binary file class that handles reading/writing*




---

**delete** - *close an ndi.database.binarydoc and delete its handle*

DELETE(NDI_BINARYDOC_OBJ)
 
  Closes an ndi.database.binarydoc (if necessary) and then deletes the handle.


---

**eq** - *== (EQ)   Test handle equality.*

Handles are equal if they are handles for the same object.
 
    H1 == H2 performs element-wise comparisons between handle arrays H1 and
    H2.  H1 and H2 must be of the same dimensions unless one is a scalar.
    The result is a logical array of the same dimensions, where each
    element is an element-wise equality result.
 
    If one of H1 or H2 is scalar, scalar expansion is performed and the 
    result will match the dimensions of the array that is not scalar.
 
    TF = EQ(H1, H2) stores the result in a logical array of the same 
    dimensions.
 
    See also NDI.DATABASE.BINARYDOC, NDI.DATABASE.BINARYDOC/GE, NDI.DATABASE.BINARYDOC/GT, NDI.DATABASE.BINARYDOC/LE, NDI.DATABASE.BINARYDOC/LT, NDI.DATABASE.BINARYDOC/NE

Help for ndi.database.binarydoc/eq is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.database.binarydoc/eq


---

**fclose** - *FCLOSE Close file.*

ST = FCLOSE(FID) closes the file associated with file identifier FID,
    which is an integer value obtained from an earlier call to FOPEN.  
    FCLOSE returns 0 if successful or -1 if not.  If FID does not represent
    an open file, or if it is equal to 0 (standard input), 1 (standard
    output), or 2 (standard error), FCLOSE throws an error.
 
    ST = FCLOSE('all') closes all open files, except 0, 1 and 2.
 
    See also FOPEN, FERROR, FPRINTF, FREAD, FREWIND, FSCANF, FTELL, FWRITE.


---

**feof** - *of-file.*

ST = FEOF(FID) returns 1 if the end-of-file indicator for the
    file with file identifier FID has been set, and 0 otherwise.
    The end-of-file indicator is set when a read operation on the file
    associated with the FID attempts to read past the end of the file.
 
    See also FERROR, FGETL, FGETS, FREAD, FSCANF, FOPEN.


---

**findobj** - *FINDOBJ   Find objects matching specified conditions.*

The FINDOBJ method of the HANDLE class follows the same syntax as the 
    MATLAB FINDOBJ command, except that the first argument must be an array
    of handles to objects.
 
    HM = FINDOBJ(H, <conditions>) searches the handle object array H and 
    returns an array of handle objects matching the specified conditions.
    Only the public members of the objects of H are considered when 
    evaluating the conditions.
 
    See also FINDOBJ, NDI.DATABASE.BINARYDOC

Help for ndi.database.binarydoc/findobj is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.database.binarydoc/findobj


---

**findprop** - *FINDPROP   Find property of MATLAB handle object.*

p = FINDPROP(H,PROPNAME) finds and returns the META.PROPERTY object
    associated with property name PROPNAME of scalar handle object H.
    PROPNAME can be a string scalar or character vector.  It can be the 
    name of a property defined by the class of H or a dynamic property 
    added to scalar object H.
   
    If no property named PROPNAME exists for object H, an empty 
    META.PROPERTY array is returned.
 
    See also NDI.DATABASE.BINARYDOC, NDI.DATABASE.BINARYDOC/FINDOBJ, DYNAMICPROPS, META.PROPERTY

Help for ndi.database.binarydoc/findprop is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.database.binarydoc/findprop


---

**fopen** - *FOPEN  Open file.*

FID = FOPEN(FILENAME) opens the file FILENAME for read access. FILENAME is the
    name of the file to be opened.
 
    FILENAME can be a MATLABPATH relative partial pathname. If the file is not found
    in the current working directory, FOPEN searches for it on the MATLAB search
    path. On UNIX systems, FILENAME may also start with a "~/" or a "~username/",
    which FOPEN expands to the current user's home directory or the specified user's
    home directory, respectively.
 
    FID is a scalar MATLAB integer valued double, called a file identifier. You use
    FID as the first argument to other file input/output routines, such as FREAD and
    FCLOSE. If FOPEN cannot open the file, it returns -1.
 
    FID = FOPEN(FILENAME,PERMISSION) opens the file FILENAME in the mode specified by
    PERMISSION:
    
        'r'     open file for reading
        'w'     open file for writing; discard existing contents
        'a'     open or create file for writing; append data to end of file
        'r+'    open (do not create) file for reading and writing
        'w+'    open or create file for reading and writing; discard existing
                contents
        'a+'    open or create file for reading and writing; append data to end of
                file             
        'W'     open file for writing without automatic flushing
        'A'     open file for appending without automatic flushing
    
    FILENAME can be a MATLABPATH relative partial pathname only if the file is opened
    for reading.
 
    You can open files in binary mode (the default) or in text mode. In binary mode,
    no characters get singled out for special treatment. In text mode on the PC, the
    carriage return character preceding a newline character is deleted on input and
    added before the newline character on output. To open a file in text mode,
    append 't' to the permission specifier, for example 'rt' and 'w+t'. (On Unix, text and
    binary mode are the same, so this has no effect. On PC systems this is
    critical.)
 
    If the file is opened in update mode ('+'), you must use an FSEEK or FREWIND
    between an input command like FREAD, FSCANF, FGETS, or FGETL and an output
    command like FWRITE or FPRINTF. You must also use an FSEEK or FREWIND between an
    output command and an input command.
 
    Two file identifiers are automatically available and need not be opened. They
    are FID=1 (standard output) and FID=2 (standard error).
    
    [FID, MESSAGE] = FOPEN(FILENAME,...) returns a system dependent error message if
    the open is not successful.
 
    [FID, MESSAGE] = FOPEN(FILENAME,PERMISSION,MACHINEFORMAT) opens the specified
    file with the specified PERMISSION and treats data read using FREAD or data
    written using FWRITE as having a format given by MACHINEFORMAT. MACHINEFORMAT is
    one of the following:
 
    'native'      or 'n' - local machine format - the default
    'ieee-le'     or 'l' - IEEE floating point with little-endian byte ordering
    'ieee-be'     or 'b' - IEEE floating point with big-endian byte ordering
    'ieee-le.l64' or 'a' - IEEE floating point with little-endian byte ordering and
                           64 bit long data type
    'ieee-be.l64' or 's' - IEEE floating point with big-endian byte ordering and 64
                           bit long data type.
    
    [FID, MESSAGE] = FOPEN(FILENAME,PERMISSION,MACHINEFORMAT,ENCODING)
    opens the specified file using the specified PERMISSION and
    MACHINEFORMAT. ENCODING specifies the name of a character encoding
    scheme associated with the file. It must be the empty character vector
    (''), empty string (""), or a name, or alias for an encoding scheme.
    Some examples are 'UTF-8', 'latin1', 'US-ASCII', and 'Shift_JIS'. For
    common names and aliases, see the Web site
    http://www.iana.org/assignments/character-sets. If ENCODING is
    unspecified, or is the empty character vector (''), or is the empty
    string (""), MATLAB's default encoding scheme is used.
 
    [FILENAME,PERMISSION,MACHINEFORMAT,ENCODING] = FOPEN(FID) returns the filename,
    permission, machine format, and character encoding values used by MATLAB when it
    opened the file associated with identifier FID. MATLAB does not determine these
    output values by reading information from the opened file. For any of these
    parameters that were not specified when the file was opened, MATLAB returns its
    default value. The ENCODING is a standard character encoding scheme name that may
    not be the same as the ENCODING argument used in the call to FOPEN that opened
    the file. An invalid FID returns empty character vector ('') for all output arguments.
 
    FIDS = FOPEN('all') returns a row vector containing the file identifiers for all
    the files currently opened by the user (but not 1 or 2).
    
    The 'W' and 'A' permissions do not automatically perform a flush of the current
    output buffer after output operations.
    
    See also FCLOSE, FERROR, FGETL, FGETS, FPRINTF, FREAD, FSCANF, FSEEK, 
             FTELL, FWRITE.


---

**fread** - *FREAD  Read binary data from file.*

A = FREAD(FID) reads binary data from the specified file and writes it into
    matrix A.  FID is an integer file identifier obtained from FOPEN.  MATLAB reads
    the entire file and positions the file pointer at the end of the file (see FEOF
    for details).
 
    A = FREAD(FID,SIZE) reads the number of elements specified by SIZE.  Valid
    entries for SIZE are:
        N      read N elements into a column vector. 
        inf    read to the end of the file.
        [M,N]  read elements to fill an M-by-N matrix, in column order.
               N can be inf, but M can't.
 
    A = FREAD(FID,SIZE,PRECISION) reads the file according to the data format
    specified by PRECISION. The PRECISION input commonly contains a datatype
    specifier like 'int' or 'float', followed by an integer giving the size in bits.
    The SIZE argument is optional when using this syntax.
 
    Any of the following values, either the MATLAB version, or their C or
    Fortran equivalent, may be used for PRECISION.  If not specified, the
    default PRECISION is 'uint8'.
        MATLAB    C or Fortran     Description
        'uchar'   'unsigned char'  unsigned integer,  8 bits.
        'schar'   'signed char'    signed integer,  8 bits.
        'int8'    'integer*1'      integer, 8 bits.
        'int16'   'integer*2'      integer, 16 bits.
        'int32'   'integer*4'      integer, 32 bits.
        'int64'   'integer*8'      integer, 64 bits.
        'uint8'   'integer*1'      unsigned integer, 8 bits.
        'uint16'  'integer*2'      unsigned integer, 16 bits.
        'uint32'  'integer*4'      unsigned integer, 32 bits.
        'uint64'  'integer*8'      unsigned integer, 64 bits.
        'single'  'real*4'         floating point, 32 bits.
        'float32' 'real*4'         floating point, 32 bits.
        'double'  'real*8'         floating point, 64 bits.
        'float64' 'real*8'         floating point, 64 bits.
 
    The following platform dependent formats are also supported but they are not
    guaranteed to be the same size on all platforms.
 
        MATLAB    C or Fortran     Description
        'char'    'char*1'         character.
        'short'   'short'          integer,  16 bits.
        'int'     'int'            integer,  32 bits.
        'long'    'long'           integer,  32 or 64 bits.
        'ushort'  'unsigned short' unsigned integer,  16 bits.
        'uint'    'unsigned int'   unsigned integer,  32 bits.
        'ulong'   'unsigned long'  unsigned integer,  32 bits or 64 bits.
        'float'   'float'          floating point, 32 bits.
 
    If the precision is 'char' or 'char*1', MATLAB reads characters using the
    encoding scheme associated with the file. See FOPEN for more information.
 
    The following formats map to an input stream of bits rather than bytes.
 
        'bitN'                     signed integer, N bits  (1<=N<=64).
        'ubitN'                    unsigned integer, N bits (1<=N<=64).
 
    If the input stream is bytes and FREAD reaches the end of file (see FEOF) in the
    middle of reading the number of bytes required for an element, the partial result
    is ignored. However, if the input stream is bits, then the partial result is
    returned as the last value.  If an error occurs before reaching the end of file,
    only full elements read up to that point are used.
 
    By default, numeric and character values are returned in class 'double' arrays.
    To return these values stored in classes other than double, create your PRECISION
    argument by first specifying your source format, then following it by '=>', and
    finally specifying your destination format. If the source and destination formats
    are the same then the following shorthand notation may be used:
 
        *source
 
    which means:
 
        source=>source
 
    For example,
 
        uint8=>uint8               read in unsigned 8-bit integers and
                                   save them in an unsigned 8-bit integer array
 
        *uint8                     shorthand version of previous example
 
        bit4=>int8                 read in signed 4-bit integers packed
                                   in bytes and save them in a signed 8-bit integer
                                   array (each 4-bit integer becomes one 8-bit
                                   integer)
 
        double=>real*4             read in doubles, convert and save
                                   as a 32-bit floating point array
 
    A = FREAD(FID,SIZE,PRECISION,SKIP) includes a SKIP argument that specifies the
    number of bytes to skip after each PRECISION value is read. If PRECISION
    specifies a bit source format, like 'bitN' or 'ubitN', the SKIP argument is
    interpreted as the number of bits to skip.  The SIZE argument is optional when
    using this syntax.
 
    When SKIP is used, the PRECISION specifier may contain a positive integer repetition factor
    of the form 'N*' which prepends the source format of the PRECISION argument, like
    '40*uchar'.  Note that 40*uchar for the PRECISION alone is equivalent to
    '40*uchar=>double', not '40*uchar=>uchar'.  With SKIP specified, FREAD reads in,
    at most, a repetition factor number of values (default of 1), does a skip of
    input specified by the SKIP argument, reads in another block of values and does a
    skip of input, etc. until SIZE number of values have been read.  If a SKIP
    argument is not specified, the repetition factor is ignored.  Repetition with
    skip is useful for extracting data in noncontiguous fields from fixed length
    records.
 
    For example,
 
        s = fread(fid,120,'40*uchar=>uchar',8);
 
    reads in 120 characters in blocks of 40 each separated by 8 characters.
 
    A = FREAD(FID,SIZE,PRECISION,SKIP,MACHINEFORMAT) treats the data read as having a
    format given by the MACHINEFORMAT. You can obtain the MACHINEFORMAT argument from
    the output of the FOPEN function. See FOPEN for possible values for
    MACHINEFORMAT. The SIZE and SKIP arguments are optional when using this syntax.
    
    [A, COUNT] = FREAD(...) Optional output argument COUNT returns the number of
    elements successfully read.
 
    Examples:
 
    The file alphabet.txt contains the 26 letters of the English alphabet, all
    capitalized. Open the file for read access with fopen, and read the first five
    elements into output c. Because a precision has not been specified, MATLAB uses
    the default precision of uchar, and the output is numeric:
 
    fid = fopen('alphabet.txt', 'r');
    c = fread(fid, 5)'
    c =
        65    66    67    68    69
    fclose(fid);
 
    This time, specify that you want each element read as an unsigned 8-bit integer
    and output as a character. (Using a precision of 'char=>char' or '*char' will
    produce the same result):
 
    fid = fopen('alphabet.txt', 'r');
    c = fread(fid, 5, 'uint8=>char')'
    c =
        ABCDE
    fclose(fid);
 
    See also FWRITE, FSEEK, FSCANF, FGETL, FGETS, LOAD, FOPEN, FEOF.


---

**fseek** - *FSEEK Set file position indicator.*

STATUS = FSEEK(FID, OFFSET, ORIGIN) repositions the file position
    indicator in the file associated with the given FID.  FSEEK sets the 
    position indicator to the byte with the specified OFFSET relative to 
    ORIGIN.
 
    FID is an integer file identifier obtained from FOPEN.
 
    OFFSET values are interpreted as follows:
        >= 0    Move position indicator OFFSET bytes after ORIGIN.
        < 0    Move position indicator OFFSET bytes before ORIGIN.
 
    ORIGIN values are interpreted as follows:
        'bof' or -1   Beginning of file
        'cof' or  0   Current position in file
        'eof' or  1   End of file
 
    STATUS is 0 on success and -1 on failure.  If an error occurs, use
    FERROR to get more information.
 
    Example:
 
        fseek(fid,0,-1)
 
    "rewinds" the file.
 
    See also FERROR, FOPEN, FPRINTF, FREAD, FREWIND, FSCANF, FSEEK, FTELL, 
             FWRITE.


---

**ftell** - *FTELL Get file position indicator.*

POSITION = FTELL(FID) returns the location of the file position
    indicator in the specified file.  Position is indicated in bytes
    from the beginning of the file.  If -1 is returned, it indicates
    that the query was unsuccessful. Use FERROR to determine the nature
    of the error.
 
    FID is an integer file identifier obtained from FOPEN.
 
    See also FERROR, FOPEN, FPRINTF, FREAD, FREWIND, FSCANF, FSEEK, FWRITE.


---

**fwrite** - *FWRITE Write binary data to file.*

COUNT = FWRITE(FID,A) writes the elements of matrix A to the specified file. The
    data are written in column order. COUNT is the number of elements successfully
    written.
 
    FID is an integer file identifier obtained from FOPEN, or 1 for standard output
    or 2 for standard error.
 
    COUNT = FWRITE(FID,A,PRECISION) writes the elements of matrix A to the specified
    file, translating MATLAB values to the specified precision.
 
    PRECISION controls the form and size of the result.  See the list of allowed
    precisions under FREAD. If PRECISION is not specified, MATLAB uses the default,
    which is 'uint8'. If either 'bitN' or 'ubitN' is used for the PRECISION then any
    out of range value of A is written as a value with all bits turned on. If the
    precision is 'char' or 'char*1', MATLAB writes characters using the encoding
    scheme associated with the file. See FOPEN for more information.
 
    COUNT = FWRITE(FID,A,PRECISION,SKIP) includes an optional SKIP argument that
    specifies the number of bytes to skip before each PRECISION value is written.
    With the SKIP argument present, FWRITE skips and writes a value, skips and writes
    another value, etc. until all of A is written.  If PRECISION is a bit format like
    'bitN' or 'ubitN' SKIP is specified in bits. This is useful for inserting data
    into noncontiguous fields in fixed length records.
 
    COUNT = FWRITE(FID,A,PRECISION,SKIP,MACHINEFORMAT) treats the data written as
    having a format given by MACHINEFORMAT. You can obtain the MACHINEFORMAT argument
    from the output of the FOPEN function. See FOPEN for possible values for
    MACHINEFORMAT.
    
    For example,
 
        fid = fopen('magic5.bin','wb')
        fwrite(fid,magic(5),'integer*4')
 
    creates a 100-byte binary file, containing the 25 elements of the 5-by-5 magic
    square, stored as 4-byte integers.
 
    See also FOPEN, FREAD, FPRINTF, SAVE, DIARY.


---

**ge** - *>= (GE)   Greater than or equal relation for handles.*

H1 >= H2 performs element-wise comparisons between handle arrays H1 and
    H2.  H1 and H2 must be of the same dimensions unless one is a scalar.
    The result is a logical array of the same dimensions, where each
    element is an element-wise >= result.
 
    If one of H1 or H2 is scalar, scalar expansion is performed and the 
    result will match the dimensions of the array that is not scalar.
 
    TF = GE(H1, H2) stores the result in a logical array of the same 
    dimensions.
 
    See also NDI.DATABASE.BINARYDOC, NDI.DATABASE.BINARYDOC/EQ, NDI.DATABASE.BINARYDOC/GT, NDI.DATABASE.BINARYDOC/LE, NDI.DATABASE.BINARYDOC/LT, NDI.DATABASE.BINARYDOC/NE

Help for ndi.database.binarydoc/ge is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.database.binarydoc/ge


---

**gt** - *> (GT)   Greater than relation for handles.*

H1 > H2 performs element-wise comparisons between handle arrays H1 and 
    H2.  H1 and H2 must be of the same dimensions unless one is a scalar.  
    The result is a logical array of the same dimensions, where each
    element is an element-wise > result.
 
    If one of H1 or H2 is scalar, scalar expansion is performed and the 
    result will match the dimensions of the array that is not scalar.
 
    TF = GT(H1, H2) stores the result in a logical array of the same 
    dimensions.
 
    See also NDI.DATABASE.BINARYDOC, NDI.DATABASE.BINARYDOC/EQ, NDI.DATABASE.BINARYDOC/GE, NDI.DATABASE.BINARYDOC/LE, NDI.DATABASE.BINARYDOC/LT, NDI.DATABASE.BINARYDOC/NE

Help for ndi.database.binarydoc/gt is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.database.binarydoc/gt


---

**isvalid** - *ISVALID   Test handle validity.*

TF = ISVALID(H) performs an element-wise check for validity on the 
    handle elements of H.  The result is a logical array of the same 
    dimensions as H, where each element is the element-wise validity 
    result.
 
    A handle is invalid if it has been deleted or if it is an element
    of a handle array and has not yet been initialized.
 
    See also NDI.DATABASE.BINARYDOC, NDI.DATABASE.BINARYDOC/DELETE

Help for ndi.database.binarydoc/isvalid is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.database.binarydoc/isvalid


---

**le** - *<= (LE)   Less than or equal relation for handles.*

Handles are equal if they are handles for the same object.  All 
    comparisons use a number associated with each handle object.  Nothing
    can be assumed about the result of a handle comparison except that the
    repeated comparison of two handles in the same MATLAB session will 
    yield the same result.  The order of handle values is purely arbitrary 
    and has no connection to the state of the handle objects being 
    compared.
 
    H1 <= H2 performs element-wise comparisons between handle arrays H1 and
    H2.  H1 and H2 must be of the same dimensions unless one is a scalar.
    The result is a logical array of the same dimensions, where each
    element is an element-wise >= result.
 
    If one of H1 or H2 is scalar, scalar expansion is performed and the 
    result will match the dimensions of the array that is not scalar.
 
    TF = LE(H1, H2) stores the result in a logical array of the same 
    dimensions.
 
    See also NDI.DATABASE.BINARYDOC, NDI.DATABASE.BINARYDOC/EQ, NDI.DATABASE.BINARYDOC/GE, NDI.DATABASE.BINARYDOC/GT, NDI.DATABASE.BINARYDOC/LT, NDI.DATABASE.BINARYDOC/NE

Help for ndi.database.binarydoc/le is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.database.binarydoc/le


---

**listener** - *LISTENER  Add listener for event without binding the listener to the source object.*

el = LISTENER(hSource, Eventname, callbackFcn) creates a listener
    for the event named Eventname.  The source of the event is the handle  
    object hSource.  If hSource is an array of source handles, the listener
    responds to the named event on any handle in the array.  callbackFcn
    is a function handle that is invoked when the event is triggered.
 
    el = LISTENER(hSource, PropName, Eventname, callback) adds a 
    listener for a property event.  Eventname must be one of  
    'PreGet', 'PostGet', 'PreSet', or 'PostSet'. Eventname can be a 
    string sclar or character vector.  PropName must be either a single 
    property name specified as a string scalar or character vector, or 
    a collection of property names specified as a cell array of character 
    vectors or a string array, or as an array of one ore more 
    meta.property objects. The properties must belong to the class of 
    hSource.  If hSource is scalar, PropName can include dynamic 
    properties.
    
    For all forms, listener returns an event.listener.  To remove a
    listener, delete the object returned by listener.  For example,
    delete(el) calls the handle class delete method to remove the listener
    and delete it from the workspace.  Calling delete(el) on the listener
    object deletes the listener, which means the event no longer causes
    the callback function to execute. 
 
    LISTENER does not bind the listener's lifecycle to the object that is
    the source of the event.  Destroying the source object does not impact
    the lifecycle of the listener object.  A listener created with LISTENER
    must be destroyed independently of the source object.  Calling 
    delete(el) explicitly destroys the listener. Redefining or clearing 
    the variable containing the listener can delete the listener if no 
    other references to it exist.  To tie the lifecycle of the listener to 
    the lifecycle of the source object, use addlistener.
 
    See also ADDLISTENER, EVENT.LISTENER, NDI.DATABASE.BINARYDOC, NOTIFY, DELETE, META.PROPERTY, EVENTS

Help for ndi.database.binarydoc/listener is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.database.binarydoc/listener


---

**lt** - *< (LT)   Less than relation for handles.*

H1 < H2 performs element-wise comparisons between handle arrays H1 and
    H2.  H1 and H2 must be of the same dimensions unless one is a scalar.
    The result is a logical array of the same dimensions, where each
    element is an element-wise < result.
 
    If one of H1 or H2 is scalar, scalar expansion is performed and the 
    result will match the dimensions of the array that is not scalar.
 
    TF = LT(H1, H2) stores the result in a logical array of the same 
    dimensions.
 
    See also NDI.DATABASE.BINARYDOC, NDI.DATABASE.BINARYDOC/EQ, NDI.DATABASE.BINARYDOC/GE, NDI.DATABASE.BINARYDOC/GT, NDI.DATABASE.BINARYDOC/LE, NDI.DATABASE.BINARYDOC/NE

Help for ndi.database.binarydoc/lt is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.database.binarydoc/lt


---

**ne** - *~= (NE)   Not equal relation for handles.*

Handles are equal if they are handles for the same object and are 
    unequal otherwise.
 
    H1 ~= H2 performs element-wise comparisons between handle arrays H1 
    and H2.  H1 and H2 must be of the same dimensions unless one is a 
    scalar.  The result is a logical array of the same dimensions, where 
    each element is an element-wise equality result.
 
    If one of H1 or H2 is scalar, scalar expansion is performed and the 
    result will match the dimensions of the array that is not scalar.
 
    TF = NE(H1, H2) stores the result in a logical array of the same
    dimensions.
 
    See also NDI.DATABASE.BINARYDOC, NDI.DATABASE.BINARYDOC/EQ, NDI.DATABASE.BINARYDOC/GE, NDI.DATABASE.BINARYDOC/GT, NDI.DATABASE.BINARYDOC/LE, NDI.DATABASE.BINARYDOC/LT

Help for ndi.database.binarydoc/ne is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.database.binarydoc/ne


---

**notify** - *NOTIFY   Notify listeners of event.*

NOTIFY(H, eventname) notifies listeners added to the event named 
    eventname for handle object array H that the event is taking place. 
    eventname can be a string scalar or character vector.  
    H is the array of handles to the event source objects, and 'eventname'
    must be a character vector.
 
    NOTIFY(H,eventname,ed) provides a way of encapsulating information 
    about an event which can then be accessed by each registered listener.
    ed must belong to the EVENT.EVENTDATA class.
 
    See also NDI.DATABASE.BINARYDOC, NDI.DATABASE.BINARYDOC/ADDLISTENER, NDI.DATABASE.BINARYDOC/LISTENER, EVENT.EVENTDATA, EVENTS

Help for ndi.database.binarydoc/notify is inherited from superclass HANDLE

    Reference page in Doc Center
       doc ndi.database.binarydoc/notify


---

