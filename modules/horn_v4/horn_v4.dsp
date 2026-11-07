// horn_v4 — air-chopper source with an exponential (dB-linear) drive curve, so the
// harmonics only bloom late in the attack; sharper pulse edges, breath, jitter, more room
import("stdfaust.lib");

gate   = button("gate");
f0     = hslider("f0", 130.8, 60, 300, 0.1);
duty   = hslider("duty", 0.175, 0.05, 0.5, 0.001);
gmin   = hslider("drive_min", 0.5, 0.1, 10, 0.01);
gmax   = hslider("drive_max", 300, 10, 1000, 1);
noiseL = hslider("breath", 0.5, 0, 2, 0.001);
wet    = hslider("room", 3, 0, 6, 0.01);
vol    = hslider("volume", 0.25, 0, 2, 0.01);

// slow random fluctuations: a living source, not a frozen one
lfn(i, fc) = no.noises(3, i) : fi.lowpass(2, fc) : *(1/sqrt(fc/ma.SR));
ampJit = 1 + 0.02*lfn(0, 15);
f0Jit  = f0 * (1 + 0.0008*lfn(1, 4));

p      = en.adsre(0.25, 0.1, 1, 0.08, gate) * ampJit;  // air pressure
g      = gmin * pow(gmax/gmin, p);                     // drive rises dB-linearly with pressure

sigm(x) = 1/(1 + exp(-x));
c      = os.osc(f0Jit);
puff   = sigm(g*(c - cos(ma.PI*duty)));                // one air puff per period
breath = lfn(2, 6000) : fi.highpass(1, 400) : *(puff*noiseL*0.1);

bell   = fi.dcblocker : fi.peak_eq(5, 2*f0, 120) : fi.peak_eq(4, 1000, 600);
sig    = (puff + breath) * p : bell : *(vol);

process = sig <: _, _, (re.zita_rev1_stereo(0, 200, 6000, 3.3, 2.8, 48000) : *(wet), *(wet)) :> _, _;
