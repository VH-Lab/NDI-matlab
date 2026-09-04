#!/usr/bin/env python3
"""Write the small synthetic .gef files TestReadGEF reads.

Deliberately written by h5py, not by MATLAB. readGEF's whole job is to
cope with files it did not write, so a fixture built by the same language
and library as the reader tests very little. This mirrors
conformance_tile.bin, which NDI-python wrote for MATLAB to decode.

Each file varies ONE thing readGEF has to probe for, so a failure names
the probe that broke. Re-run only when the fixtures must change; the
outputs are committed.

    python make_gef_fixtures.py
"""
import numpy as np, h5py, pathlib

HERE = pathlib.Path(__file__).resolve().parent

X = np.array([10, 11, 12, 20, 30, 31], np.int32)
Y = np.array([50, 51, 52, 60, 70, 71], np.int32)
C = np.array([1, 2, 200, 7, 8, 9])
GID = [b"ENSG1", b"ENSG2", b"ENSG3"]
GNM = [b"Aaa", b"Bbb", b"Ccc"]
OFF = np.array([0, 3, 4], np.uint32)
CNT = np.array([3, 1, 2], np.uint32)


def write(name, *, root="/geneExp/bin1", expr="expression", box=(0, 0, 99, 99),
          count_dtype=np.uint16, xname="x", yname="y", cname="count",
          attrs_at="bin", stat_gene=False):
    path = HERE / name
    with h5py.File(path, "w") as f:
        g = f.create_group(root)
        rec = np.zeros(len(X), dtype=[(xname, np.int32), (yname, np.int32),
                                      (cname, count_dtype)])
        rec[xname] = X
        rec[yname] = Y
        rec[cname] = C.astype(count_dtype)
        g.create_dataset(expr, data=rec)

        gene = np.zeros(3, dtype=[("geneID", "S16"), ("geneName", "S16"),
                                  ("offset", np.uint32), ("count", np.uint32)])
        gene["geneID"] = GID
        gene["geneName"] = GNM
        gene["offset"] = OFF
        gene["count"] = CNT
        g.create_dataset("gene", data=gene)

        # WHERE the extent attributes live is the point of several tests, so
        # it is a parameter. A fixture that always writes them at the root
        # agrees with the root-only-probe bug instead of catching it.
        target = g if attrs_at == "bin" else f
        for k, v in zip(("minX", "minY", "maxX", "maxY"), box):
            target.attrs[k] = np.int32(v)

        f.attrs["sn"] = np.bytes_(b"TESTCHIP01")
        f.attrs["resolution"] = np.int32(500)

        if stat_gene:
            st = np.zeros(3, dtype=[("geneID", "S16"), ("MIDcount", np.uint32)])
            st["geneID"] = GID
            st["MIDcount"] = np.array([203, 7, 17], np.uint32)  # true per-gene sums of C
            f.create_dataset("/stat/gene", data=st)
    return path


def main():
    made = [
        write("gef_basic.gef", stat_gene=True),
        write("gef_badbox.gef", box=(0, 0, 5, 5)),
        write("gef_uint8.gef", count_dtype=np.uint8),
        write("gef_altfields.gef", xname="X", cname="MIDCount"),
        write("gef_altroot.gef", root="/wholeExp/bin1", expr="cellBin"),
        write("gef_rootattrs.gef", attrs_at="root"),
    ]
    with h5py.File(HERE / "gef_notagef.gef", "w") as f:
        f.create_dataset("/nothing", data=np.zeros(1))
    made.append(HERE / "gef_notagef.gef")
    for p in made:
        print(f"{p.name:24s} {p.stat().st_size:6d} bytes")


if __name__ == "__main__":
    main()
