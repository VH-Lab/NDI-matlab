classdef WhiteMatterSessionFixture < matlab.unittest.fixtures.Fixture
    
    properties (Constant)
        
        Reader = ndr.reader('whitematter'); % The reader object instance
        HeaderBytes = 8;  % Standard header size for WM files
        ByteOrder = 'ieee-le'; % Default byte order
        DataType = 'int16'; % Data type for samples
        
    end
       
    properties (SetAccess = immutable)
        NumSubjects double % Number of subjects
        NumChannels double % Number of channels per subject
        NumSamples double % Number of samples per channel
        NumEpochs double % Number of epochs
        SampleRate double % Sampling rate (Hz)
        TempDir char % Temporary directory for test files
        DataFile char  % Full path to the data file
        ProbeFile char % Full path to the epoch probe map file
        HeaderInfo struct % Parsed header info
        Session % NDI session
        Probes % NDI probes
        OneEpoch % OneEpoch elements
    end

    methods
        function fixture = WhiteMatterSessionFixture(options)
            arguments
                options.NumSubjects (1,1) double {mustBePositive,mustBeReal} = 1;
                options.NumChannels (1,1) double {mustBePositive,mustBeReal} = 1;
                options.NumSamples (1,1) double {mustBePositive,mustBeReal} = 100;
                options.NumEpochs (1,1) double {mustBePositive,mustBeReal} = 2;
                options.SampleRate (1,1) double {mustBePositive,mustBeReal} = 100;
            end
            propNames = fieldnames(options);
            for i = 1:numel(propNames)
                fixture.(propNames{i}) = options.(propNames{i});
            end
            % fixture.NumSubjects = options.NumSubjects;
            % fixture.NumChannels = options.NumChannels
            % fixture.NumSamples = options.NumSamples
            % fixture.NumEpochs = options.NumEpochs
            % fixture.SampleRate = options.SampleRate
        end

        function setup(fixture)

            %  % Create a temporary directory
            % import matlab.unittest.fixtures.TemporaryFolderFixture
            % tempFolderFix = fixture.applyFixture(TemporaryFolderFixture);
            % disp(tempFolderFix.SetupDescription);
            % fixture.TempDir = tempFolderFix.Folder;
            % 
            % % Initialize the reader here
            % fixture.Reader = ndr.reader('whitematter');
            % fixture.assertClass(fixture.Reader, 'ndr.reader', 'Reader initialization failed.');

        end
        
        function teardown(fixture)

        end

    end

    methods (Access=protected)
        function tf = isCompatible(fixture1,fixture2)
            tf = fixture1.Format == fixture2.Format;
        end
    end

end