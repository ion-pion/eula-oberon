package ro.jahbalon.eulaoberon;

import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

/**
 * Puntea spre modulele Oberon. oberonc pune clasele fara pachet (Eula, Iesire, Motor…), iar Java nu le poate numi
 * dintr-un pachet, asa ca le cheama prin reflectie. Toate apelurile trec prin LOCK: modulele Oberon au o singura
 * stare, ca un sistem Oberon adevarat.
 */
final class Oberon {
    static final Object LOCK = new Object();
    static Method porneste, salut, incarcaFoto, salveazaFoto, goleste, mananca, mancat, pareCod, intreaba, sursaInvatat, invatat, verifica, stare;
    static Field fR, fNota, fStare;

    static void init() throws Exception {
        Class<?> e = Class.forName("Eula"), i = Class.forName("Iesire"), m = Class.forName("Motor");
        porneste = e.getMethod("Porneste", char[].class);
        salut = e.getMethod("Salut");
        incarcaFoto = e.getMethod("IncarcaFoto", char[].class, char[].class);
        salveazaFoto = e.getMethod("SalveazaFoto", char[].class, char[].class);
        goleste = e.getMethod("Goleste");
        mananca = e.getMethod("Mananca", char[].class, int.class, char[].class);
        mancat = e.getMethod("Mancat", int.class);
        pareCod = e.getMethod("PareCod", char[].class, int.class);
        intreaba = e.getMethod("Intreaba", char[].class);
        sursaInvatat = e.getMethod("SursaInvatat", char[].class);
        invatat = e.getMethod("Invatat", char[].class);
        verifica = e.getMethod("Verifica", char[].class, int.class);
        stare = e.getMethod("Stare");
        fR = i.getField("r");
        fNota = m.getField("nota");
        fStare = e.getField("stare");
    }

    /** sir Java -> ARRAY OF CHAR cu 0X la sfarsit */
    static char[] z(String s) {
        char[] c = new char[s.length() + 1];
        s.getChars(0, s.length(), c, 0);
        return c;
    }

    static String s(char[] a) {
        int k = 0;
        while (k < a.length && a[k] != 0) k++;
        return new String(a, 0, k);
    }

    static Object call(Method m, Object... args) throws Exception {
        try {
            return m.invoke(null, args);
        } catch (InvocationTargetException x) {
            Throwable c = x.getCause();
            if (c instanceof Exception) throw (Exception) c;
            throw new RuntimeException(c);
        }
    }

    static void porneste(String dir) throws Exception { call(porneste, (Object) z(dir)); }
    static String salut() throws Exception { call(salut); return raspuns(); }
    static boolean incarcaFoto(String cale, String cheie) throws Exception { return (Boolean) call(incarcaFoto, z(cale), z(cheie)); }
    static boolean salveazaFoto(String cale, String cheie) throws Exception { return (Boolean) call(salveazaFoto, z(cale), z(cheie)); }
    static void goleste() throws Exception { call(goleste); }
    static int mananca(String text, String sursa) throws Exception { return (Integer) call(mananca, z(text), text.length(), z(sursa)); }
    static String mancat(int k) throws Exception { call(mancat, k); return raspuns(); }
    static boolean pareCod(String t) throws Exception { return (Boolean) call(pareCod, z(t), t.length()); }
    static int intreaba(String q) throws Exception { return (Integer) call(intreaba, (Object) z(q)); }
    static String sursaInvatat() throws Exception { char[] d = new char[300]; call(sursaInvatat, (Object) d); return s(d); }
    static String invatat(String q) throws Exception { call(invatat, (Object) z(q)); return raspuns(); }
    static String verifica(String t) throws Exception { call(verifica, z(t), t.length()); return raspuns(); }
    static String stare() throws Exception { call(stare); return s((char[]) fStare.get(null)); }
    static String raspuns() throws Exception { return s((char[]) fR.get(null)); }
    static String nota() throws Exception { return s((char[]) fNota.get(null)); }
}
