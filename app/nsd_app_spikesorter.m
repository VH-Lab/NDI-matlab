classdef nsd_app_spikesorter < nsd_app

	properties (SetAccess=protected,GetAccess=public)


	end % properties

	methods

		function nsd_app_spikesorter_obj = nsd_app_spikesorter(varargin)
			% NSD_APP_spikesorter - an app to sort spikewaves found in experiments
			%
			% NSD_APP_spikesorter_OBJ = NSD_APP_spikesorter(EXPERIMENT)
			%
			% Creates a new NSD_APP_spikesorter object that can operate on
			% NSD_EXPERIMENTS. The app is named 'nsd_app_spikesorter'.
			%
				experiment = [];
				name = 'nsd_app_spikesorter';
				if numel(varargin)>0,
					experiment = varargin{1};
				end
				nsd_app_spikesorter_obj = nsd_app_spikesorter_obj@nsd_app(experiment, name);

		end % nsd_app_spikesorter() creator

        function spike_sort(nsd_app_spikesorter_obj, name, type, extraction_name, sort_name, sorting_params) %, sorting_params)

			% Extracts probe with name
			probes = nsd_app_spikesorter_obj.experiment.getprobes('name',name,'type',type) % can add reference
			probes = probes{1}
			%If extraction_params was inputed as a struct then no need to parse it
            if isstruct(sorting_params)
                sorting_parameters = sorting_params;
                % Consider saving in some var_branch_within probe_branch
            elseif isa(sorting_params, 'char')
                sorting_parameters = loadStructArray(sorting_params);
                % Consider saving in some var_branch_within probe_branch
            else
                error('unable to handle extraction_params.');
            end

			% Integrate for loop for multiple probes

			extraction_path = [nsd_app_spikesorter_obj.probevarpath(probes) 'nsd_app_spikeextractor' nsd_branchsep extraction_name];
			swvariable = nsd_app_spikesorter_obj.experiment.database.path2nsd_variable([extraction_path nsd_branchsep 'spikewaves'], 0, 1);
			concatenated_waves = readvhlspikewaveformfile(swvariable.filename());
			stvariable = nsd_app_spikesorter_obj.experiment.database.path2nsd_variable([extraction_path nsd_branchsep 'spiketimes'], 0, 1);
			concatenated_spiketimes = readspiketimesfile(stvariable.filename());

			%% Spike Features (PCA)

			% get covariance matrix of the TRANSPOSE of spike array (waveforms need
			% to be in the rows for cov to give what we want)
			covariance = cov(concatenated_waves);

			% get eigenvectors & eigenvalues - these are pre-sorted in order of
			% ASCENDING eigenvalue
			[eigenvectors, eigenvalues] = eig(covariance);
			eigvals = diag(eigenvalues);

			% sort in order of DESCENDING eigenvalues
			[eigvals, indx] = sort(eigvals, 'descend');
			eigenvectors = eigenvectors(:, indx);

			% Project original waveforms into eigenvector space
			projected_waveforms = concatenated_waves * [eigenvectors];

			%Features used in klustakwik_cluster
		    pca_coefficients = projected_waveforms(:, 1:sorting_parameters.num_pca_features);

			disp('KlustarinKwikly...');

	        [clusterids,numclusters] = klustakwik_cluster(pca_coefficients,3,25,5,0);
	        %cluster_spikewaves_gui('waves', concatenated_waves); % 'EpochStartSamples', epoch_start_samples, 'EpochNames', epoch_names);
	        disp('Done clustering.');
	        figure(101);
	        hist(clusterids);



	        clustering_data = var_clustering_data.data;
	        clustering_data.clusterids = clusterids;
	        clustering_data.numclusters = numclusters;
	        var_clustering_data = updatedata(var_clustering_data, clustering_data);

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

		function b = createspikewaves_variable(nsd_app_spikesorter_obj, nsd_probe_obj)
			% SAVESPIKEWAVES - save a  spikewaves file to the experiment database
			%
			% B = SAVESPIKEWAVES(NSD_APP_spikesorter, NSD_PROBE_OBJ, SPIKEWAVESFILE)
			%
			% Saves a SPIKEWAVESFILE to an experment database, in the appropriate place for
			% the NSD_PROBE_OBJ data.
			%
			% If the entry is a duplicate, it is not saved but b is still 1.
			%
			%%% implement lists of spike_extractions, many-to-many problem between extraction names and probes
				b = 1;

				sw = nsd_app_spikesorter_obj.loadspikewaves(nsd_probe_obj);
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

				nsd_app_spikesorter_obj.clearspikewaves(nsd_probe_obj);
				mp = nsd_app_spikesorter_obj.myvarpath(nsd_probe_obj);

				[v, parent] = nsd_app_spikesorter_obj.path2var(mp,1,0);
				myvar = nsd_variable(parent,'spikewaves','file','spikewaves',spikewavesfile,'Spikewaves vhlab file', 'Added by app call');

		end % savevalidinterval()

		% WARNING clear extraction instead
		function b = clear_extraction(nsd_app_spikesorter_obj, nsd_probe_obj, extraction_name)
			% CLEARSPIKEWAVES - clear all 'spikewaves' records for an NSD_PROBE_OBJ from experiment database
			%
			% B = CLEARSPIKEWAVES(NSD_APP_spikesorter_OBJ, NSD_EPOCHSET_OBJ)
			%
			% Clears all spikewaves entries from the experiment database for object NSD_PROBE_OBJ.
			%
			% Returns 1 on success, 0 otherwise.
			%%%
			% See also: NSD_APP_MARKGARBAGE/MARKVALIDINTERVAL, NSD_APP_MARKGARBAGE/SAVEALIDINTERVAL, ...
			%      NSD_APP_MARKGARBAGE/LOADVALIDINTERVAL

				b = 1;
				mp = nsd_app_spikesorter_obj.extraction_path(nsd_probe_obj, extraction_name);
				[v,parent] = nsd_app_spikesorter_obj.path2var(mp,0,0);
				if ~isempty(v),
					try,
						parent.remove(v.objectfilename);
					catch,
						b = 0;
					end;
				end
		end % clearvalidinteraval()

		function [sw, st] = create_extraction_varbranch(nsd_app_spikesorter_obj, nsd_probe_obj, extraction_name, extraction_parameters, overwrite)
			% CREATE_SPIKEWAVES_VARIABLE - Builds varbranch at probe/extraction_name path and returns nsd variable
			%
			% SW, ST = CREATE_SPIKEWAVES_VARIABLE(NSD_APP_spikesorter_OBJ, NSD_PROBE_OBJ, EXTRACTION_NAME)
			%
			% Loads stored spikewaves generated by NSD_APP_spikesorter/SPIKE_EXTRACT_PROBES
			%

				swpath = nsd_app_spikesorter_obj.spikewavesvariablepath(nsd_probe_obj, extraction_name);
				stpath = nsd_app_spikesorter_obj.spiketimesvariablepath(nsd_probe_obj, extraction_name);
				[swvariable, swparent] = nsd_app_spikesorter_obj.path2var(swpath,0,1);
				[stvariable, stparent] = nsd_app_spikesorter_obj.path2var(stpath,0,1);

				% If no variables exist yet, using or since if incomplete vars it is useless
				if isempty(swvariable) || isempty(stvariable)
					[parent] = nsd_app_spikesorter_obj.path2var(nsd_app_spikesorter_obj.extraction_path(nsd_probe_obj, extraction_name),1,0);
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

		function sw = loadspikewaves(nsd_app_spikesorter_obj, nsd_probe_obj, extraction_name)
			% LOADSPIKEWAVES - Load all spikewaves records from experiment database
			%
			% SW = LOADSPIKEWAVES(NSD_APP_spikesorter_OBJ, NSD_PROBE_OBJ)
			%
			% Loads stored spikewaves generated by NSD_APP_spikesorter/SPIKE_EXTRACT_PROBES
			%
				spikewaves = [];
                keyboard
				mp = nsd_app_spikesorter_obj.spikewavesvariablepath(nsd_probe_obj, extraction_name);
				v = nsd_app_spikesorter_obj.path2var(mp,0,1);
				if ~isempty(v),
					sw = readvhlspikewaveformfile(v.filename);
				end
		end % loadspikewaves()

		function st = loadspiketimes(nsd_app_spikesorter_obj, nsd_probe_obj, extraction_name)
			% LOADSPIKETIMES - Load all  spiketimes records from experiment database
			%
			% ST = LOADSPIKETIMES(NSD_APP_spikesorter_OBJ, NSD_PROBE_OBJ)
			%
			% Loads stored spiketimes generated by NSD_APP_spikesorter/SPIKE_EXTRACT_PROBES
			%
				spiketimes = []
				mp = nsd_app_spikesorter_obj.spiketimesvariablepath(nsd_probe_obj, extraction_name);
				v = nsd_app_spikesorter_obj.path2var(mp,0,1);
				if ~isempty(v),
					st = readspiketimesfile(v.filename);
				end
		end % loadspiketimes()

		function mp = extraction_path(nsd_app_spikesorter_obj, nsd_probe_obj, extraction_name)
			% SPIKEWAVESVARIABLEPATH - returns the path of a  interval variable within the experiment database
			%
			% MP = SPIKEWAVESVARIABLEPATH(NSD_APP_spikesorter_OBJ, NSD_PROBE_OBJ)
			%
			% Returns the path of the  interval variable for NSD_PROBE_OBJ in the experiment database.
			%
				nsd_app_spikesorter_obj.myvarpath(nsd_probe_obj)
				mp = [nsd_app_spikesorter_obj.myvarpath(nsd_probe_obj) extraction_name]
				% mp = [nsd_app_spikesorter_obj.myvarpath(nsd_probe_obj) 'spikewaves'] % previously type of
		end

		function mp = spikewavesvariablepath(nsd_app_spikesorter_obj, nsd_probe_obj, extraction_name)
			% SPIKEWAVESVARIABLEPATH - returns the path of a  interval variable within the experiment database
			%
			% MP = SPIKEWAVESVARIABLEPATH(NSD_APP_spikesorter_OBJ, NSD_PROBE_OBJ)
			%
			% Returns the path of the  interval variable for NSD_PROBE_OBJ in the experiment database.
			%
				nsd_app_spikesorter_obj.myvarpath(nsd_probe_obj)
				mp = [nsd_app_spikesorter_obj.myvarpath(nsd_probe_obj) extraction_name nsd_branchsep 'spikewaves']
				% mp = [nsd_app_spikesorter_obj.myvarpath(nsd_probe_obj) 'spikewaves'] % previously type of
		end

		function mp = spiketimesvariablepath(nsd_app_spikesorter_obj, nsd_probe_obj, extraction_name)
			% SPIKETIMESVARIABLEPATH - returns the path of a  interval variable within the experiment database
			%
			% MP = SPIKETIMESVARIABLEPATH(NSD_APP_spikesorter_OBJ, NSD_PROBE_OBJ)
			%
			% Returns the path of the  interval variable for NSD_PROBE_OBJ in the experiment database.
			%
				nsd_app_spikesorter_obj.myvarpath(nsd_probe_obj)
				mp = [nsd_app_spikesorter_obj.myvarpath(nsd_probe_obj) extraction_name nsd_branchsep 'spiketimes']
		end

	end % methods

end % nsd_app_markgarbage
