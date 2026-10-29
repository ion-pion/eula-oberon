import ro.jahbalon.oberonapp.Vorbire;

/** Conversatie (vezi sistem/def/Conversatie.Mod): aplicatiile Oberon care vorbesc. Pielea e in Vorbire. */
public final class Conversatie {
    private Conversatie() {}

    static String s(char[] c) { int k = 0; while (k < c.length && c[k] != 0) k++; return new String(c, 0, k); }
    static void pune(String s, char[] d) { if (s == null) s = ""; int n = Math.min(s.length(), d.length - 1); s.getChars(0, n, d, 0); d[n] = 0; }

    public static void Titlu(char[] t) { Vorbire.titlu(s(t)); }
    public static void Stare(char[] t) { Vorbire.stare(s(t)); }
    public static void Spune(int culoare, char[] cine, char[] ce) { Vorbire.spune(culoare, s(cine), s(ce)); }
    public static void Buton(int nr, char[] e, int fond, int scris) { Vorbire.buton(nr, s(e), fond, scris); }
    public static int Apasat() { return Vorbire.apasat(); }
    public static void Intrare(char[] d) { pune(Vorbire.intrare(), d); }
    public static void AlegeFisier() { Vorbire.alege(); }
    public static void Ales(char[] c, char[] n) { pune(Vorbire.alesCale, c); pune(Vorbire.alesNume, n); }
    public static void Dosar(char[] d) { pune(Vorbire.dosar(), d); }
    public static boolean Resursa(char[] n, char[] c) {
        String f = Vorbire.resursa(s(n));
        if (f == null) return false;
        pune(f, c);
        return true;
    }
    public static boolean Adauga(char[] cale, byte[] b, int n) { return Vorbire.adauga(s(cale), b, n); }
    public static void Acum(char[] d) { pune("" + System.currentTimeMillis(), d); }
    public static int Ms() { return Vorbire.ms(); }
    public static void Tine(char[] k, char[] v) { Vorbire.tine(s(k), s(v)); }
    public static void Setare(char[] k, char[] v) { pune(Vorbire.setare(s(k)), v); }
    public static int Aduce(char[] a, char[] cale, char[] fin, char[] tip) {
        int r = Vorbire.aduce(s(a), s(cale));
        pune(ro.jahbalon.oberonapp.Plasa.finala, fin); pune(ro.jahbalon.oberonapp.Plasa.tip, tip);
        return r;
    }
    public static boolean Descarcari(char[] d) { String x = Vorbire.descarcari(); if (x == null) return false; pune(x, d); return true; }
    public static void Ceas(int ms) { Vorbire.ceas(ms); }
}
