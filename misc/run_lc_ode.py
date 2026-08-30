#!/usr/bin/env python
"""Run the hVHDL_ode LC-filter simulation and compare it to the measurement.

1. runs the lc_filter_ode_tb testbench via the top-level vunit_test_ecp5.py
   -> misc/lc_filter_ode_tb.dat (a dithered time-domain run of the
   misc/emi_filter_model.qsch LC ladder, integrated with hVHDL_ode's RK4)
2. estimates H(f) = V(N04)/Vin from that run with the same Welch H1
   estimator template_tb uses (source/hVHDL_ode/python/freq_response.py)
3. overlays the measured Bode sweep in misc/L1C1_resp.csv, and the QSPICE
   AC analysis of the same schematic if QSPICE / PyQSPICE are available

    python misc/run_lc_ode.py
    python misc/run_lc_ode.py --no-sim --no-qspice          # replot only
"""
import argparse
import subprocess
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
sys.path.insert(0, str(REPO / "source" / "hVHDL_ode" / "python"))
from freq_response import freq_response  # noqa: E402

DAT = HERE / "lc_filter_ode_tb.dat"
N_WELCH_WINDOWS = 5  # must match freq_num_windows in lc_filter_ode_tb.vhd


def run_sim():
    runner = REPO / "vunit_test_ecp5.py"
    print(f"running {runner.name} lc_filter_ode_tb ...")
    # cwd = HERE so the testbench's lc_filter_ode_tb.dat lands in misc/
    subprocess.run([sys.executable, str(runner), "*lc_filter_ode_tb*", "-q"],
                   cwd=HERE, check=True)
    if not DAT.is_file():
        sys.exit(f"testbench did not produce {DAT}")


def ode_response():
    df = pd.read_csv(DAT, sep=r"\s+", comment="#")
    t = df["time"].to_numpy()
    fs = 1.0 / np.median(np.diff(t))
    nperseg = max(256, len(df) // N_WELCH_WINDOWS)
    f, h, coh = freq_response(df["B_u0"], df["B_u1"], fs=fs, nperseg=nperseg)
    keep = f > 0
    return f[keep], h[keep], coh[keep]


def measured_response(csv: Path):
    lines = csv.read_text(encoding="latin-1").splitlines()
    hdr = next(i for i, l in enumerate(lines) if l.lower().startswith("frequency"))
    m = pd.read_csv(csv, skiprows=hdr, encoding="latin-1")
    mag = next(c for c in m.columns if "Channel 2 Magnitude" in c)
    pha = next(c for c in m.columns if "Channel 2 Phase" in c)
    return m[m.columns[0]].to_numpy(), m[mag].to_numpy(), m[pha].to_numpy()


def qspice_response(qsch: Path, node="N04"):
    try:
        sys.path.insert(0, str(HERE))
        from plot_lc_ac_response import run_qspice_ac
        f, tf = run_qspice_ac(qsch, node)
        return f, 20 * np.log10(np.abs(tf)), np.degrees(np.angle(tf))
    except SystemExit:
        raise
    except Exception as e:
        print(f"skipping QSPICE overlay ({type(e).__name__}: {e})")
        return None


def break_wraps(phase_deg):
    p = np.asarray(phase_deg, float).copy()
    p[1:][np.abs(np.diff(p)) > 300.0] = np.nan
    return p


def peak(f, mag_db):
    i = int(np.argmax(mag_db))
    return float(f[i]), float(mag_db[i])


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--measured", type=Path, default=HERE / "L1C1_resp.csv")
    ap.add_argument("--qsch", type=Path, default=HERE / "emi_filter_model.qsch")
    ap.add_argument("--out", type=Path, default=HERE / "lc_ode_response.png")
    ap.add_argument("--no-sim", action="store_true", help="reuse the existing .dat, do not re-run the testbench")
    ap.add_argument("--no-qspice", action="store_true", help="skip the QSPICE AC overlay")
    ap.add_argument("--no-show", action="store_true")
    a = ap.parse_args()

    if not a.no_sim or not DAT.is_file():
        run_sim()

    f_ode, h_ode, coh = ode_response()
    mag_ode = 20 * np.log10(np.abs(h_ode))
    pha_ode = np.degrees(np.unwrap(np.angle(h_ode)))

    f_m, mag_m, pha_m = measured_response(a.measured)

    qs = None if a.no_qspice else qspice_response(a.qsch)

    fr_o, mg_o = peak(f_ode, mag_ode)
    fr_m, mg_m = peak(f_m, mag_m)
    print(f"hVHDL_ode  V(N04)/Vin  peak : {fr_o:9.1f} Hz   {mg_o:7.2f} dB")
    print(f"measured   {a.measured.name:<20} peak : {fr_m:9.1f} Hz   {mg_m:7.2f} dB")
    if qs is not None:
        fr_q, mg_q = peak(qs[0], qs[1])
        print(f"QSPICE     V(N04)/Vin  peak : {fr_q:9.1f} Hz   {mg_q:7.2f} dB")

    fig, (axm, axp) = plt.subplots(2, 1, sharex=True, figsize=(9, 7))

    axm.semilogx(f_ode, mag_ode, "-", lw=1.6, color="C0", label="hVHDL_ode RK4 (Welch estimate)")
    axp.semilogx(f_ode, break_wraps(pha_ode), "-", lw=1.6, color="C0")
    if qs is not None:
        axm.semilogx(qs[0], qs[1], "-", lw=1.2, color="C2", label="QSPICE .ac")
        axp.semilogx(qs[0], break_wraps(qs[2]), "-", lw=1.2, color="C2")
    axm.semilogx(f_m, mag_m, "--", lw=1.3, color="C1", label=f"measured  {a.measured.name}")
    axp.semilogx(f_m, break_wraps(pha_m), "--", lw=1.3, color="C1")

    axm.axvline(fr_o, color="C0", ls=":", lw=0.8)
    axm.axvline(fr_m, color="C1", ls=":", lw=0.8)
    axm.set_ylabel("magnitude [dB]")
    axm.set_title("LC filter V(N04)/Vin — hVHDL_ode vs QSPICE vs measured")
    axm.set_xlim(5e2, 2e5)
    axm.set_ylim(-60, 45)
    axm.grid(True, which="both", alpha=0.3)
    axm.legend()

    axp.set_ylabel("phase [deg]")
    axp.set_xlabel("frequency [Hz]")
    axp.grid(True, which="both", alpha=0.3)

    fig.tight_layout()
    fig.savefig(a.out, dpi=130)
    print(f"wrote {a.out}")
    if not a.no_show:
        plt.show()


if __name__ == "__main__":
    main()
