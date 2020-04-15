import numpy as np
import musclebeachtools as mb
import neuraltoolkit as ntk


def siout(sorted_data, noflylist, rec_time,
          file_datetime_list, ecube_time_list,
          amps=None,
          filt=None):
    '''
    function to load neuron objects from the spike interface output

    Parameters
    ----------
    datadir : Location of output files
    filenum : File number if there is many blocks (default 0)
    prbnum : Probe number (default 1). Range 1-10.
    filt : filter by quality. filt=[1], loads only quality 1 neurons.


    Returns
    -------
    n1 : All neurons as a list. For example n1[0] is first neuron.

    Raises
    ------

    See Also
    --------

    Notes
    -----

    Examples
    --------
    datadir = "/hlabhome/kiranbn/Animalname/final/"
    n1 = ksout(datadir, filenum=0, prbnum=1, filt=[1, 3])


    '''

    # filt to empty list
    if filt is None:
        filt = []

    # print("Finding unit ids")
    unique_clusters = sorted_data.get_unit_ids()

    # Sampling rate
    # print('Finding sampling rate')
    # mb.Neuron.fs = sorted_data.get_sampling_frequency()
    fs = sorted_data.get_sampling_frequency()
    print("Sampling frequency ", fs)
    n = []

    # Start and end time
    # print('Finding start and end time')
    # start_time = raw_data_start
    # end_time = raw_data_end
    # # Convert to seconds
    # end_time = (np.double(np.int64(end_time) - np.int64(start_time))/1e9)
    # # reset start to zero
    # start_time = np.double(0.0)
    # print((end_time - start_time))
    # assert (end_time - start_time) > 1.0, \
    #     'Please check start and end time is more than few seconds apart'
    # print('Start and end times are %f and %f', start_time, end_time)

    # mb.Neuron.start_time = 0.0
    start_time = 0.0

    # KIRAN this shouldn't be hard coded? max of spt below
    # mb.Neuron.end_time = 300.0
    end_time = rec_time / fs
    print("Start time ", start_time, " end time ", end_time)

    # Loop through unique clusters and make neuron list
    for unit_idx, unit in enumerate(unique_clusters):
        ch_group = sorted_data.get_unit_property(unit, "group")
        # print("Total i ", i, " unit ", unit)
        if unit_idx not in noflylist:
            # print("qual ", cluster_quals[i])
            if len(filt) == 0:
                # this is the unit number for indexing spike times
                # and unit properties
                sp_c = [unit_idx]
                # these are spike times
                sp_t = sorted_data.get_unit_spike_train(unit)
                qual = 0
                # mean WF @ Fs of recording
                mwf_list = sorted_data.get_unit_property(unit, "template").T
                # print("mwf_list ", mwf_list)
                # print("len mwf_list ", len(mwf_list))
                # mwfs = np.arange(0, 100)
                # KIRAN please spline this
                # mwfs = sorted_data.get_unit_property(unit, "template").T
                tmp_max_channel = sorted_data.get_unit_property(unit,
                                                                'max_channel')
                # sahara - don't hardcode 4, get size of channel group
                max_channel = \
                    [sorted_data.get_unit_property(unit, 'max_channel') +
                        (4 * ch_group)]
                #  try:
                # print("Skipped i ", i, " unit ", unit)
                print("unit_idx ", unit_idx, " unit ", unit,
                      " max_channel : ", tmp_max_channel,
                      " ", max_channel)
                mwf = [row[tmp_max_channel] for row in mwf_list]
                t = np.arange(0, len(mwf))
                _, mwfs = ntk.data_intpl(t, mwf, 3, intpl_kind='cubic')

                # def __init__(self, sp_c, sp_t, qual, mwf, mwfs, max_channel,
                #              fs=25000, start_time=0, end_time=12 * 60 * 60,
                #              mwft=None,
                #              sex=None, age=None, species=None):
                if ((len(file_datetime_list) == 2) and
                        (len(ecube_time_list) == 2)):
                    if amps is not None:
                        n.append(mb.Neuron(sp_c, sp_t, qual, mwf,
                                 mwfs, max_channel,
                                 fs=fs,
                                 start_time=start_time, end_time=end_time,
                                 mwft=mwf_list,
                                 rstart_time=str(file_datetime_list[0]),
                                 rend_time=str(file_datetime_list[1]),
                                 estart_time=np.int64(ecube_time_list[0]),
                                 eend_time=np.int64(ecube_time_list[1]),
                                 sp_amp=amps[unit_idx]))
                    else:
                        n.append(mb.Neuron(sp_c, sp_t, qual, mwf,
                                 mwfs, max_channel,
                                 fs=fs,
                                 start_time=start_time, end_time=end_time,
                                 mwft=mwf_list,
                                 rstart_time=str(file_datetime_list[0]),
                                 rend_time=str(file_datetime_list[1]),
                                 estart_time=np.int64(ecube_time_list[0]),
                                 eend_time=np.int64(ecube_time_list[1])))
                elif ((len(file_datetime_list) == 2) and
                        (len(ecube_time_list) == 0)):
                    n.append(mb.Neuron(sp_c, sp_t, qual, mwf,
                             mwfs, max_channel,
                             fs=fs,
                             start_time=start_time, end_time=end_time,
                             mwft=mwf_list,
                             rstart_time=str(file_datetime_list[0]),
                             rend_time=str(file_datetime_list[1])))
                else:
                    n.append(mb.Neuron(sp_c, sp_t, qual, mwf,
                             mwfs, max_channel,
                             fs=fs,
                             start_time=start_time, end_time=end_time,
                             mwft=mwf_list))
                #  except:
                #  pdb.set_trace()
            elif len(filt) > 0:
                print("sorry, we don't have qualities set yet, "
                      "run again with no filter")

    print(f'Found {len(n)} neurons\n')
    # neurons = n.copy()
    # neurons = copy.deepcopy(n)
    # return neurons
    return n
