import tkinter as tk
from tkinter import filedialog
import matplotlib
import matplotlib.pyplot as plt
import spikeinterface.extractors as se
import spikeinterface.toolkit as st
import spikeinterface.sorters as ss
# import spikeinterface.comparison as sc
import spikeinterface.widgets as sw
import spikesorters.utils.mdaio as md
import mountainlab_pytools as mtlp
import autoscoring as score
# import musclebeachtools as mbt
import numpy as np
import scipy
import siout_to_mbt as siout
import matplotlib.backends.backend_pdf as mpdf
import seaborn as sns
import json
import time
import os
import os.path as op
import sys
import glob
import shutil
# import pdb
import tempfile
import pickle
import neuraltoolkit as ntk
from argparse import ArgumentParser
from sys import platform
if platform == "darwin":
    # matplotlib.use('TkAgg')
    plt.switch_backend('TkAgg')
else:
    # matplotlib.use('Agg')
    plt.switch_backend('Agg')
# import matplotlib
# matplotlib.use('TkAgg')
# import matplotlib.pyplot as plt
# import tkinter as tk
# from tkinter import filedialog
# plt.ion()


# g_o
def dealwithbinarydata(file_path, group_tmp_dir,
                       num_channels, hstype,
                       nprobes, mdaflag=1,
                       probetosort=1,
                       lnosplit=0,
                       probe_channels=64,
                       fs=25000):
    '''
    DEALWITHBINARYDATA: Function that ultimately results in a single .mda file
    containing the user's raw data. This file is named raw.mda and is contained
    in a temp folder created by this function. This is what the sorting
    algorithm operates on. This function will also convert .bin files to .mda.
    If there are multiple .bin files selected, this will concatenate them and
    produce one .mda file. When an .mda file is selected by the user, this
    copies the .mda file into a temp directory and names it raw.mda. NB: - -
    MDA FILES MUST BE CHANNEL MAPPED - -

    Parameters
    ----------
    file_path : Location of user selected data files
    num_channels : Number of contributing channels in the raw data.
    hstype : Channel map name. This is for channel mapping .bin data.
    nprobes: number of contributing probes. At this time, run one at a time.
    mdaflag : indicator of whether the file extension of FILE_PATH is .mda.
    probetosort: Which probe to sort.
    lnosplit: 0 or 1. Indicates whether to split the data file into
              channel groups (e.g. a 64 channel tetrode recording could
              be split into 16 separate files. this is useful if for
              some reason the concatenated complete dataset is too large.
              Complicated to deal with, and best left at 0 if possible.
    probe_channels: number of channels per probe.
                    Relevant when sorting multiple probes simultanouesly.

    Returns
    -------

    Raises
    ------

    See Also
    --------

    Notes
    -----
    Lots of work will need to be done to deal with multiprobe sorting
    simultaneously. Additional data formats (beyond .bin) should be added as
    they become relevant (i.e. from collaborators). At this point, mdaflag can
    be changed to just the _ext variable (file extension) to trigger the
    appropriate workflow.

    Examples
    --------

    '''

    # fs = 25000
    print("fs ", fs)
    sectonano = 1e9
    max_value_to_check = 3800
    width_to_check = 60
    file_datetime_list = []
    ecube_time_list = []
    print("group_tmp_dir ", group_tmp_dir)
    print("mdaflag ", mdaflag)
    print('pwd ', os.getcwd())
    # g_o
    # tmp = os.path.isdir('grouped_raw_dat_temp_folder/')
    # if tmp:
    #     os.system('rm -rf grouped_raw_dat_temp_folder')
    # print(f'Current dir {os.getcwd()}')
    # os.mkdir('grouped_raw_dat_temp_folder')
    group_raw_tmp_dir = op.join(group_tmp_dir,
                                'grouped_raw_dat_temp_folder')
    print('group_raw_tmp_dir ', group_raw_tmp_dir)
    # check group_tmp_dir exits then create grouped_raw_dat_temp_folder
    if os.path.exists(group_tmp_dir) and os.path.isdir(group_tmp_dir):
        if os.path.exists(group_raw_tmp_dir) and \
                os.path.isdir(group_raw_tmp_dir):
            if os.listdir(group_raw_tmp_dir):
                raise FileExistsError("Directory {} is not empty".
                                      format(group_raw_tmp_dir))
            else:
                print("Directory {} is empty.".format(group_raw_tmp_dir))
        else:
            print("Creating directory {}".format(group_raw_tmp_dir))
            try:
                os.mkdir(group_raw_tmp_dir)
            except Exception as e:
                print(e)
                print("Could not create directory {}",
                      format(group_raw_tmp_dir))
                raise NotADirectoryError("Directory {} not found".
                                         format(group_raw_tmp_dir))
    else:
        raise NotADirectoryError("Directory {} does not exists".
                                 format(group_raw_tmp_dir))

    # ddgc.astype('int16').tofile(outfilename)
    # notes:
    # 1) make sure you're processing bin files in the correct (temporal) order.
    # 2) make sure the concatenated output files include the
    #    start and end files' times.
    # 3) how do we parallelize this whole process?

    if mdaflag == 0:
        _, ext = os.path.splitext(file_path[0])
        print("ext ", ext)
        if (ext == '.bin'):
            lecube = 1
        elif (ext == '.rhd'):
            lecube = 0
        else:
            raise ValueError('Unkown file extension')

        # ch_group to zero if lnosplit
        if lnosplit:
            ch_group = 0

        # file_path number of files
        num_files = len(file_path)
        print("num_files ", num_files)

        # for binfile in np.sort(file_path):
        for idx, binfile in enumerate(np.sort(file_path)):
            print("binfile ", binfile)
            pre = os.path.splitext(binfile)[0]

            # print in queue every 4th file
            fullfile = binfile[last_sep + 1:]
            if (idx % 4):
                print("idx % 4 ", idx % 4)
                print("File {} is being processed".format(idx))
                print("fullfile ", fullfile, flush=True)
            else:
                print("fullfile ", fullfile)
            # outfilename = 'P_' + file_path[0][last_sep + 1:]

            tic = time.time()
            # load your raw data and channel map it:
            if lecube:
                # # t, ddgc = ntk.load_raw_binary_gain_chmap_range(fullfile,
                # t, ddgc = ntk.load_raw_binary_gain_chmap_range(binfile,
                #                                              num_channels,
                #                                              hstype,
                #                                              nprobes=nprobes,
                #                                              lraw=1,
                #                                              ts=0, te=-1)
                t, ddgc = \
                    ntk.load_raw_gain_chmap_1probe(binfile,
                                                   num_channels,
                                                   hstype,
                                                   nprobes=nprobes,
                                                   lraw=1,
                                                   ts=0, te=-1,
                                                   probenum=probetosort-1,
                                                   probechans=probe_channels)
                # print("ecube t ", t)
                # print("ecube type t ", type(t))
                # print("sh t ", t.shape)
                # Artifact checks
                otic = time.time()
                edges = np.zeros((ddgc.shape[1]+2), dtype=np.int8)
                # print(edges.shape)
                edges[1:-1] = np.all(np.abs(ddgc) > max_value_to_check,
                                     axis=0).astype(np.int8)
                # print(edges.shape)

                # print("edges\n", edges)
                edges = np.diff(edges)
                # print("edges\n", edges)
                # print(edges.shape)
                val_increasing = np.where(edges == 1)[0]
                val_decreasing = np.where(edges == -1)[0]

                # print(val_increasing)
                # print(val_decreasing)
                val_width = val_decreasing - val_increasing
                # print("val_width\n", val_width)
                val_width_large = np.where(val_width > width_to_check)[0]
                # print("val_width_large\n", val_width_large)
                start_width = val_increasing[val_width_large]
                end_width = val_decreasing[val_width_large]
                print(start_width)
                print(end_width)
                # print(d)
                for i in range(start_width.shape[0]):
                    ddgc[:, start_width[i]:end_width[i]] = 0

                otoc = time.time()
                print('Artifact removal {} took {} seconds'
                      .format(fullfile, otoc - otic))

            else:

                # t, ddgc = ntk.load_intan_raw_gain_chanmap(fullfile,
                t, ddgc = ntk.load_intan_raw_gain_chanmap(binfile,
                                                          num_channels,
                                                          hstype,
                                                          nprobes=nprobes,
                                                          ldin=0)
                # print("intan t ", t)
                # print("intan type t ", type(t))
                # print("sh t ", t.shape)
                t = np.array([t])
                # print("ecube t ", t)
                # print("ecube type t ", type(t))
                # print("sh t ", t.shape)
            if not lecube:
                print("probetosort ", probetosort)
                print("((probetosort-1)*probe_channels) ",
                      ((probetosort-1)*probe_channels),
                      " ((probetosort)*probe_channels) ",
                      ((probetosort)*probe_channels))
                print("probetosort ", probetosort)
                ddgc = ddgc[((probetosort-1)*probe_channels):
                            ((probetosort)*probe_channels), :]
                print("sh ddgc ", ddgc.shape)

            toc = time.time()
            print('Loading {} took {} seconds'.format(fullfile, toc - tic))

            # KIRAN - need to fix if we've just got filenames from MDAflag 2
            if lecube:
                file_datetime = pre.split('int16_')[1]
                print("file_datetime ", file_datetime)
            else:
                print("pre ", pre)
                file_datetime = pre[-13:]
                print("file_datetime ", file_datetime)
                # Make file_datetime same format as ecube
                file_datetime = ('20' + file_datetime[0:2] +
                                 '-' + file_datetime[2:4] +
                                 '-' + file_datetime[4:9] +
                                 '-' + file_datetime[9:11] +
                                 '-' + file_datetime[11:13])
                print("file_datetime ", file_datetime)

            # Save file date time and ecube to be added to mbt
            if lecube:
                print("t[0] ", t[0])
                if idx == 0:
                    file_datetime_list.append(file_datetime)
                    ecube_time_list.append(t[0])
                if idx == (num_files - 1):
                    file_datetime_list.append(file_datetime)
                    ecube_time_list_last = \
                        np.int64(t[0] + (((ddgc.shape[1] - 1) / fs) *
                                 sectonano))
                    ecube_time_list.append(ecube_time_list_last)
            else:
                print("t[0] ", t[0])
                if idx == 0:
                    file_datetime_list.append(file_datetime)
                    # ecube_time_list.append(t[0])
                if idx == (num_files - 1):
                    file_datetime_list.append(file_datetime)
                    # ecube_time_list_last = \
                    #     np.int64(t[0] + (((ddgc.shape[1] - 1) / fs) *
                    #              sectonano))
                    # ecube_time_list.append(ecube_time_list_last)

            gcount = 0
            # this is hardcoded for 64 channels rn, shouldn't be in the future
            if lnosplit:
                tic = time.time()
                # g_o
                # savefile = (f'grouped_raw_dat_temp_folder
                # /chgroup_{gcount}_{file_datetime}.mda')

                if idx == 0:
                    try:
                        # os.mkdir(f'channel_group_{ch_group}')
                        os.chdir(group_raw_tmp_dir)
                        os.mkdir(f'channel_group_{ch_group}')
                    except Exception as e:
                        print(e)
                        print("Could not create directory {}",
                              format(f'channel_group_{ch_group}'))
                        raise NotADirectoryError("Directory not created")
                    group_raw_tmp_dir_group = \
                        op.join(group_raw_tmp_dir, f'channel_group_{ch_group}')
                    # savefile0 = \
                    #     op.join(group_raw_tmp_dir_group,
                    #             f'chgroup_{ch_group}_{file_datetime}.mda')
                    savefile0 = \
                        op.join(group_raw_tmp_dir_group, 'raw.mda')
                    ss.utils.mdaio.writemda16i(ddgc, savefile0)
                else:
                    # savefile = op.join(group_raw_tmp_dir_group,
                    #                  f'chgroup_{gcount}_{file_datetime}.mda')
                    md.appendmda(ddgc, savefile0)
                # gcount += 1
                toc = time.time()
                print('Appending mda {} took {} seconds'.format(savefile0,
                                                                toc - tic))
                del ddgc
            else:
                for chan in np.arange(0, probe_channels, 4):
                    # tetgroup = str(chan + 1)
                    print(f'Writing channel group {gcount} to .mda format.')
                    ddgc_small = ddgc[chan:(chan + 4), :]
                    # THIS WORKS to write to MDA format (very fast)
                    # g_o
                    # savefile = (f'grouped_raw_dat_temp_folder
                    # /chgroup_{gcount}_{file_datetime}.mda')
                    savefile = op.join(group_raw_tmp_dir,
                                       f'chgroup_{gcount}_{file_datetime}.mda')
                    # tested with writemda64 in order to preserve full depth
                    # but it increased the memory by 4 times
                    # so kept it with int16
                    ss.utils.mdaio.writemda16i(ddgc_small, savefile)
                    gcount += 1

        if not lnosplit:
            # Note, now we're trying to append.
            # need to pull out each tetrode and run through that
            # gfiles = os.listdir('grouped_raw_dat_temp_folder')
            print(f'{gcount} total channel groups')
            # g_o
            # os.chdir('grouped_raw_dat_temp_folder')
            try:
                os.chdir(group_raw_tmp_dir)
            except Exception as e:
                print(e)
                print("Directory {} does not exist",
                      format(group_raw_tmp_dir))
                raise NotADirectoryError("Directory {} not found".
                                         format(group_raw_tmp_dir))

            tic = time.time()
            for ch_group in range(gcount):
                print(f'merging group {ch_group}...')
                try:
                    os.mkdir(f'channel_group_{ch_group}')
                except Exception as e:
                    print(e)
                    print("Could not create directory {}",
                          format(f'channel_group_{ch_group}'))
                    raise \
                        NotADirectoryError("Directory {} not found".
                                           format(f'channel_group_{ch_group}'))

                files_to_merge = sorted((glob.glob(f"chgroup_{ch_group}_*")))
                print(files_to_merge)
                for mda_file in files_to_merge[1:]:
                    in_mda = ss.utils.mdaio.readmda(mda_file)
                    mtlp.mdaio.appendmda(in_mda, files_to_merge[0])
                    os.remove(mda_file)
                os.rename(files_to_merge[0],
                          f'channel_group_{ch_group}/raw.mda')
            toc = time.time()
            print('Merging mda took {} seconds'.format(toc - tic))

    elif mdaflag == 1:
        # case in which you're working with .mda
        # the .mda file should contain all channels of data,
        # so it doesn't need to be merged by group.
        # We'll default to 0 for consistency.
        ch_group = 0

        # g_o
        # os.mkdir(f'grouped_raw_dat_temp_folder/channel_group_{ch_group}')
        # os.mkdir(f'grouped_raw_dat_temp_folder/channel_group_{ch_group}')
        # copy the mda file to a temp folder, make it 'raw.mda'
        # g_o
        # shutil.copy(file_path[0],
        # f'grouped_raw_dat_temp_folder/channel_group_{ch_group}/raw.mda')
        print("file_path[0] ", file_path[0])
        tmp_group_raw_tmp_dir = op.join(group_raw_tmp_dir,
                                        f'channel_group_{ch_group}')
        try:
            os.mkdir(tmp_group_raw_tmp_dir)
        except Exception as e:
            print(e)
            print("Could not create directory {}",
                  format(tmp_group_raw_tmp_dir))
            raise NotADirectoryError("Directory {} not found".
                                     format(tmp_group_raw_tmp_dir))

        print('tmp_group_raw_tmp_dir ', tmp_group_raw_tmp_dir)
        print('raw.mda path ', op.join(tmp_group_raw_tmp_dir,
                                       'raw.mda'))
        shutil.copyfile(file_path[0],
                        op.join(tmp_group_raw_tmp_dir,
                        'raw.mda'))
    return file_datetime_list, ecube_time_list


def makeProbeFile(channel_group, channel_ids, geometry, labels):
    '''
    Function to produce a .prb probe file. Intention of this function is to
    automatically generate a probe file for a single channel group when you're
    splitting a full dataset into multiple files (i.e. when the total raw data
    file is too large, you could split it into separate files by tetrode, for
    example). In this case, a unique .prb file is required for each file.
    HOWEVER: splitting the data should be avoided when possible. When data is
    not split, the user selects an extant probe file that matches the geometry
    of their array, and this function will not be called.

    Parameters
    ----------
    channel_group : A string or number that is the "name" of channel group.
                    Typically 0, 1, 2, 3 etc.,
                    but it could be a brain region, e.g.
    channel_ids : The channel numbers that belong to the group.
    geometry : XY coordinates of the channels in the group.
    labels : String labels of each channel.
             For example, wire 3 from the second tetrode
             (thus channel group 1) might be t_13.

    Writes the .prb file.

    Returns
    -------
    .prb file name.

    Raises
    ------

    See Also
    --------

    Notes
    -----

    Examples
    --------

    '''

    print("channel_group ", channel_group)
    print("channel_ids ", channel_ids)
    print("geometry ", geometry)
    print("labels ", labels)
    tmp = f"channel_groups = {{ \n\t\t# Tetrode index\n\t\t{channel_group}: \n\t\t\t\t {{ \n\t\t\t\t\t'channels': [0,1,2,3],\n\t\t\t\t\t'geometry': {geometry},\n\t\t\t\t\t'label': {labels},\n\t\t\t\t\t'correct_channel_ids': {channel_ids},\n\t\t\t\t}}\n\t\t}}"
    prb_file_name = f"grp_{channel_group}.prb"
    f = open(prb_file_name, "w+")
    f.write(tmp)
    f.close()
    return prb_file_name


def badchans(rec, bad_chan_list=None, nsec=5, cutoff=5):

    '''
    Find channels with really low standard deviation.
    Get rid of these. Might also help to add in a low pass as
    well to find extremely noisy chnnels.

    '''

    studs = np.zeros(np.size(rec.get_channel_ids()))

    if bad_chan_list is not None:
        print("bad_chan_list ", bad_chan_list)
        # remove_bad_channels(recording, bad_channel_ids=None,
        # bad_threshold=2, seconds=10, verbose=False)
        # recording_remove_bad = st.preprocessing.remove_bad_channels(rec,
        # bad_channel_ids=bad_chan_list, bad_threshold=2, seconds=10,
        # verbose=True)
        remove_bad_ch = st.preprocessing.remove_bad_channels
        recording_remove_bad = remove_bad_ch(rec,
                                             bad_channel_ids=bad_chan_list,
                                             bad_threshold=2,
                                             seconds=10,
                                             verbose=True)

    else:
        for ch in rec.get_channel_ids():
            studs[ch] = np.std(rec.get_traces(channel_ids=[ch],
                               start_frame=0,
                               end_frame=np.int(nsec *
                                                rec.get_sampling_frequency())))

            print('Stdev. on channel {} = {}'.format(ch, studs[ch]))

        kills_std = np.where(studs < 5)

        print("bad_channel_ids ", kills_std)

        # recording_remove_bad = st.preprocessing.remove_bad_channels(rec,
        # bad_channel_ids=kills_std[0])
        remove_bad_ch = st.preprocessing.remove_bad_channels
        recording_remove_bad = remove_bad_ch(rec, bad_channel_ids=kills_std[0])

    print("recording_remove_bad ", recording_remove_bad)
    print("print(recording_remove_bad.get_channel_ids()) ",
          recording_remove_bad.get_channel_ids())

    return (recording_remove_bad)


def plotraw(rec, label, channel_group, clust_out_dir, bn="",
            nsec=3.0, saveflag=1):

    '''
    Plot various formats of the raw (and immediately preprocessed) data. This
    takes a recording object (e.g. the raw recording or the bandpassed
    recording) and a label (string identifier for making titles, e.g. 'raw'
    or 'bandpassed'). Saveflag is default to 1 and will write the figures to
    disk as .pdf for later examination. Best practice is to pass a dictionary
    (here called 'plotpairs' that contains "label" and "rec". This will allow
    you to loop through a variety of processing steps of the recording and
    keep the labels organized.)

    '''

    # plot __ seconds of data
    # nsec = 3

    print("rec ", rec)
    print("label ", label)
    print("channel_group ", channel_group)
    print("clust_out_dir ", clust_out_dir)
    print("saveflag ", saveflag)

    # c_o pdf = mpdf.PdfPages("clustering_output/traces_{}_{}.pdf"
    #                         .format(label, channel_group))
    pdf = mpdf.PdfPages(op.join(clust_out_dir,
                        bn + "traces_{}_{}.pdf".format(label, channel_group)))

    try:
        groups = np.unique(rec.get_channel_groups())
        chans = np.array(rec.get_channel_ids())
        chans = np.stack((chans, np.array(rec.get_channel_groups())))
        # print("groups ", groups, " chans ", chans)
    except Exception as e:
        print("Exception ", e)
        print('no groups found for {}'.format(label))
        print('Breaking into groups of 4 for plotting purposes')
        groups = np.arange(0, rec.get_num_channels() / 4)
        chans = np.array(rec.get_channel_ids())
        chans = np.stack((chans, np.repeat(groups, 4)))

    for g in groups:
        # print("group : ", g)
        chtmp = np.squeeze(chans[0, np.where(chans[1, :] == g)])
        chcolors = plt.cm.jet(np.linspace(0, 1, np.size(chtmp)))
        # print("chtmp ", chtmp, " chcolors ", chcolors)
        sns.set_style("white",
                      {'xtick.bottom': False,
                       'axes.spines.bottom': False,
                       'xtick.top': False,
                       'axes.spines.top': False,
                       'axes.spines.right': False,
                       'axes.axisbelow': False})

        figg, axg = plt.subplots(ncols=1,
                                 nrows=np.size(chtmp),
                                 figsize=[10, 10])

        # print(chtmp)
        if chtmp.size == 1:
            print('only one good channel on group {}'.format(g))
            chtmp = np.array([chtmp])

        traces = \
            rec.get_traces(channel_ids=chtmp.astype(int),
                           start_frame=0,
                           end_frame=np.int(nsec *
                                            rec.get_sampling_frequency()))

        # xs = np.arange(0, np.shape(traces)[1])

        if chtmp.size > 1:
            chcount = 0
            for ch in np.arange(0, np.size(chtmp)):
                axg[chcount].plot(traces[ch, :], color=chcolors[chcount])
                axg[chcount].get_xaxis().set_visible(False)
                chcount += 1

        elif chtmp.size == 1:
            chcount = 0
            axg.plot(traces[0], color=chcolors[chcount])
            axg.get_xaxis().set_visible(False)

        figg.suptitle('{} signal from chan group {} ({})'
                      .format(label, g, chtmp), fontsize=16)

        if saveflag:
            pdf.savefig(figg)
            # figg.savefig('clustering_output/
            # {}_traces_group{}.pdf'.format(label, g))
            print('Finished plotting {}_traces_group{}.pdf'.format(label, g))
        else:
            pass

        plt.close(figg)

    pdf.close()


def getwfs(rec, sort, num_spikes=500, saveflag=1):

    wav = {}

    # get channel group assignments
    ch_groups = np.array(rec.get_channel_groups())

    # pull the unit IDs:
    unit_ids = sort.get_unit_ids()

    # make an anonymous function to return the group, map it to unit IDs:
    g = lambda x: sort.get_unit_property(property_name='group', unit_id=x)

    h = np.array(list(map(g, unit_ids)))

    # column 1 is the unit ID, column 2 is the group assignment
    h = np.stack((unit_ids, h), 1)

    ttic = time.time()
    for grp in np.unique(h[:, 1]):
        # Loop over the groups that produced units...
        # no sense in loading the unproductive sets.

        # which units came from that group?
        tmp_units = np.squeeze(np.where(h[:, 1] == grp))
        # which channels were in that group?
        tmp_chans = np.squeeze(np.where(ch_groups == grp))
        nchan_in_group = np.size(tmp_chans)

        start_frame = 0  # start at the beginning of the file if 0
        end_frame = None

        # load data for this group:
        print('Loading timeseries data from {} channels in group {}'
              .format(np.size(tmp_chans), grp))
        tmp_dat = rec.get_traces(channel_ids=tmp_chans,
                                 start_frame=start_frame,
                                 end_frame=end_frame)

        for u in tmp_units:

            # 2: get num_spikes random spike times from this unit
            spktimes = []
            train = sort.get_unit_spike_train(u)
            train = train[np.logical_and(train > 25,
                                         train < np.shape(tmp_dat)[1] - 51)]

            # deal with cases in which there are fewer spikes than requested:
            if np.size(train) <= num_spikes:
                num_spikes = np.size(train)
            else:
                pass
            # Pre allocate wfs arrayL
            wfs = np.zeros([nchan_in_group, 75, num_spikes])

            # deal with "spike" indices that are too close to the beginning
            # of the file and those that are too close to the end of the file
            spktimes = np.random.choice(train, num_spikes, replace=False)

            # Loop through the spike time and write them to wfs array.
            tic = time.time()
            wfcount = 0
            for t in spktimes:
                t0 = t - 25
                t1 = t + 50
                try:
                    wfs[:, :, wfcount] = tmp_dat[:, t0:t1]
                except Exception as e:
                    # pdb.set_trace()
                    print("Error : ", e)
                wfcount += 1

            toc = time.time()
            print('WF extraction for unit {} took {} seconds'
                  .format(u, toc - tic))
            wav[str(u)] = wfs

    ttoc = time.time()
    print('Total WF extraction took {} seconds'.format(ttoc - ttic))

    return (wav)


def plotwfs(wf, rec, sort, mc, ch_group, noflylist,
            clust_out_dir, lmetrics, bn="", saveflag=1):

    '''
    plot wfs
    '''

    #  import matplotlib.gridspec as gridspec
    # c_o
    # pdf = mpdf.PdfPages(f"clustering_output/unit_wfs_group{ch_group}.pdf")
    tic1 = time.time()
    pdf = mpdf.PdfPages(op.join(clust_out_dir,
                        bn + 'unit_wfs_group{}.pdf'.format(ch_group)))

    # get channel group assignments
    ch_groups = np.array(rec.get_channel_groups())

    # pull the unit IDs:
    unit_ids = sort.get_unit_ids()
    # remove the crummy ones
    if (len(noflylist) > 0):
        unit_ids = np.delete(unit_ids, np.intersect1d(unit_ids, noflylist))
    else:
        print("noflylist empty")

    # make an anonymous function to return the group, map it to unit IDs:
    g = lambda x: sort.get_unit_property(property_name='group', unit_id=x)

    h = np.array(list(map(g, unit_ids)))

    # column 1 is the unit ID, column 2 is the group assignment
    h = np.stack((unit_ids, h), 1)

    # loop across the groups that produced units:
    for grp in np.unique(h[:, 1]):

        # which units came from that group?
        tmp_units = h[np.squeeze(np.where(h[:, 1] == grp)), 0]
        if np.size(tmp_units) == 1:
            tmp_units = np.array([tmp_units])
        else:
            pass

        nunits = np.size(tmp_units)
        # ncontchan = np.sum(ch_groups == grp)  # n contributing channels

        widths = np.repeat(16 / nunits, nunits)  # array of widths for each ax
        heights = [5, 2]
        gs_kw = dict(width_ratios=widths, height_ratios=heights)

        figx, axx = plt.subplots(ncols=nunits, nrows=2, gridspec_kw=gs_kw,
                                 figsize=[16, 8], constrained_layout=True)
        figx.set_constrained_layout_pads(w_pad=0, h_pad=0.5)
        # figx.canvas.draw()
        figx.set_constrained_layout(False)

        # figx, axx = plt.subplots(ncols = nunits, nrows = 2,
        # constrained_layout = True, gridspec_kw = gs_kw, figsize = [16,8])

        sns.despine()
        sns.set()

        col = np.tile(np.arange(0, nunits), 2)
        # row = np.tile([0, 1], nunits)

        axcount = 0

        print(tmp_units)
        for tu_idx, tu in enumerate(tmp_units):  # loop over temp units
            wmeans = np.mean(wf[np.int(tu_idx)], np.int(0))
            ########################################
            # get refractory period information:
            refrac = isi_contamination(sort)
            try:
                aa = np.squeeze(np.where(refrac[:, 0] == tu))
            except Exception as e:
                # pdb.set_trace()
                print("Error : ", e)
                raise RuntimeError("Error : np.squeeze plotwfs")
            try:
                bb = (sort.get_unit_spike_train(np.int(aa)) /
                      sort.get_sampling_frequency())
            except Exception as e:
                # pdb.set_trace()
                print("Error : ", e)
                raise RuntimeError("Error : sort.get_unit_spike_train/fs")
            cc = np.diff(bb)
            edges = np.arange(0, 0.05, 0.001)
            hist = np.histogram(cc, edges)

            contam3 = np.sum(cc < 0.003) / np.size(cc)
            ########################################

            if (lmetrics > 0):
                sttxt = \
                    ('SNR:{}\nLRatio:{}\nNN_hit:{}\nPresence:{}\ndprime:{}'
                     .format('%.2f' % mc.get_metrics_df()['snr'][tu],
                             '%.2f' % mc.get_metrics_df()['l_ratio'][tu],
                             '%.2f' % mc.get_metrics_df()['nn_hit_rate'][tu],
                             '%.2f' % mc.get_metrics_df()['presence_ratio']
                             [tu],
                             '%.2f' % mc.get_metrics_df()['d_prime'][tu]))
            else:
                sttxt = ''

            # Set up components for the ISI histogram:
            xval = hist[1][0:-1]
            clrs = ['red' if (x < 0.004) else 'gray' for x in xval]
            strg = '% Cont @3 {}%'.format("%.2f" % contam3)

            if np.size(tmp_units) == 1:
                topidx = 0
                botidx = 1
            elif np.size(tmp_units) > 1:
                topidx = (0, col[axcount])
                botidx = (1, col[axcount])

            axx[topidx].plot(wmeans.T, linewidth=2, alpha=0.7)
            axx[topidx].set_title('Unit #{}'.format(tu))
            axx[topidx].yaxis.label.set_fontsize(10)
            axx[topidx].xaxis.label.set_fontsize(10)
            # Print unit statistics to the figure
            props = dict(boxstyle='round', facecolor='wheat', alpha=0.5)
            plt.text(0.77, 0.3, sttxt,
                     transform=axx[topidx].transAxes,
                     fontsize=8,
                     verticalalignment='center',
                     horizontalalignment='center',
                     bbox=props)

            # NOW PLOT THE ISI HIST:
            ip = sns.barplot(xval, hist[0], ax=axx[botidx], palette=clrs)
            ip.set(xticklabels=[], yticklabels=[])
            axx[botidx].set_title('ISI hist')

            props = dict(boxstyle='round', facecolor='wheat', alpha=0.5)
            plt.text(0.73, 0.9, strg,
                     transform=axx[botidx].transAxes,
                     fontsize=8,
                     verticalalignment='center',
                     horizontalalignment='center',
                     bbox=props)

            axcount += 1

        lchan = np.squeeze(np.where(ch_groups == grp))
        figx.legend(lchan, loc='lower right', title="Channels:")
        figx.suptitle('All units detected on group {}'.format(grp))
        figx.tight_layout()

        if saveflag:
            pdf.savefig(figx)
        plt.close(figx)

        print('Finished waveform plotting for group {}'.format(grp))
    pdf.close()
    toc1 = time.time()
    print("Time taken {} seconds".format(toc1 - tic1))
    # #########################################################################
    # #########################################################################
    # PLOT THE DISCARDED UNITS:
    #  import matplotlib.gridspec as gridspec

    # c_o
    # dpdf = mpdf.PdfPages(f"clustering_output/
    # discarded_unit_wfs_group{ch_group}.pdf")
    tic2 = time.time()
    dpdf = mpdf.PdfPages(op.join(clust_out_dir,
                                 bn + 'discarded_unit_wfs_group{}.pdf'
                                 .format(ch_group)))

    # make an anonymous function to return the group, map it to unit IDs:
    dg = lambda x: sort.get_unit_property(property_name='group', unit_id=x)

    dh = np.array(list(map(dg, noflylist)))

    # column 1 is the unit ID, column 2 is the group assignment
    dh = np.stack((noflylist, dh), 1)

    # loop across the groups that produced units:
    for dgrp in np.unique(dh[:, 1]):

        # which units came from that group?
        dtmp_units = dh[np.squeeze(np.where(dh[:, 1] == dgrp)), 0]
        if np.size(dtmp_units) == 1:
            dtmp_units = np.array([dtmp_units])
        else:
            pass

        dnunits = np.size(dtmp_units)
        # ncontchan = np.sum(ch_groups == dgrp)  # n contributing channels

        # array of widths for each ax
        widths = np.repeat(16 / dnunits, dnunits)
        heights = [5, 2]
        gs_kw = dict(width_ratios=widths, height_ratios=heights)

        dfigx, daxx = plt.subplots(ncols=dnunits, nrows=2,
                                   gridspec_kw=gs_kw, figsize=[16, 8],
                                   constrained_layout=True)
        dfigx.set_constrained_layout_pads(w_pad=0, h_pad=0.5)
        # dfigx.canvas.draw()
        dfigx.set_constrained_layout(False)

        # figx, axx = plt.subplots(ncols=nunits, nrows=2,
        # constrained_layout=True, gridspec_kw=gs_kw, figsize=[16,8])

        sns.despine()
        sns.set()

        col = np.tile(np.arange(0, dnunits), 2)
        # row = np.tile([0, 1], dnunits)

        axcount = 0

        print(dtmp_units)
        for t_idx, tu in enumerate(dtmp_units):  # loop over temp units
            wmeans = np.mean(wf[np.int(tu_idx)], np.int(0))
            ########################################
            # get refractory period information:
            refrac = isi_contamination(sort)
            try:
                aa = np.squeeze(np.where(refrac[:, 0] == tu))
            except Exception as e:
                # pdb.set_trace()
                print("Error : ", e)
                raise RuntimeError("Error : np.squeeze plotwfs")
            try:
                bb = (sort.get_unit_spike_train(np.int(aa)) /
                      sort.get_sampling_frequency())
            except Exception as e:
                # pdb.set_trace()
                print("Error : ", e)
                raise RuntimeError("Error : sort.get_unit_spike_train/fs")
            cc = np.diff(bb)
            edges = np.arange(0, 0.05, 0.001)
            hist = np.histogram(cc, edges)

            contam3 = np.sum(cc < 0.003) / np.size(cc)
            ########################################

            if (lmetrics > 0):
                sttxt = \
                    ('SNR:{}\nLRatio:{}\nNN_hit:{}\nPresence:{}\ndprime:{}'
                     .format('%.2f' % mc.get_metrics_df()['snr'][tu],
                             '%.2f' % mc.get_metrics_df()['l_ratio'][tu],
                             '%.2f' % mc.get_metrics_df()['nn_hit_rate'][tu],
                             '%.2f' % mc.get_metrics_df()['presence_ratio']
                             [tu],
                             '%.2f' % mc.get_metrics_df()['d_prime'][tu]))

            # Set up components for the ISI histogram:
            xval = hist[1][0:-1]
            clrs = ['red' if (x < 0.004) else 'gray' for x in xval]
            strg = '% Cont @3 {}%'.format("%.2f" % contam3)

            if np.size(dtmp_units) == 1:
                topidx = 0
                botidx = 1
            elif np.size(dtmp_units) > 1:
                topidx = (0, col[axcount])
                botidx = (1, col[axcount])

            daxx[topidx].plot(wmeans.T, linewidth=2, alpha=0.7)
            daxx[topidx].set_title('Unit #{}'.format(tu))
            daxx[topidx].yaxis.label.set_fontsize(10)
            daxx[topidx].xaxis.label.set_fontsize(10)
            # Print unit statistics to the figure
            props = dict(boxstyle='round', facecolor='wheat', alpha=0.5)
            plt.text(0.77, 0.3, sttxt,
                     transform=daxx[topidx].transAxes,
                     fontsize=8,
                     verticalalignment='center',
                     horizontalalignment='center',
                     bbox=props)

            # NOW PLOT THE ISI HIST:
            ip = sns.barplot(xval, hist[0], ax=daxx[botidx], palette=clrs)
            ip.set(xticklabels=[], yticklabels=[])
            daxx[botidx].set_title('ISI hist')

            props = dict(boxstyle='round', facecolor='wheat', alpha=0.5)
            plt.text(0.73, 0.9, strg,
                     transform=daxx[botidx].transAxes,
                     fontsize=8,
                     verticalalignment='center',
                     horizontalalignment='center',
                     bbox=props)

            axcount += 1

        lchan = np.squeeze(np.where(ch_groups == dgrp))
        dfigx.legend(lchan, loc='lower right', title="Channels:")
        dfigx.suptitle('All units detected on group {}'.format(dgrp))
        dfigx.tight_layout()

        if saveflag:
            dpdf.savefig(dfigx)
        plt.close(dfigx)

        print('Finished waveform plotting for group {}'.format(dgrp))
    dpdf.close()
    toc2 = time.time()
    print("Time taken noflylist {} seconds".format(toc2 - tic2))


def isi_contamination(sort):

    '''
    isi_contamination
    '''

    # pull the unit IDs:
    unit_ids = sort.get_unit_ids()

    # get inter-spike intervals
    g = lambda x: np.diff(sort.get_unit_spike_train(x) /
                          sort.get_sampling_frequency())

    # first column is unit ID, second is ISI< 3, third is ISI < 4
    isi_list = np.zeros([np.size(unit_ids), 3])
    isi_list[:, 0] = unit_ids

    count = 0
    for u in unit_ids:
        isi = g(u)
        isi_list[count, 1] = np.sum(isi < 0.003) / np.size(isi)
        isi_list[count, 2] = np.sum(isi < 0.004) / np.size(isi)
        count += 1

        # isi = g(36)
        # edges   = np.linspace(0,.1,100)
        # bcounts    = np.histogram(isi,edges)
        # plt.bar( np.arange(0,np.size(bcounts[0] +1)) , bcounts[0] )
        # plt.show()

    return (isi_list)


def compute_pca_scores(rec, sort, n_comp=3, plot3=False):

    '''
    Compute pca scores
    Compute PCA scores across the tetrode (concatenate the channels):
    '''

    get_pca = st.postprocessing.compute_unit_pca_scores
    pca_scores = get_pca(rec,
                         sort, n_comp=n_comp,
                         verbose=True,
                         grouping_property='group',
                         compute_property_from_recording=True,
                         whiten=False)

    for pc in pca_scores:
        print(pc.shape)

    if plot3:
        #  from mpl_toolkits import mplot3d

        fig, ax = plt.subplots(figsize=(7, 7))
        fig.tight_layout()
        ax = plt.axes(projection='3d')

        for i in np.arange(0, len(sort.get_unit_ids())):
            ax.scatter3D(pca_scores[i][:, 0], pca_scores[i][:, 1],
                         pca_scores[i][:, 2], marker='*', alpha=0.7)
    else:
        pass

    return (pca_scores)


def plot_pca(rec, sort, pca_scores, ch_group, noflylist,
             clust_out_dir, bn="", nplots=6):

    '''
    plot pca

    '''

    max_points = 100
    # import pdb
    #  In this case, as expected, 3 principal components are extracted for each
    #  electrode.
    print('Plotting PCA figures. This takes a moment.')

    # get channel group assignments
    # ch_groups = np.array(rec.get_channel_groups())

    # pull the unit IDs:
    unit_ids = sort.get_unit_ids()

    if (len(noflylist) > 0):
        unit_ids = np.delete(unit_ids, np.intersect1d(unit_ids, noflylist))
    else:
        print("noflylist empty")

    # make an anonymous function to return the group, map it to unit IDs:
    g = lambda x: sort.get_unit_property(property_name='group', unit_id=x)

    h = np.array(list(map(g, unit_ids)))

    # column 1 is the unit ID, column 2 is the group assignment
    h = np.stack((unit_ids, h), 1)

    # get n electrodes contributing
    ne = np.shape(pca_scores[0])[1]

    # set up  xy coords for subplots
    yv = np.tile(np.arange(0, np.int(np.ceil(nplots / 2))),
                 np.int(np.ceil(nplots / 2)))
    xv = np.repeat([0, 1], np.ceil(nplots / 2))

    # generate all pairs of electrodes for visualization:
    a = np.arange(0, ne)
    c = [(i, j) for i in a for j in a]
    c2 = np.array(c)
    # get rid of plotting against self.
    kills = np.where(np.diff(c, 1) == 0)[0]
    c2 = np.delete(c2, kills, 0)
    # pick four for plotting:
    d = np.random.choice(np.shape(c2)[0], nplots, replace=False)

    # pick the PC to plot. you can change this to be more complicated later,
    # but for now stick with the first principal component
    # to explain the most variance.
    pc_use = 0

    # c_o
    # with mpdf.PdfPages(f'clustering_output/PCA_group{ch_group}.pdf') as pdf:
    with mpdf.PdfPages(op.join(clust_out_dir,
                       bn + 'PCA_group{}.pdf'.format(ch_group))) as pdf:
        for grp in np.unique(h[:, 1]):

            units = np.squeeze(h[np.where(h[:, 1] == grp), 0])
            # get number of units from this group:
            # nu = np.size(units)

            fig, ax = plt.subplots(ncols=2, nrows=np.int(np.ceil(nplots / 2)),
                                   figsize=(9, 9))
            fig.tight_layout()

            count = 0
            for r in np.arange(0, nplots):

                if np.size(units) == 1:
                    units = np.array([np.int(units)])
                else:
                    pass

                ucount = 0
                for i in units:

                    chanx = c2[d[r]][0]
                    chany = c2[d[r]][1]
                    # try:
                    # ax[yv[count], xv[count]].scatter(
                    # pca_scores[ucount][0:100, chanx, pc_use],
                    # pca_scores[ucount][0:100, chany, pc_use],
                    # color = colors[ucount], marker = '*', alpha = 0.3)
                    # ax[yv[count], xv[count]].scatter(
                    # pca_scores[ucount][0:100, chanx, pc_use],
                    # pca_scores[ucount][0:100, chany, pc_use],
                    # cmap = plt.cm.set3, marker = '*', alpha = 0.3)
                    # ax[yv[count], xv[count]].scatter(pca_scores[i][0:100,
                    #                                  chanx, pc_use],
                    # pca_scores[i][0:100, chany, pc_use],
                    # cmap=plt.get_cmap('Set3'), marker='*', alpha=0.3)
                    # except:
                    # pdb.set_trace()
                    # print("i ", i)
                    # print("pc use ", pc_use)
                    # print("pca_scores len ", len(pca_scores[i]))
                    # print("pca_scores len2 ", np.array(pca_scores[i]).shape)
                    # print("chany sh ", chany)
                    # print("chanx sh ", chanx)
                    pca_score_shape = np.array(pca_scores[i]).shape
                    if ((chanx < pca_score_shape[1]) and
                       (chany < pca_score_shape[1])):
                        if (max_points < pca_score_shape[0]):
                            ax[yv[count], xv[count]]\
                                .scatter(pca_scores[i]
                                         [0:max_points, chanx, pc_use],
                                         pca_scores[i]
                                         [0:max_points, chany, pc_use],
                                         cmap=plt.get_cmap('Set3'),
                                         marker='*', alpha=0.3)
                        else:
                            ax[yv[count], xv[count]]\
                                .scatter(pca_scores[i]
                                         [0:pca_score_shape[0], chanx, pc_use],
                                         pca_scores[i]
                                         [0:pca_score_shape[0], chany, pc_use],
                                         cmap=plt.get_cmap('Set3'),
                                         marker='*', alpha=0.3)
                    else:
                        print("Error:Skipped pca chanx, y and shape {} {} {}".
                              format(chanx, chany, pca_score_shape[1]))

                    ax[yv[count], xv[count]]\
                        .set_title('Probe {} PC {} x Probe {} PC {}'
                                   .format(chanx, pc_use, chany, pc_use))

                    ax[yv[count], xv[count]].get_xaxis().set_visible(False)
                    ax[yv[count], xv[count]].get_yaxis().set_visible(False)
                    ucount += 1

                fig.legend(units, loc='lower right', title="Unit IDs:")

                count += 1

            pdf.savefig(fig)

            plt.close(fig)


def compute_metrics(sort, rec, ch_group,
                    clust_out_dir, bn="",
                    verbose=True):

    '''
    Call spikeinterface functions to compute a variety of metrics that are
    helpful in curation. The toolkit.validation submodule has a
    MetricCalculator class that enables you to compute metrics in a compact and
    easy way. You first need to instantiate a MetricCalculator object with
    SortingExtractor and RecordingExtractor objects.

    Beware: This is a slow set of functions. You can speed thigns up by passing
    a list of only the metrics that you want to extract, rather than pulling
    all of them. Here are the metrics that are included in spikeinterface's
    internal kit (note that isi % contamination is missing. isi_viol seems
    inaccurate thus far):

    ‘firing_rate’,
    ‘num_spikes’,
    ‘isi_viol’,
    ‘presence_ratio’,
    ‘amplitude_cutoff’,
    ‘max_drift’,
    ‘cumulative_drift’,
    ‘silhouette_score’,
    ‘presence_ratio’,
    ‘isolation_distance’, # Computes and returns the mahalanobis metric,
                          isolation distance, for the sorted dataset.
    ‘l_ratio’, # Computes and returns the mahalanobis metric,
               l-ratio, for the sorted dataset.
    ‘d_prime’, # Computes and returns the lda-based metric, d-prime,
               for the sorted dataset.
    ‘nn_hit_rate’, # nearest neighbor metrics
    ‘nn_miss_rate’, # nearest neighbor metrics
    ‘snr’.

    If metric_names is None, all metrics will be calculated.
    Otherwise, pass a list of names from above.

    '''

    # metric_names = ["presence_ratio","l_ratio","d_prime",
    # "nn_hit_rate","nn_miss_rate"]
    metric_names = None

    # Step 1: Compute initial data necessary for computing metrics:
    mc = st.validation.MetricCalculator(sort, recording=rec, verbose=verbose)

    maxn = 1500   # max spikes per cluster for related metrics
    maxnn = 1500  # max spikes if you're calculating nearest neighbor stats
    # Step 2: Then compute metrics (the slow step)
    # mc.compute_metrics(metric_names=metric_names,
    # max_spikes_per_cluster=maxn, max_spikes_for_nn=maxnn,)
    # mc.compute_metrics(isi_threshold=0.0015,
    #                    min_isi=0.000166,
    #                    snr_mode="mad",
    #                    snr_noise_duration=10.0,
    #                    max_spikes_per_unit_for_snr=maxn,
    #                    drift_metrics_interval_s=51,
    #                    drift_metrics_min_spikes_per_interval=10,
    #                    max_spikes_for_silhouette=maxn,
    #                    num_channels_to_compare=4,
    #                    max_spikes_per_cluster=maxn,
    #                    max_spikes_for_nn=maxnn,
    #                    n_neighbors=4,
    #                    metric_names=None,
    #                    seed=0)
    mc.compute_metrics(max_spikes_per_cluster=maxn,
                       max_spikes_for_nn=maxnn,
                       n_neighbors=4,
                       metric_names=metric_names,
                       seed=0)

    # #########################################################################
    # This is the list of the computed metrics:
    print(list(mc.get_metrics_dict().keys()))

    # #########################################################################
    # The :code:`get_metrics_dict` and :code:`get_metrics_df`
    # return all metrics as a dictionary or a pandas dataframe:

    print(mc.get_metrics_dict())
    print(mc.get_metrics_df())

    # Write the dataframe to a .csv file
    # c_o
    # mc.get_metrics_df().to_csv(
    # f'clustering_output/all_metrics_group{ch_group}.csv')
    mc.get_metrics_df().to_csv(op.join(clust_out_dir,
                                       bn + 'all_metrics_group{}.csv'
                                       .format(ch_group)))

    # #########################################################################
    # If you don't need to compute all metrics, you can either pass a
    # 'metric_names' list to the `compute_metrics` or
    # call separate methods for computing single metrics:

    # This only computes signal-to-noise ratio (SNR)
    # mc.compute_metrics(metric_names=['snr'])

    print(mc.get_metrics_df()['snr'])
    print(mc.get_metrics_df()['l_ratio'])
    print(mc.get_metrics_df()['d_prime'])
    print(mc.get_metrics_df()['isolation_distance'])
    print(mc.get_metrics_df()['cumulative_drift'])
    print(mc.get_metrics_df()['nn_hit_rate'])
    print(mc.get_metrics_df()['nn_miss_rate'])
    print(mc.get_metrics_df()['isi_viol'])
    print(mc.get_metrics_df()['presence_ratio'])
    print(mc.get_metrics_df()['silhouette_score'])

    isi_list = isi_contamination(sort)
    # a = np.log(mc.get_metrics_df()['isi_viol'])
    b = mc.get_metrics_df()['l_ratio']
    c = mc.get_metrics_df()['nn_hit_rate']
    # d = mc.get_metrics_df()['d_prime']
    # e = mc.get_metrics_df()['silhouette_score']
    f = mc.get_metrics_df()['isolation_distance']
    # g = mc.get_metrics_df()['snr']
    # h = mc.get_metrics_df()['nn_miss_rate']
    i = isi_list[:, 1]

    # This function also returns the SNRs (as an example)
    # snrs = st.validation.compute_snrs(sorting_MS4, recording_pp)
    # print(snrs)

    # c_o
    # with mpdf.PdfPages(f'clustering_output/
    # clust_qual_scatter_group{ch_group}.pdf') as pdf:
    with mpdf.PdfPages(op.join(clust_out_dir,
                               bn + 'clust_qual_scatter_group{}.pdf'
                               .format(ch_group))) as pdf:
        sns.set_style('darkgrid')

        figi, axi = plt.subplots(nrows=1, ncols=1, figsize=[10, 10])

        sns.scatterplot(b, i, hue=f, size=c, ax=axi)

        axi.set_ylabel('ISI contamination %')
        axi.set_title('Cluster Quality Metrics by Unit')

        pdf.savefig()  # saves the current figure into a pdf page
        plt.close()

    return mc, isi_list


def plotmda(datdirec):

    '''
    IN DEVELOPMENT! Pass this the directory containing the MDA file, save the
    working direction, cd into the data directory, do the plotting, then cd
    back to the OG working directory (for cases in which you're not doing
    everything in the same directory.) #### Take a look at the raw data in
    the MDA file for the sake of sanity.

    '''

    g = os.pwd()
    x = ss.utils.mdaio.readmda('raw.mda')
    num_channels = np.shape(x)[0]
    ntets = num_channels / 4

    rc = np.int(np.ceil(np.sqrt(num_channels / 4)))
    c = np.tile(np.arange(0, rc), rc)
    r = np.repeat(np.arange(0, rc), rc)

    fig1, ax1 = plt.subplots(nrows=rc, ncols=rc)

    count = 0
    for i in np.arange(0, ntets):

        firstchan = np.int(i * 4)

        for g in np.arange(0, 4):
            ax1[r[count], c[count]]\
                .plot(x[firstchan + g, 0:25000 * 5] + 100 * g)

        # ax1[i].axis('off')
        count += 1

    fig1.suptitle('Five Sec. of Raw Data from Channels {} through {}'
                  .format(1, num_channels))


def plot_trace_clust(rec, sort, noflylist,
                     clust_out_dir,
                     bn="",
                     startsec=30,
                     nsec=2):

    '''
    This function makes clust_projection_datatrace.pdf plot in clust_out_dir
       directory

    plot_trace_clust(recording, sorting, clust_out_dir, startsec=30, nsec=2)

    Parameters
    ----------
    recording : recording objects
    sort : sorting objects
    noflylist : List of bad units
    clust_out_dir : directory to save numpy files of
                    rec_channels_std, num_channels and rec_length
    startsec : From which second to start plotting rawdata to plot spikes
    nsec : Number of seconds from startsec to plot rawdata to plot spikes

    Returns
    -------

    Raises
    ------

    See Also
    --------

    Notes
    -----

    Examples
    --------
    plot_trace_clust(recording_pp, sorting_MS4, clust_out_dir,
                     startsec=30, nsec=2)

    '''

    print('Projecting clusters onto raw data. Plotting.')

    # constants
    wf_size = np.int64(30)
    dcolors = ['#ff028d', '#c7fdb5', '#9a0eea', '#069af3', '#fffe40',
               '#f58231', '#3f9b0b', '#46f0f0', '#bcf60c', '#fabebe',
               '#008080', '#e6beff', '#9a6324', '#800000', '#ff9408',
               '#aaffc3', '#808000', '#ffd8b1', '#000075', '#808080',
               '#2ee8bb', '#ffffff', '#000000', '#fff000']

    # Get basic info
    fs = rec.get_sampling_frequency()
    t0 = np.int(startsec * fs)
    # t1 = np.int(startsec * fs + np.int(nsec * fs))
    t1 = np.int(t0 + np.int(nsec * fs))

    with mpdf.PdfPages(op.join(clust_out_dir,
                       bn + 'clust_projection_datatrace.pdf')) as pdf:

        # pull the unit IDs:
        unit_ids = sort.get_unit_ids()

        # remove the crummy ones
        if (len(noflylist) > 0):
            unit_ids = np.delete(unit_ids, np.intersect1d(unit_ids, noflylist))
        else:
            print("noflylist empty")

        # make an anonymous function to return the group, map it to unit IDs:
        g = lambda x: sort.get_unit_property(property_name='group',
                                             unit_id=x)

        h = np.array(list(map(g, unit_ids)))

        # column 1 is the unit ID, column 2 is the group assignment
        h = np.stack((unit_ids, h), 1)
        # print("t0 ", t0, " t1 ", t1)
        # print("h ", h)

        # get channel group assignments
        chgroups = np.array(rec.get_channel_groups())
        # print("chgroups ", chgroups)

        for gg in np.unique(h[:, 1]):

            thesechans = np.squeeze(np.where(chgroups == gg))
            # print("thesechans ", thesechans)
            theseclusts = h[:, 0][np.where(h[:, 1] == gg)]
            # print("theseclusts ", theseclusts)

            figc, axc = plt.subplots(ncols=1, nrows=np.size(thesechans),
                                     figsize=[16, 10], sharex=True,
                                     gridspec_kw={'hspace': 0})

            print("t0 ", t0, " t1 ", t1, " thesechans ", thesechans)
            trace = rec.get_traces(channel_ids=thesechans,
                                   start_frame=t0, end_frame=t1)

            for i, ch in enumerate(thesechans):
                groupch = np.squeeze(np.where(thesechans == ch))
                # Plot the raw traces in this channel group
                axc[i].plot(trace[groupch, :], color=[0.4, 0.4, 0.4],
                            linewidth=0.5)
                sns.despine(left=True, bottom=True)

            # Add more colors to dcolors if needed
            if (len(theseclusts) > len(dcolors)):
                print("Added more colors")
                dcolors.extend(list(matplotlib.colors.cnames.values()))

            for c, clust in enumerate(theseclusts):
                # Pull the spike times from this cluster that fit
                # within the time window being plotted
                print(f'Projecting spike trains from cluster {clust}')
                clr = dcolors[c]

                # WF size, so t do not go out of bounds
                t1l = t1 - wf_size
                t0l = t0 + wf_size
                temptimes = sort.get_unit_spike_train(clust)
                temptimes = temptimes[np.where(np.logical_and
                                               (temptimes < t1l,
                                                temptimes > t0l))]

                tcount = 0
                axcount = 0
                # j is the axis, k is the channel (use for y data)
                for j, k in zip(figc.axes, thesechans):
                    maxch = thesechans[sort.get_unit_property(clust,
                                                              'max_channel')]

                    for t in temptimes:
                        if maxch == k:
                            alphaval = 0.75
                        else:
                            alphaval = 0.5
                        # print("t 1 ", t, " t1 ", t1, " t0 ", t0)
                        # print("t 1 ", t, " t1 ", t1, " t0 ", t0,
                        #       " t0l ", t0l, " t1l ", t1l)
                        # t = t - fs*startsec
                        t = t - t0
                        # print("t 2 ", t, )
                        # solid line plotting for single units
                        gch = np.squeeze(np.where(thesechans == k))
                        # print("gch ", gch)
                        # print("trace ", trace[gch, int(t-30):int(t+30)])
                        # print("shape trace ",
                        #       len(trace[gch, int(t-30):int(t+30)]))
                        j.plot(np.arange(t - wf_size, t + wf_size),
                               trace[gch, int(t - wf_size):int(t + wf_size)],
                               alpha=alphaval, linewidth=2.0,
                               color=clr,
                               label=f'Unit {clust}'
                               if np.sum([axcount, tcount]) == 0 else '')

                        tcount = 1
                        axcount = 1

            figc.legend()

            # xlims = axc[0].get_xlim()
            axc[0].set_xlim([0, nsec*fs])
            plt.draw()
            # labels = [item.get_text() for item in ax[-1].get_xticklabels()]
            # print("labels ", labels)
            # labels2 = [int(int(i)/25) for i in labels]
            # print("labels2 ", labels2)
            # ax[-1].set_xticklabels(labels2);
            # ax[-1].set_xlabel('Time (msec)',fontsize = 16);

            figc.text(0.09, 0.5, 'Voltage (uV)', va='center',
                      rotation='vertical', fontsize=16)

            axc[0].set_title('Clusters {} on channels {}'.format(theseclusts,
                                                                 thesechans))

            pdf.savefig(figc)
            plt.close(figc)


def widget_plots(rec, sort, noflylist,
                 clust_out_dir, lmetrics, bn=""):

    '''
    Run some of the widget plots from within spikeinterface. They're annoying
    to use... Currently outputting cross correlograms and amplitude spread and
    drift.

    '''

    maxspk = 1500

    # pull the unit IDs:
    unitlist = sort.get_unit_ids()
    # remove the crummy ones
    if (len(noflylist) > 0):
        unitlist = np.delete(unitlist, np.intersect1d(unitlist, noflylist))
    else:
        print("noflylist empty")

    # make an anonymous function to return the group, map it to unit IDs:
    g = lambda x: sort.get_unit_property(property_name='group', unit_id=x)

    h = np.array(list(map(g, unitlist)))

    # column 1 is the unit ID, column 2 is the group assignment
    h = np.stack((unitlist, h), 1)

    # get channel group assignments
    chgroups = np.array(rec.get_channel_groups())
    # c_o
    # with mpdf.PdfPages(f'clustering_output
    # /amplitude_descriptives.pdf') as zpdf:
    if (lmetrics > 0):
        with mpdf.PdfPages(op.join(clust_out_dir,
                                   bn + 'amplitude_descriptives.pdf')) as zpdf:
            for gg in np.unique(h[:, 1]):

                thesechans = np.squeeze(np.where(chgroups == gg))
                theseclusts = h[:, 0][np.where(h[:, 1] == gg)]

                # sharex=True, gridspec_kw={'hspace': 0}
                figw, axw = plt.subplots(ncols=1, nrows=1,
                                         figsize=[16, 10])

                sw.plot_amplitudes_distribution(rec, sort,
                                                max_spikes_per_unit=maxspk,
                                                unit_ids=theseclusts,
                                                figure=figw, ax=axw)

                # sharex=True, gridspec_kw={'hspace': 0}
                figy, axy = plt.subplots(ncols=1, nrows=np.size(theseclusts),
                                         figsize=[16, 10])

                for aa, bb in zip(figy.axes, theseclusts):
                    sw.plot_amplitudes_timeseries(rec, sort,
                                                  max_spikes_per_unit=maxspk,
                                                  unit_ids=np.array([bb]),
                                                  figure=figy, ax=aa)
                zpdf.savefig(figy)
                zpdf.savefig(figw)
                plt.close('figw')
                plt.close('figy')

    # Plot cross correlograms by channel group
    # c_o
    # with mpdf.PdfPages(f'clustering_output/crosscorrelograms.pdf') as ccpdf:
    with mpdf.PdfPages(op.join(clust_out_dir,
                       bn + 'crosscorrelograms.pdf')) as ccpdf:

        for gg in np.unique(h[:, 1]):

            thesechans = np.squeeze(np.where(chgroups == gg))
            theseclusts = h[:, 0][np.where(h[:, 1] == gg)]

            figcc, axcc = plt.subplots(ncols=1, nrows=1, figsize=[10, 10])
            tmp_fs = sort.get_sampling_frequency()
            # sw.plot_crosscorrelograms(sort,
            # sampling_frequency=sort.get_sampling_frequency(),
            # unit_ids=theseclusts, bin_size=1,
            # window=10, figure=figcc, ax=axcc)
            sw.plot_crosscorrelograms(sort,
                                      sampling_frequency=tmp_fs,
                                      unit_ids=theseclusts,
                                      bin_size=1, window=10,
                                      figure=figcc, ax=axcc)

            # figcc.suptitle(f'Cross correlograms for units {theseclusts}
            # on channels {thesechans}')
            figcc.suptitle('Cross correlograms for units {} on channels {}'
                           .format(theseclusts, thesechans))

            ack = plt.gcf()
            ack.set_size_inches(10, 10)
            ccpdf.savefig(figcc)
            plt.close('figcc')


def compute_SNR(rec, clust_out_dir,
                ch_group, bn="",
                nsec=60):

    '''
    This function computes signal to noise ratio for all channels and saves
       rec_channels_std, num_channels and rec_length in clust_out_dir

    compute_SNR(recording, clust_out_dir, ch_group, nsec=60)

    Parameters
    ----------
    recording : recording objects
    clust_out_dir : directory to save numpy files of
                    rec_channels_std, num_channels and rec_length
    ch_group : group number
    nsec : number of seconds of data from which rec_channels_std
           to be calculated

    Returns
    -------
    rec_length : recording length

    Raises
    ------

    See Also
    --------

    Notes
    -----

    Examples
    --------
    compute_SNR(recording, clust_out_dir, ch_group, nsec=60)

    '''

    # Get number of channels and length
    num_channels = rec.get_num_channels()
    rec_length_for_std = np.int64(nsec * rec.get_sampling_frequency())
    rec_length = rec.get_num_frames()
    print('Num. channels = {}'.format(num_channels))
    print('Num. timepoints = {}'.format(rec_length),
          flush=True)

    # Calculate start and end
    if (rec_length > rec_length_for_std):
        start = np.random.randint(0, high=(rec_length - rec_length_for_std),
                                  size=1, dtype='int64')
        end = start + rec_length_for_std
        print("start ", start, " end ", end)
        print("shape start ", start.shape, " shape end ", end.shape)
        # get raw data
        dat_for_std = rec.get_traces(start_frame=start[0], end_frame=end[0])
    else:
        start = 0
        end = rec_length
        print("start ", start, " end ", end)
        dat_for_std = rec.get_traces(start_frame=start, end_frame=end)

    # Calculate std for each channel
    rec_channels_std = []
    for chans in range(num_channels):
        chan_std = np.std(dat_for_std[chans, :])
        print('Standard deviation for channel {} is {}'
              .format(chans, chan_std))
        rec_channels_std.append(chan_std)

    # Save rec_channels_std, num_channels and rec_length
    # so it can be used in mbt latter
    np.save(op.join(clust_out_dir,
            bn + "rec_channels_std{}.npy".format(ch_group)),
            rec_channels_std)
    np.save(op.join(clust_out_dir,
            bn + "num_channels{}.npy".format(ch_group)),
            num_channels)
    np.save(op.join(clust_out_dir,
            bn + "rec_length{}.npy".format(ch_group)),
            rec_length)
    return rec_length


def bigmamma(thresh,
             folder,
             datdir,
             lfp,
             sortpick,
             probefile, # geom here
             sorter_config,
             clust_out_dir,
             bad_chan_list=None, # doesn't work
             rawdatfilt=None, lnosplit=0, lsorting=1, num_cpu=1,
             sampling_frequency=25000,
             ecube_time_list=None,
             file_datetime_list=None,
             bn="",
             ndi_input=False,
             ndi_hengen_path=False):

    '''
    WRITE ME!!!!!

    '''

    # current_chan_dir = datdir + 'grouped_raw_dat_temp_folder/' + folder
    current_chan_dir = op.join(datdir, folder)
    print("datdir ", datdir)
    print("folder ", folder)
    print("current_chan_dir ", current_chan_dir)
    print("pwd 4 ", os.getcwd())
    os.chdir(current_chan_dir)
    print("pwd 5 ", os.getcwd())
    print("clust_out_dir ", clust_out_dir)

    params_file = 1

    if params_file:
        # create a params.json file. If you already have one in the directory,
        # you can skip this, but it only takes a few milliseconds and
        # might not be worth the trouble of tinkering with.
        # params = {
        #     "samplerate": 25000,
        #     "spike_sign": -1,
        #     "adjacency_radius": 100
        # }
        params = {
            "samplerate": sampling_frequency,
        }
        with open('params.json', 'w') as fp:
            json.dump(params, fp)
    else:
        pass
    # TODO: add ndi inputted geometry of probe
    # create a .geom file
    geom = 1
    if geom:
        # if ndi input pass in dummy geometry
        if args.ndi_input:
            geom = ndi_input['g']
            
        # else run code below
        else:
            tetrode = 1 # unused
            # ckbn todo remove hardcoding
            g = ss.utils.mdaio.readmda_header('raw.mda') # hardcoded

            print("\ng ", g)
            num_channels = g.dims[0]
            print("num_channels ", num_channels)
            ntets = num_channels / 4
            print("ntets ", ntets)
            geom = np.zeros((num_channels, 2))
            geom[:, 0] = range(num_channels)

            for i in np.arange(0, num_channels, 4): # modify channels and channel groups accordingly
                geom[i, :] = [100 * i + 0, 100 * i + 25]
                geom[i + 1, :] = [100 * i + 25, 100 * i + 25]
                geom[i + 2, :] = [100 * i - 25, 100 * i - 25]
                geom[i + 3, :] = [100 * i + 25, 100 * i + 0]

            print("Intial geom before probefile {}\n".format(geom))
            np.savetxt("geom.csv", geom, delimiter=",", fmt='%i')
    else:
        pass
    # ####################### Load the recording ##############################
    if ndi_input:
        ndi_input = scipy.io.loadmat(os.path.join(ndi_hengen_path, 'ndiouttmp.mat'))

        ndi_timeseries = ndi_input['d']
        ndi_samplerate = ndi_input['sr']

        # TODO: add geom to extractor
        recording = se.NumpyRecordingExtractor(timeseries=np.transpose(ndi_timeseries), sampling_frequency=ndi_samplerate, geom=geom)

    else:
        # first load recording with geom (default)
        recording = se.MdaRecordingExtractor(current_chan_dir)

    # Standard deviation of first channel in the list
    # if length is less than 10 minutes
    print('Num. channels = {}'.format(len(recording.get_channel_ids())))
    print('Num. timepoints = {}'.format(recording.get_num_frames()),
          flush=True)
    # if (recording.get_num_frames() < (25000 * 600)):
    #     _tmp_channel = recording.get_channel_ids()[0]
    #     print('Stdev. on {} channel = {}'.
    #           format(_tmp_channel,
    #                  np.std(recording.get_traces(_tmp_channel))))

    # TODO: ask Kiran about lnosplit
    # gonna load the prb file now
    tic = time.time()
    print('lnosplit ', lnosplit)
    if lnosplit:
        channel_group = int(folder[folder.rfind("_") + 1:])
        print('datdir ', datdir)
        print('folder ', folder)
        print('pwd ', os.getcwd())

        shutil.copyfile(probefile, "grp_0.prb")

        prb_file_name = glob.glob('*.prb')[0]

        print("prb_file_name ", prb_file_name)

        # def load_probe_file(recording, probe_file, channel_map=None,
        #                     channel_groups=None, verbose=False):
        recording_prb = recording.load_probe_file(probe_file=prb_file_name,
                                                  verbose=True)

    else:
        channel_group = int(folder[folder.rfind("_") + 1:])
        offset = 4 * channel_group
        channel_ids = [x + offset for x in [0, 1, 2, 3]]
        geometry_base = [[0, 0], [1, 0], [0, 1], [1, 1]]
        x_offset = 3 * channel_group
        geometry = [[x + x_offset, y] for [x, y] in geometry_base]
        labels = [f't_{channel_group}{x}' for x in [0, 1, 2, 3]]

        probe_file = makeProbeFile(channel_group, channel_ids,
                                   geometry, labels)

        prb_file_name = glob.glob('*.prb')[0]

        recording_prb = recording.load_probe_file(probe_file=prb_file_name,
                                                  verbose=True)
    toc = time.time()
    print('\nSpikeInterface load probefile took {} seconds'.
          format(toc - tic), flush=True)

    # Bandpass the recording
    tic = time.time()
    # def bandpass_filter(recording, freq_min=300,
    #                     freq_max=6000, freq_wid=1000,
    #                     type='fft', order=3,
    #                     chunk_size=30000, cache_to_file=False,
    #                     cache_chunks=False):
    # chunk_size: int
    #    The chunk size to be used for the filtering.
    # cache_to_file: bool (default False).
    #    If True, filtered traces are computed and cached all at once on
    #             disk in temp file
    # cache_chunks: bool (default False).
    #    If True then each chunk is cached in memory (in a dict)

    # Load sorter_config file and adjust bandpass range
    try:
        with open(sorter_config, 'r') as f:
            d_sort_config = json.load(f)
        # Get data
        dsc_chunk_size = int(d_sort_config['chunk_size'])
        dsc_freq_min = float(d_sort_config['freq_min'])
        dsc_freq_max = float(d_sort_config['freq_max'])
        print("dsc_chunk_size ", dsc_chunk_size)
        print("dsc_freq_min ", dsc_freq_min)
        print("dsc_freq_max ", dsc_freq_max)
    except Exception as e:
        print("Error : ", e)
        raise ValueError('Error please check data in file {}'
                         .format(sorter_config))

    recording_f = st.preprocessing.bandpass_filter(recording_prb,
                                                   freq_min=dsc_freq_min,
                                                   freq_max=dsc_freq_max,
                                                   freq_wid=1000,
                                                   type='fft', order=3, # TODO: add type of bandpass butter or fft
                                                   chunk_size=dsc_chunk_size,
                                                   cache_to_file=True,
                                                   cache_chunks=False)

    # NB: cache_to_file is VERY important for speeding things up. Prevents lazy
    # operations from bogging you down in sorting and processing snippets of
    # the timeseries (e.g. when calculating WFs etc.) In testing, this cut ms4
    # clustering from 600s to 150s.
    toc = time.time()
    print('\nSpikeInterface bandpass filter took {} seconds'.
          format(toc - tic), flush=True)

    # identify bad channels? # FIGURE OUT HOW TO MAKE THIS PROPAGATE THROUGH!
    # Probe file seems to disrupt it??? KIRAN - somehow this is fucking up
    # postprocessing. Can't calculate max channel when we sort with bad
    # channels removed... bug in their code? KIRAN - we should debug this
    if bad_chan_list is not None:
        rbad = 1
        print("rbad ", rbad)
    else:
        rbad = 0
        print("rbad ", rbad)
    if rbad:
        recording_f_remove_bad = badchans(recording_f, bad_chan_list,
                                          nsec=5, cutoff=5)
        recording_f = recording_f_remove_bad
    else:
        pass

    # Perform common median referencing (Kiran also likes to use common mean.
    # Will do direct comparison later on.)
    # def common_reference(recording, reference='median', groups=None,
    #                      ref_channels=None, verbose=False):
    #     reference: str
    #       'median', 'average', or 'single'.
    #       If 'median', common median reference (CMR) is implemented (the
    #        median of the selected channels is removed for each timestamp).
    #       If 'average', common average reference (CAR) is implemented (the
    #        mean of the selected channels is removed
    #       for each timestamp).
    #       If 'single', the selected channel(s) is remove from all channels.
    #     groups: list
    #       List of lists containins the channels for splitting the reference.
    #        The CMR, CAR, or referencing with respect to single channels are
    #        applied group-wise. It is useful when dealing with different
    #        channel groups, e.g. multiple tetrodes.
    #     ref_channels: list or int
    #       If no 'groups' are specified, all channels are referenced to
    #        'ref_channels'. If 'groups' is provided, then a list of channels
    #        to be applied to each group is expected. If 'single' reference, a
    #        list of one channel  or an int is expected.

    if rawdatfilt == 'median':
        tic = time.time()
        print('\nSpikeInterface rawdatfilt median')
        recording_cmr = st.preprocessing.common_reference(recording_f,
                                                          reference='median')
        toc = time.time()
        print('SpikeInterface rawdatfilt average took {} seconds'.
              format(toc - tic), flush=True)
    elif rawdatfilt == 'average':
        tic = time.time()
        print('\nSpikeInterface rawdatfilt average')
        recording_cmr = st.preprocessing.common_reference(recording_f,
                                                          reference='average')
        toc = time.time()
        print('SpikeInterface rawdatfilt average took {} seconds'.
              format(toc - tic), flush=True)
    elif rawdatfilt.startswith('blank_saturation'):
        tic = time.time()
        print('\nSpikeInterface rawdatfilt blank_saturation')
        bs_threshold = float(rawdatfilt.split('_')[-1])
        print('SpikeInterface rawdatfilt blank_saturation threshold is {}'
              .format(bs_threshold))
        recording_cmr = \
            st.preprocessing.blank_saturation(recording_f,
                                              threshold=bs_threshold)
        toc = time.time()
        print('SpikeInterface rawdatfilt blank_saturation took {} seconds'.
              format(toc - tic), flush=True)
    else:
        print('\nrawdatfilt {}\n'.format(rawdatfilt))
        recording_cmr = recording_f

    # Whiten the recording
    white = 0
    if ((white) and (rawdatfilt is not None)):
        recording_w = st.preprocessing.whiten(recording_cmr,
                                              cache_chunks=True)
        recording_pp = recording_w
    elif ((white) and (rawdatfilt is None)):
        recording_w = st.preprocessing.whiten(recording_f,
                                              cache_chunks=True)
        recording_pp = recording_w
    else:
        recording_pp = recording_cmr

    # Do you want to extract LFP?
    if lfp:
        tic = time.time()
        # SAHARA remember to concatenate the LFP when users want to save it
        print('\nExtracting LFP', flush=True)
        # recording_lfp = st.preprocessing.bandpass_filter(recording,
        #                                                  freq_min=0.1,
        #                                                  freq_max=250
        #                                                  )

        ltic = time.time()
        recording_lfp = st.preprocessing.bandpass_filter(recording,
                                                         freq_min=0.1,
                                                         freq_max=250,
                                                         freq_wid=1000,
                                                         type='fft',
                                                         order=3,
                                                         chunk_size=90000,
                                                         cache_to_file=True,
                                                         cache_chunks=False)
        ltoc = time.time()
        print('SpikeInterface lfp bandpass filter took {} seconds'.
              format(ltoc - ltic), flush=True)

        print('Downsampling LFP', flush=True)
        ltic = time.time()
        recording_lfp = st.preprocessing.resample(recording_lfp, 500)
        ltoc = time.time()
        print('SpikeInterface lfp downsampling took {} seconds'.
              format(ltoc - ltic), flush=True)

        print('Writing LFP to disk.', flush=True)
        ltic = time.time()
        lfp_write_mda = se.MdaRecordingExtractor.write_recording
        lfp_write_mda(recording=recording_lfp,
                      save_path=op.join(clust_out_dir, 'lfp'))
        print('Finished writing LFP to disk.', flush=True)
        ltoc = time.time()
        print('SpikeInterface lfp writing to disk took {} seconds'.
              format(ltoc - ltic), flush=True)
        # c_o
        # os.system(f'mv clustering_output/lfp/raw.mda
        #  clustering_output/lfp/lfp_group{channel_group}.mda')
        ltic = time.time()
        print("lfp file ", op.join(clust_out_dir, 'lfp/raw.mda'))
        print("lfp file ", op.join(clust_out_dir,
                                   f'lfp/lfp_group{channel_group}.mda'))
        shutil.move(op.join(clust_out_dir, 'lfp/raw.mda'),
                    op.join(clust_out_dir,
                            f'lfp/lfp_group{channel_group}.mda'))
        ltoc = time.time()
        print('SpikeInterface lfp moving to output dir took {} seconds'.
              format(ltoc - ltic), flush=True)

        toc = time.time()
        print('SpikeInterface lfp bandpass filter took {} seconds'.
              format(toc - tic))

    # g_o
    # os.chdir(datdir)
    # SAHARA - can you plot this ONLY when it's group 0,
    #          but for the entire 64ch probe. better way:
    # if it doesn't exist, plot it, else move on.
    # # take a look at the probe geometry ------ not working at the moment
    try:
        wif, wax = plt.subplots(ncols=1, nrows=1, figsize=[10, 2])
        # def plot_electrode_geometry(recording, markersize=20,
        #                             marker='o', figure=None, ax=None):
        w_elec = sw.plot_electrode_geometry(recording_pp, markersize=15,
                                            ax=wax)
        plt.tight_layout()
        wif.suptitle('Probe geometry / recording site layout.')
        wif.savefig(op.join(clust_out_dir, bn + 'probe_geometry_vis.pdf'))
        plt.close(wif)
    except Exception as e:
        print("Error : ", e)
        print("Error creating probe_geometry_vis.pdf")

    # print some basic descriptives of the recording so that you can
    # make sure it's running and loading correctly
    print('\nNum. channels = {}'.format(len(recording_pp.get_channel_ids())))
    print('Channel ids:', recording_pp.get_channel_ids())
    print('Loaded properties',
          recording_pp.get_shared_channel_property_names())
    # print('Label of channel 0:',
    # recording_pp.get_channel_property(channel_id=0, property_name='label'))
    # 'group' and 'location' can be returned as lists:
    print('Recording channel groups ',
          recording_pp.get_channel_groups())
    print('Recording channel locations ',
          recording_pp.get_channel_locations())
    print('Sampling frequency = {} Hz'
          .format(recording_pp.get_sampling_frequency()))
    print('Num. timepoints = {}'
          .format(recording_pp.get_num_frames()), flush=True)
    # print('Location of third electrode = {}'
    # .format(recording_pp.get_channel_property(channel_id=2,
    #                                           property_name='location')))

    # make plotpairs
    plotpairs = {}
    if 'recording' in locals():
        plotpairs[1] = {'label': 'raw', 'rec': recording}
    else:
        pass
    if 'recording_f' in locals():
        plotpairs[2] = {'label': 'bandpassed', 'rec': recording_f}
    else:
        pass
    if 'recording_cmr' in locals():
        if rawdatfilt is not None:
            plotpairs[3] = {'label': 'common_corrected', 'rec': recording_cmr}
    else:
        pass
    if 'recording_w' in locals():
        plotpairs[4] = {'label': 'whitened', 'rec': recording_w}
    else:
        pass
    if 'recording_pp' in locals():
        plotpairs[5] = {'label': 'submitted_processing', 'rec': recording_pp}
    else:
        pass

    # check to see if you've already generated some traces files.
    # If so, get rid of them and start fresh.
    # c_o
    # tracecheck = glob.glob('clustering_output/traces*.pdf')
    # tracecheck = glob.glob(clust_out_dir + op.pathsep + 'traces*.pdf')
    # print("tracecheck ", tracecheck)
    # # ckbn todo :This can be removed as clustering_output is removed earlier
    # if tracecheck:
    #     for fn in tracecheck:
    #         print("Removing file ", fn)
    #         os.remove(fn)
    # else:
    #     pass

    for p in plotpairs:
        # c_o plotraw(**plotpairs[p], channel_group=channel_group)
        plotraw(plotpairs[p]['rec'],
                plotpairs[p]['label'],
                channel_group,
                clust_out_dir,
                bn=bn,
                nsec=3.0,
                saveflag=1)

    # Compute SNR
    rec_length = compute_SNR(recording, clust_out_dir,
                             channel_group,
                             bn=bn,
                             nsec=60)

    # #########################################################################
    # Now you are ready to spikesort using the :code:`sorters` module!
    # Let's first check which sorters are implemented and which are installed
    print('\nAvailable sorters', ss.available_sorters())
    print('Installed sorters', ss.installed_sorter_list, flush=True)
    # #########################################################################
    # The :code:`ss.installed_sorter_list` will list the sorters installed
    # in the machine. Each spike sorter is implemented as a class.
    # We can see we have Klusta and Mountainsort4 installed.
    # Spike sorters come with a set of parameters that users can change.
    # The available parameters are dictionaries and can be accessed
    # with e.g., ss.get_default_params('mountainsort4')
    # #########################################################################
    # Do the clustering and spike sorting!
    # First kill any prior jobs that left temporary folders.
    # ckbn todo :This can be moved to start of job all deletion
    # os.system('rm -rf tmp_*')

    # Load sorter_config file and adjust bandpass range
    try:
        d_sort_config = None
        with open(sorter_config, 'r') as f:
            d_sort_config = json.load(f)
    except Exception as e:
        print("Error : ", e)
        raise ValueError('Error please check data in file {}'
                         .format(sorter_config))

    try:
        if sortpick == 'm':
            try:
                # Get data
                dsc_sorter_name = str(d_sort_config['sorter_name'])
                dsc_adjacency_radius = int(d_sort_config['adjacency_radius'])
                dsc_curation = bool(d_sort_config['curation'])
                dsc_noise_overlap_threshold = \
                    float(d_sort_config['noise_overlap_threshold'])
                dsc_filter = bool(d_sort_config['filter'])
                dsc_freq_min = float(d_sort_config['freq_min'])
                dsc_freq_max = float(d_sort_config['freq_max'])
                dsc_detect_sign = int(d_sort_config['detect_sign'])
                dsc_whiten = bool(d_sort_config['whiten'])
                dsc_grouping_property = str(d_sort_config['grouping_property'])
                dsc_clip_size = int(d_sort_config['clip_size'])
                dsc_detect_interval = int(d_sort_config['detect_interval'])
                dsc_parallel = bool(d_sort_config['parallel'])
                dsc_verbose = int(d_sort_config['verbose'])
            except Exception as e:
                print("Error : ", e)
                raise ValueError('Error loading sorter_config file {}'
                                 .format(sorter_config))
            sorter_name = dsc_sorter_name
            print('mmmm, mountainsort. Nice choice.')
            sort_params = ss.get_default_params(sorter_name)
            sort_params['detect_threshold'] = thresh
            sort_params['curation'] = dsc_curation
            sort_params['num_workers'] = num_cpu
            sort_params['adjacency_radius'] = dsc_adjacency_radius
            sort_params['filter'] = dsc_filter
            sort_params['freq_min'] = dsc_freq_min
            sort_params['freq_max'] = dsc_freq_max
            sort_params['detect_sign'] = dsc_detect_sign
            sort_params['whiten'] = dsc_whiten
            sort_params['grouping_property'] = dsc_grouping_property
            sort_params['clip_size'] = dsc_clip_size
            sort_params['detect_interval'] = dsc_detect_interval
            sort_params['parallel'] = dsc_parallel
            sort_params['noise_overlap_threshold'] = \
                dsc_noise_overlap_threshold
            # sort_params['verbose'] = 'minimal'
            sort_params['verbose'] = dsc_verbose
            print("sort_params ", sort_params, flush=True)

            # look at github.com/
            # flatironinstitute/spikeforest/blob/master/spikeforest/
            # spikeforestsorters/mountainsort4/mountainsort4.py
            # for details on this algorithm and more that we can pass to it
            # sorter_name = 'mountainsort4'
            # print('mmmm, mountainsort. Nice choice.')
            # # Pass full dictionary containing the parameters:
            # sort_params = ss.get_default_params(sorter_name)
            # sort_params['detect_threshold'] = thresh
            # sort_params['curation'] = False
            # sort_params['num_workers'] = num_cpu
            # # adjacency_radius -1 then there is only one
            # # electrode neighborhood containing all the channels.
            # # adjacency_radius=0, then each channel is sorted independently.
            # sort_params['adjacency_radius'] = 2
            # sort_params['freq_min'] = 400
            # sort_params['freq_max'] = 7500
            # # -1 for negative, 1 for positive, 0 for both
            # sort_params['detect_sign'] = 0
            # sort_params['whiten'] = True
            # sort_params['grouping_property'] = 'group'
            # sort_params['parallel'] = False
            # sort_params['noise_overlap_threshold'] = 0.15
            # # sort_params['verbose'] = 'minimal'
            # sort_params['verbose'] = 1
            # print("sort_params ", sort_params, flush=True)

        elif sortpick == 'ks2':
            sorter_name = 'kilosort2'
            print('Sorter selected is Kilosort2')
            sort_params = ss.get_default_params(sorter_name)
            print("sort_params ", sort_params)
        elif sortpick == 'h':
            sorter_name = 'herdingspikes'
            print('Sorter selected is Herdingspikes')
            sort_params = ss.get_default_params(sorter_name)
            print("Currently not available")
            sys.exit()
        else:
            raise ValueError('Please check spk_sorter value')
    except Exception as e:
        print("Error : ", e)
        raise RuntimeError('Crashed at sorting params')

    # KIRAN - BIG ISSUE: when running parallel = True,
    # this will crash because it can't get through the function
    # "get_result_from_folder" in file "mountainsort4.py".
    # That function isn't even called when it's not parallel.
    # It isn't creating a file, 'samplerate.txt'.
    # But when I have a left over tmp folder, parallel will run successfully.
    # Thoughts?

    try:
        if lsorting:
            tic = time.time()
            print("\nStarted sorting")
            sorting_MS4 = ss.run_sorter(sorter_name_or_class=sorter_name,
                                        recording=recording_pp, **sort_params)
            print("sorting_MS4")
            print('Saving sorting_MS4')
            pickle_out = open(op.join(clust_out_dir,
                                      "spi_dict.pickle"), "wb")
            pickle.dump(sorting_MS4, pickle_out)
            pickle_out.close()
            print('Saved')
            print("Finished sorting")
    except Exception as e:
        print("Error : ", e)
        raise RuntimeError('Crashed at sorting')

    # lcompMS4KS2 = 0
    # if lcompMS4KS2:
    #     comp_KL_MS4 = sc.compare_two_sorters(sorting1=sorting_KL,
    #                                          sorting2=sorting_MS4)

    if not lsorting:
        try:
            sort_pickle_file = op.join(clust_out_dir,
                                       'spi_dict.pickle')
            print("picklefile_selected ", sort_pickle_file)
            pickle_in = open(sort_pickle_file, "rb")
            sorting_MS4 = pickle.load(pickle_in)
            pickle_in.close()
        except Exception as e:
            print("Error : ", e)
            raise FileNotFoundError('Error loading spi_dict.pickle')

    # Catch instances in which a group has no units.
    if len(sorting_MS4.get_unit_ids()) == 0:
        print('Error : Found no units')
        raise RuntimeError('Found no units, sorting_MS4.get_unit_ids()=0')

    if 'group' not in sorting_MS4.get_shared_unit_property_names():
        for unit in sorting_MS4.get_unit_ids():
            sorting_MS4.set_unit_property(unit, 'group', channel_group)

    # # Alternatively, pass the parameters as inputs:
    # sorting_MS4 = ss.run_sorter(sorter_name_or_class = sorter_name,
    # recording = recording_pp, verbose = 'minimal', detect_threshold = 5,
    # adjacency_radius = 3, noise_overlap_threshold = 0.15,
    # grouping_property = 'group', whiten = True, parallel = True,
    # curation = True)
    toc = time.time()
    print('SpikeInterface spikesorting took {} seconds'.
          format(toc - tic), flush=True)

    # Why is this NOT finding the parameters.json file???
    print('\nUnits:', sorting_MS4.get_unit_ids())
    print('Number of units:', len(sorting_MS4.get_unit_ids()))
    print('current properties are {} '
          .format(sorting_MS4.get_unit_property_names(
                  sorting_MS4.get_unit_ids()[0])))

    # with mpdf.PdfPages(f'clustering_output/
    # all_unit_raster_vis_group{channel_group}.pdf') as pdf:
    try:
        if (lmetrics >= 0):
            print('\nSpikeInterface creating raster plot')
            tic = time.time()

            with mpdf.PdfPages(op.join(clust_out_dir,
                               bn + 'all_unit_raster_vis_group{}.pdf'
                               .format(channel_group))) as pdf:
                rfig, rax = plt.subplots(nrows=1, ncols=1, figsize=[10, 10])
                w_rs = sw.plot_rasters(sorting_MS4, trange=[0, 5], ax=rax)
                rfig.suptitle('Raster plot of all units found by {}.'.
                              format(sorter_name))
                pdf.savefig()  # saves the current figure into a pdf page
                plt.close()

            toc = time.time()
            print('SpikeInterface creating raster plot took {} seconds'.
                  format(toc - tic), flush=True)
    except Exception as e:
        print("Error : ", e)
        print("Error creating all_unit_raster_vis_group{}.pdf"
              .format(channel_group))

    # #########################################################################
    # #########################################################################
    # ######################## Compute unit waveforms #########################

    # Compute unit waveforms:
    # wf = st.postprocessing.get_unit_waveforms(recording_pp, sorting_MS4,
    # ms_before=1, ms_after=2, max_spikes_per_unit=1500,
    # grouping_property='group', save_as_features=True, verbose=True)
    # def get_unit_waveforms(recording, sorting, unit_ids=None,
    #                        grouping_property=None, channel_ids=None,
    #                        ms_before=3., ms_after=3., dtype=None,
    #                        max_spikes_per_unit=np.inf, save_as_features=True,
    #                        compute_property_from_recording=False,
    #                        verbose=False, seed=0, return_idxs=False)
    print('\nSpikeInterface extracting wf')
    tic = time.time()
    get_wf = st.postprocessing.get_unit_waveforms
    wf = get_wf(recording_pp, sorting_MS4,
                unit_ids=None,
                grouping_property='group',
                channel_ids=None,
                ms_before=1.0, ms_after=2.0,
                dtype=None,
                max_spikes_per_unit=np.int(2500),
                save_as_features=True,
                compute_property_from_recording=True,
                verbose=False, seed=0, return_idxs=False)
    toc = time.time()
    print('SpikeInterface wf extraction took {} seconds'.
          format(toc - tic), flush=True)
    # np.save(f"clustering_output/waveforms_group{channel_group}.npy", wf)
    np.save(op.join(clust_out_dir, bn + "waveforms_group{}.npy"
                    .format(channel_group)), wf)

    # compute_property_from_recording=True??? try this

    # #########################################################################
    # Compute PCA scores by concatenating the channels across a group
    # for each spike
    # pca_scores = compute_pca_scores(recording_pp, sorting_MS4,
    # n_comp = 3, plot3 = False)
    # #########################################################################
    #  PCA scores can be also computed electrode-wise. In the previous example,
    #  PCA was applied to the concatenation of the waveforms over channels.
    # pca_scores_by_electrode = \
    # st.postprocessing.compute_unit_pca_scores(recording_f,
    # sorting_MS4, n_comp=3, by_electrode=True, verbose=True)
    # def compute_unit_pca_scores(recording, sorting, unit_ids=None, n_comp=3,
    #                             by_electrode=False,
    #                             grouping_property=None,
    #                             ms_before=3., ms_after=3., dtype=None,
    #                             max_spikes_per_unit=np.inf,
    #                             max_spikes_for_pca=np.inf,
    #                             save_as_features=False,
    #                             save_waveforms_as_features=False,
    #                             compute_property_from_recording=False,
    #                             whiten=False,
    #                             verbose=False, seed=0, return_idxs=False):
    # pc_scores, pca_idxs = \
    #     compute_unit_pca_scores(recording, sorting, n_comp=n_comp,
    #                             by_electrode=True,
    #                             max_spikes_per_unit=max_spikes_per_unit,
    #                             ms_before=ms_before,
    #                             ms_after=ms_after, dtype=dtype,
    #                             save_as_features=save_features_props,
    #                             max_spikes_for_pca=max_spikes_for_pca,
    #                             verbose=verbose, seed=seed,
    #                             return_idxs=True)
    tic = time.time()
    print('\nSpikeInterface extracting pca')
    get_pca = st.postprocessing.compute_unit_pca_scores
    pca_scores_by_electrode = get_pca(recording_pp, sorting_MS4,
                                      unit_ids=None,
                                      n_comp=3,
                                      by_electrode=True,
                                      grouping_property=None,
                                      ms_before=1.0, ms_after=2.0,
                                      dtype=None,
                                      max_spikes_per_unit=np.int(1500),
                                      max_spikes_for_pca=np.int(10000),
                                      save_waveforms_as_features=False,
                                      compute_property_from_recording=True,
                                      whiten=False,
                                      verbose=False, seed=0, return_idxs=False)
    np.save(op.join(clust_out_dir,
            bn + "pca_scores_by_electrode{}.npy".format(channel_group)),
            pca_scores_by_electrode)
    # pca_scores_by_group = get_pca(recording_pp, sorting_MS4,
    #                                   unit_ids=None,
    #                                   n_comp=3,
    #                                   by_electrode=False,
    #                                   grouping_property='group',
    #                                   ms_before=1.0, ms_after=2.0,
    #                                   dtype=None,
    #                                   max_spikes_per_unit=np.int(1500),
    #                                   max_spikes_for_pca=np.int(10000),
    #                                   save_waveforms_as_features=False,
    #                                   compute_property_from_recording=True,
    #                                   whiten=False,
    #                                   verbose=False, seed=0,
    #                                   return_idxs=False)
    # np.save(op.join(clust_out_dir,
    #                 f"pca_scores_by_group{channel_group}.npy"),
    #                 pca_scores_by_group)

    # for pc in pca_scores_by_electrode:
    #     print(pc.shape)
    toc = time.time()
    print('SpikeInterface pca extraction took {} seconds'.
          format(toc - tic), flush=True)

    # #########################################################################

    # # Get unit waveforms (500 each) with LOCAL function:
    # wfs = getwfs(recording_pp, sorting_MS4, num_spikes = 500, saveflag = 1)

    # now run get unit templates (this should be faster?):
    # idea is that this will be necessary for max chan etc...
    # try adding get WFs etc
    # #########################################################################
    # Compute unit templates
    # --------------------------

    #  Similarly to waveforms, templates - average waveforms - can be easily
    #  extracted using the :code:`get_unit_templates`. When spike trains have
    #  numerous spikes, you can set the :code:`max_spikes_per_unit`
    #  to be extracted.
    #  If waveforms have already been computed and stored as :code:`features`,
    #  those will be used. Templates can be saved as unit properties.
    tic = time.time()
    print('\nSpikeInterface extracting templates')
    # templates = st.postprocessing.get_unit_templates(recording_pp,
    # sorting_MS4, max_spikes_per_unit=1500, save_as_property=True,
    # save_wf_as_features=True, verbose=True)
    # def get_unit_templates(recording, sorting, unit_ids=None, mode='median',
    #                        grouping_property=None, save_as_property=True,
    #                        ms_before=3., ms_after=3., dtype=None,
    #                        max_spikes_per_unit=np.inf,
    #                        save_wf_as_features=True,
    #                        compute_property_from_recording=False,
    #                        verbose=False, recompute_waveforms=False, seed=0):
    get_templates = st.postprocessing.get_unit_templates
    get_templates(recording_pp, sorting_MS4,
                  unit_ids=None, mode='median',
                  grouping_property='group',
                  save_as_property=True,
                  ms_before=1., ms_after=3.,
                  dtype=None,
                  max_spikes_per_unit=np.int(1500),
                  save_wf_as_features=True,
                  compute_property_from_recording=True,
                  verbose=False, recompute_waveforms=False, seed=0)

    toc = time.time()
    print('SpikeInterface template extraction took {} seconds'.
          format(toc - tic), flush=True)

    ###########################################################################
    # Get cluster metrics:

    if (lmetrics > 0):
        tic = time.time()
        print('\nSpikeInterface extracting compute metrics')
        mc, isi_list = compute_metrics(sorting_MS4, recording_pp,
                                       channel_group,
                                       clust_out_dir,
                                       bn=bn)
        toc = time.time()
        print('SpikeInterface compute metrics extraction took {} seconds'.
              format(toc - tic), flush=True)
    else:
        mc = None
    # KIRAN = this is insane if you don't cache the data above...
    # mc is a MetricCalculator object, return with all metrics computed.
    # Type: print(list(mc.get_metrics_dict().keys())) to
    # return a set of metrics by name.

    # The :code:`get_metrics_dict` and :code:`get_metrics_df` return all
    # metrics as a dictionary or a pandas dataframe:

    # print(mc.get_metrics_dict())
    # print(mc.get_metrics_df())

    # See more notes in the function def.

    ###########################################################################
    #  Compute unit maximum channel:
    #  -----------------------------

    tic = time.time()
    print('\nSpikeInterface extracting max channel')
    # st.postprocessing.get_unit_max_channels(recording_pp, sorting_MS4,
    # max_spikes_per_unit=1500, grouping_property='group',
    # save_as_property=True, verbose=True)
    # def get_unit_max_channels(recording, sorting, unit_ids=None,
    #                           max_channels=1, peak='both', mode='median',
    #                           grouping_property=None,
    #                           save_as_property=True,
    #                           ms_before=3., ms_after=3.,
    #                           dtype=None,
    #                           max_spikes_per_unit=np.inf,
    #                           compute_property_from_recording=False,
    #                           verbose=False,
    #                           recompute_templates=False, seed=0):
    get_maxch = st.postprocessing.get_unit_max_channels
    try:
        get_maxch(recording_pp, sorting_MS4,
                  unit_ids=None, max_channels=1,
                  peak='both', mode='median',
                  grouping_property='group',
                  save_as_property=True,
                  ms_before=1., ms_after=3.,
                  dtype=None,
                  max_spikes_per_unit=np.int(1500),
                  compute_property_from_recording=True,
                  verbose=False, recompute_templates=False, seed=0)
    except Exception as e:
        print(e)
        # def get_unit_max_channels(recording, sorting, unit_ids=None,
        #                           peak='both', mode='median',
        #                           grouping_property=None,
        #                           save_as_property=True,
        #                           ms_before=3., ms_after=3.,
        #                           dtype=None, max_spikes_per_unit=np.inf,
        #                           compute_property_from_recording=False,
        #                           verbose=False, recompute_templates=False,
        #                           seed=0):
        get_maxch(recording_pp, sorting_MS4,
                  unit_ids=None,
                  peak='both', mode='median',
                  grouping_property='group',
                  save_as_property=True,
                  ms_before=1., ms_after=3.,
                  dtype=None,
                  max_spikes_per_unit=np.int(1500),
                  compute_property_from_recording=True,
                  verbose=False, recompute_templates=False, seed=0)

    toc = time.time()
    print('SpikeInterface max channel extraction took {} seconds'.
          format(toc - tic), flush=True)

    # First and last waveforms
    try:
        print('\n SpikeInterface extracting b/e wf')
        tic = time.time()
        n_pad = [int(1.0 * sampling_frequency / 1000),
                 int(2.0 * sampling_frequency / 1000)]
        # print("n_pad ", n_pad)
        unique_clusters = sorting_MS4.get_unit_ids()
        print("unique_clusters  ", unique_clusters)
        b_wf = []
        e_wf = []
        for unit_c in unique_clusters:
            # print("unit_c ", unit_c)
            unit_st_c = sorting_MS4.get_unit_spike_train(unit_id=unit_c)

            # unit_ch_c = recording_pp.get_channel_ids()
            # print("unit_ch_c ", unit_ch_c)

            ch_group = sorting_MS4.get_unit_property(unit_c, "group")
            # print("ch_group ", ch_group)
            spikes_max_ch = \
                [sorting_MS4.get_unit_property(unit_c, 'max_channel') +
                 (4 * ch_group)]
            # print("spikes_max_ch ", spikes_max_ch)
            spikes_bwf = \
                recording_pp.get_snippets(
                    reference_frames=unit_st_c[0:min(1000,
                                               len(unit_st_c))]
                    .astype('int64'),
                    snippet_len=n_pad, channel_ids=spikes_max_ch)
            # print("len spikes_bwf ", len(spikes_bwf))
            # print("len spikes_bwf[0] ", len(spikes_bwf[0]))
            # print("spikes_bwf[0] ", spikes_bwf[0])
            spikes_bwf = np.squeeze(spikes_bwf)
            b_wf.append(spikes_bwf)
            spikes_ewf = \
                recording_pp.get_snippets(
                    reference_frames=unit_st_c[-min(1000,
                                               len(unit_st_c)):]
                    .astype('int64'),
                    snippet_len=n_pad, channel_ids=spikes_max_ch)
            spikes_ewf = np.squeeze(spikes_ewf)
            e_wf.append(spikes_ewf)
        np.save(op.join(clust_out_dir, bn + "b_waveforms_group{}.npy"
                        .format(channel_group)), b_wf)
        np.save(op.join(clust_out_dir, bn + "e_waveforms_group{}.npy"
                        .format(channel_group)), e_wf)
        toc = time.time()
        print('SpikeInterface b/e wf extraction took {} seconds'.
              format(toc - tic), flush=True)
    except Exception as e:
        print("Error : ", e)
        print("Error saving b_waveforms_group{}.npy/e_waveforms_group{}.npy"
              .format(channel_group, channel_group))

    # Kiran... why isn't this working?
    tic = time.time()
    print('\nSpikeInterface extraction amplitude')
    #  (and in the same way, we can get the recording channel with the maximum
    #  amplitude and save it as a property.)
    # amps = st.postprocessing.get_unit_amplitudes(recording_pp,
    # sorting_MS4, max_spikes_per_unit = 3000)
    # def get_unit_amplitudes(recording, sorting,
    #                         unit_ids=None, method='absolute',
    #                         save_as_features=True, peak='both',
    #                         frames_before=3, frames_after=3,
    #                         max_spikes_per_unit=np.inf, seed=0,
    #                         return_idxs=False):
    # amplitudes_list, amp_idxs = \
    #     get_unit_amplitudes(recording, sorting, method=amp_method,
    #                         save_as_features=save_features_props,
    #                         peak=amp_peak,
    #                         max_spikes_per_unit=max_spikes_per_unit,
    #                         frames_before=amp_frames_before,
    #                         frames_after=amp_frames_after,
    #                         seed=seed, return_idxs=True)
    # ckbn todo get amplitudes_list, amp_idxs and remove spikes in clusters
    # beyond some criteria, clean up in mbt
    get_amps = st.postprocessing.get_unit_amplitudes
    #               max_spikes_per_unit=np.int(3000), seed=0,
    amps, amp_idxs = get_amps(recording_pp, sorting_MS4,
                              unit_ids=None, method='absolute',
                              save_as_features=True, peak='both',
                              frames_before=np.int(1), frames_after=np.int(3),
                              return_idxs=True)
    # print("amp type ", type(amps))
    # print("len amps ", len(amps))
    # for amps_tmp in amps:
    #     print('Amplitude ', amps_tmp)
    np.save(op.join(clust_out_dir,
            bn + "amplitudes{}.npy".format(channel_group)),
            amps)
    np.save(op.join(clust_out_dir,
            bn + "amplitudes_idxs{}.npy".format(channel_group)),
            amp_idxs)
    toc = time.time()
    print('SpikeInterface amplitude extraction took {} seconds\n'.
          format(toc - tic), flush=True)
    print("sorting_MS4.get_shared_unit_spike_feature_names() ",
          sorting_MS4.get_shared_unit_spike_feature_names())
    print("sorting_MS4.get_shared_unit_property_names() ",
          sorting_MS4.get_shared_unit_property_names())

    # Save sorting_MS4 and recording_pp
    print('\nSaving sorting_MS4')
    pickle_out = open(op.join(clust_out_dir,
                              "spi_dict_final.pickle"), "wb")
    pickle.dump(sorting_MS4, pickle_out)
    pickle_out.close()
    print('Saved')
    lrec_pickle = 0
    if lrec_pickle:
        print('Saving recording_pp')
        pickle_out = open(op.join(clust_out_dir,
                                  "rec_dict_final.pickle"), "wb")
        pickle.dump(recording_pp, pickle_out)
        pickle_out.close()
        print('Saved')

    # Filter out crummy units. Add in XGA Boost to score unit quality.
    if (lmetrics > 0):
        tic = time.time()
        print('\nSpikeInterface calculating noflylist')
        noflylist = score.splishsplashiwastakinabath(sorting_MS4, isi_list,
                                                     amp_min=20, isi_max=0.5)
        toc = time.time()
        print('SpikeInterface calculating noflylist took {} seconds'.
              format(toc - tic), flush=True)
    else:
        noflylist = []

    # Produce unit WF output documents:
    if (lmetrics >= 0):
        tic = time.time()
        print('\nSpikeInterface plotting wfs')
        plotwfs(wf, recording_pp, sorting_MS4, mc, channel_group, noflylist,
                clust_out_dir, lmetrics, bn=bn)
        toc = time.time()
        print('SpikeInterface plotting wfs took {} seconds'.
              format(toc - tic), flush=True)

    # save figures from PCA:
    if (lmetrics > 0):
        tic = time.time()
        plot_pca(recording_pp, sorting_MS4, pca_scores_by_electrode,
                 channel_group, noflylist, clust_out_dir, bn=bn, nplots=6)
        toc = time.time()
        print('SpikeInterface plotting pca took {} seconds'.
              format(toc - tic), flush=True)

    # Plot trace
    try:
        if (lmetrics >= 0):
            tic = time.time()
            print('\nSpikeInterface plotting trace')
            plot_trace_clust(recording_pp, sorting_MS4, noflylist,
                             clust_out_dir, bn=bn)
            toc = time.time()
            print('\nSpikeInterface plotting trace took {} seconds'.
                  format(toc - tic), flush=True)
    except Exception as e:
        print("Error ", e)
        print("Error: plot_trace_clust crashed")

    # plot widgets
    try:
        if (lmetrics > 0):
            tic = time.time()
            print('\nSpikeInterface plotting widgets')
            widget_plots(recording_pp, sorting_MS4, noflylist,
                         clust_out_dir, lmetrics, bn=bn)
            toc = time.time()
            print('\nSpikeInterface plotting widgets took {} seconds'.
                  format(toc - tic), flush=True)
    except Exception as e:
        print("Error ", e)
        print("Error: widget_plots crashed")

    # KBH - start here. add the cluster colored raw data plotting.

    # Save phy out
    lphy = 0
    if lphy == 1:
        tic = time.time()
        print('\nSpikeInterface saving output for phy')
        print("Saving phy output")
        st.postprocessing.export_to_phy(recording_pp,
                                        sorting_MS4,
                                        output_folder='phy',
                                        verbose=True)
        toc = time.time()
        print('\nSpikeInterface saving output for phy took {} seconds'.
              format(toc - tic), flush=True)

    # time
    # rec_time = recording.get_num_frames()

    # KIRAN AND KEITH - add a column to the csv file with the
    # isi contamination for each unit...
    del recording
    del recording_f
    del recording_pp
    return (sorting_MS4, channel_group, noflylist, rec_length,
            amps)


if __name__ == '__main__':
    # Get json file name
    # parser = ArgumentParser(fromfile_prefix_chars='@')
    parser = ArgumentParser()
    parser.add_argument("--file", "-f", type=str, required=True,
                        help="/home/kbn/spkint_wrapper_input.json")
    parser.add_argument('--experiment-path', type=str, help='path where to look for clustering_output')
    parser.add_argument('--ndi-hengen-path', type=str, help='path where default settings for hengen app are located in ndi')
    parser.add_argument('--ndi-input', action='store_true', help='boolean to flag if ndi is passing in data')
    args = parser.parse_args()

    # Check json file and load data
    if not (os.path.exists(args.file) and os.path.isfile(args.file)):
        raise FileNotFoundError("Input json file {} does not exists".
                                format(args.file))

    try:
        with open(args.file, 'r') as f:
            d = json.load(f)

        # Get data
        thresh = int(d['thresh'])
        num_channels = int(d['num_channels'])
        nprobes = int(d['nprobes'])
        hstype = None
        # hstype = []
        hstype = d['hstype']
        # if (nprobes == 1):
        # else:
        #     tmp_hs_t = d['hstype']
        #     print("tmp_hs_t ", tmp_hs_t)
        #     print("type tmp_hs_t ", type(tmp_hs_t))
        #     tmp_hs_t = tmp_hs_t.split(",")
        #     print("tmp_hs_t ", tmp_hs_t)
        #     for tmp_hs_t_i in tmp_hs_t:
        #         hstype.append(tmp_hs_t_i)
        probetosort = int(d['probetosort'])
        probe_channels = int(d['probe_channels'])
        fs = float(d['fs'])
        bad_chans = int(d['bad_chans'])
        if bad_chans < 0:
            bad_chans = None
        rawdatfilt = str(d['rawdatfilt'])
        lnosplit = bool(d['lnosplit'])
        lsorting = bool(d['lsorting'])
        lmetrics = int(d['lmetrics'])
        spk_sorter = str(d['spk_sorter'])
        lfp = int(d['lfp'])
        ncpus = int(d['ncpus'])
        sorter_config = str(d['sorter_config'])
        sorter_config = os.path.join(args.ndi_hengen_path, sorter_config)
        ltk = bool(d['ltk'])
        TMPDIR_LOC = str(d['TMPDIR_LOC'])
        TMPDIR_LOC = os.path.join(args.experiment_path, TMPDIR_LOC)
        probefile = str(d['probefile'])
        probefile = os.path.join(args.ndi_hengen_path, probefile)

        if args.ndi_input:
            ndi_input = scipy.io.loadmat(os.path.join(args.ndi_hengen_path, 'ndiouttmp.mat'))
            print('extraction_p: \n', ndi_input['extraction_p'])
            print('sorting_p: \n', ndi_input['sorting_p'])
            file_path = os.path.join(args.ndi_hengen_path, 'ndiouttmp.mat')
            extraction_p = ndi_input['extraction_p']
            thresh = int(extraction_p['thresh'])
            num_channels = int(extraction_p['num_channels'])
            nprobes = int(extraction_p['nprobes'])
            hstype = extraction_p['hstype'][0][0][0]
            probetosort = int(extraction_p['probetosort'])
            probe_channels = int(extraction_p['probe_channels'])
            fs = float(ndi_input['sr'])
            bad_chans = int(extraction_p['bad_chans'])
            rawdatfilt = str(extraction_p['rawdatfilt'][0][0][0])
            lnosplit = bool(extraction_p['lnosplit'])
            lsorting = bool(extraction_p['lsorting'])
            lmetrics = int(extraction_p['lmetrics'])
            spk_sorter = str(extraction_p['spk_sorter'][0][0][0]) # hardcoded index arrays as of weird translation to .mat
            lfp = int(extraction_p['lfp'])
            ncpus = int(extraction_p['ncpus'])
            ltk = bool(extraction_p['ltk'])
        else:
            file_path = str(d['file_path'])
            file_path = os.path.join(args.experiment_path, file_path)
        clustering_output = str(d['clustering_output'])
        clustering_output = os.path.join(args.experiment_path, clustering_output)


    except Exception as e:
        print("Error : ", e)
        raise ValueError('Error please check data in file {}'
                         .format(args.file))

    # # Change these variables before running jobs
    # # Sorting Threshold (many sorters allow user input for SD thresholding
    # # during spike detection)
    # thresh = 4
    # # num_channels, hstype, nprobes
    # # num_channels = 20     # Total number of channels
    # num_channels = 64       # Total number of channels
    # # num_channels = 512    # Total number of channels
    # # num_channels = 192    # Total number of channels
    # # num_channels = 512      # Total number of channels
    # # num_channels = 32     # Total number of channels
    # # Channel map necessary if converting from binary to .mda
    # #   'hs64' 'eibless-hs64_port32''eibless-hs64_port64' 'intan32'
    # #   'Si_64_KS_chmap' 'Si_64_KT_T1_K2_chmap' 'PCB_tetrode'
    # #   'EAB50chmap_00' 'linear'
    # # For multiprobe : hstype = ['PCB_tetrode', 'PCB_tetrode', 'PCB_tetrode']
    # # hstype = ['eibless-hs64_port32']  # Channel map
    # hstype = ['hs64']   # Channel map
    # # hstype = ['EAB50chmap_00', 'EAB50chmap_00', 'EAB50chmap_00']
    # # hstype = ['EAB50chmap_00', 'EAB50chmap_00', 'EAB50chmap_00',
    # #           'EAB50chmap_00', 'EAB50chmap_00', 'EAB50chmap_00',
    # #           'EAB50chmap_00', 'EAB50chmap_00']   # Channel map
    # # hstype = ['intan32']
    # nprobes = 1           # Number of probes
    # # nprobes = 8           # Number of probes
    # probetosort = 1      # Which probe to sort
    # # probe_channels = 20   # Number of channels in a probe
    # probe_channels = 64   # Number of channels in a probe
    # # probe_channels = 32   # Number of channels in a probe
    # bad_chans = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    #              17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,
    #              32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46,
    #              47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61,
    #              62, 63]
    # fs = 25000            # 25000 Sampling frequency
    # bad_chans = None
    # # rawdatfilt can be None, 'median', or 'average'.
    # # Common referencing options.
    # # These are useful cases of cross channel noise contamination
    # # events like the pulse sync.
    # rawdatfilt = None
    # lnosplit = 1       # Do not split files by tetrodes (by channel group)
    # lsorting = 1       # Restart from sorted data spi_dict.pickle (0) else 1
    # lmetrics = 0       # whether to compute metrics 1 else 0
    # # "m" mountainsort, "ks2" Kilosort2, 'h' 'herdingspikes'
    # spk_sorter = "m"      # "m" , "ks2" and "h"
    # lfp = 0               # Do lfp or not
    # ncpus = 4             # number of cpu's to use
    # if spk_sorter == "ks2":
    #     KSPATH = '/hlabhome/hlabhome/opt/Kilosort2/'  # KS2 path
    #     if os.path.isdir(KSPATH):
    #         ss.Kilosort2Sorter.set_kilosort2_path(KSPATH)
    #     else:
    #         raise ValueError('Please check KSPATH')
    # ltk = 0               # No tkinter, keep 0 else 1

    # Start
    setic = time.time()
    print("\n \t\tStarting")
    print("\tTotal number of channels is {}".
          format(num_channels))
    print("\tNumber of probes is {}".
          format(nprobes))
    print("\tProbes to sort is {}".
          format(probetosort))
    print("\tNumber of channels in each probe is {}".
          format(probe_channels))
    print("\tSampling rate is {}".
          format(fs))

    print("\tthresh ", thresh)
    print("\thstype ", hstype)
    print("\tbad_chans ", bad_chans)
    print("\trawdatfilt ", rawdatfilt)
    try:
        if rawdatfilt.startswith('blank_saturation'):
            bs_threshold = float(rawdatfilt.split('_')[-1])
    except Exception as e:
        print('Error : ', e)
        raise ValueError('rawdatfilt blank_saturation_*, {}'
                         .format(rawdatfilt))
    print("\tlnosplit ", lnosplit)
    print("\tlsorting ", lsorting)
    print("\tlmetrics ", lmetrics)
    print("\tspk_sorter ", spk_sorter)
    print("\tlfp ", lfp)
    print("\tncpus ", ncpus)
    print("\tsorter_config ", sorter_config)
    print("\tltk ", ltk)
    print("\tTMPDIR_LOC ", TMPDIR_LOC)
    print("\tprobefile ", probefile)
    print("\tfile_path ", file_path)
    print("\tclustering_output ", clustering_output)
    print("\tInput json file ", args.file)

    # Basic checks
    # check nprobes vs hstype
    if len(hstype) != nprobes:
        raise ValueError('Please check length of hstype same as nprobes')
    if nprobes*probe_channels != num_channels:
        raise ValueError('Please check nprobes*probe_channels = num_channels:')
    if spk_sorter not in ["m", "ks2", "h"]:
        raise ValueError('Please check spk_sorter, unknown sorter')
    if probetosort > nprobes:
        raise ValueError('Please check probetosort > nprobes:')

    # Get all directories and files to run
    print("\n")
    if ltk:
        # if tkinter, i.e. run a GUI for file selection
        root = tk.Tk()
        root.withdraw()
    # else:
    #     # if no tkinter, i.e. ltk is 0. Paste file path into the code.
    #     # base_path = '/hlabhome/kiranbn/git/spk_intf_test5/'
    #     # base_path = '/hlabhome/kiranbn/git/spk_intf_test5/binfolder/ch64/'
    #     # TMPDIR_LOC = op.join(base_path, 'tmp')
    #     # TMPDIR_LOC = '/media/bs001r/ckbn/tmp/'
    #     TMPDIR_LOC = '/media/bs001s/ckbn/spkint_test/demo_tmp/'
    #     # TMPDIR_LOC = '/media/bs001s/ckbn/spkint_test/tmp/'
    #     probefile = '/home/kiranbn/probe_files/4by4tetrodes.prb'
    #     # file_path = (base_path+'/binfolder/ch64/', )
    #     # file_path = ('/media/bs001r/ckbn/spikeint_test/', )
    #     # file_path = '/media/bs001r/ckbn/spikeint_test/'
    #     file_path = '/media/bs001s/ckbn/spkint_test/raw/'
    #     # file_path = '/media/bs001s/ckbn/spkint_test/file_path_name.txt'
    #     # file_path = '/media/bs005s/vkd/spikeinterface/EAB50_T2_7-8_7-10/'
    #     # file_path = '/media/bs001s/ckbn/spkint_test/mdafile/raw.mda'
    #     # file_path = '/media/bs001s/ckbn/spkint_test/raw192/'
    #     # file_path = '/media/bs001s/ckbn/spkint_test/raw512/'
    #     # file_path = '/media/bs001s/vkd/SPKINTtest/block3_12hours/'
    #     # file_path = '/media/bs005s/vkd/spikeinterface/EAB50_T2_7-8_7-10/'
    #     # c_o
    #     # clustering_output = base_path + '/test_co/clustering_output/'
    #     # clustering_output = base_path + '/test_co/1/'
    #     # clustering_output = '/media/bs001r/ckbn/c_out/'
    #     clustering_output = '/media/bs001s/ckbn/spkint_test/demo_c_o/'
    #     # clustering_output = '/media/bs001s/ckbn/spkint_test/c_o/'

    # Initialize basename
    bn = ""

    # check sorter_config
    # check sorter_config exist
    if os.path.exists(sorter_config) and os.path.isfile(sorter_config):
        print("sorter_config ", sorter_config)
    else:
        raise FileNotFoundError("sorter_config file {} does not exists".
                                format(sorter_config))

    # check sorter_config can be loaded
    # crash here than crash at sorting step
    try:
        d_sort_config = None
        with open(sorter_config, 'r') as f:
            d_sort_config = json.load(f)
    except Exception as e:
        print("Error : ", e)
        raise ValueError('Error please check data in file {}'
                         .format(sorter_config))
    if spk_sorter == 'm':
        try:
            if ndi_input:
                sorting_p = ndi_input['sorting_p']
                # Get data
                dsc_sorter_name = str(sorting_p['sorter_name'])
                print("dsc_sorter_name ", dsc_sorter_name)

                dsc_adjacency_radius = int(sorting_p['adjacency_radius'])
                dsc_curation = bool(sorting_p['curation'])
                print("dsc_curation ", dsc_curation, flush=True)
                dsc_noise_overlap_threshold = \
                    float(sorting_p['noise_overlap_threshold'])
                dsc_chunk_size = int(sorting_p['chunk_size'])
                dsc_filter = bool(sorting_p['filter'])
                dsc_freq_min = float(sorting_p['freq_min'])
                dsc_freq_max = float(sorting_p['freq_max'])
                dsc_detect_sign = int(sorting_p['detect_sign'])
                dsc_whiten = bool(sorting_p['whiten'])
                dsc_grouping_property = str(sorting_p['grouping_property'])
                dsc_clip_size = int(sorting_p['clip_size'])
                dsc_detect_interval = int(sorting_p['detect_interval'])
                dsc_parallel = bool(sorting_p['parallel'])
                dsc_verbose = int(sorting_p['verbose'])
            else:
                # Get data
                dsc_sorter_name = str(d_sort_config['sorter_name'])
                print("dsc_sorter_name ", dsc_sorter_name)

                dsc_adjacency_radius = int(d_sort_config['adjacency_radius'])
                dsc_curation = bool(d_sort_config['curation'])
                print("dsc_curation ", dsc_curation, flush=True)
                dsc_noise_overlap_threshold = \
                    float(d_sort_config['noise_overlap_threshold'])
                dsc_chunk_size = int(d_sort_config['chunk_size'])
                dsc_filter = bool(d_sort_config['filter'])
                dsc_freq_min = float(d_sort_config['freq_min'])
                dsc_freq_max = float(d_sort_config['freq_max'])
                dsc_detect_sign = int(d_sort_config['detect_sign'])
                dsc_whiten = bool(d_sort_config['whiten'])
                dsc_grouping_property = str(d_sort_config['grouping_property'])
                dsc_clip_size = int(d_sort_config['clip_size'])
                dsc_detect_interval = int(d_sort_config['detect_interval'])
                dsc_parallel = bool(d_sort_config['parallel'])
                dsc_verbose = int(d_sort_config['verbose'])
        except Exception as e:
            print("Error : ", e)
            raise ValueError('Error loading sorter_config file {}'
                             .format(sorter_config))

    # clustering_output
    # c_o
    if ltk:
        print("\n\nSelect clustering_output folder\n\n")
        clustering_output = \
            filedialog.askdirectory(title="Select clustering_output folder")
    # filedialog.askdirectory(initialdir="",
    # title="Select clustering_output folder")
    # Check clustering_output directory exists and is empty
    # Best ideas is to crash here than overwritting some data
    # which took hours to sort
    if os.path.exists(clustering_output) and os.path.isdir(clustering_output):
        if lsorting:
            if os.listdir(clustering_output):
                raise \
                    FileExistsError("Directory {} not empty, select another.".
                                    format(clustering_output))
            else:
                print("Directory {} is empty.".format(clustering_output))
    else:
        raise NotADirectoryError("Directory {} does not exists".
                                 format(clustering_output))

    # set scratch directory
    # TMPDIR_LOC='/hlabhome/kiranbn/git/spk_intf_test2/tmp/'
    if ltk:
        print("\n\nSelect tmp folder\n\n")
        TMPDIR_LOC = filedialog.askdirectory(title="Select tmp directory")
    if os.path.exists(TMPDIR_LOC) and os.path.isdir(TMPDIR_LOC):
        print('TMPDIR_LOC ', TMPDIR_LOC)
        if lsorting:
            if os.listdir(TMPDIR_LOC):
                raise \
                    FileExistsError("Directory {} not empty, select another.".
                                    format(TMPDIR_LOC))
    else:
        raise NotADirectoryError("Directory {} does not exists".
                                 format(TMPDIR_LOC))

    # add path sep
    clustering_output = op.join(clustering_output, '', '')
    TMPDIR_LOC = op.join(TMPDIR_LOC, '', '')

    try:
        path_tmpdir_loc = tempfile.mkdtemp(dir=TMPDIR_LOC)
    except Exception as e:
        print("Error : ", e)
        raise NotADirectoryError("Temporary directory not created")

    print('path_tmpdir_loc ', path_tmpdir_loc)
    os.environ['TMP'] = path_tmpdir_loc
    os.environ['TEMP'] = path_tmpdir_loc
    os.environ['ML_TEMPORARY_DIRECTORY'] = path_tmpdir_loc
    os.environ['TEMPDIR'] = path_tmpdir_loc

    print('TMP ', os.environ.get('TMP', '/tmp'))
    print('TEMP ', os.environ.get('TEMP', '/tmp'))
    print('ML_TEMPORARY_DIRECTORY ',
          os.environ.get('ML_TEMPORARY_DIRECTORY', '/tmp'))
    print('TEMPDIR ', os.environ.get('TEMPDIR', '/tmp'))

    # Select probefile
    if ltk:
        print("\n\nSelect probe file\n\n")
        probefile = filedialog.askopenfilenames(title="Select probe file")[0]
    if os.path.exists(probefile) and os.path.isfile(probefile):
        print("Probefile ", probefile)
    else:
        raise FileNotFoundError("Probe file {} does not exists".
                                format(probefile))
    # Select pickle file
    if not lsorting:
        # Check for spi_dict
        sort_pickle = op.join(clustering_output,
                              'spi_dict.pickle')
        if os.path.exists(sort_pickle) and os.path.isfile(sort_pickle):
            print("sort_pickle ", sort_pickle)
        else:
            raise FileNotFoundError("Sort pickle file {} does not exists".
                                    format(sort_pickle))

        # load ecube_time_list and file_datetime_list

        try:
            # ecube_time_list = np.load(op.join(clustering_output,
            #                           'ecube_time_list.npy'),
            #                           allow_pickle=True)
            ecube_time_list_file = \
                glob.glob(clustering_output +
                          '*ecube_time_list.npy')
            print("ecube_time_list_file ", ecube_time_list_file, flush=True)
            ecube_time_list = np.int64(np.load(ecube_time_list_file[0],
                                               allow_pickle=True))
            print("ecube_time_list ", ecube_time_list, flush=True)
        except Exception as e:
            print("Error : ", e)
            raise ValueError('Error opening file {}'
                             .format(ecube_time_list_file))
        try:
            # file_datetime_list = np.load(op.join(clustering_output,
            #                              'file_datetime_list.npy'),
            #                              allow_pickle=True)
            file_datetime_list_file = \
                glob.glob(clustering_output +
                          '*file_datetime_list.npy')
            print("file_datetime_list_file ", file_datetime_list_file)
            file_datetime_list = np.load(file_datetime_list_file[0],
                                         allow_pickle=True)
            print("file_datetime_list ", file_datetime_list)

        except Exception as e:
            print("Error : ", e)
            raise ValueError('Error opening file {}'
                             .format(file_datetime_list_file))
        # Get basename
        if (len(file_datetime_list) == 2):
            bn = str("H_" + str(file_datetime_list[0]) + str("_") +
                     str(file_datetime_list[1]) + str("_"))
            print("bn ", bn)

    # select raw files
    if ltk:
        print("\n\nSelect raw files to spike sort\n\n")
        file_path = filedialog.askopenfilenames(title="Select your file(s)")
    else:
        if isinstance(file_path, str):
            if op.exists(file_path) and op.isfile(file_path):
                fl_name, fl_ext = op.splitext(file_path)
                print("fl_name, fl_ext ", fl_name, " ", fl_ext)
                if (fl_ext == '.txt'):
                    print("file_path ", file_path)
                    file_path_tmp_lines = []
                    with open(file_path, 'r') as f:
                        for line in f.readlines():
                            print("Line ", line.strip('\n'))
                            if line.strip('\n'):
                                file_path_tmp_lines.append(line.strip('\n'))
                    file_path = tuple(file_path_tmp_lines)

                    print("file_path ", file_path)
                    print("type file_path ", type(file_path))

    # Change file_path to tuple if it is string
    if isinstance(file_path, str):
        print("type(file_path) ", type(file_path))
        file_path = (file_path, )
        print("file_path ", file_path)

    # Change file_path to tuple if it is string
    if isinstance(file_path, str):
        print("type(file_path) ", type(file_path))
        file_path = (file_path, )
        print("file_path ", file_path)

    # Case in which user passes a directory. Find all of the bin files
    # and make an array with the full path to each one. Pass this into
    # the rest of the code as if the user had selected the group
    # through a GUI.
    if os.path.isdir(file_path[0]):
        if (len(glob.glob(file_path[0]+os.path.sep+'*.bin')) > 0):
            file_path_tmp = glob.glob(file_path[0]+os.path.sep+'*.bin')
            print("len(file_path_tmp) ", len(file_path_tmp))
            print('file_path_tmp ', file_path_tmp)
            file_path = tuple(file_path_tmp)
            print('type(file_path) ', type(file_path))
            print('file_path ', file_path)
        elif (len(glob.glob(file_path[0]+os.path.sep+'*.rhd')) > 0):
            file_path_tmp = glob.glob(file_path[0]+os.path.sep+'*.rhd')
            print("len(file_path_tmp) ", len(file_path_tmp))
            print('file_path_tmp ', file_path_tmp)
            file_path = tuple(file_path_tmp)
        elif (len(glob.glob(file_path[0]+os.path.sep+'*.mda')) > 0):
            file_path_tmp = glob.glob(file_path[0]+os.path.sep+'*.mda')
            print("2 len(file_path_tmp) ", len(file_path_tmp))
            print('2 file_path_tmp ', file_path_tmp)
            file_path = tuple(file_path_tmp)
        else:
            raise ValueError('Error : Unknown file ext, check filepath')

    #  Sort files in case it is not given in order manually
    print("type(file_path)1 ", type(file_path))
    file_path = np.sort(file_path)
    print("type(file_path)2 ", type(file_path))

    # Check file path [0]
    for _tmprfile in file_path:
        ext_list = ['.bin', '.rhd', '.mda', '.mat']
        print("_tmp_rfile ", _tmprfile)
        _, tmprfile_ext = op.splitext(_tmprfile)
        if not (os.path.exists(_tmprfile) and os.path.isfile(_tmprfile)):
            # print("rawfile ", _tmprfile)
            raise FileNotFoundError("Rawdata file {} does not exists".
                                    format(_tmprfile))
        if tmprfile_ext not in ext_list:
            raise ValueError("Rawdata file {} unknown file extension"
                             .format(_tmprfile))

    # Print all paths
    print("clustering_output ", clustering_output)
    print("type(file_path) ", type(file_path))
    print("file_path ", file_path)
    print("file_path[0] ", file_path[0])
    print("Sampling frequency ", fs)

    # If multiple files, immediately sort file path by the recording time.
    last_sep = file_path[0].rfind('/')
    datdir = file_path[0][0:last_sep+1]
    first_file_name = file_path[0][last_sep:]
    last_file_name = file_path[-1][last_sep:]
    print("datdir ", datdir)
    print("pwd now0 ", os.getcwd())
    # ch_o
    # os.chdir(datdir)
    # if np.size(file_path) == 1:
    #     # get the dat dir:
    #     last_sep    = file_path[0].rfind('/')
    #     datdir      = file_path[0][0:last_sep+1]

    # elif np.size(file_path) > 1:
    #     last_sep    = file_path[0].rfind('/')
    #     datdir      = file_path[0][0:last_sep+1]
    print("file_path[0] ", file_path[0])
    _, ext = os.path.splitext(file_path[0])

    print("ext ", ext)
    tic = time.time()
    print('\nSpikeInterface extracting rawdata files')
    print("file_path {}".format(file_path))
    print("datdir {}".format(datdir))
    print("TMPDIR_LOC {}\n".format(TMPDIR_LOC), flush=True)
    if lsorting:
        if ext == '.mda':
            print("gonna do things")
            # g_o
            file_datetime_list, ecube_time_list = \
                dealwithbinarydata(file_path, TMPDIR_LOC,
                                   num_channels, hstype, nprobes,
                                   mdaflag=1,
                                   probetosort=probetosort, lnosplit=lnosplit,
                                   probe_channels=probe_channels,
                                   fs=fs)
        # This will move ahead with an extant .mda file.
        # No need to deal with other files/formats.

        elif ((ext == '.bin') or (ext == '.rhd')):
            # Load and convert the binary files.
            # hstype = ['eibless-hs64_port32']
            # hstype = ['hs64']
            # nprobes = 1
            # num_channels = 64
            # g_o
            file_datetime_list, ecube_time_list = \
                dealwithbinarydata(file_path, TMPDIR_LOC,
                                   num_channels, hstype, nprobes,
                                   mdaflag=0,
                                   probetosort=probetosort, lnosplit=lnosplit,
                                   probe_channels=probe_channels,
                                   fs=fs)
        
        elif ext == '.mat':
            # read .mat file
            # output: file_datetime_list, ecube_time_list
            print('.mat file inputted from NDI')
            file_datetime_list = False
            ecube_time_list = False

            group_tmp_dir = TMPDIR_LOC
            
            group_raw_tmp_dir = op.join(group_tmp_dir,
                                'grouped_raw_dat_temp_folder')
            print('group_raw_tmp_dir ', group_raw_tmp_dir)
            # check group_tmp_dir exits then create grouped_raw_dat_temp_folder
            if os.path.exists(group_tmp_dir) and os.path.isdir(group_tmp_dir):
                if os.path.exists(group_raw_tmp_dir) and \
                        os.path.isdir(group_raw_tmp_dir):
                    if os.listdir(group_raw_tmp_dir):
                        raise FileExistsError("Directory {} is not empty".
                                            format(group_raw_tmp_dir))
                    else:
                        print("Directory {} is empty.".format(group_raw_tmp_dir))
                else:
                    print("Creating directory {}".format(group_raw_tmp_dir))
                    try:
                        os.mkdir(group_raw_tmp_dir)
                    except Exception as e:
                        print(e)
                        print("Could not create directory {}",
                            format(group_raw_tmp_dir))
                        raise NotADirectoryError("Directory {} not found".
                                                format(group_raw_tmp_dir))
            else:
                raise NotADirectoryError("Directory {} does not exists".
                                        format(group_raw_tmp_dir))

        else:
            pass

    if lsorting:
        if file_datetime_list and ecube_time_list:
            # Get basename
            if (len(file_datetime_list) == 2):
                bn = str("H_" + str(file_datetime_list[0]) + str("_") +
                        str(file_datetime_list[1]) + str("_"))
                print("bn ", bn)
            print("ecube_time_list ", ecube_time_list)
            print("file_datetime_list ", file_datetime_list)
            np.save(op.join(clustering_output,
                    bn + 'ecube_time_list.npy'),
                    ecube_time_list)
            np.save(op.join(clustering_output,
                    bn + 'file_datetime_list.npy'),
                    file_datetime_list)

    toc = time.time()
    print('SpikeInterface extracting rawdata files took {} seconds\n'.
          format(toc - tic))

    print("pwd now1 ", os.getcwd())
    print("datdir ", datdir)
    # ch_o
    # os.chdir(datdir)
    print("pwd now2 ", os.getcwd())

    tic = time.time()
    print('\nSpikeInterface change to group directory')
    # check to see if you've already generated some traces files.
    # if so, get rid of them and start fresh.
    # c_o outputcheck = glob.glob('clustering_output/')
    # outputcheck = glob.glob(clustering_output)
    # print("outputcheck ", outputcheck)
    # if outputcheck:
    #     os.system('rm -rf {}'.format(outputcheck[0]))
    #     # shutil.rmtree(outputcheck)
    # else:
    #     pass
    # # c_o os.mkdir('clustering_output')
    # os.mkdir(clustering_output)

    # define colors per unit here... keep throughout.
    colors = ["#9b59b6", "#3498db", "#95a5a6", "#e74c3c", "#34495e",
              "#2ecc71", '#ff000d', '#5cac2d']

    # #########################################################################

    # #########################################################################
    # g_o
    # os.chdir("grouped_raw_dat_temp_folder")
    try:
        os.chdir(op.join(TMPDIR_LOC,
                         "grouped_raw_dat_temp_folder"))
    except Exception as e:
        print(e)
        print("Directory {} does not exist",
              format(op.join(TMPDIR_LOC, "grouped_raw_dat_temp_folder")))
        raise NotADirectoryError(
            "Directory {} not found".
            format(op.join(TMPDIR_LOC, "grouped_raw_dat_temp_folder")))

    



    folders = sorted(glob.glob("*channel_group_*"))
    print("folders ", folders)
    print("pwd now3 ", os.getcwd())
    #  probe_folder_path = \
    #      filedialog.askdirectory(title="Select your probe folder")
    #  print(f'probe folder: {probe_folder_path}')
    #  ckbn lfp = input('Do you want to save LFP? y or n. ')
    #  SAHARA we need to get the installed sorters and
    #  automatically populate this question and the subsequent component
    # in bigmama
    #  ckbn sorter = input('Which sorter do you want? Mountainsort4 (m),
    #  or HerdingSpikes (h) ?  ')
    # sorter = 'm'
    toc = time.time()
    print('SpikeInterface change to group directory took {} seconds'.
          format(toc - tic), flush=True)

    if args.ndi_input:
        tic = time.time()
        print('\nSpikeInterface sorting wrapper')
        # c_o
        # g_o
        # bigmamma(thresh, folder, datdir,
        sorted_data, ch_group, noflylist, rec_length, amps = \
            bigmamma(thresh, folder,
                    op.join(TMPDIR_LOC, "grouped_raw_dat_temp_folder"),
                    lfp, spk_sorter, probefile,
                    sorter_config,
                    clustering_output,
                    bad_chan_list=bad_chans,
                    rawdatfilt=rawdatfilt,
                    lnosplit=lnosplit,
                    lsorting=lsorting,
                    num_cpu=ncpus,
                    sampling_frequency=fs,
                    ecube_time_list=ecube_time_list,
                    file_datetime_list=file_datetime_list,
                    bn=bn,
                    ndi_input=args.ndi_input,
                    ndi_hengen_path=args.ndi_hengen_path)
        toc = time.time()
        print('SpikeInterface sorting wrapper took {} seconds'.
            format(toc - tic), flush=True)

        # Save results using mbt
        tic = time.time()
        print('\nSpikeInterface saving output for mbt')
        if sorted_data.get_unit_ids() == []:
            print("no units were found on this group")
        else:
            print('\nUnits:', sorted_data.get_unit_ids())
            all_units = list(sorted_data.get_unit_ids())
            print('Number of units:', len(sorted_data.get_unit_ids()))
            print('ch_group ', ch_group)
            print('noflylist ', noflylist)
            n = siout.siout(sorted_data, noflylist, rec_length,
                            file_datetime_list, ecube_time_list,
                            amps)
            # np.save(f"clustering_output/neurons_group{ch_group}.npy", n)
            np.save(op.join(clustering_output,
                            bn + f'neurons_group{ch_group}.npy'), n)
            good_units = list(set(all_units).difference(noflylist))
            print("good units ", good_units)
            if (lmetrics > 0):
                nb = siout.siout(sorted_data, good_units, rec_length,
                                file_datetime_list, ecube_time_list,
                                amps)
                np.save(op.join(clustering_output,
                                bn + f'neurons_group{ch_group}_bad.npy'), nb)
            np.save(op.join(clustering_output,
                            bn + f'noflylist_group{ch_group}.npy'), noflylist)
            np.save(op.join(clustering_output,
                            bn + f'good_units_group{ch_group}.npy'),
                    good_units)
        toc = time.time()
        print('SpikeInterface saving output for mbt took {} seconds'.
            format(toc - tic), flush=True)

        # Summary
        print("\n \t\tSummary")
        print("\tFound total {} units".
            format((len(good_units) + len(noflylist))))
        print("\tFound {} good units".format(len(good_units)))
        if (lmetrics > 0):
            print("\tFound {} bad units".format(len(noflylist)), flush=True)
    else:
        for folder in folders:
            tic = time.time()
            print('\nSpikeInterface sorting wrapper')
            # c_o
            # g_o
            # bigmamma(thresh, folder, datdir,
            sorted_data, ch_group, noflylist, rec_length, amps = \
                bigmamma(thresh, folder,
                        op.join(TMPDIR_LOC, "grouped_raw_dat_temp_folder"),
                        lfp, spk_sorter, probefile,
                        sorter_config,
                        clustering_output,
                        bad_chan_list=bad_chans,
                        rawdatfilt=rawdatfilt,
                        lnosplit=lnosplit,
                        lsorting=lsorting,
                        num_cpu=ncpus,
                        sampling_frequency=fs,
                        ecube_time_list=ecube_time_list,
                        file_datetime_list=file_datetime_list,
                        bn=bn)
            toc = time.time()
            print('SpikeInterface sorting wrapper took {} seconds'.
                format(toc - tic), flush=True)

            # Save results using mbt
            tic = time.time()
            print('\nSpikeInterface saving output for mbt')
            if sorted_data.get_unit_ids() == []:
                print("no units were found on this group")
            else:
                print('\nUnits:', sorted_data.get_unit_ids())
                all_units = list(sorted_data.get_unit_ids())
                print('Number of units:', len(sorted_data.get_unit_ids()))
                print('ch_group ', ch_group)
                print('noflylist ', noflylist)
                n = siout.siout(sorted_data, noflylist, rec_length,
                                file_datetime_list, ecube_time_list,
                                amps)
                # np.save(f"clustering_output/neurons_group{ch_group}.npy", n)
                np.save(op.join(clustering_output,
                                bn + f'neurons_group{ch_group}.npy'), n)
                good_units = list(set(all_units).difference(noflylist))
                print("good units ", good_units)
                if (lmetrics > 0):
                    nb = siout.siout(sorted_data, good_units, rec_length,
                                    file_datetime_list, ecube_time_list,
                                    amps)
                    np.save(op.join(clustering_output,
                                    bn + f'neurons_group{ch_group}_bad.npy'), nb)
                np.save(op.join(clustering_output,
                                bn + f'noflylist_group{ch_group}.npy'), noflylist)
                np.save(op.join(clustering_output,
                                bn + f'good_units_group{ch_group}.npy'),
                        good_units)
            toc = time.time()
            print('SpikeInterface saving output for mbt took {} seconds'.
                format(toc - tic), flush=True)

            # Summary
            print("\n \t\tSummary")
            print("\tFound total {} units".
                format((len(good_units) + len(noflylist))))
            print("\tFound {} good units".format(len(good_units)))
            if (lmetrics > 0):
                print("\tFound {} bad units".format(len(noflylist)), flush=True)

    setoc = time.time()
    print('\nTotal time took {} seconds'.
          format(setoc - setic), flush=True)
    # Delete path_tmpdir_loc
    print('\nTMPDIR_LOC ', TMPDIR_LOC, flush=True)
    print('path_tmpdir_loc \n', path_tmpdir_loc)
    if os.path.isdir(path_tmpdir_loc):
        try:
            print('Removing directory {}'.format(path_tmpdir_loc))
            shutil.rmtree(path_tmpdir_loc)
        except Exception as e:
            print(e)
            print('Error: deleting directory {}'.format(path_tmpdir_loc))
    # Delete grouped_raw_dat_temp_folder
    grouped_raw_dat_temp_folder_del = op.join(TMPDIR_LOC,
                                              'grouped_raw_dat_temp_folder')
    print("grouped_raw_dat_temp_folder ",
          grouped_raw_dat_temp_folder_del)
    if os.path.isdir(grouped_raw_dat_temp_folder_del):
        try:
            print('Removing directory {}'
                  .format(grouped_raw_dat_temp_folder_del), flush=True)
            shutil.rmtree(grouped_raw_dat_temp_folder_del)
        except Exception as e:
            print(e)
            print('Error: deleting directory {}'
                  .format(grouped_raw_dat_temp_folder_del), flush=True)

    # # TODO:, add if to check for files not found
    # # neurons_group0_files = glob.glob(os.path.join(clustering_output, '*neurons_group0.npy'))
    # # amplitudes0_files = glob.glob(os.path.join(clustering_output, '*amplitudes0.npy'))

    # n = np.load(glob.glob(os.path.join(clustering_output, '*neurons_group0.npy'))[0])
    # n_amp = mbt.load_spike_amplitudes(n, glob.glob(os.path.join(clustering_output, '*amplitudes0.npy'))[0])
    
    # scipy.io.savemat(os.path.join(clustering_output, 'tmp.mat'), {'n': n})
