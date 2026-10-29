import java.io.*;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import ro.jahbalon.eulaoberon.Dx;
import ro.jahbalon.eulaoberon.Rulator;

/**
 * Nucleu (vezi def/Nucleu.Mod): apelurile de sistem ale Eulei. Biblioteca de module e un dosar: pentru fiecare
 * modul, Nume.smb (interfata, pentru compilator) si Nume.jar (codul, pentru Android). Un modul din biblioteca e
 * incarcat o data si isi pastreaza starea intre comenzi, ca in Oberon; dupa o compilare, biblioteca se reincarca.
 */
public final class Nucleu {
    private Nucleu() {}

    /** modulele care vin cu sistemul (stau in sistem.jar); numele lor nu pot fi refolosite */
    static final String[] SISTEM = {"Out", "In", "Files", "Math", "Strings", "Os",
        "Param", "Dosar", "Retea", "Nucleu", "Senzor", "Ecran", "Sunet", "Conversatie", "Pachet", "Fisiere", "Net", "Module", "Aplicatie", "Shell", "Sir", "Axml", "Semnatura", "EulaSistem", "OberonRuntime"};
    static final String[] SISTEM_VIZIBILE = {"Out", "In", "Files", "Math", "Strings", "Param", "Dosar", "Retea", "Nucleu", "Senzor", "Pachet", "Fisiere", "Net", "Module", "Aplicatie", "Shell"};

    static File unelte, bin, mod, tmp;
    static boolean dalvik;
    static ClassLoader dxL, biblio;
    static String eroare = "";
    static List<String> module = new ArrayList<String>();
    static List<Boolean> dinBib = new ArrayList<Boolean>();
    static List<String> comenzi = new ArrayList<String>();

    static void init(File unelteDir, File sistemDir) {
        unelte = unelteDir;
        bin = new File(unelte, "bin");
        mod = new File(sistemDir, "biblioteca");
        tmp = new File(sistemDir, "tmp");
        mod.mkdirs();
        tmp.mkdirs();
        try { Class.forName("dalvik.system.DexClassLoader"); dalvik = true; } catch (Throwable t) { dalvik = false; }
    }

    // ---------------------------------------------------------------- incarcatoare

    static ClassLoader incarca(ClassLoader parinte, File... surse) throws Exception {
        if (dalvik) {
            StringBuilder c = new StringBuilder();
            for (File f : surse) {
                f.setReadOnly();
                if (c.length() > 0) c.append(':');
                c.append(f.getAbsolutePath());
            }
            Class<?> k = Class.forName("dalvik.system.DexClassLoader");
            return (ClassLoader) k.getConstructor(String.class, String.class, String.class, ClassLoader.class)
                .newInstance(c.toString(), null, null, parinte);
        }
        URL[] u = new URL[surse.length];
        for (int i = 0; i < surse.length; i++) u[i] = surse[i].toURI().toURL();
        return new URLClassLoader(u, parinte);
    }

    static File[] codBiblioteca() {
        File[] l = mod.listFiles(new FileFilter() {
            public boolean accept(File f) { return dalvik ? f.getName().endsWith(".jar") : f.isDirectory(); }
        });
        if (l == null) l = new File[0];
        Arrays.sort(l);
        return l;
    }

    static ClassLoader biblioteca() throws Exception {
        if (biblio == null) biblio = incarca(Nucleu.class.getClassLoader(), codBiblioteca());
        return biblio;
    }

    // ---------------------------------------------------------------- compilare

    static boolean eSistem(String n) {
        for (String s : SISTEM) if (s.equals(n)) return true;
        return false;
    }

    static final String C0 = "\u0002", C1 = "\u0003";

    /** textul cu blocuri de cod (\u0002…\u0003) pentru terminal: codul cu "  | " in fata */
    static String terminal(String s) {
        StringBuilder b = new StringBuilder();
        int i = 0;
        while (i < s.length()) {
            int a = s.indexOf(C0, i);
            if (a < 0) { b.append(s.substring(i)); break; }
            b.append(s, i, a);
            int z = s.indexOf(C1, a + 1);
            if (z < 0) z = s.length();
            if (b.length() > 0 && b.charAt(b.length() - 1) != '\n') b.append('\n');
            for (String l : s.substring(a + 1, z).split("\n", -1)) b.append("  | ").append(l).append('\n');
            if (b.length() > 0) b.setLength(b.length() - 1);
            i = z + 1;
        }
        return b.toString();
    }

    /** compileaza modulele din fisier in biblioteca; intoarce numele lor sau null (si scrie de ce) */
    static List<String> compileaza(final File f) {
        eroare = "";
        if (!f.isFile()) { eroare = "nu găsesc " + f.getPath(); System.out.println(eroare); return null; }
        final String text = Rulator.citeste(f);
        final List<Rulator.Modul> mods = Rulator.module(text);
        if (mods.isEmpty()) { eroare = "în " + f.getName() + " nu e niciun MODULE … END Nume."; System.out.println(eroare); return null; }
        for (Rulator.Modul m : mods)
            if (eSistem(m.nume)) { eroare = m.nume + " e numele unui modul al sistemului; alege alt nume"; System.out.println(eroare); return null; }
        final File src = new File(tmp, "src"), out = new File(tmp, "out");
        Rulator.sterge(src); Rulator.sterge(out);
        src.mkdirs(); out.mkdirs();
        // interfetele modulelor tale, ca sa le poata importa
        File[] smb = mod.listFiles();
        if (smb != null) for (File s : smb) if (s.getName().endsWith(".smb")) copiaza(s, new File(out, s.getName()));
        final String[] rau = {null};
        final int[] erori = {0};
        final ByteArrayOutputStream mesaje = new ByteArrayOutputStream();
        Thread t = new Thread(null, new Runnable() { public void run() {
            PrintStream vechi = System.out;
            try {
                System.setOut(new PrintStream(mesaje, true, "UTF-8"));
                ClassLoader cl = incarca(String.class.getClassLoader(), new File(unelte, dalvik ? "compilator.jar" : "compilator"));
                Class<?> ojb = Class.forName("OJB", true, cl);
                char[] h = (char[]) ojb.getField("homeFolder").get(null);
                String b = bin.getAbsolutePath();
                Arrays.fill(h, '\0');
                b.getChars(0, Math.min(b.length(), h.length - 1), h, 0);
                Method compile = Class.forName("OJP", true, cl).getMethod("Compile", char[].class, boolean.class, char[].class);
                java.lang.reflect.Field ec = Class.forName("OJS", true, cl).getField("errcnt");
                for (Rulator.Modul m : mods) {
                    File s = new File(src, m.nume + ".Mod");
                    Writer w = new OutputStreamWriter(new FileOutputStream(s), "UTF-8");
                    w.write(m.text);
                    w.close();
                    compile.invoke(null, z(s.getAbsolutePath()), true, z(out.getAbsolutePath()));
                    erori[0] = ec.getInt(null);
                    if (erori[0] > 0) break;
                }
            } catch (Throwable x) {
                rau[0] = "compilatorul a pățit ceva: " + Rulator.numeste(Rulator.cauza(x));
            } finally {
                System.out.flush();
                System.setOut(vechi);
            }
        }}, "compilator", 64L << 20);
        t.start();
        try { t.join(); } catch (InterruptedException e) { return null; }
        String msg;
        try { msg = mesaje.toString("UTF-8"); } catch (UnsupportedEncodingException e) { msg = mesaje.toString(); }
        if (rau[0] != null) { eroare = rau[0]; System.out.println(rau[0]); if (!msg.trim().isEmpty()) System.out.println(msg.trim()); return null; }
        if (erori[0] > 0) {
            eroare = "erori de compilare";
            String r = Rulator.erori(msg, text).replaceFirst("^oberonc n-a primit codul\\. ", "");
            System.out.println(terminal(r));
            return null;
        }
        // fiecare modul: interfata .smb si codul lui (clasele Nume, Nume_*, plus cele comune) in biblioteca
        List<String> nume = new ArrayList<String>();
        File[] cls = out.listFiles();
        for (Rulator.Modul m : mods) {
            File c = new File(out, m.nume + ".class");
            if (!c.exists()) { eroare = "lipsește " + c.getName(); System.out.println(eroare); return null; }
            File d = new File(tmp, "cod-" + m.nume);
            Rulator.sterge(d);
            d.mkdirs();
            for (File x : cls) {
                String n = x.getName();
                if (!n.endsWith(".class")) continue;
                String b = n.substring(0, n.length() - 6);
                boolean almeu = b.equals(m.nume) || b.startsWith(m.nume + "_");
                boolean alAltuia = false;
                for (Rulator.Modul o : mods) if (o != m && (b.equals(o.nume) || b.startsWith(o.nume + "_"))) alAltuia = true;
                if (almeu || (!alAltuia && Character.isLowerCase(b.charAt(0)))) copiaza(x, new File(d, n));
            }
            try {
                if (dalvik) {
                    File cl = clase(m.nume);                 // si clasele, pentru aplicatiile facute cu Pachet
                    Rulator.sterge(cl);
                    cl.mkdirs();
                    for (File x : d.listFiles()) copiaza(x, new File(cl, x.getName()));
                    File jar = new File(mod, m.nume + ".jar");
                    if (jar.exists()) { jar.setWritable(true); jar.delete(); }
                    Dx.dex(dx(), d, jar);
                } else {
                    File dd = new File(mod, m.nume);
                    Rulator.sterge(dd);
                    if (!d.renameTo(dd)) throw new IOException("nu pot muta " + d);
                }
            } catch (Throwable x) {
                eroare = "dx a pățit ceva: " + Rulator.numeste(Rulator.cauza(x));
                System.out.println(eroare);
                return null;
            }
            copiaza(new File(out, m.nume + ".smb"), new File(mod, m.nume + ".smb"));
            Rulator.sterge(d);
            nume.add(m.nume);
        }
        biblio = null;                     // biblioteca s-a schimbat: o reincarc la urmatoarea comanda
        return nume;
    }

    static ClassLoader dx() throws Exception {
        if (dxL == null) dxL = incarca(String.class.getClassLoader(), new File(unelte, dalvik ? "dx.jar" : "dx"));
        return dxL;
    }

    /** dosarul cu clasele (.class) unui modul din biblioteca */
    static File clase(String m) { return dalvik ? new File(new File(mod, "clase"), m) : new File(mod, m); }

    static void copiaza(File a, File b) {
        try {
            InputStream i = new FileInputStream(a);
            OutputStream o = new FileOutputStream(b);
            byte[] buf = new byte[65536];
            int k;
            while ((k = i.read(buf)) > 0) o.write(buf, 0, k);
            o.close(); i.close();
        } catch (IOException e) { /* raman fara */ }
    }

    static char[] z(String s) {
        char[] c = new char[s.length() + 1];
        s.getChars(0, s.length(), c, 0);
        return c;
    }

    public static boolean Compileaza(char[] fis) {
        List<String> n = compileaza(Dosar.f(fis));
        if (n == null) return false;
        for (String m : n) {
            int k = comenzi(m);
            StringBuilder b = new StringBuilder("✓ " + m + " e în bibliotecă");
            if (k > 0) {
                b.append("; comenzi: ");
                for (int i = 0; i < k; i++) b.append(i > 0 ? ", " : "").append(m).append('.').append(comenzi.get(i));
            }
            System.out.println(b);
        }
        return true;
    }

    /** compileaza si porneste ultimul modul cu un incarcator proaspat (corpul lui ruleaza de la zero) */
    public static boolean Ruleaza(char[] fis) {
        List<String> n = compileaza(Dosar.f(fis));
        if (n == null) return false;
        String m = n.get(n.size() - 1);
        try {
            ClassLoader l = incarca(Nucleu.class.getClassLoader(), codBiblioteca());
            Class<?> c = Class.forName(m, false, l);
            ruleazaFir(c.getMethod("main", String[].class), (Object) new String[0]);
            return true;
        } catch (Throwable x) {
            Throwable c = Rulator.cauza(x);
            eroare = Rulator.capcana(c);
            System.out.println();
            System.out.println(eroare);
            return false;
        }
    }

    /** semnele pentru Ctrl+C: "ocupat" cat ruleaza o comanda, "opreste" cand ai apasat Ctrl+C (le vede ecranul) */
    static File semn(String n) {
        String s = System.getenv("EULA_SISTEM");
        return new File(s == null ? "." : s, n);
    }

    /** codul tau ruleaza pe un fir cu stiva mare (recursia Oberon); exceptiile se intorc la cel care a chemat */
    static void ruleazaFir(final Method m, final Object... a) throws Throwable {
        File oc = semn("ocupat");
        semn("opreste").delete();
        try { new FileOutputStream(oc).close(); } catch (IOException e) { /* fara semn */ }
        try { ruleazaFir0(m, a); } finally { oc.delete(); semn("opreste").delete(); }
    }

    /** Ctrl+C: programele care il asculta se pot opri singure, frumos (altfel ecranul reporneste sistemul) */
    public static boolean Oprit() { return semn("opreste").exists(); }

    static void ruleazaFir0(final Method m, final Object... a) throws Throwable {
        final Throwable[] r = {null};
        Thread t = new Thread(null, new Runnable() { public void run() {
            try { m.invoke(null, a); } catch (Throwable x) { r[0] = x; }
        }}, "modul", 64L << 20);
        t.start();
        t.join();
        System.out.flush();
        if (r[0] != null) throw r[0];
    }

    public static int Cheama(char[] modul, char[] comanda) {
        eroare = "";
        String m = Sir.s(modul), c = Sir.s(comanda);
        Class<?> k;
        try {
            k = Class.forName(m, false, biblioteca());
        } catch (ClassNotFoundException e) {
            eroare = "nu am modulul " + m;
            return 1;
        } catch (Throwable e) {
            eroare = "nu pot încărca biblioteca: " + Rulator.numeste(Rulator.cauza(e));
            return 1;
        }
        if (k.getName().indexOf('.') >= 0 || !esteModul(k)) { eroare = "nu am modulul " + m; return 1; }
        Method p;
        try {
            p = k.getMethod(c);
        } catch (NoSuchMethodException e) {
            eroare = m + " n-are comanda " + c;
            return 2;
        }
        if (!Modifier.isStatic(p.getModifiers()) || p.getReturnType() != void.class) { eroare = m + "." + c + " nu e o comandă"; return 2; }
        try {
            ruleazaFir(p);
            return 0;
        } catch (Throwable x) {
            eroare = Rulator.capcana(Rulator.cauza(x));
            System.out.println();
            System.out.println(eroare);
            return 3;
        }
    }

    /** un modul Oberon compilat de oberonc: clasa finala, fara pachet (nu orice clasa Java) */
    static boolean esteModul(Class<?> k) {
        if (k.getPackage() != null && !k.getPackage().getName().isEmpty()) return false;
        if (eSistem(k.getName())) {
            for (String s : SISTEM_VIZIBILE) if (s.equals(k.getName())) return true;
            return false;
        }
        return new File(mod, k.getName() + ".smb").exists();
    }

    // ---------------------------------------------------------------- liste

    public static int Module() {
        module.clear();
        dinBib.clear();
        for (String s : SISTEM_VIZIBILE) { module.add(s); dinBib.add(false); }
        String[] l = mod.list();
        if (l != null) {
            Arrays.sort(l, String.CASE_INSENSITIVE_ORDER);
            for (String n : l) if (n.endsWith(".smb")) { module.add(n.substring(0, n.length() - 4)); dinBib.add(true); }
        }
        return module.size();
    }
    public static void Modul(int i, char[] s) { Sir.pune(i >= 0 && i < module.size() ? module.get(i) : "", s); }
    public static boolean DinBiblioteca(int i) { return i >= 0 && i < dinBib.size() && dinBib.get(i); }

    static int comenzi(String m) {
        comenzi.clear();
        try {
            Class<?> k = Class.forName(m, false, biblioteca());
            if (!esteModul(k)) return -1;
            for (Method p : k.getDeclaredMethods()) {
                int md = p.getModifiers();
                if (Modifier.isPublic(md) && Modifier.isStatic(md) && p.getParameterTypes().length == 0
                    && p.getReturnType() == void.class && !p.getName().startsWith("<") && !p.isSynthetic())
                    comenzi.add(p.getName());
            }
            java.util.Collections.sort(comenzi);
            return comenzi.size();
        } catch (Throwable e) {
            return -1;
        }
    }
    public static int Comenzi(char[] modul) { return comenzi(Sir.s(modul)); }
    public static void Comanda(int i, char[] s) { Sir.pune(i >= 0 && i < comenzi.size() ? comenzi.get(i) : "", s); }

    public static boolean Uita(char[] modul) {
        String m = Sir.s(modul);
        File s = new File(mod, m + ".smb");
        if (!s.exists() || eSistem(m)) return false;
        s.delete();
        File j = new File(mod, m + ".jar");
        j.setWritable(true);
        j.delete();
        Rulator.sterge(new File(mod, m));
        Rulator.sterge(clase(m));
        biblio = null;
        return true;
    }

    public static void Eroare(char[] s) { Sir.pune(eroare, s); }

    // ---------------------------------------------------------------- legaturi cu ecranul si cu Android-ul

    public static void Terminal(char[] cerere) {
        System.out.print("\033]7777;" + Sir.s(cerere) + "\007");
        System.out.flush();
    }

    public static int Sh(char[] comanda) {
        String c = Sir.s(comanda);
        String sh = new File("/system/bin/sh").exists() ? "/system/bin/sh" : "/bin/sh";
        try {
            ProcessBuilder pb = c.trim().isEmpty() ? new ProcessBuilder(sh, "-i") : new ProcessBuilder(sh, "-c", c);
            pb.directory(Dosar.curent);
            pb.inheritIO();
            return pb.start().waitFor();
        } catch (Exception e) {
            eroare = e.toString();
            System.out.println("sh n-a pornit: " + e);
            return -1;
        }
    }

    /** Inferno in terminal (fara ecran grafic): emulatorul cu sh-ul lui; "" = interactiv, altfel o comanda */
    public static int Inferno(char[] comanda) {
        String c = Sir.s(comanda).trim();
        String emu = System.getenv("EULA_INFERNO_EMU"), rad = System.getenv("EULA_INFERNO_ROOT");
        if (emu == null || rad == null || !new File(emu).exists()) {
            System.out.println("Inferno lipsește din aplicație (merge doar pe telefoane arm64).");
            return -1;
        }
        File semn = new File(rad, ".versiune");
        if (!semn.exists()) {
            System.out.print("pregătesc Inferno (prima dată durează puțin)…");
            System.out.flush();
            for (int i = 0; i < 1200 && !semn.exists(); i++) Asteapta(100);
            System.out.println();
            if (!semn.exists()) { System.out.println("radăcina lui Inferno nu s-a despachetat; închide și deschide terminalul"); return -1; }
        }
        try {
            List<String> a = new ArrayList<String>();
            a.add(emu);
            a.add("-r" + rad);
            a.add("/dis/sh.dis");
            if (!c.isEmpty()) { a.add("-c"); a.add(c); }
            ProcessBuilder pb = new ProcessBuilder(a);
            pb.directory(new File(rad));
            pb.environment().put("USER", "inferno");
            pb.environment().put("EMUCAFILE", new File(rad, "lib/android/cacert.pem").getAbsolutePath());
            pb.inheritIO();
            if (c.isEmpty()) System.out.println("Inferno (sh). Ieși cu: exit");
            return pb.start().waitFor();
        } catch (Exception e) {
            eroare = e.toString();
            System.out.println("Inferno n-a pornit: " + e);
            return -1;
        }
    }

    static final long START = System.currentTimeMillis();
    public static int Timp() { return (int) (System.currentTimeMillis() - START); }
    public static void Asteapta(int ms) { try { Thread.sleep(Math.max(0, ms)); } catch (InterruptedException e) { /* gata */ } }

    public static void Opreste(int cod) {
        System.out.flush();
        System.exit(cod);
    }
}
