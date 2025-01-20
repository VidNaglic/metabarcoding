import pandas as pd
import h5py
from scipy.sparse import csr_matrix

# Define file paths
coi_table_path = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_neretva/bioinfo/exported-rep-seqs/feature-table.tsv"
bold_results_path = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_neretva/bioinfo/exported-rep-seqs/bold_results.tsv"
output_path = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_neretva/bioinfo/exported-rep-seqs/joined_coi_bold_results.xlsx"

try:
    # Debugging HDF5 file structure
    print("Opening COI table HDF5 file for inspection...")
    with h5py.File(coi_table_path, "r") as hdf:
        print("HDF5 File Structure:")
        hdf.visit(print)

    # Load COI table
    print("Loading COI table from 'observation/matrix'...")
    with h5py.File(coi_table_path, "r") as hdf:
        # Extract sparse matrix components
        data = hdf["observation/matrix/data"][:]
        indices = hdf["observation/matrix/indices"][:]
        indptr = hdf["observation/matrix/indptr"][:]
        observation_ids = hdf["observation/ids"][:].astype(str)
        sample_ids = hdf["sample/ids"][:].astype(str)

        # Create sparse matrix
        sparse_matrix = csr_matrix((data, indices, indptr), shape=(len(observation_ids), len(sample_ids)))

        # Convert to DataFrame
        coi_table = pd.DataFrame.sparse.from_spmatrix(sparse_matrix, index=observation_ids, columns=sample_ids)

    print("COI table loaded successfully!")

    # Load BOLDigger results
    print("Loading BOLDigger results...")
    bold_results = pd.read_csv(bold_results_path, sep=',', index_col=0)
    bold_results.index.name = "Feature ID"

    # Merge tables
    print("Merging COI table with BOLDigger results...")
    merged = pd.merge(coi_table, bold_results, left_index=True, right_index=True, how='inner')

    # Save to Excel
    print(f"Saving merged results to {output_path}...")
    merged.to_excel(output_path)
    print("Joining complete. Results saved!")

except FileNotFoundError as e:
    print(f"Error: {e}")
    print("Check if the files exist at the specified paths.")
except Exception as e:
    print(f"An unexpected error occurred: {e}")
