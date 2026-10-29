package ro.jahbalon.eulaoberon;

import java.io.*;
import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Compilatorul din Eula: ia modulele lipite, le compileaza cu oberonc (Luca Boasso, MIT; el insusi scris in Oberon),
 * le trece prin dx si le ruleaza, prinzand tot ce scrie Out. Nu stie nimic de Android: incarcatul claselor si dx-ul
 * vin din Mediu, ca sa poata fi incercat si pe un calculator.
 */
public final class Rulator {
    interface Mediu {
        /** un incarcator nou, curat, peste jar-urile/dosarele date; parintele e doar Java de baza */
        ClassLoader incarca(File... surse) throws Exception;
        /** .class din dosar -> jar cu dex (pe calculator: nimic, intoarce chiar dosarul) */
        File dex(File dosarClase, File jar) throws Exception;
    }

    static final char C0 = '\u0002', C1 = '\u0003';
    static final int MAX_IESIRE = 60000;

    final Mediu m;
    final File compilator, rt, bin, lucru;
    long msCompilare, msRulare;
    /** chemat chiar inainte sa porneasca programul (dupa compilare si dx) */
    Runnable pornesc;

    Rulator(Mediu m, File compilator, File rt, File bin, File lucru) {
        this.m = m; this.compilator = compilator; this.rt = rt; this.bin = bin; this.lucru = lucru;
    }

    /** Oberon nu are "catch", deci asta opreste orice program care scrie la nesfarsit */
    public static final class PreaMult extends Error {
        PreaMult() { super("prea mult text"); }
    }

    /** ce scrie programul: in fisier (ca sa ramana ceva si daca il opresc) si numarat */
    static final class Iesire extends OutputStream {
        final OutputStream o; int n;
        Iesire(OutputStream o) { this.o = o; }
        @Override public void write(int b) throws IOException {
            if (++n > MAX_IESIRE) throw new PreaMult();
            o.write(b);
            if (b == '\n') o.flush();
        }
        @Override public void write(byte[] b, int off, int len) throws IOException {
            for (int i = 0; i < len; i++) write(b[off + i]);
        }
        @Override public void flush() throws IOException { o.flush(); }
    }

    public static final class Modul { public String nume, text; public int linia; }

    /** taie textul lipit in module: MODULE X … END X. (in ordinea in care apar) */
    public static List<Modul> module(String t) {
        List<Modul> l = new ArrayList<Modul>();
        Matcher a = Pattern.compile("(?m)(?<![A-Za-z0-9_])MODULE\\s*\\*?\\s*([A-Za-z][A-Za-z0-9_]*)").matcher(t);
        int de = 0;
        while (a.find(de)) {
            String nume = a.group(1);
            Matcher z = Pattern.compile("(?<![A-Za-z0-9_])END\\s+" + nume + "\\s*\\.").matcher(t);
            if (!z.find(a.end())) break;
            Modul md = new Modul();
            md.nume = nume;
            md.linia = linia(t, a.start());
            // pastrez randurile de deasupra goale, ca numerele de rand din erori sa fie ca in casuta
            StringBuilder sb = new StringBuilder();
            for (int i = 1; i < md.linia; i++) sb.append('\n');
            sb.append(t, a.start(), z.end()).append('\n');
            md.text = sb.toString();
            l.add(md);
            de = z.end();
        }
        return l;
    }

    public static int linia(String t, int poz) {
        int n = 1;
        for (int i = 0; i < poz && i < t.length(); i++) if (t.charAt(i) == '\n') n++;
        return n;
    }

    public static void sterge(File f) {
        File[] k = f.listFiles();
        if (k != null) for (File x : k) sterge(x);
        f.delete();
    }

    static char[] z(String s) {
        char[] c = new char[s.length() + 1];
        s.getChars(0, s.length(), c, 0);
        return c;
    }

    /** Raspunsul pentru ecran; ce e intre \u0002 si \u0003 iese ca bloc de cod. iesireLive: unde scrie programul. */
    String ruleaza(String text, File iesireLive) {
        List<Modul> mods = module(text);
        if (mods.isEmpty())
            return "Ca să rulez, am nevoie de un modul întreg: de la MODULE Nume; până la END Nume. (cu punct). "
                + "Bucățile de cod le pot doar verifica, cu Verifică.";
        File src = new File(lucru, "src"), out = new File(lucru, "out");
        sterge(src); sterge(out);
        src.mkdirs(); out.mkdirs();

        // 1. compilez, cu un oberonc proaspat (are stare globala, ca orice modul Oberon)
        long t0 = System.currentTimeMillis();
        ByteArrayOutputStream mesaje = new ByteArrayOutputStream();
        PrintStream vechi = System.out;
        int erori = 0;
        String rau = null;
        try {
            System.setOut(new PrintStream(mesaje, true, "UTF-8"));
            ClassLoader cl = m.incarca(compilator);
            Class<?> ojb = Class.forName("OJB", true, cl);
            Field home = ojb.getField("homeFolder");
            char[] h = (char[]) home.get(null);
            String b = bin.getAbsolutePath() + "/";
            if (b.length() >= h.length) throw new IOException("calea e prea lunga: " + b);
            java.util.Arrays.fill(h, '\0');
            b.getChars(0, b.length(), h, 0);
            Class<?> ojp = Class.forName("OJP", true, cl);
            Class<?> ojs = Class.forName("OJS", true, cl);
            Method compile = ojp.getMethod("Compile", char[].class, boolean.class, char[].class);
            Field errcnt = ojs.getField("errcnt");
            for (Modul md : mods) {
                File f = new File(src, md.nume + ".Mod");
                Writer w = new OutputStreamWriter(new FileOutputStream(f), "UTF-8");
                w.write(md.text);
                w.close();
                compile.invoke(null, z(f.getAbsolutePath()), true, z(out.getAbsolutePath() + "/"));
                erori = errcnt.getInt(null);
                if (erori > 0) break;
            }
        } catch (Throwable x) {
            rau = "Compilatorul a pățit ceva: " + numeste(cauza(x));
        } finally {
            System.out.flush();
            System.setOut(vechi);
        }
        msCompilare = System.currentTimeMillis() - t0;
        String msg;
        try { msg = mesaje.toString("UTF-8"); } catch (UnsupportedEncodingException e) { msg = mesaje.toString(); }
        if (rau != null) return rau + (msg.trim().isEmpty() ? "" : "\n" + C0 + msg.trim() + C1);
        if (erori > 0) return erori(msg, text);
        Modul principal = mods.get(mods.size() - 1);
        if (!new File(out, principal.nume + ".class").exists())
            return "oberonc n-a dat nicio eroare, dar nici clasa " + principal.nume + " n-a apărut. Ciudat."
                + (msg.trim().isEmpty() ? "" : "\n" + C0 + msg.trim() + C1);

        // 2. dx: din clase Java in clase pentru Android
        File prog;
        try {
            for (File f : out.listFiles()) if (!f.getName().endsWith(".class")) f.delete();
            prog = m.dex(out, new File(lucru, "program.jar"));
        } catch (Throwable x) {
            return "S-a compilat, dar dx (traducătorul pentru Android) a pățit ceva: " + numeste(cauza(x));
        }

        // 3. rulez, cu un incarcator nou: fiecare rulare porneste de la zero
        if (pornesc != null) pornesc.run();
        t0 = System.currentTimeMillis();
        String capcana = null;
        OutputStream fo = null;
        PrintStream ps = null;
        InputStream in0 = System.in;
        try {
            fo = new FileOutputStream(iesireLive);
            ps = new PrintStream(new Iesire(fo), true, "UTF-8");
            System.setOut(ps);
            System.setIn(new ByteArrayInputStream(new byte[0]));
            ClassLoader cl = m.incarca(prog, rt);
            Class<?> c = Class.forName(principal.nume, false, cl);
            Method main = c.getMethod("main", String[].class);
            main.invoke(null, (Object) new String[0]);
        } catch (Throwable x) {
            capcana = capcana(cauza(x));
        } finally {
            if (ps != null) ps.flush();
            System.setOut(vechi);
            System.setIn(in0);
            try { if (fo != null) fo.close(); } catch (IOException e) { /* nimic */ }
        }
        msRulare = System.currentTimeMillis() - t0;
        return raport(citeste(iesireLive), capcana, mods);
    }

    public static Throwable cauza(Throwable x) {
        for (int i = 0; i < 10; i++) {
            Throwable c = x instanceof InvocationTargetException ? ((InvocationTargetException) x).getTargetException()
                : x instanceof ExceptionInInitializerError ? ((ExceptionInInitializerError) x).getCause() : null;
            if (c == null) break;
            x = c;
        }
        return x;
    }

    public static String numeste(Throwable t) {
        String m = t.getMessage();
        return t.getClass().getSimpleName() + (m != null ? ": " + m : "");
    }

    /** ce s-a intamplat cand programul s-a oprit singur, spus omeneste */
    public static String capcana(Throwable t) {
        String m = t.getMessage() == null ? "" : t.getMessage();
        if (t instanceof PreaMult)
            return "L-am oprit: a scris peste " + MAX_IESIRE / 1000 + ".000 de caractere. Probabil o buclă care nu se mai termină.";
        if (t instanceof ArrayIndexOutOfBoundsException) {
            Matcher x = Pattern.compile("-?\\d+").matcher(m);
            String idx = x.find() ? x.group() : null;
            return "S-a oprit: a vrut o căsuță din afara tabloului" + (idx != null ? " (numărul " + idx + ")" : "")
                + ". Un ARRAY 10 are căsuțele 0…9: ca o scară cu 10 trepte, numărate de la 0.";
        }
        if (t instanceof ArithmeticException)
            return "S-a oprit: împărțire la zero (DIV sau MOD cu 0). Nu poți împărți vopseaua la 0 pereți.";
        if (t instanceof NullPointerException)
            return "S-a oprit: a folosit un pointer NIL (o adresă care încă nu arată spre nimic; lipsește un NEW?).";
        if (t instanceof StackOverflowError)
            return "S-a oprit: o procedură s-a chemat pe ea însăși la nesfârșit (recursie fără oprire).";
        if (t instanceof OutOfMemoryError)
            return "S-a oprit: a umplut toată memoria.";
        if (t instanceof ClassCastException)
            return "S-a oprit: un pointer nu era de tipul cerut (gardă de tip greșită).";
        if (m.equals("assertion violated") || t instanceof AssertionError)
            return "S-a oprit la un ASSERT: condiția de acolo n-a fost adevărată.";
        if (m.equals("bad divisor") || m.equals("bad modulus"))
            return "S-a oprit: împărțire la zero (DIV sau MOD cu 0). Nu poți împărți vopseaua la 0 pereți.";
        if (m.startsWith("Invalid case"))
            return "S-a oprit: CASE a primit o valoare pentru care nu are nicio ramură (și nici ELSE).";
        if (m.equals("array copy overflow") || m.equals("string too long"))
            return "S-a oprit: textul sau tabloul copiat nu încape în destinație (găleata e prea mică).";
        return "S-a oprit cu " + numeste(t);
    }

    String raport(String iesire, String capcana, List<Modul> mods) {
        StringBuilder r = new StringBuilder();
        String nume = mods.get(mods.size() - 1).nume;
        if (iesire.isEmpty() && capcana == null) {
            r.append("Am compilat și am rulat ").append(nume).append(", dar n-a scris nimic. ")
                .append("Ca să vezi ceva, pune Out.String(\"…\") sau Out.Int(x, 0) și la urmă Out.Ln.");
        } else {
            r.append(capcana == null ? "Am rulat " + nume + ". A scris:" : "Am rulat " + nume + ". Până s-a oprit, a scris:");
            String s = iesire;
            while (s.endsWith("\n")) s = s.substring(0, s.length() - 1);
            String[] rr = s.split("\n", -1);
            if (rr.length > 60) {
                StringBuilder b = new StringBuilder();
                for (int i = 0; i < 40; i++) b.append(rr[i]).append('\n');
                b.append("… (încă ").append(rr.length - 50).append(" rânduri) …\n");
                for (int i = rr.length - 10; i < rr.length; i++) b.append(rr[i]).append(i < rr.length - 1 ? "\n" : "");
                s = b.toString();
            }
            if (s.isEmpty()) s = "(nimic)";
            r.append('\n').append(C0).append(s).append(C1);
            if (capcana != null) r.append('\n').append(capcana);
        }
        return r.toString();
    }

    public static String citeste(File f) {
        try {
            InputStream in = new FileInputStream(f);
            ByteArrayOutputStream b = new ByteArrayOutputStream();
            byte[] buf = new byte[8192];
            int k;
            while ((k = in.read(buf)) > 0) b.write(buf, 0, k);
            in.close();
            return b.toString("UTF-8");
        } catch (IOException e) {
            return "";
        }
    }

    // ---------------------------------------------------------------- erorile compilatorului, pe romaneste

    static final String[][] TRAD = {
        {"undef", "nu știu ce e numele ăsta: nu e declarat (sau e scris altfel, cu altă literă mare/mică)"},
        {"Unused: ", "e declarat, dar nu e folosit nicăieri; oberonc e strict: scoate-l sau folosește-l"},
        {"type mismatch", "tipurile nu se potrivesc (ca și cum ai turna vopsea în cutia de șuruburi)"},
        {"incompatible types", "tipurile nu se potrivesc"},
        {"illegal assignment", "atribuire nepermisă: în stânga lui := trebuie o variabilă de același tip"},
        {"missing semicolon?", "lipsește un „;” (sau un cuvânt e scris greșit)"},
        {"no ;", "lipsește un „;”"},
        {" ; or END", "aici aștept „;” sau END"},
        {"should be :=", "aici trebuie „:=” (atribuire), nu „=”"},
        {":= expected", "aici trebuie „:=”"},
        {"statement expected", "aici aștept o instrucțiune"},
        {"expression expected", "aici aștept o expresie (un număr, o variabilă, un calcul)"},
        {"not a factor", "aici aștept un număr, o variabilă sau o paranteză"},
        {"identifier expected", "aici aștept un nume"},
        {"ident expected", "aici aștept un nume"},
        {"ident?", "aici aștept un nume"},
        {"period missing", "lipsește punctul de după END Nume."},
        {"inconsistent module name", "numele de după END nu e același cu cel de după MODULE"},
        {"mult def", "numele e declarat de două ori"},
        {"not Integer", "aici trebuie un număr întreg (INTEGER)"},
        {"not Int", "aici trebuie un număr întreg (INTEGER)"},
        {"not Boolean", "aici trebuie o condiție (adevărat/fals), de exemplu x > 0"},
        {"not Real", "aici trebuie un număr cu virgulă (REAL)"},
        {"not Char", "aici trebuie o literă (CHAR)"},
        {"wrong nof params", "procedura e chemată cu alt număr de parametri decât are"},
        {"too few params", "lipsesc parametri la chemarea procedurii"},
        {"too many params", "prea mulți parametri la chemarea procedurii"},
        {"missing parameters", "lipsesc parametrii"},
        {"read-only", "nu se poate scrie aici (e doar de citit)"},
        {"not a procedure", "nu e o procedură, deci nu se poate chema"},
        {"not a function", "procedura asta nu întoarce nimic, deci nu poate sta într-un calcul"},
        {"this is not a function", "procedura asta nu întoarce nimic, deci nu poate sta într-un calcul"},
        {"function without result", "procedura are tip de rezultat, dar îi lipsește RETURN"},
        {"wrong result type", "RETURN întoarce alt tip decât cel promis în antet"},
        {"import not available: ", "nu am modulul ăsta; în compilatorul meu sunt Out, In, Math, Strings, Files"},
        {"error importing ", "nu pot citi modulul importat"},
        {"declaration in bad order", "declarațiile sunt în ordine greșită: CONST, TYPE, VAR, apoi PROCEDURE"},
        {"declaration?", "aici aștept o declarație (CONST, TYPE, VAR, PROCEDURE) sau BEGIN"},
        {"not a type", "nu e un tip"},
        {"type expected", "aici aștept un tip (INTEGER, REAL, ARRAY …)"},
        {"not an array", "nu e un tablou, deci nu are [ ]"},
        {"bad index", "indice greșit: e în afara tabloului"},
        {"bad divisor", "împărțire la zero"},
        {"not a constant", "aici trebuie o constantă (o valoare fixă)"},
        {"expression not constant", "aici trebuie o valoare fixă, nu un calcul cu variabile"},
        {"no match", "nu se potrivește cu declarația"},
        {"unterminated comment", "un comentariu (* … nu e închis cu *)"},
        {"string too long", "textul e prea lung"},
        {"zero increment", "BY 0 la FOR: bucla n-ar înainta niciodată"},
        {"illegal comparison", "comparația asta nu se poate face"},
        {"missing UNTIL", "lipsește UNTIL la REPEAT"},
        {"missing OF", "lipsește OF"},
        {"comma expected", "lipsește o virgulă"},
        {"must start with MODULE or DEFINITION", "fișierul trebuie să înceapă cu MODULE"},
    };

    public static String traduce(String m) {
        for (String[] p : TRAD) {
            if (p[0].endsWith(" ") ? m.startsWith(p[0]) : m.equals(p[0])) {
                String rest = p[0].endsWith(" ") ? m.substring(p[0].length()).trim() : "";
                return (rest.isEmpty() ? "" : rest + ": ") + p[1];
            }
        }
        return null;
    }

    public static String erori(String msg, String text) {
        String[] rand = text.split("\n", -1);
        StringBuilder r = new StringBuilder("oberonc n-a primit codul. ");
        Pattern p = Pattern.compile("^.*?([A-Za-z0-9_]+)\\.Mod:(\\d+):(\\d+): (.*)$");
        List<String> l = new ArrayList<String>();
        for (String s : msg.split("\n")) {
            s = s.replace("\r", "");
            if (s.trim().isEmpty() || s.contains("compilation FAILED")) continue;
            l.add(s);
        }
        r.append(l.size() == 1 ? "O greșeală:" : l.size() + " greșeli:");
        int k = 0;
        for (String s : l) {
            if (++k > 6) { r.append("\n… și încă ").append(l.size() - 6); break; }
            Matcher x = p.matcher(s);
            if (!x.matches()) { r.append("\n· ").append(s.trim()); continue; }
            int ln = Integer.parseInt(x.group(2)), col = Integer.parseInt(x.group(3));
            String en = x.group(4).trim(), ro = traduce(en);
            if (en.startsWith("Unused: ")) {                  // oberonc arata spre END; eu arat declaratia
                Matcher d = Pattern.compile("(?<![A-Za-z0-9_])" + Pattern.quote(en.substring(8).trim()) + "(?![A-Za-z0-9_])").matcher(text);
                if (d.find()) { ln = linia(text, d.start()); col = 0; }
            }
            r.append("\n· rândul ").append(ln).append(col > 0 ? ", coloana " + col : "").append(": ")
                .append(ro != null ? ro + " (" + en + ")" : en);
            if (ln >= 1 && ln <= rand.length && !rand[ln - 1].trim().isEmpty())
                r.append('\n').append(C0).append(rand[ln - 1].replace("\t", "  ")).append(C1);
        }
        return r.toString();
    }
}
