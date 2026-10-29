package ro.jahbalon.eulaoberon;

import android.content.Context;

import java.io.*;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Inferno in Eula: emulatorul (Inferno64 al lui Dinsmoor, compilat pentru arm64, musl static) sta in APK ca
 * lib/arm64-v8a/libinfernoemu.so; radacina lui (dis, fonts, lib, icons) sta in assets/inferno-root.zip si se
 * despacheteaza o data pe versiune in files/inferno. Ce pui tu in usr/inferno ramane.
 */
public final class Inferno {
    private Inferno() {}

    static File radacina(Context c) { return new File(c.getFilesDir(), "inferno"); }

    static File emu(Context c) { return new File(c.getApplicationInfo().nativeLibraryDir, "libinfernoemu.so"); }

    static File semn(File rad) { return new File(rad, ".versiune"); }

    /** despacheteaza radacina daca lipseste sau e de la alta versiune; intoarce dosarul */
    static File pregateste(Context c) throws Exception {
        File rad = radacina(c);
        rad.mkdirs();
        String ver = "" + c.getPackageManager().getPackageInfo(c.getPackageName(), 0).lastUpdateTime;
        RandomAccessFile raf = new RandomAccessFile(new File(c.getFilesDir(), "inferno.lacat"), "rw");
        java.nio.channels.FileLock lacat = raf.getChannel().lock();
        try {
            File s = semn(rad);
            if (s.exists() && Rulator.citeste(s).trim().equals(ver)) return rad;
            s.delete();
            ZipInputStream z = new ZipInputStream(new BufferedInputStream(c.getAssets().open("inferno-root.zip"), 65536));
            byte[] b = new byte[65536];
            String baza = rad.getCanonicalPath() + File.separator;
            ZipEntry e;
            while ((e = z.getNextEntry()) != null) {
                File f = new File(rad, e.getName());
                if (!f.getCanonicalPath().startsWith(baza)) continue;     // nimic in afara radacinii
                if (e.isDirectory()) { f.mkdirs(); continue; }
                f.getParentFile().mkdirs();
                OutputStream o = new FileOutputStream(f);
                int k;
                while ((k = z.read(b)) > 0) o.write(b, 0, k);
                o.close();
            }
            z.close();
            for (String d : new String[] {"tmp", "usr/inferno/tmp", "n", "mnt"}) new File(rad, d).mkdirs();
            Writer w = new OutputStreamWriter(new FileOutputStream(s), "UTF-8");
            w.write(ver);
            w.close();
        } finally {
            lacat.release();
            raf.close();
        }
        return rad;
    }

    /** mediul pentru emulator: certificatele pentru https si un nume de utilizator */
    static void mediu(java.util.Map<String, String> env, File rad) {
        env.put("USER", "inferno");
        env.put("EMUCAFILE", new File(rad, "lib/android/cacert.pem").getAbsolutePath());
    }

    static void adaugaMediu(List<String> env, Context c) {
        File rad = radacina(c);
        env.add("EULA_INFERNO_EMU=" + emu(c).getAbsolutePath());
        env.add("EULA_INFERNO_ROOT=" + rad.getAbsolutePath());
    }
}
