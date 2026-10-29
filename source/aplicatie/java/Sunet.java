import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import ro.jahbalon.oberonapp.Panza;

/** Sunet (vezi sistem/def/Sunet.Mod): clopotei sintetizati aici (Nota, 8 voci) si esantioane calculate in Oberon
 *  (Reda, 8 voci), amestecate intr-un fir cu AudioTrack. Din v18: STEREO -- fiecare voce are locul ei intre
 *  stanga si dreapta (NotaPan, RedaPan; Nota si Reda sunt la mijloc). Se aude in casti; difuzorul telefonului
 *  e adesea unul singur. Din v19: REVERB peste tot sunetul (Reverb procent), un Freeverb stereo: 8 pieptene
 *  cu amortizare si 4 trece-tot pe fiecare canal, ca ecoul unei sali. */
public final class Sunet {
    private Sunet() {}
    static final int SR = 44100, VOCI = 8, VB = 16, ATAC = 220;   // 8 clopotei, 16 esantioane din Oberon deodata (v19)
    static final long t0 = System.currentTimeMillis();
    static final double[] faza = new double[VOCI], pas = new double[VOCI];
    static final float[] amp = new float[VOCI], cad = new float[VOCI];
    static final int[] ramas = new int[VOCI], varsta = new int[VOCI];
    static int urm, urmB;
    static final float[][] buf = new float[VB][];
    static final int[] bpos = new int[VB];
    static final float[] nL = new float[VOCI], nR = new float[VOCI];   // castigul stanga / dreapta al clopoteilor
    static final float[] bL = new float[VB], bR = new float[VB];   // si al esantioanelor din Oberon
    static final float MIJ = (float) Math.sqrt(0.5);

    /** pan -100 (stanga) .. 100 (dreapta) -> castiguri cu putere egala: la mijloc ambele 0,707 */
    // ---------------------------------------------------------------- reverbul (Freeverb, stereo)
    static final int[] CL = {1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617}, AL = {556, 441, 341, 225};
    static final int SPREAD = 23;
    static final float[][] combS = new float[8][], combD = new float[8][], apS = new float[4][], apD = new float[4][];
    static final int[] cpS = new int[8], cpD = new int[8], apPS = new int[4], apPD = new int[4];
    static final float[] filS = new float[8], filD = new float[8];
    static volatile float umed = 0f;                  // cat reverb: 0 .. 1
    static final float FB = 0.84f, DAMP = 0.22f;      // sala: cat de lunga, cat de "moale"
    static {
        for (int i = 0; i < 8; i++) { combS[i] = new float[CL[i]]; combD[i] = new float[CL[i] + SPREAD]; }
        for (int i = 0; i < 4; i++) { apS[i] = new float[AL[i]]; apD[i] = new float[AL[i] + SPREAD]; }
    }

    /** cat de mult reverb, 0 (uscat) .. 100 (sala mare) */
    public static void Reverb(int procent) { umed = Math.max(0, Math.min(procent, 100)) / 100f; }

    static float comb(float[] b, int[] poz, float[] fil, int i, float x) {
        int p = poz[i]; float y = b[p];
        fil[i] = y * (1 - DAMP) + fil[i] * DAMP;
        b[p] = x + fil[i] * FB;
        poz[i] = (p + 1 == b.length) ? 0 : p + 1;
        return y;
    }

    static float trece(float[] b, int[] poz, int i, float x) {
        int p = poz[i]; float y = b[p];
        b[p] = x + y * 0.5f;
        poz[i] = (p + 1 == b.length) ? 0 : p + 1;
        return y - x;
    }

    static float stanga(int pan) { double p = (Math.max(-100, Math.min(100, pan)) + 100) / 200.0; return (float) Math.cos(p * Math.PI / 2); }
    static float dreapta(int pan) { double p = (Math.max(-100, Math.min(100, pan)) + 100) / 200.0; return (float) Math.sin(p * Math.PI / 2); }
    static Thread fir;

    // ---------------------------------------------------------------- vocea continua (ton Shepard, alunecare)
    static volatile float vHz, vVol;
    static volatile int timbru;
    static double pc = -1, ampV, lp;
    static final double[] fazaV = new double[6];
    static final double[] greutate = new double[6];

    public static void Voce(float hz, int volum) {
        porneste();
        vHz = hz;
        vVol = Math.max(0, Math.min(volum, 100)) / 100f;
    }

    public static void Timbru(int t) { timbru = t; }

    static double undaV(double p) {
        switch (timbru) {
            case 1: return 2 * p - 1;
            case 2: return p < 0.5 ? 0.8 : -0.8;
            case 3: return 4 * Math.abs(p - 0.5) - 1;
            default: return Math.sin(2 * Math.PI * p);
        }
    }

    /** o bucata de voce, adunata peste esantioanele s[] (inainte de compresie) */
    static void voce(float[] s, int n) {
        float hz = vHz;
        if (hz > 0) {
            double t = Math.log(hz / 65.0) / Math.log(2);
            t -= Math.floor(t);
            if (pc < 0) pc = t;
            double d = t - pc;
            if (d > 0.5) d -= 1; else if (d < -0.5) d += 1;
            pc += d * (1 - Math.exp(-n / (0.05 * SR)));        // alunecare ~50 ms, pe drumul cel mai scurt
            pc -= Math.floor(pc);
        }
        if (pc < 0) return;
        double baza = 65.0 * Math.pow(2, pc), suma = 0;
        for (int k = 0; k < 6; k++) {
            double o = Math.log(baza * (1 << k) / 262.0) / Math.log(2);
            greutate[k] = Math.exp(-o * o / (2 * 0.9 * 0.9));
            suma += greutate[k];
        }
        double kA = 1 - Math.exp(-1 / (0.03 * SR)), tinta = vVol;
        double kLp = timbru == 0 ? 1 : 0.22;
        for (int i = 0; i < n; i++) {
            ampV += (tinta - ampV) * kA;
            if (ampV < 1e-5) continue;
            double x = 0;
            for (int k = 0; k < 6; k++) {
                fazaV[k] += baza * (1 << k) / SR;
                fazaV[k] -= Math.floor(fazaV[k]);
                x += greutate[k] * undaV(fazaV[k]);
            }
            x /= suma;
            lp += (x - lp) * kLp;
            s[i] += (float) (lp * ampV * 1.0);
        }
    }

    public static int Ms() { return (int) (System.currentTimeMillis() - t0); }

    public static void Nota(int hz, int ms, int volum) { NotaPan(hz, ms, volum, 0); }

    public static synchronized void NotaPan(int hz, int ms, int volum, int pan) {
        if (hz <= 0 || ms <= 0 || volum <= 0) return;
        porneste();
        int v = -1;
        for (int i = 0; i < VOCI; i++) if (ramas[i] <= 0) { v = i; break; }
        if (v < 0) { v = urm; urm = (urm + 1) % VOCI; }
        int n = (int) ((long) ms * SR / 1000);
        faza[v] = 0;
        pas[v] = 2 * Math.PI * hz / SR;
        amp[v] = Math.min(volum, 100) / 100f;
        cad[v] = (float) Math.exp(Math.log(0.004) / n);     // la sfarsit a ramas 0.4%
        ramas[v] = n;
        varsta[v] = 0;
        nL[v] = stanga(pan); nR[v] = dreapta(pan);
    }

    /** esantioane facute in Oberon (scara 16 biti); le copiez, ca Oberon sa-si poata refolosi bufferul */
    public static void Reda(float[] b, int n, int volum) { RedaPan(b, n, volum, 0); }

    public static void RedaPan(float[] b, int n, int volum, int pan) {
        if (b == null || n <= 0 || volum <= 0) return;
        if (n > b.length) n = b.length;
        float g = Math.min(volum, 100) / 100f / 32768f;
        float[] c = new float[n];
        for (int k = 0; k < n; k++) c[k] = b[k] * g;
        porneste();
        synchronized (Sunet.class) {
            int v = -1;
            for (int i = 0; i < VB; i++) if (buf[i] == null) { v = i; break; }
            if (v < 0) { v = urmB; urmB = (urmB + 1) % VB; }
            buf[v] = c;
            bpos[v] = 0;
            bL[v] = stanga(pan); bR[v] = dreapta(pan);
        }
    }

    public static synchronized void Liniste() { for (int i = 0; i < VOCI; i++) ramas[i] = 0; for (int i = 0; i < VB; i++) buf[i] = null; }

    static float[] vbuf = new float[256];

    /** b: stereo intercalat (stanga, dreapta, stanga, ...) */
    static synchronized void umple(short[] b) {
        int n = b.length / 2;
        if (vbuf.length != n) vbuf = new float[n];
        java.util.Arrays.fill(vbuf, 0);
        voce(vbuf, n);
        for (int k = 0; k < n; k++) {
            float sl = 0, sr = 0;
            for (int v = 0; v < VOCI; v++) {
                if (ramas[v] <= 0) continue;
                double f = faza[v];
                float x = (float) (Math.sin(f) + 0.28 * Math.sin(2 * f) + 0.07 * Math.sin(3 * f));
                float a = amp[v];
                if (varsta[v] < ATAC) a *= varsta[v] / (float) ATAC;
                sl += x * a * nL[v]; sr += x * a * nR[v];
                faza[v] = f + pas[v];
                if (faza[v] > 2 * Math.PI * 64) faza[v] -= 2 * Math.PI * 64;
                amp[v] *= cad[v];
                varsta[v]++;
                ramas[v]--;
            }
            sl *= 0.32f / MIJ; sr *= 0.32f / MIJ;   // la mijloc suna cat inainte, in mono
            sl += vbuf[k]; sr += vbuf[k];
            for (int v = 0; v < VB; v++) {
                float[] c = buf[v];
                if (c == null) continue;
                float x = c[bpos[v]] * 1.4f / MIJ;
                sl += x * bL[v]; sr += x * bR[v];
                if (++bpos[v] >= c.length) buf[v] = null;
            }
            float u = umed;
            if (u > 0.001f) {                                  // reverbul: intra suma celor doua canale
                float in = (sl + sr) * 0.015f, ws = 0, wd = 0;
                for (int i = 0; i < 8; i++) { ws += comb(combS[i], cpS, filS, i, in); wd += comb(combD[i], cpD, filD, i, in); }
                for (int i = 0; i < 4; i++) { ws = trece(apS[i], apPS, i, ws); wd = trece(apD[i], apPD, i, wd); }
                sl += ws * 3f * u; sr += wd * 3f * u;
            }
            sl = sl / (1 + Math.abs(sl));                     // nu se sparge cand suna multe deodata
            sr = sr / (1 + Math.abs(sr));
            b[2 * k] = (short) (sl * 32000);
            b[2 * k + 1] = (short) (sr * 32000);
        }
    }

    static synchronized void porneste() {
        if (fir != null) return;
        fir = new Thread(new Runnable() { public void run() { canta(); } }, "sunet");
        fir.setDaemon(true);
        fir.setPriority(Thread.MAX_PRIORITY);
        fir.start();
    }

    static void canta() {
        int min = AudioTrack.getMinBufferSize(SR, AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_16BIT);
        if (min <= 0) min = 8192;
        AudioTrack t = new AudioTrack(AudioManager.STREAM_MUSIC, SR, AudioFormat.CHANNEL_OUT_STEREO,
            AudioFormat.ENCODING_PCM_16BIT, min, AudioTrack.MODE_STREAM);
        short[] b = new short[512];
        boolean merge = false;
        try {
            while (true) {
                if (!Panza.activ) {                            // aplicatia e in spate: tac
                    if (merge) { t.pause(); t.flush(); merge = false; }
                    Liniste(); vVol = 0; ampV = 0;
                    Thread.sleep(100);
                    continue;
                }
                if (!merge) { t.play(); merge = true; }
                umple(b);
                t.write(b, 0, b.length);
            }
        } catch (Throwable e) {
            try { t.release(); } catch (Throwable x) {}
        }
    }
}
