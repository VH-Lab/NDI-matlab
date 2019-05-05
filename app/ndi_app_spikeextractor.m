classdef ndi_app_spikeextractor < ndi_app

	properties (SetAccess=protected,GetAccess=public)


	end % properties

	methods

		function ndi_app_spikeextractor_obj = ndi_app_spikeextractor(varargin)
			% NDI_APP_SPIKEEXTRACTOR - an app to extract probes found in experiments
			%
			% NDI_APP_SPIKEEXTRACTOR_OBJ = NDI_APP_SPIKEEXTRACTOR(EXPERIMENT)
			%
			% Creates a new NDI_APP_SPIKEEXTRACTOR object that can operate on
			% NDI_EXPERIMENTS. The app is named 'ndi_app_spikeextractor'.
			%
				experiment = [];
				name = 'ndi_app_spikeextractor';
				if numel(varargin)>0,
					experiment = varargin{1};
				end
				ndi_app_spikeextractor_obj = ndi_app_spikeextractor_obj@ndi_app(experiment, name);

		end % ndi_app_spikeextractor() creator

        function spike_extract_probes(ndi_app_spikeextractor_obj, name, type, extraction_name, extraction_params) %, sorting_params)
			% extraction_params is a struct or a string address to file
			% Extracts probe with name
			probes = ndi_app_spikeextractor_obj.experiment.getprobes('name', name, 'type', type); % can add reference

			% Need to pass in the extraction parameters and sorting parameters

			% TODO Handle an ndi_document

			%If extraction_params was inputed as a struct then no need to parse it
            if isstruct(extraction_params)

                extraction_parameters = extraction_params;
                % Consider saving in some var_branch_within probe_branch
            elseif isa(extraction_params, 'char') % TODO fix loading struct to loading an ndi doc
                extraction_parameters = loadStructArray(extraction_params);
                % Consider saving in some var_branch_within probe_branch
            else
                error('unable to handle extraction_params.');
            end

			% %If sorting_params was inputed as a struct then no need to parse it
	        % if isstruct(sorting_params)
	        %     sorting_parameters = sorting_params;
	        %     %Save to var struct
	        %     %extraction_parameters_var_struct.writeStructArray(parameters);
	        % %Else we parse it
	        % elseif isa(parameters, 'char')
	        %     sorting_parameters = loadStructArray(sorting_params);
	        %     %Save to var struct
	        %     %extraction_parameters_var_struct.writeStructArray(extraction_parameters);
	        % else
	        %     error(['unable to handle sorting_params.']);
	        % end

			for prb=1:length(probes)
				%Set probe to variable
				probe = probes{prb};
				%Calculate number of epochs based on probe
			    numberofepochs = probe.numepochs();
			    %Device sample rate
			    sample_rate = samplerate(probe,1);
				%For every epoch in probe we read...
			    for n=1:numberofepochs
			        %extract and store file
			        %for all samples loop inf 30000
			        %Variable to know if end of file reached
					start_time = 1;
			        endReached = 0;
					spikewavesfid = -1;

					center_range       = extraction_parameters.center_range;
					interpolation      = extraction_parameters.interpolation;
					read_size          = extraction_parameters.read_size;
					overlap            = extraction_parameters.overlap;
					refractory_samples = extraction_parameters.refractory_samples;
					spike_sample_start = extraction_parameters.spike_sample_start;
					spike_sample_end   = extraction_parameters.spike_sample_end;

					epochtic = tic;
					disp(['Epoch ' int2str(n) ' spike extraction started...']);
			        while (~endReached)

			            end_time = start_time + read_size * sample_rate;

			    		data = read_epochsamples(probe,n,start_time, end_time); % SpikeGadgets

			            if abs(length(data) - ((end_time - start_time) + 1)) > 2 % | T(end)>100,
			                endReached = 1;
			            end

			            %Applies Chebyshev Type I filter to channels
			            [b,a] = cheby1(4,0.8,300/(0.5 * sample_rate),'high');
			            data = filtfilt(b,a,data);

			            %plot_multichan(data,1:30000,400);

			            %Spike locations stored here
			            locations = [];

			            %For number of channels
			            for j=1:size(data,2) %channel
			                %Calculate stdev for channel j
			                stddev = std(data(:,j));
			                %Dot discriminator to find thresholds
			                locations{j} = dotdisc(double(data(:,j)),[-4*stddev -1 0]); % 4*stddev
			                %Accomodates spikes according to refractory period
			                locations{j} = refractory(locations{j}, refractory_samples);
			                locations{j} = locations{j}(find(locations{j} > -spike_sample_start & locations{j} <= length(data(:,j))-spike_sample_end));
			            end

			            %All channels spike locations will be stored here
			            locs = [];
						%Storing all channels spike locations
			            for j=1:size(data,2)
			                locs = [locs; locations{j}(:)];
			            end

			            %Sorts locs
			            locs = sort(locs);

						%Apply refractory period to all channels locs
						locs = refractory(locs, refractory_samples);

			    		sample_offsets = repmat([spike_sample_start:spike_sample_end]',1,size(data,2));

			    		channel_offsets = repmat([0:size(data,2)-1], spike_sample_end - spike_sample_start + 1,1);

			    		single_spike_selection = sample_offsets + channel_offsets*size(data,1);

			    		spike_selections = repmat(single_spike_selection(:)', length(locs), 1) + repmat(locs(:), 1, prod(size(sample_offsets)));

			    		waveforms = single(data(spike_selections))'; % (spike-spike-spike-spike) X Nspikes

			    		waveforms = reshape(waveforms, spike_sample_end - spike_sample_start + 1, size(data,2), length(locs)); % Nsamples X Nchannels X Nspikes

			            waveforms = permute(waveforms,[3 1 2]); % Nspikes X Nsamples X Nchannels

			            %Center spikes
			    		waveforms = centerspikes_neg(waveforms,center_range);

			            %Uncomment to plot specific spike
				            %figure(1);
				            %spike = squeeze(waveforms(1,:,:));
							%plot(spike);
				            %plot_multichan(spike,spike_samples(1):spike_samples(2),400);
							%keyboard

						%If start_time == 1 then we have a new epoch
			            % WARNING POTENTIAL SOURCE OF BUGS AS NOT ALWAYS WILL WE BE READING AT BEGINNING OF FILE
			            % SO REMEMBER TO ADD OPTION FOR FULL REWRITE OF FILES
			            if start_time==1
							% Clear extraction within probe with extraction_name
							ndi_app_spikeextractor_obj.clear_extraction(probe, extraction_name)

							% Create extraction parameters ndi_doc
							extraction_parameters_doc = ndi_app_spikeextractor_obj.experiment.newdocument('apps/spikeextractor/extraction_parameters', 'extraction_parameters', extraction_parameters) ...
								+ probe.newdocument() + ndi_app_spikeextractor_obj.newdocument();
							% Create spikes ndi_doc
							spikes_doc = ndi_app_spikeextractor_obj.experiment.newdocument('apps/spikeextractor/spikes', ...
							'spike_extraction.extraction_name', extraction_name, ...
							'spike_extraction.extraction_parameters_file_id', extraction_parameters_doc.doc_unique_id()) ...
								+ probe.newdocument() + ndi_app_spikeextractor_obj.newdocument();

							times_doc = ndi_app_spikeextractor_obj.experiment.newdocument('apps/spikeextractor/times', ...
							'spike_extraction.extraction_name', extraction_name, ...
							'spike_extraction.extraction_parameters_file_id', extraction_parameters_doc.doc_unique_id()) ...
								+ probe.newdocument() + ndi_app_spikeextractor_obj.newdocument();

							% Add docs to database
							ndi_app_spikeextractor_obj.experiment.database.add(extraction_parameters_doc);
							ndi_app_spikeextractor_obj.experiment.database.add(spikes_doc);
							ndi_app_spikeextractor_obj.experiment.database.add(times_doc);

							% WARNING spike extractor varbranch here
							%[current_waveforms_file, current_spiketimes_file] = ndi_app_spikeextractor_obj.create_extraction_varbranch(probe, extraction_name, extraction_parameters)
			                %Create variable file waveforms within spike_extraction to store waveforms
			                %disp(['creating waveforms variable file within spike_extraction...']);
			                %current_waveforms_file = ndi_variable(spike_extraction, ['spikewaves_epoch_' int2str(n)],'file','spikewaves',[],'Extracted spike waveforms binary file','extracted by ndi_app_spikeextractor');

							%Create variable file waveforms within spike_extraction to store waveforms
			                %disp(['creating spiketimes variable file within spike_extraction...']);
			                %current_spiketimes_file = ndi_variable(spike_extraction, ['spiketimes_epoch_' int2str(n)],'file','spiketimes',[],'Extracted spike times binary file','extracted by ndi_app_spikeextractor');

			                %struct with parameters written in spikewaveforms header
			                fileparameters.numchannels = size(data,2);
			                fileparameters.S0 = spike_sample_start * interpolation - interpolation + 1;
			                fileparameters.S1 = spike_sample_end * interpolation;
			                fileparameters.name = probe.name;
			                fileparameters.ref =  probe.reference;

							%if channel list is to be saved in files somwhere accessed with the method below
							%[dev, devname, devepoch, channeltype, channellist] = getchanneldevinfo(probe, n)

			                fileparameters.comment = n; %epoch % used to be devicename and channels read
			                fileparameters.samplingrate = double(samplerate(probe,1));
			                fileparameters,
			                % Detailed parameter information
			                % parameters.numchannels (uint8)    : Number of channels
			                % parameters.S0 (int8)              : Number of samples before spike center
			                %                                   :  (usually negative)
			                % parameters.S1 (int8)              : Number of samples after spike center
			                %                                   :  (usually positive)
			                % parameters.name (80xchar)         : Name (up to 80 characters)
			                % parameters.ref (uint8)            : Reference number
			                % parameters.comment (80xchar)      : Up to 80 characters of comment
			                % parameters.samplingrate           : The sampling rate (float32)
			                % (first 512 bytes are free for additional header use)

							% TODO handle the ndi_document way
							%if ~isempty(ndi_app_spikeextractor_obj.loadspikes)

							%end
							%probes{prb}.newdocument(,'')
							%Filename of variable file current_waveforms_file

							spikewaves_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database.openbinarydoc(spikes_doc)

			                %spikewavesfilename = current_waveforms_file.filename();
			                %disp(['spikewaves filename: ' spikewavesfilename]);
			                %Add header to variable file current_waveforms_file
			                %Stores spikewavesfid
			                %spikewavesfid = newvhlspikewaveformfile(spikewavesfilename, fileparameters);
							%fclose(spikewavesfid);

							% write header
							spikewaves_binarydoc_fid.fseek(0,'bof');                                            % now at 0 bytes
							spikewaves_binarydoc_fid.fwrite(uint8(fileparameters.numchannels),'uint8');         % now at 1 byte
							spikewaves_binarydoc_fid.fwrite(int8(fileparameters.S0),'int8');                    % now at 2 bytes
							spikewaves_binarydoc_fid.fwrite(int8(fileparameters.S1),'int8');                    % now at 3 bytes

							if length(fileparameters.name)>80,
								fileparameters.name = fileparameters.name(1:80);
							end;
							spikewaves_binarydoc_fid.fwrite(fileparameters.name,'char');
							spikewaves_binarydoc_fid.fwrite(zeros(1,80-length(fileparameters.name)),'char');    % now at 83 bytes

							spikewaves_binarydoc_fid.fwrite(uint8(fileparameters.ref),'uint8');                 % now at 84 bytes

							if length(fileparameters.comment)>80,
								fileparameters.comment = fileparameters.comment(1:80);
							end;

							spikewaves_binarydoc_fid.fwrite(fileparameters.comment,'char');
							spikewaves_binarydoc_fid.fwrite(zeros(1,80-length(fileparameters.comment)),'char');      % now at 164 bytes
							spikewaves_binarydoc_fid.fwrite(single(fileparameters.samplingrate),'float32');      % now at 168 bytes

							% about to write byte 168; we want to fill up to 512 with 0's
							%  this is 512-168+1 bytes
							spikewaves_binarydoc_fid.fwrite(zeros(1,512-168),'uint8');

							spikewaves_binarydoc_fid.fseek(512,'bof');

							% Close the spikewaves doc
							ndi_app_spikeextractor_obj.experiment.database.closebinarydoc(spikewaves_binarydoc_fid)

							%Filename of variable file current_spiketimes_file
			                %spiketimesfilename = current_spiketimes_file.filename();
			                %disp(['spiketimes filename: ' spiketimesfilename]);
			                %Add header to variable file current_waveforms_file
			                %Stores spikewavesfid
			                %spiketimesfid = newspiketimesfile(spiketimesfilename, fileparameters);
							%fclose(spiketimesfid);

							spiketimes_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database.openbinarydoc(times_doc)

							% write header
							spiketimes_binarydoc_fid.fseek(0,'bof');                                        % now at 0 bytes
							spiketimes_binarydoc_fid.fwrite(uint8(fileparameters.numchannels),'uint8');         % now at 1 byte
							spiketimes_binarydoc_fid.fwrite(int8(fileparameters.S0),'int8');                    % now at 2 bytes
							spiketimes_binarydoc_fid.fwrite(int8(fileparameters.S1),'int8');                    % now at 3 bytes

							if length(fileparameters.name)>80,
							   fileparameters.name = fileparameters.name(1:80);
							end;

							spiketimes_binarydoc_fid.fwrite(fileparameters.name,'char');
							spiketimes_binarydoc_fid.fwrite(zeros(1,80-length(fileparameters.name)),'char');    % now at 83 bytes

							spiketimes_binarydoc_fid.fwrite(uint8(fileparameters.ref),'uint8');                 % now at 84 bytes

							if length(fileparameters.comment)>80,
							   fileparameters.comment = fileparameters.comment(1:80);
							end;

							spiketimes_binarydoc_fid.fwrite(fileparameters.comment,'char');
							spiketimes_binarydoc_fid.fwrite(zeros(1,80-length(fileparameters.comment)),'char'); % now at 164 bytes

							spiketimes_binarydoc_fid.fwrite(single(fileparameters.samplingrate),'float32');      % now at 168 bytes

							% about to write byte 168; we want to fill up to 512 with 0's
							%  this is 512-168+1 bytes
							spiketimes_binarydoc_fid.fwrite(zeros(1,512-168),'uint8');

							spiketimes_binarydoc_fid.fseek(512,'bof');

							% Close the spiketimes doc
							ndi_app_spikeextractor_obj.experiment.database.closebinarydoc(spiketimes_binarydoc_fid)
			            end
			            %Permute waveforms for addvhlspikewaveformfile to Nsamples X Nchannels X Nspikes
			            waveforms = permute(waveforms, [2 3 1]);

						%Interpolation of waveforms
						interpolated_waveforms = [];
						%Required vectors for interpolation
						spikelength = spike_sample_end - spike_sample_start + 1;
						x = 1:spikelength;
					    xq = 1/interpolation: 1/interpolation :spikelength; % 1/3 sets up interpolation at 3x

						% WARNING CHECK TRANSPOSES FOR BUGS

						%For number of spikes
						for i=1:size(waveforms, 3);
							%Clear variable to store [interp_spike-interp_spike-interp_spike-interp_spike]
							interpolated_spikes = [];
			                 %i
							%For channelspike in tetrode
			  				for channelspike=1:size(waveforms, 2)
			  					%Get one channelspike [spike-spike-spike-spike]
			                    current_spike = waveforms(:,channelspike,i);
			            		%disp('start');
			            		%(((i-1) * spikelength * size(waveforms, 2))+((channelspike-1) * spikelength) + 1)
			            		%disp('end');
			            		%((i-1) * spikelength * size(waveforms, 2))*(channelspike * spikelength)
			            		%current_spike = waveforms( (((i-1) * spikelength * size(waveforms, 2))+((channelspike-1) * spikelength) + 1):((i-1) * spikelength * size(waveforms, 2))+(channelspike * spikelength) );
			            		current_spike = double(current_spike);
			                    %channelspike
			                    %disp('length current_spike');
			                    %length(current_spike)
			            		%Interpolate channelspike
			            		interpolated_spike = interp1(x, current_spike, xq, 'spline');
			            		%Add to [interpolated_spike-interpolated_spike-interpolated_spike-interpolated_spike]
			            		interpolated_spikes = [interpolated_spikes interpolated_spike];
			                end
			                %figure(11);
			                %plot(interpolated_spikes);
			                %keyboard
							%Add in new row to waveforms to be written to file
							interpolated_waveforms = [interpolated_waveforms; interpolated_spikes];
			            end

			            interpolated_waveforms = interpolated_waveforms';

			            %Reshape array to store in file
			            interpolated_waveforms = reshape(interpolated_waveforms, spikelength * interpolation, size(waveforms,2), size(waveforms,3));
			      		%Uncomment to plot example interpolated_spikes
			      		%figure(10);
			      		%plot(interpolated_spikes);
			            %keyboard

			            %Permute waveforms for addvhlspikewaveformfile to Nsamples X Nchannels X Nspikes
			            %interpolated_waveforms = permute(interpolated_waveforms, [2 3 1]);

			            %Store epoch waveforms in file

			            %addvhlspikewaveformfile(current_waveforms_file.filename(), interpolated_waveforms);
						% TODO open every time or keep open?
						spikewaves_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database.openbinarydoc(spikes_doc);
						[num_samples,numchannels,num_waveforms] = size(interpolated_waveforms);
						% we need the spikes waveforms to be represented in the columns of the matrix
						% this means we need to push all of the channels into 1 dimension
						interpolated_waveforms = single(reshape(interpolated_waveforms,num_samples*numchannels,num_waveforms));
						spikewaves_binarydoc_fid.fseek(0,'eof');  % go to the end
						spikewaves_binarydoc_fid.fwrite(single(interpolated_waveforms),'float32');
						ndi_app_spikeextractor_obj.experiment.database.closebinarydoc(spikewaves_binarydoc_fid);
						%finalwaves = cat()
			      		%Store epoch spike times in file
			      		%addspiketimesfile(current_spiketimes_file.filename(), locs);
						spiketimes_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database.openbinarydoc(times_doc);
						spiketimes_binarydoc_fid.fseek(0,'eof');  % go to the end
						spiketimes_binarydoc_fid.fwrite(double(locs),'float32');
						ndi_app_spikeextractor_obj.experiment.database.closebinarydoc(spiketimes_binarydoc_fid);
			            %finaltimes = [finaltimes locs];
			            %Update start_time
			            start_time = start_time + read_size * sample_rate - overlap * sample_rate;
			        end %while ~endReached

					disp(['Epoch ' int2str(n) ' spike extraction done.']);
			    end %epoch n
			end %prb
		end %function

		function b = clear_extraction(ndi_app_spikeextractor_obj, ndi_probe_obj, extraction_name)
			% CLEARSPIKEWAVES - clear all 'spikewaves' records for an NDI_PROBE_OBJ from experiment database
			%
			% B = CLEARSPIKEWAVES(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_EPOCHSET_OBJ)
			%
			% Clears all spikewaves entries from the experiment database for object NDI_PROBE_OBJ.
			%
			% Returns 1 on success, 0 otherwise.
			%%%
			% See also: NDI_APP_MARKGARBAGE/MARKVALIDINTERVAL, NDI_APP_MARKGARBAGE/SAVEALIDINTERVAL, ...
			%      NDI_APP_MARKGARBAGE/LOADVALIDINTERVAL

			% Look for any docs matching extraction name and remove them
			% Concatenate app query parameters and extraction_name parameter
			searchq = cat(2,ndi_app_spikeextractor_obj.searchquery(), ...
				{'spike_extraction.extraction_name', extraction_name});

			% Concatenate probe query parameters
			searchq = cat(2, searchq, ndi_probe_obj.searchquery());

			% Search and get any docs
			mydoc = ndi_app_spikeextractor_obj.experiment.database.search(searchq);

			% Remove the docs
			if ~isempty(mydoc),

				for i=1:numel(mydoc),
					ndi_app_spikeextractor_obj.experiment.database.remove(mydoc{i}.doc_unique_id)
				end
				warning(['removed ' num2str(i) ' doc(s) with same extraction name'])
				b = 1;
			end
		end % clearvalidinteraval()

		function concatenated_spikes = load_spikes(ndi_app_spikeextractor_obj, ndi_probe_obj, extraction_name)
			% LOADSPIKES - Load all spikewaves records from experiment database
			%
			% SW = LOADSPIKES(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_PROBE_OBJ, EXTRACTION_NAME)
			%
			% Loads stored spikewaves generated by NDI_APP_SPIKEEXTRACTOR/SPIKE_EXTRACT_PROBES
			%
				spikes_searchq = cat(2, ndi_app_spikeextractor_obj.searchquery(), ...
					{'document_class.class_name','spikes'});
				spikes_searchq = cat(2, spikes_searchq, ndi_probe_obj.searchquery());
				spikes_searchq = cat(2, spikes_searchq, ...
					{'spike_extraction.extraction_name', extraction_name});
				docs = ndi_app_spikeextractor_obj.experiment.database.search(spikes_searchq);

				% TODO How to get them in order? maybe add epoch_number to spikes and times ndi_doc
				if ~isempty(docs)
					% TODO make sure multiple epochs work
					for i=1:numel(docs)
						spikes_doc = ndi_app_spikeextractor_obj.experiment.database.read(docs{i}.doc_unique_id);
						spikewaves_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database.openbinarydoc(spikes_doc);
						waveforms = [];

						header_size = 512; % 512 bytes in the header

						 % step 1 - read header
						spikewaves_binarydoc_fid.fseek(0,'bof');
						parameters.numchannels = spikewaves_binarydoc_fid.fread(1,'uint8');      % now at 1 byte
						parameters.S0 = spikewaves_binarydoc_fid.fread(1,'int8');                % now at 2 bytes
						parameters.S1 = spikewaves_binarydoc_fid.fread(1,'int8');                % now at 3 bytes
						parameters.name = spikewaves_binarydoc_fid.fread(80,'char');             % now at 83 bytes
						parameters.name = char(parameters.name(find(parameters.name)))';
						parameters.ref = spikewaves_binarydoc_fid.fread(1,'uint8');              % now at 84 bytes
						parameters.comment = spikewaves_binarydoc_fid.fread(80,'char');          % now at 164 bytes
						parameters.comment = char(parameters.comment(find(parameters.comment)))';
						parameters.samplingrate= double(spikewaves_binarydoc_fid.fread(1,'float32'));

						% step 2 - read the waveforms
						my_wave_start = 1;
					 	my_wave_end = Inf;
						% each data points takes 4 bytes; the number of samples is equal to the number of channels
						%       multiplied by the number of samples taken from each channel, which is S1-S0+1
						samples_per_channel = parameters.S1-parameters.S0+1;
						wave_size = parameters.numchannels * samples_per_channel;

						data_size = 4; % 32 bit floats

						if my_wave_start>0,
							spikewaves_binarydoc_fid.fseek(header_size+data_size*(my_wave_start-1)*wave_size,'bof'); % move to the right place in the file
							data_size_to_read = (my_wave_end-my_wave_start+1)*wave_size;
							waveforms = spikewaves_binarydoc_fid.fread(data_size_to_read,'float32');
							waves_actually_read = length(waveforms)/(parameters.numchannels*samples_per_channel);
							if abs(waves_actually_read-round(waves_actually_read))>0.0001,
								error(['Got an odd number of samples for these spikes. Corrupted file perhaps?']);
							end;
							concatenated_spikes = reshape(waveforms,samples_per_channel,parameters.numchannels,waves_actually_read);
						end;
						% TODO make sure multiple epochs work
						%if i > 1
						%	waveforms = cat(2,)
						ndi_app_spikeextractor_obj.experiment.database.closebinarydoc(spikewaves_binarydoc_fid);
					end
					%warning(['concatenated ' num2str(i) ' epochs(s) with same extraction name within probe'])
				end
		end % load_spikes()

		function concatenated_times = load_times(ndi_app_spikeextractor_obj, ndi_probe_obj, extraction_name)
			% LOADSPIKETIMES - Load all  spiketimes records from experiment database
			%
			% ST = LOADSPIKETIMES(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_PROBE_OBJ, EXTRACTION_NAME)
			%
			% Loads stored spiketimes generated by NDI_APP_SPIKEEXTRACTOR/SPIKE_EXTRACT_PROBES
			%
			times_searchq = cat(2, ndi_app_spikeextractor_obj.searchquery(), ...
				{'document_class.class_name','times'});
			times_searchq = cat(2, times_searchq, ndi_probe_obj.searchquery());
			times_searchq = cat(2, times_searchq, ...
				{'spike_extraction.extraction_name',extraction_name});
			docs = ndi_app_spikeextractor_obj.experiment.database.search(times_searchq);

			% TODO How to get them in order? maybe add epoch_number to times and times ndi_doc
			if ~isempty(docs)
				% TODO make sure multiple epochs work
				for i=1:numel(docs)
					times_doc = ndi_app_spikeextractor_obj.experiment.database.read(docs{i}.doc_unique_id)
					spiketimes_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database.openbinarydoc(times_doc);

					% step 1 - read header
					spiketimes_binarydoc_fid.fseek(0,'bof');
					parameters.numchannels = spiketimes_binarydoc_fid.fread(1,'uint8');      % now at 1 byte
					parameters.S0 = spiketimes_binarydoc_fid.fread(1,'int8');                % now at 2 bytes
					parameters.S1 = spiketimes_binarydoc_fid.fread(1,'int8');                % now at 3 bytes
					parameters.name = spiketimes_binarydoc_fid.fread(80,'char');             % now at 83 bytes
					parameters.name = char(parameters.name(find(parameters.name)))';
					parameters.ref = spiketimes_binarydoc_fid.fread(1,'uint8');              % now at 84 bytes
					parameters.comment = spiketimes_binarydoc_fid.fread(80,'char');          % now at 164 bytes
					parameters.comment = char(parameters.comment(find(parameters.comment)))';
					parameters.samplingrate = double(spiketimes_binarydoc_fid.fread(1,'float32'));

					spiketimes_binarydoc_fid.fseek( 512, 'bof');

					spiketimes = spiketimes_binarydoc_fid.fread(Inf,'float32');
					epoch = [parameters.ref];
					% 1xspiketimes
					epocharray = repmat(epoch, [1, size(spiketimes, 1)]);

					concatenated_times = cat(1, epocharray, spiketimes');
					% TODO make sure multiple epochs work
					%if i > 1
					%	waveforms = cat(2,)
					ndi_app_spikeextractor_obj.experiment.database.closebinarydoc(spiketimes_binarydoc_fid);
				end
				%warning(['concatenated ' num2str(i) ' epochs(s) with same extraction name within probe'])
			end
		end % loadspiketimes()

		function parameters = load_parameters(ndi_app_spikeextractor_obj, ndi_probe_obj)
			% LOADSPIKES - Load all spikewaves records from experiment database
			%
			% SW = LOADSPIKES(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_PROBE_OBJ, EXTRACTION_NAME)
			%
			% Loads stored spikewaves generated by NDI_APP_SPIKEEXTRACTOR/SPIKE_EXTRACT_PROBES
			%
				parameters_searchq = cat(2, ndi_app_spikeextractor_obj.searchquery(), ...
					{'document_class.class_name','extraction_parameters'});
				parameters_searchq = cat(2, parameters_searchq, ndi_probe_obj.searchquery());
				%parameters_searchq = cat(2, parameters_searchq, ...
				%	{'spike_extraction.extraction_name',extraction_name});
				docs = ndi_app_spikeextractor_obj.experiment.database.search(parameters_searchq);

				% TODO How to get them in order? maybe add epoch_number to spikes and times ndi_doc
				if ~isempty(docs)
					% TODO make sure multiple epochs work
					for i=1:numel(docs)
						parameters_doc = ndi_app_spikeextractor_obj.experiment.database.read(docs{i}.doc_unique_id)
						spikewaves_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database.read(parameters_doc);
						waveforms = [];

						header_size = 512; % 512 bytes in the header

						 % step 1 - read header
						spikewaves_binarydoc_fid.fseek(0,'bof');
						parameters.numchannels = spikewaves_binarydoc_fid.fread(1,'uint8');      % now at 1 byte
						parameters.S0 = spikewaves_binarydoc_fid.fread(1,'int8');                % now at 2 bytes
						parameters.S1 = spikewaves_binarydoc_fid.fread(1,'int8');                % now at 3 bytes
						parameters.name = spikewaves_binarydoc_fid.fread(80,'char');             % now at 83 bytes
						parameters.name = char(parameters.name(find(parameters.name)))';
						parameters.ref = spikewaves_binarydoc_fid.fread(1,'uint8');              % now at 84 bytes
						parameters.comment = spikewaves_binarydoc_fid.fread(80,'char');          % now at 164 bytes
						parameters.comment = char(parameters.comment(find(parameters.comment)))';
						parameters.samplingrate= double(spikewaves_binarydoc_fid.fread(1,'float32'));

						% step 2 - read the waveforms
						my_wave_start = 1;
					 	my_wave_end = Inf;
						% each data points takes 4 bytes; the number of samples is equal to the number of channels
						%       multiplied by the number of samples taken from each channel, which is S1-S0+1
						samples_per_channel = parameters.S1-parameters.S0+1;
						wave_size = parameters.numchannels * samples_per_channel;

						data_size = 4; % 32 bit floats

						if my_wave_start>0,
							spikewaves_binarydoc_fid.fseek(header_size+data_size*(my_wave_start-1)*wave_size,'bof'); % move to the right place in the file
							data_size_to_read = (my_wave_end-my_wave_start+1)*wave_size;
							waveforms = spikewaves_binarydoc_fid.fread(data_size_to_read,'float32');
							waves_actually_read = length(waveforms)/(parameters.numchannels*samples_per_channel);
							if abs(waves_actually_read-round(waves_actually_read))>0.0001,
								error(['Got an odd number of samples for these spikes. Corrupted file perhaps?']);
							end;
							concatenated_spikes = reshape(waveforms,samples_per_channel,parameters.numchannels,waves_actually_read);
						end;
						% TODO make sure multiple epochs work
						%if i > 1
						%	waveforms = cat(2,)
					end
					%warning(['concatenated ' num2str(i) ' epochs(s) with same extraction name within probe'])
				end
		end % load_spikes()

	end % methods

end % ndi_app_markgarbage
