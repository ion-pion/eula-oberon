package ro.jahbalon.eulaoberon;

import android.app.Service;
import android.content.Intent;
import android.content.res.AssetManager;
import android.os.Bundle;
import android.os.IBinder;
import android.os.Process;
import android.os.ResultReceiver;

import java.io.*;

import dalvik.system.DexClassLoader;

/**
 * Atelierul de rulat: un proces separat (":rulare"), ca un program cu bucla fara sfarsit sa poata fi oprit fara s-o
 * opreasca si pe Eula. Aici stau compilatorul oberonc, dx si programul tau; Eula doar ii trimite textul si asteapta.
 */
public class Rulare extends Service {
    static final int PID = 1, GATA = 2, PORNESC = 3;
    static final String TEXT = "text", RR = "rr", R = "r";

    private Rulator rulator;
    private ClassLoader dxLoader;

    static File dosar(android.content.Context c) { return new File(c.getFilesDir(), "rulare"); }
    static File iesire(android.content.Context c) { return new File(dosar(c), "iesire.txt"); }

    @Override public IBinder onBind(Intent i) { return null; }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) { stopSelf(); return START_NOT_STICKY; }
        final String text = intent.getStringExtra(TEXT);
        final ResultReceiver rr = intent.getParcelableExtra(RR);
        if (text == null || rr == null) return START_NOT_STICKY;
        Bundle p = new Bundle();
        p.putInt("pid", Process.myPid());
        rr.send(PID, p);
        new Thread(null, new Runnable() { public void run() {
            String r;
            try {
                if (rulator == null) rulator = pregateste();
                rulator.pornesc = new Runnable() { public void run() { rr.send(PORNESC, new Bundle()); } };
                r = rulator.ruleaza(text, iesire(Rulare.this));
                r += "\n(compilat în " + rulator.msCompilare + " ms, rulat în " + rulator.msRulare + " ms)";
            } catch (Throwable t) {
                r = "Atelierul a pățit ceva: " + Rulator.numeste(Rulator.cauza(t));
            }
            Bundle b = new Bundle();
            b.putString(R, r);
            rr.send(GATA, b);
        }}, "rulare", 128L << 20).start();
        return START_NOT_STICKY;
    }

    /** scot din APK compilatorul, runtime-ul, dx-ul si fisierele .smb; o singura data pe versiune.
     *  Il cheama si atelierul (procesul ":rulare") si terminalul, deci un lacat pe fisier ii tine la rand. */
    static File unelte(android.content.Context c) throws Exception {
        File d = dosar(c);
        d.mkdirs();
        File unelte = new File(d, "unelte");
        File bin = new File(unelte, "bin");
        long ver = c.getPackageManager().getPackageInfo(c.getPackageName(), 0).lastUpdateTime;
        File semn = new File(unelte, "versiune");
        java.io.RandomAccessFile raf = new java.io.RandomAccessFile(new File(d, "lacat"), "rw");
        java.nio.channels.FileLock lacat = raf.getChannel().lock();
        try {
            boolean lipsa = false;
            for (String f : new String[] {"compilator.jar", "rt.jar", "dx.jar", "sistem.jar", "aplicatie.jar", "pagina.dex"}) if (!new File(unelte, f).exists()) lipsa = true;
            if (lipsa || !semn.exists() || !citeste(semn).equals("" + ver)) {
                Rulator.sterge(unelte);
                bin.mkdirs();
                AssetManager a = c.getAssets();
                for (String f : new String[] {"compilator.jar", "rt.jar", "dx.jar", "sistem.jar", "aplicatie.jar", "pagina.dex"}) scoate(a, "rulare/" + f, new File(unelte, f));
                for (String f : a.list("rulare/bin")) scoate(a, "rulare/bin/" + f, new File(bin, f));
                Writer w = new OutputStreamWriter(new FileOutputStream(semn), "UTF-8");
                w.write("" + ver);
                w.close();
            }
        } finally {
            lacat.release();
            raf.close();
        }
        return unelte;
    }

    private Rulator pregateste() throws Exception {
        File d = dosar(this);
        final File unelte = unelte(this);
        File bin = new File(unelte, "bin");
        final File cod = getCodeCacheDir();
        Rulator.Mediu m = new Rulator.Mediu() {
            public ClassLoader incarca(File... surse) {
                StringBuilder cale = new StringBuilder();
                for (File f : surse) {
                    f.setReadOnly();                          // Android 14 nu incarca dex care se poate scrie
                    if (cale.length() > 0) cale.append(File.pathSeparatorChar);
                    cale.append(f.getAbsolutePath());
                }
                return new DexClassLoader(cale.toString(), cod.getAbsolutePath(), null, String.class.getClassLoader());
            }
            public File dex(File dosarClase, File jar) throws Exception {
                if (dxLoader == null) dxLoader = incarca(new File(unelte, "dx.jar"));
                Dx.dex(dxLoader, dosarClase, jar);
                return jar;
            }
        };
        File lucru = new File(d, "lucru");
        lucru.mkdirs();
        return new Rulator(m, new File(unelte, "compilator.jar"), new File(unelte, "rt.jar"), bin, lucru);
    }

    private static void scoate(AssetManager a, String din, File in) throws IOException {
        InputStream i = a.open(din);
        OutputStream o = new FileOutputStream(in);
        byte[] b = new byte[65536];
        int k;
        while ((k = i.read(b)) > 0) o.write(b, 0, k);
        o.close();
        i.close();
    }

    private static String citeste(File f) {
        return Rulator.citeste(f).trim();
    }
}
