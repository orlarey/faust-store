declare name "horn_v40";
// Foghorn v40 — Poisson valve pulse; self-oscillation with a sharp threshold (amp = pressure^23),
// brightness / low mode / noise tied to the oscillation amplitude, valve slam, pitch dip and jitter,
// refitted horn body, spaced mic pair, harbour = the library's zita_rev1; fitted on target/foghorn.wav
// "pattern" plays the target's three blasts (3.36 / 2.86 / 1.59 s, onsets 0 / 7.83 / 14.72 s)
import("stdfaust.lib");

// three-blast pattern of the target, started by a press, gate lengths include the ~0.30 s build-up
pat   = button("pattern");
start = pat > pat';
cnt   = (\(c).(select2(start, min(c + 1, 1e9), 0))) ~ _;
tp    = cnt / ma.SR;
on    = (\(a).(max(start, a * (tp < 20)))) ~ _;
blast(a, d) = (tp >= a) & (tp < a + d);
gate  = max(button("gate"), on * (blast(0, 3.66) + blast(7.83, 3.16) + blast(14.72, 1.89)));
f0n  = hslider("f0", 130.8, 60, 300, 0.1);
vol  = hslider("gain", 0.115, 0, 1, 0.001);
wet  = hslider("reverb", 1.0, 0, 4, 0.01);
dry  = checkbox("dry");
wind = hslider("wind", 1.4, 0, 6, 0.01);
room = hslider("headroom", 7, 2, 100, 0.1);

// asymmetric one-pole (attack / release time constants)
ar(ta, tr, x) = fb ~ _ with {
  fb(y) = y + (x - y) * select2(x > y, 1 - ba.tau2pole(tr), 1 - ba.tau2pole(ta));
};

// blowing pressure (2 x 77 ms); the valve only oscillates near full pressure (amp = pressure^23):
// build-up and overshoot fitted on the target within 0.5 dB; at the cut the tone dies away dark (H2 only)
// from the first instant, tau 0.2 s (target: -4.7 dB at 0.1 s), with no hold-then-collapse
pr   = gate : ar(0.077, 2.0) : ar(0.077, 2.0);
amp0 = pr^23 * (gate : ar(0.0005, 0.2));
bump = max(0, amp0 - (amp0 : ar(0.08, 0.05)));       // pressure overshoot during the build-up
slam = max(0, (gate : ar(0.0005, 0.04)) - gate);     // valve slam at cut-off (+2.5 dB, every blast)
amp  = amp0 * (1 + 3.5 * bump + 0.6 * slam);
shut = gate : ar(0.0005, 0.012);                     // brightness collapses within ~12 ms at cut-off
slow = gate : si.smooth(ba.tau2pole(1.5));           // reservoir sag during the blast
live = 1 + 0.12 * no.lfnoise(8);                     // measured AM: 0.4 dB std, ~7 Hz

// pitch: glide 113 -> 131 Hz in the first ~30 ms of oscillation, -0.4 % dip during the overshoot, and a slow
// wander that broadens the upper partials' skirts (target H11-40: 4.2 Hz wide at -20 dB, side components
// -18 dB; v32 with 1.5x this wander: 5.6 Hz and -10 dB, too chorused)
f0 = f0n * (1 - 0.14 * (1 - amp0)^12) * (1 - 0.012 * bump)
   * (1 + 0.001 * no.lfnoise(12) + 0.0007 * no.lfnoise(2));

// valve pulse: sum r^k cos(k th), closed form; r -> 0 sine, r -> 1 sharp pulse
// brightness opens between -14 and -3 dB of oscillation amplitude (measured), H2 -14 dB at onset
ra = amp0 * shut;
open = ((ra - 0.2) / 0.5) : max(0) : min(1);
r  = max(0.985 * (1 - 0.03 * slow) * open^1.3 * (1 + 0.1 * bump), 0.4 * ra) : max(0.001) : min(0.99);
th = 2 * ma.PI * os.lf_sawpos(f0);
pulse = (r * cos(th) - r * r) / (1 - 2 * r * cos(th) + r * r) / r;
// energy through the body grows 8.6 dB with r: normalise so the amplitude alone sets the level
flow = amp * live * pulse / (1 + 1.506 * r^1.749) : fi.lowpass(1, 30);   // 1/k tilt (beta = -1)

// jet noise ("wind"), radiated at the mouth (not filtered by the horn's reflection and resonances, which made
// it metallic), modulated by the flow. Shaped on the target's noise floor between harmonics: flat to ~500 Hz,
// -6 dB/oct up to ~4 kHz, steep above ~5 kHz. Measured attack: the blowing starts with the tone (within 40 ms,
// nothing before) at ~3 dB above its sustain level while the tone is still -13 dB (2-8 kHz at -10 dB rel.
// sustain, flatness 0.23): full level from oscillation amplitude ~-18 dB, air burst during the overshoot,
// stops with the valve at the cut.
blow = min(1, 8 * amp0) * shut * (1 + 1.5 * bump);
turb = no.noise * blow * (1 + pulse * 0.1) * wind : fi.highpass(1, 40) : fi.lowpass(1, 500) : fi.lowpass(2, 4800);

// body: inverted reflection 1.336 ms, horn low mode (257 Hz, H2 -6 dB at +50 ms: builds with amplitude^3), a
// broad main resonance, a measured narrow residual at H3 (stable to 0.4 dB across blasts), phase dispersion,
// and a 4.5 kHz rolloff (target above 8 kHz is noise-dominated: harmonics -63 dB, v30 had -53 dB).
// Reflection gain 0.9 and first-order allpasses (v30's gain 1 and allpass combs sounded metallic).
// Main resonance refitted on the target H1-H20 (2.2 dB rms): broad and low (718 Hz, 347 Hz wide, +8.7 dB);
// the narrow 805 Hz one made H6 stick out and H4-H5 too weak (nasal rather than "fat"). EQ fitted on the
// target's per-channel spectrum (what stereo listening hears; its mono sum hides H1 and H4 by ~4 dB because
// of the 4.65 ms mic offset): low shelf so that H1 = H2, a peak at H4, a little presence at 2.5 kHz, and a
// 4.5 kHz rolloff (per-channel H1-H20 within 2.4 dB rms, v34 3.2 dB).
comb(x) = x - 0.9 * de.fdelay(256, 0.001336 * ma.SR, x);
lowmode(x) = x : fi.peak_eq(2.8 * min(1, ra)^3, 257, 43);
residual = fi.peak_eq(-4, 392, 60);
ap1(a) = \(x).(x' - a * x : + ~ *(a));                 // first-order allpass
ap2(fc, r) = fi.tf2(r * r, c, 1, c, r * r) with { c = -2 * r * cos(2 * ma.PI * fc / ma.SR); };   // 2nd-order
// second-order allpasses around the low harmonics scramble their phases: crest 10.6 -> 8.9 dB with no
// spectral change (the target's dense waveform: crest 7.7 dB)
disperse = seq(i, 8, ap1(0.3 + 0.08 * i)) : ap2(180, 0.9) : ap2(330, 0.9) : ap2(520, 0.9) : ap2(900, 0.9);
eq = fi.lowshelf(1, 4.3, 100) : fi.peak_eq(6, 523, 130) : fi.peak_eq(1.3, 2500, 800);
body = comb : lowmode : fi.peak_eq(8.7, 718, 347) : residual : eq : disperse : fi.lowpass(2, 4500);

// loud horn, dense waveform: gentle soft saturation of the radiated sound (target crest 7.7 dB at -6.5 LUFS;
// v36 crest 10.6 dB at -13 LUFS sounded smaller and weaker). Before the body it did not lower the crest (the
// body re-shapes the waveform); hard settings after it filled the horn's notches, hence a gentle one.
// headroom = level where it bends; 7 with gain 0.115 measured -7.2 LUFS, crest 8.0 dB, peak -0.4 dBFS.
throat(x) = room * ma.tanh(x / room);
horn = (flow * 20 : body) + turb : throat : *(vol);

// space: spaced mic pair (measured on the target: R 4.65 ms later and 2.4 dB louder, zero-lag correlation
// ~0, coherence 0.85-1.0; v34's common direct path made the image mono, corr +0.8) + the library's
// zita_rev1 fed directly by the horn.
// Measured target release: -15.9 dB/s, fluctuating only slowly (~1 Hz). freeverb's combs beat at 6-7 Hz on
// this tonal source (an AM the target does not have); zita's denser FDN fluctuates at 1-2 Hz like the target.
// Fed directly (no long pre-delay), zita's input stops with the direct sound, so no cliff appears in the tail.
// The harbour returns little fundamental (target tail: H1 14-15 dB under H2; v35's reverb had H1 = H2 + 2 dB,
// and its steady H1 cancelled the direct one: per-channel H1 -8 dB vs H2, target 0): 4th-order highpass
// at 230 Hz on the reverb send.
rdel = hslider("predelay [unit:ms]", 20, 0, 150, 1);
t60m = hslider("rt60", 4.0, 1, 8, 0.1);
t60l = hslider("rt60low", 3.4, 1, 8, 0.1);
rev  = re.zita_rev1_stereo(rdel, 200, 2500, t60l, t60m, 48000);
mics = _ <: *(0.87), (de.delay(1024, int(0.00465 * ma.SR)) : *(1.15));
space = _ <: mics, (fi.highpass(4, 230) <: rev : *(wet), *(wet)) :> _, _;

// recording chain: the target is band-limited (brick-wall at ~10.8 kHz: -61 dB above 11 kHz)
recording = fi.lowpass(8, 11200), fi.lowpass(8, 11200);

process = horn <: (space : *(1 - dry), *(1 - dry)), (*(dry) <: _, _) :> recording;
