import numpy as np
from scipy import stats
# import pdb


def splishsplashiwastakinabath(sorted_data, isi_contamination, amp_min=-20,
                               isi_max=0.5):
    '''
    Generate a list of units that meet exclusion criteria. Sorters will
    identify some units that are quickly classifiable as noise. Pull those with
    various thresholds. Soon, this will contain the XGA_Boost decision tree for
    automated scoring of unit quality. Continue to build this as time goes on.
    Initially, units with too low of an amplitude will be ignored
    '''

    # Here are some initial normalized waveforms that fit
    # "unit-like" classification:

    # Here are some common noise waveforms (normalized) that appear
    # on our system. Feel free to add to this if necessary:

    badtraces = [
        [0.09767442,  0.11162791,  0.12093023,  0.13023256,  0.14418605,
         0.15348837,  0.16744186,  0.1767442,  0.18837209,  0.2,
         0.20930232,  0.22325581,  0.23255815,  0.2372093,  0.24186046,
         0.26976743,  0.26511627,  0.25348836,  0.31627908,  0.26046512,
         -0.19534884, -0.7372093, -0.90697676, -0.8604651, -0.9255814,
         -1.0, -0.9395349, -0.855814, -0.74418604, -0.5813953,
         -0.47906977, -0.20465116,  0.3255814,  0.53953487,  0.31627908,
         0.19767442,  0.26046512,  0.26511627,  0.23255815,  0.22790697,
         0.21860465,  0.20465116,  0.19069767,  0.18139535,  0.16744186,
         0.15813954,  0.14418605,  0.13023256,  0.12093023,  0.10697675,
         0.09767442,  0.0883721,  0.07906977,  0.06744186,  0.06046512,
         0.05116279,  0.04186046,  0.03255814,  0.02790698,  0.01860465,
         0.01395349,  0.00465116,  0.0,  0.0,  0.0,
         -0.00930233, -0.00930233, -0.01395349, -0.01395349, -0.01860465,
         -0.01860465, -0.01395349, -0.01395349, -0.01860465, -0.01860465],

        [0.11267605,  0.12676056,  0.14084508,  0.14084508,  0.15492958,
         0.15492958,  0.16901408,  0.18309858,  0.1971831,  0.1971831,
         0.2112676,  0.22535211,  0.23943663,  0.23943663,  0.2535211,
         0.2535211,  0.2535211,  0.26760563,  0.26760563,  0.11267605,
         -0.26760563, -0.5915493, -0.70422536, -0.8028169, -0.943662,
         -1.0, -0.9859155, -0.91549295, -0.8028169, -0.69014084,
         -0.53521127, -0.11267605,  0.28169015,  0.32394367,  0.2112676,
         0.1971831,  0.23943663,  0.23943663,  0.22535211,  0.22535211,
         0.22535211,  0.22535211,  0.2112676,  0.2112676,  0.1971831,
         0.18309858,  0.16901408,  0.15492958,  0.15492958,  0.12676056,
         0.11267605,  0.09859155,  0.08450704,  0.08450704,  0.08450704,
         0.07042254,  0.05633803,  0.04225352,  0.04225352,  0.02816901,
         0.01408451,  0.01408451,  0.0, 0.0,  0.0,
         0.0, 0.0, 0.0, -0.01408451, -0.01408451,
         -0.01408451, -0.01408451, -0.02816901, -0.02816901, -0.02816901]
            ]

    goodtraces = [
        [0.06349207,  0.07936508,  0.0952381,  0.07936508,  0.0952381,
         0.0952381,  0.0952381,  0.0952381,  0.11111111,  0.11111111,
         0.12698413,  0.12698413,  0.12698413,  0.12698413,  0.12698413,
         0.12698413,  0.12698413,  0.0952381,  0.0952381,  0.07936508,
         0.03174603, -0.01587302, -0.11111111, -0.4047619, -0.7936508,
         -1.0, -0.93650794, -0.6825397, -0.47619048, -0.34920636,
         -0.25396827, -0.15873016, -0.07936508, -0.03174603,  0.0,
         0.03174603,  0.06349207,  0.0952381,  0.11111111,  0.12698413,
         0.15873016,  0.16666667,  0.17460318,  0.18253969,  0.1904762,
         0.17460318,  0.17460318,  0.17460318,  0.17460318,  0.15873016,
         0.15873016,  0.14285715,  0.12698413,  0.11111111,  0.0952381,
         0.0952381,  0.07936508,  0.07936508,  0.06349207,  0.04761905,
         0.03174603,  0.01587302,  0.01587302,  0.0, 0.0,
         0.0, 0.0,  0.0,  0.0, -0.01587302,
         -0.01587302, -0.01587302, -0.01587302, -0.01587302, -0.01587302],
        [0.03883495,  0.04368932,  0.03883495,  0.04368932,  0.04854369,
         0.05339806,  0.0631068,  0.06796116,  0.07281554,  0.0776699,
         0.08252427,  0.08737864,  0.09708738,  0.09708738,  0.10679612,
         0.12135922,  0.13106796,  0.13106796,  0.13106796,  0.12135922,
         0.0776699,  0.04854369,  0.00485437, -0.2524272, -0.7330097,
         -1.0, -0.80582523, -0.4563107, -0.22815534, -0.08737864,
         0.01941748,  0.09708738,  0.13592233,  0.1553398,  0.1553398,
         0.1553398,  0.14563107,  0.13106796,  0.12135922,  0.10679612,
         0.09708738,  0.09223301,  0.08252427,  0.07281554,  0.07281554,
         0.0631068,  0.05339806,  0.04854369,  0.04368932,  0.04368932,
         0.03883495,  0.03398058,  0.02912621,  0.02427184,  0.02427184,
         0.01941748,  0.01456311,  0.01456311,  0.01456311,  0.01213592,
         0.00485437,  0.00485437, 0.0, 0.0, 0.0,
         0.0, 0.0, 0.0, -0.00485437, -0.00970874,
         -0.00485437, 0.0, 0.0, 0.0, -0.00485437]

    ]

    units = sorted_data.get_unit_ids()

    nbad = np.shape(badtraces)[0]
    ngood = np.shape(goodtraces)[0]
    bad_kstat = np.zeros([np.size(units), nbad])
    bad_pval = np.zeros([np.size(units), nbad])
    badcorr = np.zeros([np.size(units), nbad])
    good_kstat = np.zeros([np.size(units), ngood])
    good_pval = np.zeros([np.size(units), ngood])
    goodcorr = np.zeros([np.size(units), ngood])

    amps = np.zeros(np.size(units))
    ucount = 0
    for i in units:
        template = sorted_data.get_unit_property(i, 'template')
        amps[ucount] = np.min(template)
        maxchan = sorted_data.get_unit_property(i, 'max_channel')
        normwf = template[maxchan]/np.abs(amps[ucount])

        # test against bad traces:
        badcount = 0
        for bad in badtraces:
            a, b = stats.ks_2samp(normwf, bad)
            bad_kstat[ucount, badcount] = a
            bad_pval[ucount, badcount] = b
            badcorr[ucount, badcount] = np.corrcoef(normwf, bad)[0, 1]
            badcount += 1

        # test against bad traces:
        goodcount = 0
        for good in goodtraces:
            c, d = stats.ks_2samp(normwf, good)
            good_kstat[ucount, goodcount] = c
            good_pval[ucount, goodcount] = d
            goodcorr[ucount, goodcount] = np.corrcoef(normwf, good)[0, 1]
            goodcount += 1

        # fig, ax = plt.subplots(ncols = 1, nrows = 1, figsize = [8,8])
        # ax.plot(normwf)
        # ax.text(s = f'good corr {goodcorr[ucount,:]}
        # \nbad corr {badcorr[ucount,:]}', y = -0.9, x = 0.5)
        ucount += 1

        # figz,axz = plt.subplots(ncols = 1, nrows = 1, figsize = [8,8])
        # badunits = [22,25,26,32,35,36,39]
        # for e in np.arange(0, np.size(units)):
        #     if e in badunits:
        #         color = 'r'
        #     else:
        #         color = 'b'

        #     if amps[e]<-20:
        #         axz.scatter(goodcorr[e,0], badcorr[e,0], color = color)
        #         axz.scatter(goodcorr[e,1], badcorr[e,1],
        #                     color = color, marker = '*')

        #         if goodcorr[e,0]<0.9 and badcorr[e,0]<0.75:
        #             fig, ax = plt.subplots(ncols = 1, nrows = 1,
        #                                    figsize = [8,8])
        #             ax.plot(sorted_data.get_unit_property(e,'template').T)
        #             ax.text(s = f'good corr {goodcorr[e,:]}
        #             \nbad corr {badcorr[e,:]}', y = -0.9, x = 0.5)
        #     else:
        #         pass
    kill_list = np.array([])

    bad_kills = np.squeeze(np.where(np.any(badcorr > 0.95, 1)))
    nogoods_kill = np.squeeze(np.where(np.all(goodcorr < 0.6, 1)))
    amp_kills = np.squeeze(np.where(amps > amp_min))

    if np.size(bad_kills) != 0:
        kill_list = np.append(kill_list, bad_kills)
    if np.size(nogoods_kill) != 0:
        kill_list = np.append(kill_list, nogoods_kill)
    if np.size(amp_kills) > 0:
        kill_list = np.append(kill_list, amp_kills)

    # kill_list = np.concatenate((bad_kills,nogoods_kill,amp_kills), axis = 0)
    kill_list = np.int64(np.unique(kill_list))

    return kill_list
