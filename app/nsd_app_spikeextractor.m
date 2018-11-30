classdef nsd_app_spikeextractor < nsd_app

	properties (SetAccess=protected,GetAccess=public)


	end % properties

	methods

		function nsd_app_spikeextractor_obj = nsd_app_spikeextractor(varargin)
			% NSD_APP_SPIKEEXTRACTOR - an app to extract probes found in experiments
			%
			% NSD_APP_SPIKEEXTRACTOR_OBJ = NSD_APP_SPIKEEXTRACTOR(EXPERIMENT)
			%
			% Creates a new NSD_APP_SPIKEEXTRACTOR object that can operate on
			% NSD_EXPERIMENTS. The app is named 'nsd_app_spikeextractor'.
			%
				experiment = [];
				name = 'nsd_app_spikeextractor';
				if numel(varargin)>0,
					experiment = varargin{1};
				end
				nsd_app_spikeextractor_obj = nsd_app_spikeextractor_obj@nsd_app(experiment, name);

		end % nsd_app_spikeextractor() creator

        function spike_extract_probes(nsd_app_spikeextractor_obj, name, type, extraction_name, extraction_params) %, sorting_params)

			% Extracts probe with name
			probes = nsd_app_spikeextractor_obj.experiment.getprobes('name',name,'type',type); % can add reference

			% Need to pass in the extraction parameters and sorting parameters

			%If extraction_params was inputed as a struct then no need to parse it
            if isstruct(extraction_params)
                extraction_parameters = extraction_params;
                % Consider saving in some var_branch_within probe_branch
            elseif isa(extraction_params, 'char')
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
% 							if isempty(nsd_app_spikeextractor_obj.loadspikewaves(probe))
% 								nsd_app_spikeextractor_obj.clearspikewaves(probe)
% 							end

							[current_waveforms_file, current_spiketimes_file] = nsd_app_spikeextractor_obj.create_extraction_varbranch(probe, extraction_name, extraction_parameters)
			                %Create variable file waveforms within spike_extraction to store waveforms
			                %disp(['creating waveforms variable file within spike_extraction...']);
			                %current_waveforms_file = nsd_variable(spike_extraction, ['spikewaves_epoch_' int2str(n)],'file','spikewaves',[],'Extracted spike waveforms binary file','extracted by nsd_app_spikeextractor');

							%Create variable file waveforms within spike_extraction to store waveforms
			                %disp(['creating spiketimes variable file within spike_extraction...']);
			                %current_spiketimes_file = nsd_variable(spike_extraction, ['spiketimes_epoch_' int2str(n)],'file','spiketimes',[],'Extracted spike times binary file','extracted by nsd_app_spikeextractor');

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

							%Filename of variable file current_waveforms_file
			                spikewavesfilename = current_waveforms_file.filename();
			                %disp(['spikewaves filename: ' spikewavesfilename]);
			                %Add header to variable file current_waveforms_file
			                %Stores spikewavesfid
			                spikewavesfid = newvhlspikewaveformfile(spikewavesfilename, fileparameters);
							fclose(spikewavesfid);

							%Filename of variable file current_spiketimes_file
			                spiketimesfilename = current_spiketimes_file.filename();
			                %disp(['spiketimes filename: ' spiketimesfilename]);
			                %Add header to variable file current_waveforms_file
			                %Stores spikewavesfid
			                spiketimesfid = newspiketimesfile(spiketimesfilename, fileparameters);
							fclose(spiketimesfid);
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
			            addvhlspikewaveformfile(current_waveforms_file.filename(), interpolated_waveforms);
			            %finalwaves = cat()
			      		%Store epoch spike times in file
			      		addspiketimesfile(current_spiketimes_file.filename(), locs);
			            %finaltimes = [finaltimes locs];
			            %Update start_time
			            start_time = start_time + read_size * sample_rate - overlap * sample_rate;
			        end %while ~endReached

					disp(['Epoch ' int2str(n) ' spike extraction done.']);
			    end %epoch n
			end %prb
		end %function



		% developer note: it would be great to have a 'markinvalidinterval' companion
		function b = markvalidinterval(nsd_app_markgarbage_obj, nsd_epochset_obj, t0, timeref_t0, t1, timeref_t1)
			% MARKVALIDINTERVAL - mark a valid intervalin an epoch (all else is garbage)
			%
			% B = MARKVALIDINTERVAL(NSD_APP_MARKGARBAGE_APP, NSD_EPOCHSET_OBJ, T0, TIMEREF_T0, ...
			%	T1, TIMEREF_T1)
			%
			% Saves a variable marking a valid interval from T0 to T1 with respect
			% to an NSD_TIMEREFERENCE object TIMEREF_T0 (for T0) and TIMEREF_T1 (for T1) for
			% an NSD_EPOCHSET object NSD_EPOCHSET_OBJ.  Examples of NSD_EPOCHSET objects include
			% NSD_IODEVICE and NSD_PROBE and their subclasses.
			%
			% TIMEREF_T0 and TIMEREF_T1 are saved as a name and type for looking up later.
			%
				% developer note: might be good idea to make sure these times exist at saving
				validinterval.timeref_structt0 = timeref_t0.nsd_timereference_struct();
				validinterval.t0 = t0;
				validinterval.timeref_structt1 = timeref_t1.nsd_timereference_struct();
				validinterval.t1 = t1;

				b = nsd_app_markgarbage_obj.savevalidinterval(nsd_epochset_obj, validinterval);

		end % markvalidinterval()

		function b = createspikewaves_variable(nsd_app_spikeextractor_obj, nsd_probe_obj)
			% SAVESPIKEWAVES - save a  spikewaves file to the experiment database
			%
			% B = SAVESPIKEWAVES(NSD_APP_SPIKEEXTRACTOR, NSD_PROBE_OBJ, SPIKEWAVESFILE)
			%
			% Saves a SPIKEWAVESFILE to an experment database, in the appropriate place for
			% the NSD_PROBE_OBJ data.
			%
			% If the entry is a duplicate, it is not saved but b is still 1.
			%
			%%% implement lists of spike_extractions, many-to-many problem between extraction names and probes
				b = 1;

				sw = nsd_app_spikeextractor_obj.loadspikewaves(nsd_probe_obj);
				% match = -1;
				% for i=1:numel(vi),
				% 	if eqlen(vi(i),intervalstruct),
				% 		match = i;
				% 		return;
				% 	end;
				% end
				%
				% % if we are here, we found no match
				% vi(end+1) = intervalstruct;

				nsd_app_spikeextractor_obj.clearspikewaves(nsd_probe_obj);
				mp = nsd_app_spikeextractor_obj.myvarpath(nsd_probe_obj);

				[v, parent] = nsd_app_spikeextractor_obj.path2var(mp,1,0);
				myvar = nsd_variable(parent,'spikewaves','file','spikewaves',spikewavesfile,'Spikewaves vhlab file', 'Added by app call');

		end % savevalidinterval()

		% WARNING clear extraction instead
		function b = clear_extraction(nsd_app_spikeextractor_obj, nsd_probe_obj, extraction_name)
			% CLEARSPIKEWAVES - clear all 'spikewaves' records for an NSD_PROBE_OBJ from experiment database
			%
			% B = CLEARSPIKEWAVES(NSD_APP_SPIKEEXTRACTOR_OBJ, NSD_EPOCHSET_OBJ)
			%
			% Clears all spikewaves entries from the experiment database for object NSD_PROBE_OBJ.
			%
			% Returns 1 on success, 0 otherwise.
			%%%
			% See also: NSD_APP_MARKGARBAGE/MARKVALIDINTERVAL, NSD_APP_MARKGARBAGE/SAVEALIDINTERVAL, ...
			%      NSD_APP_MARKGARBAGE/LOADVALIDINTERVAL

				b = 1;
				mp = nsd_app_spikeextractor_obj.extraction_path(nsd_probe_obj, extraction_name);
				[v,parent] = nsd_app_spikeextractor_obj.path2var(mp,0,0);
				if ~isempty(v),
					try,
						parent.remove(v.objectfilename);
					catch,
						b = 0;
					end;
				end
		end % clearvalidinteraval()

		function [sw, st] = create_extraction_varbranch(nsd_app_spikeextractor_obj, nsd_probe_obj, extraction_name, extraction_parameters, overwrite)
			% CREATE_SPIKEWAVES_VARIABLE - Builds varbranch at probe/extraction_name path and returns nsd variable
			%
			% SW, ST = CREATE_SPIKEWAVES_VARIABLE(NSD_APP_SPIKEEXTRACTOR_OBJ, NSD_PROBE_OBJ, EXTRACTION_NAME)
			%
			% Loads stored spikewaves generated by NSD_APP_SPIKEEXTRACTOR/SPIKE_EXTRACT_PROBES
			%

				swpath = nsd_app_spikeextractor_obj.spikewavesvariablepath(nsd_probe_obj, extraction_name);
				stpath = nsd_app_spikeextractor_obj.spiketimesvariablepath(nsd_probe_obj, extraction_name);
				[swvariable, swparent] = nsd_app_spikeextractor_obj.path2var(swpath,0,1);
				[stvariable, stparent] = nsd_app_spikeextractor_obj.path2var(stpath,0,1);

				% If no variables exist yet, using or since if incomplete vars it is useless
				if isempty(swvariable) || isempty(stvariable)
					[parent] = nsd_app_spikeextractor_obj.path2var(nsd_app_spikeextractor_obj.extraction_path(nsd_probe_obj, extraction_name),1,0);
					str = 'y';
				% If both sw and st exist, ask if overwrite
				else
					prompt = 'Are you sure you want to overwrite existing extraction? y/n [y]: ';
					str = input(prompt,'s');
					if isempty(str)
    					str = 'y';
					end
					if strcmp(str,'y')
						disp(['Overwriting "' extraction_name '" extraction...'])
					end
				end
				% Create both vars and add extraction paramaeters to branch
				if strcmp(str,'y')
					sw = nsd_variable(parent,'spikewaves','file','spikewaves',[],'Spikewaves vhlab file', 'Added by app call');
					st = nsd_variable(parent,'spiketimes','file','spiketimes',[],'Spiketimes vhlab file', 'Added by app call');
					p = nsd_variable(parent,'extraction_parameters','struct','parameters',extraction_parameters,'extraction parameters for vhlab spike extractor', 'Added by app call');
				end

		end % create_spikewaves_variable()

		function sw = loadspikewaves(nsd_app_spikeextractor_obj, nsd_probe_obj, extraction_name)
			% LOADSPIKEWAVES - Load all spikewaves records from experiment database
			%
			% SW = LOADSPIKEWAVES(NSD_APP_SPIKEEXTRACTOR_OBJ, NSD_PROBE_OBJ)
			%
			% Loads stored spikewaves generated by NSD_APP_SPIKEEXTRACTOR/SPIKE_EXTRACT_PROBES
			%
				spikewaves = [];
                keyboard
				mp = nsd_app_spikeextractor_obj.spikewavesvariablepath(nsd_probe_obj, extraction_name);
				v = nsd_app_spikeextractor_obj.path2var(mp,0,1);
				if ~isempty(v),
					sw = readvhlspikewaveformfile(v.filename);
				end
		end % loadspikewaves()

		function st = loadspiketimes(nsd_app_spikeextractor_obj, nsd_probe_obj, extraction_name)
			% LOADSPIKETIMES - Load all  spiketimes records from experiment database
			%
			% ST = LOADSPIKETIMES(NSD_APP_SPIKEEXTRACTOR_OBJ, NSD_PROBE_OBJ)
			%
			% Loads stored spiketimes generated by NSD_APP_SPIKEEXTRACTOR/SPIKE_EXTRACT_PROBES
			%
				spiketimes = []
				mp = nsd_app_spikeextractor_obj.spiketimesvariablepath(nsd_probe_obj, extraction_name);
				v = nsd_app_spikeextractor_obj.path2var(mp,0,1);
				if ~isempty(v),
					st = readspiketimesfile(v.filename);
				end
		end % loadspiketimes()

		function mp = extraction_path(nsd_app_spikeextractor_obj, nsd_probe_obj, extraction_name)
			% SPIKEWAVESVARIABLEPATH - returns the path of a  interval variable within the experiment database
			%
			% MP = SPIKEWAVESVARIABLEPATH(NSD_APP_SPIKEEXTRACTOR_OBJ, NSD_PROBE_OBJ)
			%
			% Returns the path of the  interval variable for NSD_PROBE_OBJ in the experiment database.
			%
				nsd_app_spikeextractor_obj.myvarpath(nsd_probe_obj)
				mp = [nsd_app_spikeextractor_obj.myvarpath(nsd_probe_obj) extraction_name]
				% mp = [nsd_app_spikeextractor_obj.myvarpath(nsd_probe_obj) 'spikewaves'] % previously type of
		end

		function mp = spikewavesvariablepath(nsd_app_spikeextractor_obj, nsd_probe_obj, extraction_name)
			% SPIKEWAVESVARIABLEPATH - returns the path of a  interval variable within the experiment database
			%
			% MP = SPIKEWAVESVARIABLEPATH(NSD_APP_SPIKEEXTRACTOR_OBJ, NSD_PROBE_OBJ)
			%
			% Returns the path of the  interval variable for NSD_PROBE_OBJ in the experiment database.
			%
				nsd_app_spikeextractor_obj.myvarpath(nsd_probe_obj)
				mp = [nsd_app_spikeextractor_obj.myvarpath(nsd_probe_obj) extraction_name nsd_branchsep 'spikewaves']
				% mp = [nsd_app_spikeextractor_obj.myvarpath(nsd_probe_obj) 'spikewaves'] % previously type of
		end

		function mp = spiketimesvariablepath(nsd_app_spikeextractor_obj, nsd_probe_obj, extraction_name)
			% SPIKETIMESVARIABLEPATH - returns the path of a  interval variable within the experiment database
			%
			% MP = SPIKETIMESVARIABLEPATH(NSD_APP_SPIKEEXTRACTOR_OBJ, NSD_PROBE_OBJ)
			%
			% Returns the path of the  interval variable for NSD_PROBE_OBJ in the experiment database.
			%
				nsd_app_spikeextractor_obj.myvarpath(nsd_probe_obj)
				mp = [nsd_app_spikeextractor_obj.myvarpath(nsd_probe_obj) extraction_name nsd_branchsep 'spiketimes']
		end

	end % methods

end % nsd_app_markgarbage
