import java.io.*;
import java.util.Arrays;

/** Dosar (vezi def/Dosar.Mod): fisierele, cu un dosar curent al shell-ului */
public final class Dosar {
    private Dosar() {}
    static File curent = new File(System.getProperty("user.dir", "/"));
    static File acasa = curent;
    private static String[] lista = new String[0];

    static File f(String c) {
        if (c.equals("~")) return acasa;
        if (c.startsWith("~/")) return new File(acasa, c.substring(2));
        File x = new File(c);
        return x.isAbsolute() ? x : new File(curent, c);
    }
    static File f(char[] c) { return f(Sir.s(c)); }
    static String canon(File x) { try { return x.getCanonicalPath(); } catch (IOException e) { return x.getAbsolutePath(); } }

    public static void Acasa(char[] s) { Sir.pune(acasa.getPath(), s); }
    public static void Curent(char[] s) { Sir.pune(curent.getPath(), s); }
    public static boolean Schimba(char[] c) {
        String t = Sir.s(c);
        File x = t.isEmpty() ? acasa : f(t);
        if (!x.isDirectory()) return false;
        curent = new File(canon(x));
        return true;
    }
    public static void Cale(char[] n, char[] abs) { Sir.pune(canon(f(n)), abs); }
    public static boolean Exista(char[] c) { return f(c).exists(); }
    public static boolean EsteDosar(char[] c) { return f(c).isDirectory(); }
    public static int Marime(char[] c) { long n = f(c).length(); return n > Integer.MAX_VALUE ? Integer.MAX_VALUE : (int) n; }
    public static int Lista(char[] c) {
        String t = Sir.s(c);
        File d = t.isEmpty() ? curent : f(t);
        String[] l = d.list();
        if (l == null) { lista = new String[0]; return -1; }
        Arrays.sort(l, String.CASE_INSENSITIVE_ORDER);
        lista = l;
        return l.length;
    }
    public static void Nume(int i, char[] s) { Sir.pune(i >= 0 && i < lista.length ? lista[i] : "", s); }
    public static boolean Creeaza(char[] c) { File x = f(c); return x.isDirectory() || x.mkdirs(); }
    public static boolean Sterge(char[] c) { return f(c).delete(); }
    public static boolean Muta(char[] a, char[] b) {
        File x = f(a), y = f(b);
        if (y.isDirectory()) y = new File(y, x.getName());
        return x.renameTo(y);
    }
    public static boolean Copiaza(char[] a, char[] b) {
        File x = f(a), y = f(b);
        if (y.isDirectory()) y = new File(y, x.getName());
        if (!x.isFile()) return false;
        try {
            InputStream i = new FileInputStream(x);
            OutputStream o = new FileOutputStream(y);
            byte[] buf = new byte[65536];
            int k;
            while ((k = i.read(buf)) > 0) o.write(buf, 0, k);
            o.close(); i.close();
            return true;
        } catch (IOException e) { return false; }
    }
}
