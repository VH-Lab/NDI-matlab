# How to Write a New Stimulus Reader Class in NDI

This document outlines the steps to create a new stimulus reader class within the `ndi.setup.daq.reader.mfdaq.stimulus` package. These classes are responsible for interpreting stimulus presentation data (often from metadata files) and exposing them as NDI event or marker channels, synchronized with the underlying DAQ system.

## 1. Choose the Base Class

Your new class should inherit from an existing `ndi.daq.reader.mfdaq` class that handles the raw data acquisition format or hardware used in your setup.

*   If your system uses Blackrock files, inherit from `ndi.daq.reader.mfdaq.blackrock`.
*   If your system uses Intan files, inherit from `ndi.daq.reader.mfdaq.intan`.
*   If your system uses CED Spike2 files, inherit from `ndi.daq.reader.mfdaq.cedspike2`.
*   If your system uses another format, ensure there is a corresponding reader in `ndi.daq.reader.mfdaq` or create one first.

**Example Declaration:**
```matlab
classdef my_stimulus_reader < ndi.daq.reader.mfdaq.intan
```

## 2. Implement the Constructor

The constructor should accept standard arguments (usually passed as `varargin`) and pass them to the superclass constructor.

**Example:**
```matlab
    methods
        function obj = my_stimulus_reader(varargin)
            % MY_STIMULUS_READER - Create a new stimulus reader object
            %
            %  OBJ = MY_STIMULUS_READER(NAME, THEFILENAVIGATOR, DAQREADER)
            %
            obj = obj@ndi.daq.reader.mfdaq.intan(varargin{:});
        end
```

## 3. Define Virtual Channels (`getchannelsepoch`)

Override the `getchannelsepoch` method to define the "virtual" channels that this reader will provide. These are typically markers (`mk`) or events (`e`) that represent stimulus properties (e.g., Stimulus On/Off, Stimulus ID).

**Key properties for channels:**
*   `name`: e.g., 'mk1', 'mk2', 'e1'.
*   `type`: usually 'marker' or 'event'.
*   `time_channel`: usually `NaN` (indicating they share the time base of the device).

**Example:**
```matlab
        function channels = getchannelsepoch(thedev, epochfiles)
            % Define the channels available in this epoch
            channels        = struct('name','mk1','type','marker','time_channel',NaN); % Stimulus On/Off
            channels(end+1) = struct('name','mk2','type','marker','time_channel',NaN); % Stimulus ID
        end
```

## 4. Implement Event Reading (`readevents_epochsamples_native`)

Override `readevents_epochsamples_native` to perform the core logic: reading stimulus metadata, aligning it with DAQ triggers, and returning the data.

**Steps:**
1.  **Locate and Read Metadata:** Use `epochfiles` to find the relevant metadata files (e.g., `.mat`, `.txt`, `.xml`) produced by the stimulus computer. You may need to use helper functions or classes to parse these files.
2.  **Read Synchronization Triggers:** Use the inherited `readchannels_epochsamples` method to read digital triggers recorded on the DAQ system. These triggers often indicate the precise start/stop times of stimuli.
3.  **Align and Decode:** Combine the metadata (which tells you *what* was shown and *roughly when*) with the DAQ triggers (which tell you *exactly when*).
    *   Match stimulus IDs from metadata to the trigger times.
    *   Handle any discrepancies (dropped frames, missing triggers).
4.  **Format Output:** Return `timestamps` and `data` for the requested channels.
    *   `timestamps`: A column vector of times.
    *   `data`: Corresponding data values (e.g., `1`/`-1` for On/Off, or Integer IDs).

**Example Skeleton:**
```matlab
        function [timestamps,data] = readevents_epochsamples_native(obj, channeltype, channel, epochfiles, t0, t1)
            timestamps = {};
            data = {};

            % 1. Parse 'channeltype' to handle single string or cell array inputs
            if ~iscell(channeltype), channeltype = repmat({channeltype},numel(channel),1); end

            % 2. Read Metadata from epochfiles
            % (Implementation depends on your file format)
            % [stim_ids, stim_params] = read_my_metadata(epochfiles);

            % 3. Read DAQ Digital Triggers (if needed for syncing)
            % [dig_data] = obj.readchannels_epochsamples('digital_in', [1], epochfiles, ...);
            % trigger_times = find_triggers(dig_data);

            % 4. Align Metadata and Triggers
            % matched_times = align_data(trigger_times, stim_ids);

            % 5. Construct Output for requested channels
            for i=1:numel(channel)
                switch (ndi.daq.system.mfdaq.mfdaq_prefix(channeltype{i}))
                    case 'mk'
                        % Populate timestamps{i} and data{i}
                        % e.g., channel 1 is Stim On/Off, channel 2 is Stim ID
                    case 'e'
                        % Populate events
                    otherwise
                        error(['Unknown channel.']);
                end
            end

            % Filter by requested time range [t0, t1]
            % ...

            % Unwrap cell array if single channel requested
            if numel(data)==1, timestamps = timestamps{1}; data = data{1}; end
        end
```

## 5. Override `epochclock` (Optional)

If your device uses the standard local time of the DAQ system, you usually do not need to change this. However, some implementations explicitly return `ndi.time.clocktype('dev_local_time')`.

## 6. Metadata Readers (`ndi.daq.metadatareader`)

To keep the stimulus reader class focused on synchronization and data formatting, parsing complex metadata files is often offloaded to a dedicated **Metadata Reader** class.

These classes are found in `src/ndi/+ndi/+daq/+metadatareader/` or `src/ndi/+ndi/+setup/+daq/+metadatareader/`.

### How to Write a New Metadata Reader

1.  **Inherit from `ndi.daq.metadatareader`**:
    Your new class must inherit from `ndi.daq.metadatareader`.

    ```matlab
    classdef my_metadata_reader < ndi.daq.metadatareader
    ```

2.  **Override `readmetadatafromfile`**:
    This is the core method you must implement. It takes a filename, parses it, and returns a cell array of parameter structures.

    ```matlab
    methods
        function parameters = readmetadatafromfile(obj, file)
            % READMETADATAFROMFILE - Read metadata from the specified file
            %
            % PARAMETERS = READMETADATAFROMFILE(OBJ, FILE)
            %
            % Returns a cell array where PARAMETERS{i} is a structure
            % containing the parameters for the i-th stimulus.

            parameters = {};

            % Example: Loading a MATLAB file
            data = load(file, '-mat');

            % Iterate through loaded data and populate the cell array
            for i = 1:numel(data.stimuli)
                parameters{i} = data.stimuli(i);
            end
        end
    end
    ```

3.  **Use in Stimulus Reader**:
    In your main stimulus reader class (step 4 above), instantiate and use your metadata reader:

    ```matlab
    md_reader = ndi.setup.daq.metadatareader.my_metadata_reader();
    parameters = md_reader.readmetadatafromfile(my_metadata_file);
    ```

## Examples in Codebase

Refer to the following files in `src/ndi/+ndi/+setup/+daq/+reader/+mfdaq/+stimulus/` for concrete examples:

*   **`angelucci_visstim.m`**: Example using `ndi.daq.reader.mfdaq.blackrock` and a separate metadata reader class.
*   **`nielsenvisintan.m`**: Example using `ndi.daq.reader.mfdaq.intan`, reading `.analyzer` files and aligning with digital inputs.
*   **`vhlabvisspike2.m`**: Example using `ndi.daq.reader.mfdaq.cedspike2`, reading text files and Spike2 files.

For metadata readers, see:
*   `src/ndi/+ndi/+daq/metadatareader.m` (Base class)
*   `src/ndi/+ndi/+setup/+daq/+metadatareader/AngelucciStims.m`
*   `src/ndi/+ndi/+daq/+metadatareader/NewStimStims.m`
