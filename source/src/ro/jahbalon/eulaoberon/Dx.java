package ro.jahbalon.eulaoberon;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.OutputStream;
import java.lang.reflect.Constructor;

/**
 * dx chemat din interior, fara System.exit: acelasi dx ca in Termux (pachetul lui e redenumit "dx.dx…"; in AOSP e
 * "com.android.dx…", asa ca le incerc pe amandoua).
 */
public final class Dx {
    private Dx() {}

    public static void dex(ClassLoader dx, File dosar, File jar) throws Exception {
        Class<?> ctxC = null, mainC = null, argC = null;
        for (String p : new String[] {"dx.dx.command.dexer.", "com.android.dx.command.dexer."}) {
            try {
                ctxC = Class.forName(p + "DxContext", true, dx);
                mainC = Class.forName(p + "Main", true, dx);
                argC = Class.forName(p + "Main$Arguments", true, dx);
                break;
            } catch (ClassNotFoundException e) { ctxC = null; }
        }
        if (ctxC == null) throw new IOException("nu găsesc dx în dx.jar");
        ByteArrayOutputStream jurnal = new ByteArrayOutputStream();
        Object ctx = ctxC.getConstructor(OutputStream.class, OutputStream.class).newInstance(jurnal, jurnal);
        Object args = argC.getConstructor(ctxC).newInstance(ctx);
        if (jar.exists()) { jar.setWritable(true); jar.delete(); }
        argC.getMethod("parseFlags", String[].class).invoke(args, (Object) new String[] {"--output=" + jar.getAbsolutePath()});
        argC.getField("fileNames").set(args, new String[] {dosar.getAbsolutePath()});
        argC.getMethod("makeOptionsObjects").invoke(args);
        Constructor<?> k = mainC.getConstructor(ctxC);
        int r;
        try {
            r = (Integer) mainC.getMethod("runDx", argC).invoke(k.newInstance(ctx), args);
        } catch (java.lang.reflect.InvocationTargetException x) {
            Throwable c = x.getTargetException();
            throw new IOException("dx: " + c + "\n" + jurnal.toString("UTF-8"), c);
        }
        if (r != 0 || !jar.exists()) throw new IOException("dx a întors " + r + "\n" + jurnal.toString("UTF-8"));
    }
}
