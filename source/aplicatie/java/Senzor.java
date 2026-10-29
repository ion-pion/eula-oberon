import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;

/** Senzor (vezi sistem/def/Senzor.Mod), varianta pentru aplicatii: aceeasi interfata ca in terminalul Eulei. */
public final class Senzor {
    private Senzor() {}
    static SensorManager sm;
    static SensorEventListener asc;
    static volatile int azimut = -1;
    static boolean pornit;
    static final float[] rot = new float[9], ori = new float[3], grav = new float[3], mag = new float[3];
    static boolean areG, areM;

    static boolean manager() {
        Context ctx = ro.jahbalon.oberonapp.Panza.ctx;
        if (ctx == null) return false;
        if (sm == null) sm = (SensorManager) ctx.getSystemService(Context.SENSOR_SERVICE);
        ro.jahbalon.oberonapp.Panza.pauza = new Runnable() { public void run() { pauza(); } };
        ro.jahbalon.oberonapp.Panza.reia = new Runnable() { public void run() { reia(); } };
        return sm != null;
    }

    public static boolean Porneste() {
        if (!manager()) return false;
        pornit = true;
        return inregistreaza();
    }

    // ---------------------------------------------------------------- gravitatia (nivela)
    static SensorEventListener ascG;
    static boolean pornitG;
    static volatile float gx, gy, gz = 1000;

    public static boolean PornesteGravitatia() {
        if (!manager()) return false;
        pornitG = true;
        return inregistreazaG();
    }

    static boolean inregistreazaG() {
        Sensor s = sm.getDefaultSensor(Sensor.TYPE_GRAVITY);
        final boolean brut = s == null;                 // fara senzor de gravitatie: accelerometrul, netezit
        if (brut) s = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
        if (s == null) return false;
        if (ascG != null) sm.unregisterListener(ascG);
        ascG = new SensorEventListener() {
            public void onSensorChanged(SensorEvent e) {
                float k = 1000f / SensorManager.GRAVITY_EARTH, a = brut ? 0.2f : 1f;
                gx += (e.values[0] * k - gx) * a;
                gy += (e.values[1] * k - gy) * a;
                gz += (e.values[2] * k - gz) * a;
            }
            public void onAccuracyChanged(Sensor x, int y) {}
        };
        sm.registerListener(ascG, s, SensorManager.SENSOR_DELAY_GAME);
        return true;
    }

    // ---------------------------------------------------------------- miscarea pe verticala (salt in sus / in jos)
    static SensorEventListener ascM;
    static boolean pornitM;
    static volatile float sus, mx, my, mz;
    static final float[] lent = new float[3];     // gravitatia, cand n-am senzor de acceleratie liniara

    public static boolean PornesteMiscarea() {
        if (!manager()) return false;
        if (!pornitG) PornesteGravitatia();
        pornitM = true;
        return inregistreazaM();
    }

    static boolean inregistreazaM() {
        Sensor s = sm.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION);
        final boolean brut = s == null;
        if (brut) s = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
        if (s == null) return false;
        if (ascM != null) sm.unregisterListener(ascM);
        ascM = new SensorEventListener() {
            public void onSensorChanged(SensorEvent e) {
                float k = 1000f / SensorManager.GRAVITY_EARTH;
                float lx = e.values[0] * k, ly = e.values[1] * k, lz = e.values[2] * k;
                if (brut) {                                   // scad gravitatia, urmarita lent
                    lent[0] += (lx - lent[0]) * 0.1f; lent[1] += (ly - lent[1]) * 0.1f; lent[2] += (lz - lent[2]) * 0.1f;
                    lx -= lent[0]; ly -= lent[1]; lz -= lent[2];
                }
                mx = lx; my = ly; mz = lz;
                float n = (float) Math.sqrt(gx * gx + gy * gy + gz * gz);
                if (n < 100) return;
                sus = (lx * gx + ly * gy + lz * gz) / n;      // proiectia pe verticala (gravitatia arata spre cer)
            }
            public void onAccuracyChanged(Sensor x, int y) {}
        };
        sm.registerListener(ascM, s, SensorManager.SENSOR_DELAY_GAME);
        return true;
    }

    public static int Sus() { return Math.round(sus); }
    public static int LX() { return Math.round(mx); }
    public static int LY() { return Math.round(my); }
    public static int LZ() { return Math.round(mz); }

    public static int GX() { return Math.round(gx); }
    public static int GY() { return Math.round(gy); }
    public static int GZ() { return Math.round(gz); }

    static boolean inregistreaza() {
        Sensor rv = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR);
        Sensor acc = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER), mg = sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD);
        if (rv == null && (acc == null || mg == null)) return false;
        if (asc != null) sm.unregisterListener(asc);
        asc = new SensorEventListener() {
            public void onSensorChanged(SensorEvent e) {
                int t = e.sensor.getType();
                if (t == Sensor.TYPE_ROTATION_VECTOR) SensorManager.getRotationMatrixFromVector(rot, e.values);
                else {
                    if (t == Sensor.TYPE_ACCELEROMETER) { System.arraycopy(e.values, 0, grav, 0, 3); areG = true; }
                    else { System.arraycopy(e.values, 0, mag, 0, 3); areM = true; }
                    if (!areG || !areM || !SensorManager.getRotationMatrix(rot, null, grav, mag)) return;
                }
                SensorManager.getOrientation(rot, ori);
                azimut = ((int) Math.round(Math.toDegrees(ori[0])) + 360) % 360;
            }
            public void onAccuracyChanged(Sensor s, int a) {}
        };
        if (rv != null) sm.registerListener(asc, rv, SensorManager.SENSOR_DELAY_GAME);
        else { sm.registerListener(asc, acc, SensorManager.SENSOR_DELAY_GAME); sm.registerListener(asc, mg, SensorManager.SENSOR_DELAY_GAME); }
        return true;
    }

    public static int Azimut() { return azimut; }
    public static void Opreste() { pornit = false; if (sm != null && asc != null) sm.unregisterListener(asc); asc = null; }
    static void pauza() {
        if (sm != null && asc != null) sm.unregisterListener(asc);
        asc = null;
        if (sm != null && ascG != null) sm.unregisterListener(ascG);
        ascG = null;
        if (sm != null && ascM != null) sm.unregisterListener(ascM);
        ascM = null;
    }
    static void reia() {
        if (pornit && sm != null && asc == null) inregistreaza();
        if (pornitG && sm != null && ascG == null) inregistreazaG();
        if (pornitM && sm != null && ascM == null) inregistreazaM();
    }
}
