import sys
import argparse
import glob
import numpy as np
# import musclebeachtools as mbt
import scipy

parser = argparse.ArgumentParser(description='Rate neuron quality using musclebeachtools')
parser.add_argument('--experiment-path', type=str, help='path where to look for clustering_output')

args = parser.parse_args()
print(args)

print('exp path: ', args.experiment_path)

# *neurons_group0.npy file handling
neurons_group0_files = glob.glob(f'{args.experiment_path}/clustering_output/*neurons_group0.npy')
print('neurons_group0_files:', neurons_group0_files)

if len(neurons_group0_files) == 0:
    sys.exit(f'No sorting output found in {args.experiment_path}/clustering_output')

# *neurons_group0.npy file handling
amplitudes0_files = glob.glob(f'{args.experiment_path}/clustering_output/*amplitudes0.npy')

if len(amplitudes0_files) == 0:
    sys.exit(f'No sorting output found in {args.experiment_path}/clustering_output')


n = np.load(neurons_group0_files[0], allow_pickle=True)
# n_amp = mbt.load_spike_amplitudes(n, amplitudes0_files[0])

print(len(n)) # number of neurons

n[0].checkqual() # opens plots with radio buttons to modify quality rating

# to save results
scipy.io.savemat('tmp.mat', {'n': n}) # has to be passed as a dict like that
